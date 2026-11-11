import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accounting_system/data/app_database.dart';
import 'package:accounting_system/data/accounting_repository.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late AccountingRepository repo;
  setUp(()async{
    directory=await Directory.systemTemp.createTemp('accounting_test_');
    database=await AppDatabase.open(demo:true,filePath:'${directory.path}/demo.db',factory:databaseFactoryFfi);
    repo=AccountingRepository(database);
    await repo.login('demo','Demo@2026!');
  });
  tearDown(()async{await database.close();await directory.delete(recursive:true);});
  Map<String,Object?> header()=>{'TransDate':DateTime.now().toIso8601String().substring(0,10),'WarehouseId':1,'PaymentMethod':'Cash','CashboxId':1,'Notes':'test'};
  Map<String,Object?> line(int qty,int price)=>{'ItemId':101,'ItemUnitId':1011,'Qty':qty,'Price':price,'Discount':0,'Tax':0};

  test('repository posts atomically, rejects duplicates, persists after reopen',()async{
    final purchase=await repo.saveInvoice(1,header(),[line(10000,1000)]);
    expect(await repo.inventory(),isEmpty);
    await repo.saveInvoice(1,header(),[line(12000,1000)],id:purchase);
    await repo.post('invoice',purchase,1);
    final sale=await repo.saveInvoice(2,header(),[line(3000,1500)]);
    await repo.post('invoice',sale,2);
    expect((await repo.inventory()).single['QtyBase'],9000);
    await expectLater(repo.post('invoice',purchase,1),throwsA(isA<DatabaseException>()));
    final file=database.db.path;
    await database.close();
    database=await AppDatabase.open(demo:true,filePath:file,factory:databaseFactoryFfi);
    repo=AccountingRepository(database)..userId=1;
    expect((await repo.inventory()).single['QtyBase'],9000);
    expect(await database.db.rawQuery('PRAGMA foreign_key_check'),isEmpty);
  });

  test('repository refuses an unbalanced journal and rolls back late failure',()async{
    final journal=await repo.saveJournal({'EntryDate':header()['TransDate']},[{'AccountId':1110,'Debit':100,'Credit':0},{'AccountId':3100,'Debit':0,'Credit':99}]);
    await expectLater(repo.post('journal',journal),throwsA(isA<DatabaseException>()));
    final invoice=await repo.saveInvoice(1,header(),[line(1000,1000)]);
    await database.db.execute("CREATE TRIGGER injected_failure BEFORE INSERT ON AuditLogs WHEN NEW.EntityName='Trans' AND NEW.Action='post' BEGIN SELECT RAISE(ABORT,'test failure'); END");
    await expectLater(repo.post('invoice',invoice,1),throwsA(isA<DatabaseException>()));
    expect(await repo.inventory(),isEmpty);
    expect(await database.db.query('InventoryMovements'),isEmpty);
    expect((await repo.invoices(1)).single['Status'],'Draft');
  });

  test('production setup and role enforcement',()async{
    final production=await AppDatabase.open(filePath:'${directory.path}/production.db',factory:databaseFactoryFfi);
    final manager=AccountingRepository(production);
    expect(await manager.needsSetup(),isTrue);
    await manager.createAdministrator('owner','StrongLocalPassword!');
    await manager.login('owner','StrongLocalPassword!');
    await manager.authorize('admin');
    await expectLater(manager.createAdministrator('other','AnotherPassword!'),throwsStateError);
    manager.logout();
    await expectLater(manager.accounts(),throwsStateError);
    await production.close();
  });

  test('fresh Android metadata does not block first migration',()async{
    final file='${directory.path}/android_like.db';
    final raw=await databaseFactoryFfi.openDatabase(file);
    await raw.execute('CREATE TABLE android_metadata(locale TEXT)');
    await raw.execute("INSERT INTO android_metadata VALUES('en_US')");
    await raw.close();
    final created=await AppDatabase.open(demo:true,filePath:file,factory:databaseFactoryFfi);
    expect((await created.db.query('DocTyp')).length,7);
    await created.close();
  });
}
