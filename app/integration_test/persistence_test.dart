import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:accounting_system/data/app_database.dart';
import 'package:accounting_system/data/accounting_repository.dart';
import 'package:accounting_system/main.dart' as application;

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline=DateTime.now().add(const Duration(seconds:90));
  while(finder.evaluate().isEmpty){
    if(DateTime.now().isAfter(deadline)){
      fail('Android UI did not reach the expected state: $finder');
    }
    await tester.pump(const Duration(milliseconds:200));
    final error=tester.takeException();
    if(error!=null){throw error;}
  }
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  // ListView builds children lazily. Older devices may keep a button outside
  // the built viewport, so ensureVisible alone cannot find its element.
  await tester.scrollUntilVisible(finder,200,scrollable:find.byType(Scrollable).first,maxScrolls:30);
  await tester.pumpAndSettle();
}

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android sqflite create/read/edit/post and reopen',(tester)async{
    final file=path.join(await getDatabasesPath(),'integration_only.db');
    await deleteDatabase(file);
    var db=await AppDatabase.open(demo:true,filePath:file);
    var repo=AccountingRepository(db);
    await repo.login('demo','Demo@2026!');
    final header=<String,Object?>{'TransDate':DateTime.now().toIso8601String().substring(0,10),'WarehouseId':1,'PaymentMethod':'Cash','CashboxId':1,'Notes':'Android persistence'};
    Map<String,Object?> line(int qty)=>{'ItemId':101,'ItemUnitId':1011,'Qty':qty,'Price':1000,'Discount':0,'Tax':0};
    final invoice=await repo.saveInvoice(1,header,[line(1000)]);
    await repo.saveInvoice(1,header,[line(2000)],id:invoice);
    expect((await repo.invoices(1)).single['Total'],2000);
    await repo.post('invoice',invoice,1);
    await db.close();
    db=await AppDatabase.open(demo:true,filePath:file);
    repo=AccountingRepository(db);
    await repo.login('demo','Demo@2026!');
    expect((await repo.inventory()).single['QtyBase'],2000);
    expect(await db.db.rawQuery('PRAGMA foreign_key_check'),isEmpty);
    await db.close();
    await deleteDatabase(file);
  });

  testWidgets('Android login, purchase editor, posting and inventory use SQLite',(tester)async{
    final file=path.join(await getDatabasesPath(),'integration_ui_only.db');
    await deleteDatabase(file);
    final db=await AppDatabase.open(demo:true,filePath:file);
    final repo=AccountingRepository(db);
    try{
      await tester.pumpWidget(application.AccountingApp(repository:repo));
      await waitFor(tester,find.text('تسجيل الدخول'));
      await tester.enterText(find.byType(TextFormField).at(0),'demo');
      await tester.enterText(find.byType(TextFormField).at(1),'Demo@2026!');
      await tester.tap(find.widgetWithText(FilledButton,'دخول'));
      await waitFor(tester,find.text('دليل الأصناف'));

      await tester.tap(find.text('دليل الأصناف'));
      await waitFor(tester,find.textContaining('حليب'));
      await tester.tap(find.byType(BackButton).first);
      await waitFor(tester,find.text('فواتير المشتريات'));
      await tester.tap(find.text('فواتير المشتريات'));
      await waitFor(tester,find.byType(FloatingActionButton));
      await tester.tap(find.byType(FloatingActionButton));
      await waitFor(tester,find.text('فواتير المشتريات · مسودة'));
      await reveal(tester,find.text('إضافة صنف'));
      await tester.tap(find.text('إضافة صنف'));
      await waitFor(tester,find.text('تفاصيل الصنف'));
      final quantity=find.widgetWithText(TextFormField,'الكمية');
      final price=find.widgetWithText(TextFormField,'سعر الوحدة');
      await tester.ensureVisible(quantity);
      await tester.pumpAndSettle();
      await tester.enterText(quantity,'2');
      await tester.ensureVisible(price);
      await tester.pumpAndSettle();
      await tester.enterText(price,'10');
      await tester.tap(find.text('اعتماد السطر'));
      await tester.pumpAndSettle();
      await reveal(tester,find.text('حفظ المسودة'));
      await tester.tap(find.text('حفظ المسودة'));
      await waitFor(tester,find.textContaining('فاتورة 1'));
      expect((await repo.invoices(1)).single['Total'],2000);
      await tester.tap(find.textContaining('فاتورة 1'));
      await waitFor(tester,find.text('ترحيل المستند'));
      await tester.ensureVisible(find.text('ترحيل المستند'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ترحيل المستند'));
      await waitFor(tester,find.textContaining('مرحّلة'));
      expect((await repo.inventory()).single['QtyBase'],2000);
      expect(await db.db.rawQuery('PRAGMA foreign_key_check'),isEmpty);

      await tester.tap(find.byType(BackButton).first);
      await waitFor(tester,find.text('النظام المحاسبي'));
      await reveal(tester,find.text('المخزون'));
      await tester.tap(find.text('المخزون'));
      await waitFor(tester,find.textContaining('حليب'));
      expect(find.textContaining('2.000'),findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await deleteDatabase(file);
    }
  });
}
