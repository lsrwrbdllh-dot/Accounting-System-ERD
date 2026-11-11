import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:accounting_system/data/app_database.dart';
import 'package:accounting_system/data/accounting_repository.dart';

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
}
