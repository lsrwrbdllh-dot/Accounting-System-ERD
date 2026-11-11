import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

typedef DbRow = Map<String, Object?>;

class AccountingRepository {
  final AppDatabase database;
  int? userId;
  AccountingRepository(this.database);
  Database get db => database.db;

  Future<void> authorize(String permission, [DatabaseExecutor? executor]) async {
    final rows = await (executor ?? db).rawQuery('SELECT 1 FROM UserPermissions WHERE UserId=? AND PermissionCode=?', [userId ?? -1, permission]);
    if (rows.isEmpty) { throw StateError('ليست لديك صلاحية لهذه العملية'); }
  }

  static final _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256);
  static Future<String> hashPassword(String password) async {
    if (password.length < 10) { throw const FormatException('كلمة المرور لا تقل عن 10 أحرف'); }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
    return 'pbkdf2_sha256\$600000\$${base64Encode(salt)}\$${base64Encode(await key.extractBytes())}';
  }

  Future<bool> needsSetup() async => (await db.query('Users', limit: 1)).isEmpty;

  Future<void> createAdministrator(String username, String password) async {
    if (database.demo || username.trim().isEmpty) { throw StateError('تعذر إعداد المستخدم'); }
    final hash = await hashPassword(password);
    await db.transaction((txn) async {
      if ((await txn.query('Users', limit: 1)).isNotEmpty) { throw StateError('تم إعداد المدير مسبقًا'); }
      final id = await txn.insert('Users', {'BranchId':1, 'Username':username.trim(), 'PasswordHash':hash});
      await txn.insert('UserRoles', {'UserId':id, 'RoleId':1});
    }, exclusive: true);
  }

  Future<void> login(String username, String password) async {
    final rows = await db.query('Users', where: 'Username=? AND IsActive=1', whereArgs: [username.trim()]);
    if (rows.isEmpty) { throw StateError('اسم المستخدم أو كلمة المرور غير صحيحة'); }
    final parts = (rows.first['PasswordHash'] as String).split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256' || parts[1] != '600000') { throw StateError('صيغة كلمة المرور غير مدعومة'); }
    final actual = await _pbkdf2.deriveKeyFromPassword(password:password, nonce:base64Decode(parts[2]));
    final bytes = await actual.extractBytes();
    final expected = base64Decode(parts[3]);
    var difference = bytes.length ^ expected.length;
    for (var i=0; i<bytes.length && i<expected.length; i++) { difference |= bytes[i] ^ expected[i]; }
    if (difference != 0) { throw StateError('اسم المستخدم أو كلمة المرور غير صحيحة'); }
    userId = rows.first['UserId'] as int;
  }

  void logout() { userId = null; }

  Future<List<DbRow>> accounts([String search = '']) async {
    await authorize('read');
    return db.rawQuery('SELECT * FROM AccountBalances b JOIN Accounts a USING(AccountId) WHERE a.AccountName LIKE ? OR a.Code LIKE ? ORDER BY a.Code', ['%$search%','%$search%']);
  }

  Future<List<DbRow>> items([String search = '']) async {
    await authorize('read');
    return db.rawQuery('SELECT * FROM Stk_Item WHERE ItemName LIKE ? OR Code LIKE ? OR Barcode LIKE ? ORDER BY Code', ['%$search%','%$search%','%$search%']);
  }

  Future<List<DbRow>> lookup(String table) async {
    await authorize('read');
    const allowed = {'Units','Stk_ItemUnit','Customers','Suppliers','Cashboxes','Warehouses','FiscalPeriods'};
    if (!allowed.contains(table)) { throw ArgumentError('Unsupported lookup'); }
    return db.query(table);
  }

  Future<List<DbRow>> itemUnits(int itemId) async {
    await authorize('read');
    return db.rawQuery('SELECT u.*,n.UnitName FROM Stk_ItemUnit u JOIN Units n USING(UnitId) WHERE u.ItemId=? ORDER BY u.IsBase DESC', [itemId]);
  }

  Future<List<DbRow>> invoices(int typ, [String search = '']) async {
    await authorize('read');
    return db.rawQuery('SELECT t.*,o.Outstanding FROM Trans t LEFT JOIN InvoiceOutstanding o ON t.TransId=o.TransId AND t.Typ=o.Typ WHERE t.Typ=? AND (CAST(t.TransId AS TEXT) LIKE ? OR t.Notes LIKE ?) ORDER BY t.TransId DESC',[typ,'%$search%','%$search%']);
  }

  Future<List<DbRow>> invoiceLines(int id,int typ) async {
    await authorize('read');
    return db.rawQuery('SELECT d.*,i.ItemName,u.UnitName FROM TransDt d JOIN Stk_Item i USING(ItemId) JOIN Stk_ItemUnit n USING(ItemUnitId) JOIN Units u USING(UnitId) WHERE d.TransId=? AND d.Typ=? ORDER BY d.LineNo',[id,typ]);
  }

  Future<List<DbRow>> vouchers(int typ,[String search='']) async {
    await authorize('read');
    return db.rawQuery('SELECT * FROM Mstndat WHERE Typ=? AND (CAST(VoucherId AS TEXT) LIKE ? OR Description LIKE ?) ORDER BY VoucherId DESC',[typ,'%$search%','%$search%']);
  }

  Future<List<DbRow>> journals([String search='']) async {
    await authorize('read');
    return db.rawQuery('SELECT j.*,coalesce(sum(y.Debit),0) AS Amount FROM JournalEntries j LEFT JOIN Yomia y USING(JournalId) WHERE CAST(j.JournalId AS TEXT) LIKE ? OR j.Description LIKE ? GROUP BY j.JournalId ORDER BY j.JournalId DESC',['%$search%','%$search%']);
  }

  Future<List<DbRow>> documentLines(String family,int id,[int? typ]) async {
    await authorize('read');
    if (family=='journal') { return db.rawQuery('SELECT y.*,a.AccountName FROM Yomia y JOIN Accounts a USING(AccountId) WHERE y.JournalId=? ORDER BY y.LineNo',[id]); }
    if (family=='voucher') { return db.rawQuery('SELECT d.*,a.AccountName FROM VoucherDt d JOIN Accounts a USING(AccountId) WHERE d.VoucherId=? AND d.Typ=? ORDER BY d.LineNo',[id,typ]); }
    throw ArgumentError('Unsupported document');
  }

  Future<List<DbRow>> allocations(int id,int typ) async {
    await authorize('read');
    return db.query('PaymentAllocation',where:'VoucherId=? AND VoucherTyp=?',whereArgs:[id,typ]);
  }

  Future<List<DbRow>> outstanding(int typ) async {
    await authorize('read');
    return db.rawQuery('SELECT o.*,t.CustomerId,t.SupplierId FROM InvoiceOutstanding o JOIN Trans t ON t.TransId=o.TransId AND t.Typ=o.Typ WHERE o.Typ=? AND o.Outstanding>0 ORDER BY o.TransId',[typ]);
  }

  Future<List<DbRow>> inventory([String search='']) async {
    await authorize('read');
    return db.rawQuery('SELECT s.*,i.ItemName,w.WarehouseName,b.LotNumber FROM StockBalances s JOIN Stk_Item i USING(ItemId) JOIN Warehouses w USING(WarehouseId) LEFT JOIN ItemBatches b USING(BatchId) WHERE i.ItemName LIKE ? OR i.Code LIKE ? ORDER BY w.WarehouseName,i.Code',['%$search%','%$search%']);
  }

  Future<void> _audit(DatabaseExecutor txn,String entity,String key,String action) => txn.insert('AuditLogs',{'UserId':userId,'EntityName':entity,'EntityKey':key,'Action':action}).then((_) {});

  Future<void> saveAccount(DbRow values,{int? id}) async {
    await db.transaction((txn) async {
      await authorize('write',txn);
      final key = id ?? await txn.insert('Accounts', values);
      if (id!=null) { await txn.update('Accounts',values,where:'AccountId=?',whereArgs:[id]); }
      await _audit(txn,'Accounts','$key','save');
    });
  }

  Future<void> saveItem(DbRow values,{int? id,int baseUnitId=1}) async {
    await db.transaction((txn) async {
      await authorize('write',txn);
      final key = id ?? await txn.insert('Stk_Item',values);
      if (id!=null) { await txn.update('Stk_Item',values,where:'ItemId=?',whereArgs:[id]); }
      if (id==null && values['ItemType']=='Item') { await txn.insert('Stk_ItemUnit',{'ItemId':key,'UnitId':baseUnitId,'PackingQty':1000,'IsBase':1}); }
      await _audit(txn,'Stk_Item','$key','save');
    });
  }

  Future<void> addItemUnit(int itemId,int unitId,int packing) async {
    await db.transaction((txn) async {
      await authorize('write',txn);
      await txn.insert('Stk_ItemUnit',{'ItemId':itemId,'UnitId':unitId,'PackingQty':packing,'IsBase':0});
      await _audit(txn,'Stk_Item','$itemId','add_unit');
    });
  }

  Future<int> addParty(bool supplier,String name) async {
    if (name.trim().isEmpty) { throw const FormatException('الاسم مطلوب'); }
    return db.transaction((txn) async {
      await authorize('write',txn);
      final parent=supplier?2100:1140;
      final maxId=Sqflite.firstIntValue(await txn.rawQuery('SELECT coalesce(max(AccountId),0)+1 FROM Accounts'))!;
      final account=await txn.insert('Accounts',{'Code':'${supplier?'S':'C'}$maxId','ParentAccountId':parent,'AccountName':name.trim(),'AccountType':'Sub','NormalBalance':supplier?'Credit':'Debit'});
      final key=await txn.insert(supplier?'Suppliers':'Customers',{'AccountId':account,supplier?'SupplierName':'CustomerName':name.trim()});
      await _audit(txn,supplier?'Suppliers':'Customers','$key','create');
      return key;
    },exclusive:true);
  }

  Future<int> saveInvoice(int typ,DbRow header,List<DbRow> lines,{int? id}) async {
    if (lines.isEmpty) { throw const FormatException('أضف سطرًا واحدًا على الأقل'); }
    return db.transaction((txn) async {
      await authorize('write',txn);
      final key=id ?? Sqflite.firstIntValue(await txn.rawQuery('SELECT coalesce(max(TransId),0)+1 FROM Trans WHERE Typ=?',[typ]))!;
      final values=<String,Object?>{...header,'CreatedBy':userId,'CurrencyId':1,'Subtotal':0,'Discount':0,'Tax':0,'Total':0};
      if (id!=null) {
        final existing=await txn.query('Trans',where:'TransId=? AND Typ=? AND Status=?',whereArgs:[id,typ,'Draft']);
        if (existing.isEmpty) { throw StateError('الفاتورة ليست مسودة'); }
        await txn.delete('TransDt',where:'TransId=? AND Typ=?',whereArgs:[id,typ]);
        await txn.update('Trans',values,where:'TransId=? AND Typ=?',whereArgs:[id,typ]);
      } else { await txn.insert('Trans',{'TransId':key,'Typ':typ,...values}); }
      var gross=0,discount=0,tax=0;
      final returned=<int,int>{};
      for (var i=0;i<lines.length;i++) {
        final line=Map<String,Object?>.from(lines[i]);
        line.removeWhere((k,_)=>!{'ItemId','ItemUnitId','Qty','Price','Discount','Tax','BatchId','OriginalLineNo'}.contains(k));
        var amount=((line['Qty'] as int)*(line['Price'] as int)+500)~/1000;
        if (typ==3 || typ==4) {
          final originalLine=line['OriginalLineNo'] as int?;
          if (originalLine==null) { throw const FormatException('اختر سطر الفاتورة الأصلية'); }
          final source=await txn.query('TransDt',where:'TransId=? AND Typ=? AND LineNo=?',whereArgs:[header['OriginalTransId'],header['OriginalTyp'],originalLine]);
          if (source.isEmpty) { throw StateError('السطر الأصلي غير موجود'); }
          final original=source.first;
          final previous=(Sqflite.firstIntValue(await txn.rawQuery("SELECT coalesce(sum(d.Qty),0) FROM TransDt d JOIN Trans t ON t.TransId=d.TransId AND t.Typ=d.Typ WHERE t.OriginalTransId=? AND t.OriginalTyp=? AND t.Status='Posted' AND d.OriginalLineNo=?",[header['OriginalTransId'],header['OriginalTyp'],originalLine])) ?? 0)+(returned[originalLine]??0);
          final originalQty=original['Qty'] as int;
          int portion(int value)=>(value*(previous+(line['Qty'] as int))+originalQty~/2)~/originalQty-(value*previous+originalQty~/2)~/originalQty;
          line['Discount']=portion(original['Discount'] as int);
          line['Tax']=portion(original['Tax'] as int);
          amount=portion((original['GrossAmount'] as int)-(original['Discount'] as int))+(line['Discount'] as int);
          returned[originalLine]=(returned[originalLine]??0)+(line['Qty'] as int);
        }
        line['GrossAmount']=amount;
        await txn.insert('TransDt',{'TransId':key,'Typ':typ,'LineNo':i+1,...line});
        gross+=amount;discount+=line['Discount'] as int? ?? 0;tax+=line['Tax'] as int? ?? 0;
      }
      await txn.update('Trans',{'Subtotal':gross,'Discount':discount,'Tax':tax,'Total':gross-discount+tax},where:'TransId=? AND Typ=?',whereArgs:[key,typ]);
      await _audit(txn,'Trans','$key:$typ','save');
      return key;
    },exclusive:true);
  }

  Future<int> saveVoucher(int typ,DbRow header,List<DbRow> lines,List<DbRow> allocations,{int? id}) async {
    if (lines.isEmpty) { throw const FormatException('أضف سطرًا واحدًا على الأقل'); }
    return db.transaction((txn) async {
      await authorize('write',txn);
      final key=id ?? Sqflite.firstIntValue(await txn.rawQuery('SELECT coalesce(max(VoucherId),0)+1 FROM Mstndat WHERE Typ=?',[typ]))!;
      final values=<String,Object?>{...header,'CurrencyId':1,'CreatedBy':userId,'Amount':lines.fold<int>(0,(a,b)=>a+(b['Amount'] as int))};
      if (id!=null) {
        await txn.delete('PaymentAllocation',where:'VoucherId=? AND VoucherTyp=?',whereArgs:[id,typ]);
        await txn.delete('VoucherDt',where:'VoucherId=? AND Typ=?',whereArgs:[id,typ]);
        if (await txn.update('Mstndat',values,where:'VoucherId=? AND Typ=? AND Status=?',whereArgs:[id,typ,'Draft'])!=1) { throw StateError('السند ليس مسودة'); }
      } else { await txn.insert('Mstndat',{'VoucherId':key,'Typ':typ,...values}); }
      for (var i=0;i<lines.length;i++) { await txn.insert('VoucherDt',{'VoucherId':key,'Typ':typ,'LineNo':i+1,'AccountId':lines[i]['AccountId'],'Amount':lines[i]['Amount']}); }
      for (final allocation in allocations) { await txn.insert('PaymentAllocation',{'VoucherId':key,'VoucherTyp':typ,'TransId':allocation['TransId'],'TransTyp':allocation['TransTyp'],'Amount':allocation['Amount']}); }
      await _audit(txn,'Mstndat','$key:$typ','save');
      return key;
    },exclusive:true);
  }

  Future<int> saveJournal(DbRow header,List<DbRow> lines,{int? id}) async {
    return db.transaction((txn) async {
      await authorize('write',txn);
      final periods=await txn.rawQuery('SELECT PeriodId FROM FiscalPeriods WHERE ? BETWEEN StartDate AND EndDate',[header['EntryDate']]);
      if (periods.isEmpty) { throw StateError('لا توجد فترة مالية لهذا التاريخ'); }
      final values=<String,Object?>{...header,'PeriodId':periods.first['PeriodId'],'CreatedBy':userId};
      final int key;
      if (id!=null) {
        await txn.delete('Yomia',where:'JournalId=?',whereArgs:[id]);
        if (await txn.update('JournalEntries',values,where:'JournalId=? AND Typ=7 AND Status=?',whereArgs:[id,'Draft'])!=1) { throw StateError('القيد ليس مسودة يدوية'); }
        key=id;
      } else { key=await txn.insert('JournalEntries',{'Typ':7,...values}); }
      for (var i=0;i<lines.length;i++) { await txn.insert('Yomia',{'JournalId':key,'LineNo':i+1,'AccountId':lines[i]['AccountId'],'Debit':lines[i]['Debit']??0,'Credit':lines[i]['Credit']??0}); }
      await _audit(txn,'JournalEntries','$key','save');
      return key;
    },exclusive:true);
  }

  Future<void> post(String family,int id,[int? typ]) async {
    const tables={'invoice':('Trans','TransId'),'voucher':('Mstndat','VoucherId'),'journal':('JournalEntries','JournalId')};
    final table=tables[family];
    if (table==null) { throw ArgumentError('Unsupported document'); }
    await db.transaction((txn) async {
      await authorize('post',txn);
      final count=await txn.update(table.$1,{'CreatedBy':userId,'Status':'Posted'},where:'${table.$2}=? AND Typ=?',whereArgs:[id,typ??7]);
      if (count!=1) { throw StateError('المستند غير موجود'); }
    },exclusive:true);
  }

  Future<DbRow> summary() async {
    await authorize('read');
    return (await db.rawQuery("SELECT (SELECT count(*) FROM Trans WHERE Status='Draft') AS Drafts,(SELECT count(*) FROM Trans WHERE Status='Posted') AS Posted,(SELECT coalesce(sum(StockValue),0) FROM StockBalances) AS StockValue,(SELECT Balance FROM AccountBalances WHERE AccountId=1110) AS Cash" )).first;
  }
}
