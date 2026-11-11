import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accounting_system/data/app_database.dart';
import 'package:accounting_system/data/accounting_repository.dart';
import 'package:accounting_system/main.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('Arabic login uses the real database', (tester)async{
    final db=await AppDatabase.open(demo:true,filePath:inMemoryDatabasePath,factory:databaseFactoryFfi);
    await tester.pumpWidget(AccountingApp(repository:AccountingRepository(db)));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'),findsOneWidget);
    expect(find.byType(TextFormField),findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).first,'demo');
    expect(await db.db.query('Trans'),isEmpty);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
