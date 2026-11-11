import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  final Database db;
  final bool demo;
  AppDatabase._(this.db, this.demo);

  static Future<AppDatabase> open({bool demo = false, String? filePath, DatabaseFactory? factory}) async {
    final bundle = jsonDecode(await rootBundle.loadString('assets/database.json')) as Map<String, dynamic>;
    final migrations = (bundle['migrations'] as List).cast<Map<String, dynamic>>();
    final seeds = bundle['seeds'] as Map<String, dynamic>;
    final selectedFactory = factory ?? databaseFactory;
    final file = filePath ?? path.join(await selectedFactory.getDatabasesPath(), demo ? 'accounting_demo.db' : 'accounting_production.db');
    Future<void> apply(DatabaseExecutor executor, int old, int next) async {
      if (old == 0) {
        final existing = await executor.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name<>'android_metadata'");
        if (existing.isNotEmpty) { throw StateError('قاعدة قديمة غير مرقمة؛ يلزم نسخ احتياطي وتحويل منفصل'); }
        await executor.execute('CREATE TABLE SchemaMigrations(Version INTEGER PRIMARY KEY,Name TEXT NOT NULL,Checksum TEXT NOT NULL)');
      }
      for (final migration in migrations) {
        final version = migration['version'] as int;
        if (version <= old) {
          final rows = await executor.query('SchemaMigrations', where: 'Version=?', whereArgs: [version]);
          if (rows.isEmpty || rows.first['Checksum'] != migration['sha256']) { throw StateError('تغيّر ملف تحديث مطبق'); }
        } else if (version <= next) {
          for (final statement in (migration['statements'] as List).cast<String>()) { await executor.execute(statement); }
          await executor.insert('SchemaMigrations', {'Version':version, 'Name':migration['name'], 'Checksum':migration['sha256']});
        }
      }
      if (old == 0) {
        for (final name in ['production', if (demo) 'demo']) {
          for (final statement in ((seeds[name] as Map)['statements'] as List).cast<String>()) { await executor.execute(statement); }
        }
      }
    }
    final db = await selectedFactory.openDatabase(file, options: OpenDatabaseOptions(
      version: migrations.length,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        await db.execute('PRAGMA recursive_triggers=ON');
        await db.execute('PRAGMA busy_timeout=10000');
      },
      onCreate: (db, version) => apply(db, 0, version),
      onUpgrade: apply,
      onDowngrade: (db, old, next) async { throw StateError('لا يُسمح بتخفيض إصدار القاعدة'); },
      onOpen: (db) async {
        if (Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')) != 1) { throw StateError('المفاتيح الأجنبية غير مفعلة'); }
        final mode = await db.query('AppSettings', where: 'SettingKey=?', whereArgs: ['environment']);
        if (mode.first['SettingValue'] != (demo ? 'demo' : 'production')) { throw StateError('قاعدة التجربة منفصلة عن الإنتاج'); }
        for (final migration in migrations) {
          final saved = await db.query('SchemaMigrations', where: 'Version=?', whereArgs: [migration['version']]);
          if (saved.isEmpty || saved.first['Checksum'] != migration['sha256']) { throw StateError('تعذر التحقق من سجل التحديثات'); }
        }
      },
    ));
    return AppDatabase._(db, demo);
  }

  Future<void> close() => db.close();
}
