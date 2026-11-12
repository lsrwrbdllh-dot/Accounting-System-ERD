import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accounting_system/data/app_database.dart';
import 'package:accounting_system/data/accounting_repository.dart';
import 'package:accounting_system/main.dart';
import 'package:accounting_system/ui/home_page.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    // Prepare real SQLite outside the widget test's fake clock. In-process FFI
    // avoids waiting on isolate messages while fake async is being pumped.
    db=await AppDatabase.open(demo:true,filePath:inMemoryDatabasePath,factory:databaseFactoryFfiNoIsolate);
  });
  tearDown(() async { await db.close(); });
  testWidgets('Arabic login uses the real database', (tester)async{
    await tester.pumpWidget(AccountingApp(repository:AccountingRepository(db)));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'),findsOneWidget);
    expect(find.byType(TextFormField),findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).first,'demo');
    expect(await db.db.query('Trans'),isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Returning from a directory refreshes home without async setState',(tester)async{
    final repo=AccountingRepository(db)..userId=1;
    await tester.pumpWidget(MaterialApp(home:HomePage(repo,onLogout:(){})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دليل الأصناف'));
    await tester.pumpAndSettle();
    expect(find.textContaining('حليب'),findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    expect(find.text('النظام المحاسبي'),findsOneWidget);
    expect(find.textContaining('الصندوق 0.00'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
