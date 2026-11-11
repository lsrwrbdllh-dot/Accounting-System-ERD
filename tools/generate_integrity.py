"""Generate repetitive SQL guards. The emitted migration is the runtime source of truth."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sql = []

def add(value):
    sql.append('\n'.join(line.rstrip() for line in value.strip().splitlines()) + '\n')

def trigger(name, event, table, body, when=''):
    add(f'CREATE TRIGGER {name} {event} ON {table} {when}\nBEGIN\n{body}\nEND;')

def reject(condition, message):
    return f"SELECT CASE WHEN {condition} THEN RAISE(ABORT,'{message}') END;"

for table, pk, parent, kind, leaf, group in [
    ('Accounts','AccountId','ParentAccountId','AccountType','Sub','Main'),
    ('Stk_Item','ItemId','ParentItemId','ItemType','Item','Group'),
]:
    for event in ('INSERT','UPDATE'):
        trigger(f'{table}_tree_{event}', f'BEFORE {event}', table,
            reject(f"NEW.{parent} IS NOT NULL AND NOT EXISTS(SELECT 1 FROM {table} WHERE {pk}=NEW.{parent} AND {kind}='{group}')", 'Parent must be a group') +
            reject(f"EXISTS(WITH RECURSIVE ancestors(id) AS (SELECT NEW.{parent} UNION SELECT t.{parent} FROM {table} t JOIN ancestors a ON t.{pk}=a.id WHERE t.{parent} IS NOT NULL) SELECT 1 FROM ancestors WHERE id=NEW.{pk})", 'Hierarchy cycle') +
            reject(f"NEW.{kind}='{leaf}' AND EXISTS(SELECT 1 FROM {table} WHERE {parent}=NEW.{pk})", 'Group has children'))

trigger('accounts_identity','BEFORE UPDATE','Accounts',
    reject("(NEW.AccountId<>OLD.AccountId OR NEW.AccountType<>OLD.AccountType OR NEW.NormalBalance<>OLD.NormalBalance) AND (EXISTS(SELECT 1 FROM Yomia WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Customers WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Suppliers WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Cashboxes WHERE AccountId=OLD.AccountId))", 'Used account identity is locked'))
for table in ('Customers','Suppliers','Cashboxes'):
    for event in ('INSERT','UPDATE'):
        trigger(f'{table}_account_{event}',f'BEFORE {event}',table,
            reject("NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1)", 'Posting account required'))
trigger('item_identity','BEFORE UPDATE','Stk_Item',
    reject("(NEW.ItemId<>OLD.ItemId OR NEW.ItemType<>OLD.ItemType) AND EXISTS(SELECT 1 FROM Stk_ItemUnit WHERE ItemId=OLD.ItemId)", 'Item identity in use'))
for table, pk, invoice_ref in [('Customers','CustomerId','CustomerId'),('Suppliers','SupplierId','SupplierId'),('Cashboxes','CashboxId','CashboxId')]:
    trigger(f'{table}_identity','BEFORE UPDATE',table,
        reject(f"NEW.AccountId<>OLD.AccountId AND EXISTS(SELECT 1 FROM Trans WHERE {invoice_ref}=OLD.{pk})", 'Used party account is locked'))
trigger('cashbox_voucher_identity','BEFORE UPDATE','Cashboxes',reject("(NEW.AccountId<>OLD.AccountId OR NEW.BranchId<>OLD.BranchId) AND EXISTS(SELECT 1 FROM Mstndat WHERE CashboxId=OLD.CashboxId)", 'Used cashbox identity is locked'))
trigger('warehouse_identity','BEFORE UPDATE','Warehouses',reject("NEW.BranchId<>OLD.BranchId AND EXISTS(SELECT 1 FROM Trans WHERE WarehouseId=OLD.WarehouseId)", 'Used warehouse branch is locked'))
for event in ('UPDATE','DELETE'):
    trigger(f'batch_identity_{event}',f'BEFORE {event}','ItemBatches',reject("EXISTS(SELECT 1 FROM TransDt WHERE BatchId=OLD.BatchId)", 'Used batch identity is locked'))
    trigger(f'doctype_identity_{event}',f'BEFORE {event}','DocTyp',"SELECT RAISE(ABORT,'Document type semantics are fixed');")
    trigger(f'settings_lock_{event}',f'BEFORE {event}','AppSettings',reject("EXISTS(SELECT 1 FROM JournalEntries WHERE Status='Posted')", 'Posting settings are locked after first posting'))
for event in ('INSERT','UPDATE'):
    trigger(f'unit_item_{event}',f'BEFORE {event}','Stk_ItemUnit',
        reject("NOT EXISTS(SELECT 1 FROM Stk_Item WHERE ItemId=NEW.ItemId AND ItemType='Item' AND IsActive=1)", 'Unit requires an active item'))
trigger('unit_lock','BEFORE UPDATE','Stk_ItemUnit',
    reject("(NEW.ItemId<>OLD.ItemId OR NEW.PackingQty<>OLD.PackingQty OR NEW.IsBase<>OLD.IsBase OR NEW.UnitId<>OLD.UnitId OR NEW.ItemUnitId<>OLD.ItemUnitId) AND EXISTS(SELECT 1 FROM TransDt WHERE ItemUnitId=OLD.ItemUnitId)", 'Used unit conversion is locked'))
for table in ('FiscalYears','FiscalPeriods'):
    pk='FiscalYearId' if table=='FiscalYears' else 'PeriodId'
    for event in ('INSERT','UPDATE'):
        body=reject(f"EXISTS(SELECT 1 FROM {table} WHERE {pk}<>NEW.{pk} AND StartDate<=NEW.EndDate AND EndDate>=NEW.StartDate)", 'Overlapping fiscal dates')
        if table=='FiscalPeriods':
            body+=reject("NOT EXISTS(SELECT 1 FROM FiscalYears WHERE FiscalYearId=NEW.FiscalYearId AND NEW.StartDate>=StartDate AND NEW.EndDate<=EndDate)", 'Period outside fiscal year')
        trigger(f'{table}_dates_{event}',f'BEFORE {event}',table,body)
    trigger(f'{table}_boundaries','BEFORE UPDATE',table,
        reject("NEW.StartDate<>OLD.StartDate OR NEW.EndDate<>OLD.EndDate", 'Fiscal boundaries are immutable'))

add('''CREATE VIEW UserPermissions AS
 SELECT DISTINCT u.UserId,p.PermissionCode FROM Users u JOIN UserRoles ur USING(UserId)
 JOIN RolePermissions rp USING(RoleId) JOIN Permissions p USING(PermissionId) WHERE u.IsActive=1;
CREATE VIEW StockBalances AS
 SELECT m.WarehouseId,m.ItemId,m.BatchId,sum(m.QuantityChange) AS QtyBase,sum(m.ValueChange) AS StockValue
 FROM InventoryMovements m JOIN Trans t ON t.TransId=m.TransId AND t.Typ=m.Typ
 WHERE t.Status='Posted' GROUP BY m.WarehouseId,m.ItemId,m.BatchId;
CREATE VIEW AccountBalances AS
 SELECT a.AccountId,a.Code,a.AccountName,a.NormalBalance,
 coalesce(sum(CASE WHEN j.Status='Posted' THEN y.Debit ELSE 0 END),0) AS Debit,
 coalesce(sum(CASE WHEN j.Status='Posted' THEN y.Credit ELSE 0 END),0) AS Credit,
 coalesce(sum(CASE WHEN j.Status='Posted' THEN y.Debit-y.Credit ELSE 0 END),0) AS Balance
 FROM Accounts a LEFT JOIN Yomia y USING(AccountId) LEFT JOIN JournalEntries j USING(JournalId)
 GROUP BY a.AccountId;
CREATE VIEW InvoiceOutstanding AS
 SELECT t.TransId,t.Typ,t.Total,
 t.Total-coalesce((SELECT sum(r.Total) FROM Trans r WHERE r.OriginalTransId=t.TransId AND r.OriginalTyp=t.Typ AND r.Status='Posted'),0)
 -coalesce((SELECT sum(p.Amount) FROM PaymentAllocation p JOIN Mstndat v ON v.VoucherId=p.VoucherId AND v.Typ=p.VoucherTyp
 WHERE p.TransId=t.TransId AND p.TransTyp=t.Typ AND v.Status='Posted'),0) AS Outstanding
 FROM Trans t WHERE t.Typ IN (1,2) AND t.Status='Posted' AND t.PaymentMethod='Credit';
CREATE VIEW InvoiceLineAmounts AS
 SELECT d.*, d.GrossAmount-d.Discount AS NetAmount,
 (d.Qty*u.PackingQty)/1000 AS QtyBase
 FROM TransDt d JOIN Stk_ItemUnit u ON u.ItemUnitId=d.ItemUnitId;
CREATE VIEW ReturnLineCumulative AS
 SELECT d.TransId,d.Typ,d.LineNo,d.Qty,o.Qty AS OriginalQty,o.GrossAmount AS OriginalGross,o.Discount AS OriginalDiscount,o.Tax AS OriginalTax,
 coalesce((SELECT sum(r.Qty) FROM TransDt r JOIN Trans h ON h.TransId=r.TransId AND h.Typ=r.Typ
 WHERE h.OriginalTransId=t.OriginalTransId AND h.OriginalTyp=t.OriginalTyp AND h.Status='Posted'
 AND NOT(h.TransId=t.TransId AND h.Typ=t.Typ) AND r.OriginalLineNo=d.OriginalLineNo),0)
 +coalesce((SELECT sum(n.Qty) FROM TransDt n WHERE n.TransId=d.TransId AND n.Typ=d.Typ AND n.OriginalLineNo=d.OriginalLineNo AND n.LineNo<d.LineNo),0) AS PreviousQty
 FROM TransDt d JOIN Trans t ON t.TransId=d.TransId AND t.Typ=d.Typ
 JOIN TransDt o ON o.TransId=t.OriginalTransId AND o.Typ=t.OriginalTyp AND o.LineNo=d.OriginalLineNo;
CREATE VIEW ReturnExpectedAmounts AS
 SELECT TransId,Typ,LineNo,
 ((OriginalGross-OriginalDiscount)*(PreviousQty+Qty)+OriginalQty/2)/OriginalQty-((OriginalGross-OriginalDiscount)*PreviousQty+OriginalQty/2)/OriginalQty
 +(OriginalDiscount*(PreviousQty+Qty)+OriginalQty/2)/OriginalQty-(OriginalDiscount*PreviousQty+OriginalQty/2)/OriginalQty AS GrossAmount,
 (OriginalDiscount*(PreviousQty+Qty)+OriginalQty/2)/OriginalQty-(OriginalDiscount*PreviousQty+OriginalQty/2)/OriginalQty AS Discount,
 (OriginalTax*(PreviousQty+Qty)+OriginalQty/2)/OriginalQty-(OriginalTax*PreviousQty+OriginalQty/2)/OriginalQty AS Tax
 FROM ReturnLineCumulative;
CREATE VIEW InvoiceTotals AS
 SELECT t.TransId,t.Typ,t.Subtotal-t.Discount AS NetAmount,t.Tax,t.Total,
 coalesce((SELECT sum(CostAmount) FROM TransDt d WHERE d.TransId=t.TransId AND d.Typ=t.Typ),0) AS CostAmount,
 CASE WHEN t.PaymentMethod='Cash' THEN (SELECT AccountId FROM Cashboxes WHERE CashboxId=t.CashboxId)
 WHEN t.Typ IN (1,4) THEN (SELECT AccountId FROM Suppliers WHERE SupplierId=t.SupplierId)
 ELSE (SELECT AccountId FROM Customers WHERE CustomerId=t.CustomerId) END AS PartyAccount
 FROM Trans t;
CREATE VIEW PostingSettings AS
 SELECT
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='inventory_account') AS INTEGER) AS InventoryAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='sales_account') AS INTEGER) AS SalesAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='sales_returns_account') AS INTEGER) AS ReturnsAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='cogs_account') AS INTEGER) AS CogsAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='input_tax_account') AS INTEGER) AS InputTaxAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='output_tax_account') AS INTEGER) AS OutputTaxAccount,
 CAST((SELECT SettingValue FROM AppSettings WHERE SettingKey='variance_account') AS INTEGER) AS VarianceAccount;
CREATE VIEW InvoicePostingLines AS
 SELECT TransId,Typ,1 AS Slot,PartyAccount AS AccountId,
 CASE WHEN Typ IN (2,4) THEN Total ELSE 0 END AS Debit,
 CASE WHEN Typ IN (1,3) THEN Total ELSE 0 END AS Credit FROM InvoiceTotals
 UNION ALL
 SELECT TransId,Typ,2,CASE WHEN Typ IN (1,4) THEN InventoryAccount WHEN Typ=2 THEN SalesAccount ELSE ReturnsAccount END,
 CASE WHEN Typ IN (1,3) THEN NetAmount ELSE 0 END,
 CASE WHEN Typ=2 THEN NetAmount WHEN Typ=4 THEN CostAmount ELSE 0 END FROM InvoiceTotals CROSS JOIN PostingSettings
 UNION ALL
 SELECT TransId,Typ,3,CASE WHEN Typ IN (1,4) THEN InputTaxAccount ELSE OutputTaxAccount END,
 CASE WHEN Typ IN (1,3) THEN Tax ELSE 0 END,CASE WHEN Typ IN (2,4) THEN Tax ELSE 0 END FROM InvoiceTotals CROSS JOIN PostingSettings
 UNION ALL
 SELECT TransId,Typ,4,CogsAccount,CASE WHEN Typ=2 THEN CostAmount ELSE 0 END,
 CASE WHEN Typ=3 THEN CostAmount ELSE 0 END FROM InvoiceTotals CROSS JOIN PostingSettings WHERE Typ IN (2,3)
 UNION ALL
 SELECT TransId,Typ,5,InventoryAccount,CASE WHEN Typ=3 THEN CostAmount ELSE 0 END,
 CASE WHEN Typ=2 THEN CostAmount ELSE 0 END FROM InvoiceTotals CROSS JOIN PostingSettings WHERE Typ IN (2,3)
 UNION ALL
 SELECT TransId,Typ,6,VarianceAccount,max(CostAmount-NetAmount,0),max(NetAmount-CostAmount,0)
 FROM InvoiceTotals CROSS JOIN PostingSettings WHERE Typ=4;
''')

# Draft-only insert; the only transition is the guarded UPDATE.
for table, pk in [('Trans','TransId'),('Mstndat','VoucherId'),('JournalEntries','JournalId')]:
    trigger(f'{table}_draft_insert','BEFORE INSERT',table,reject("NEW.Status<>'Draft'", 'Insert a draft first'))
    for event in ('UPDATE','DELETE'):
        trigger(f'{table}_posted_{event}',f'BEFORE {event}',table,"SELECT RAISE(ABORT,'Posted document is immutable');", "WHEN OLD.Status='Posted'")
    trigger(f'{table}_key_lock','BEFORE UPDATE',table,reject(f'NEW.{pk}<>OLD.{pk} OR NEW.Typ<>OLD.Typ','Document identity is immutable'))

for table,parent,keys in [
 ('TransDt','Trans',['TransId','Typ']),('VoucherDt','Mstndat',['VoucherId','Typ']),
 ('PaymentAllocation','Mstndat',['VoucherId','VoucherTyp']),('Yomia','JournalEntries',['JournalId']),
 ('YomiaCostCenters','JournalEntries',['JournalId']),
]:
    for event in ('INSERT','UPDATE','DELETE'):
        checks=[]
        for ref in (['NEW'] if event=='INSERT' else ['OLD'] if event=='DELETE' else ['OLD','NEW']):
            where=' AND '.join(f'{"Typ" if k=="VoucherTyp" else k}={ref}.{k}' for k in keys)
            checks.append(f"coalesce((SELECT Status FROM {parent} WHERE {where}),'Missing')<>'Draft'")
        trigger(f'{table}_draft_{event}',f'BEFORE {event}',table,reject(' OR '.join(checks),'Lines require a draft parent'))

for event in ('INSERT','UPDATE'):
    trigger(f'yomia_account_{event}',f'BEFORE {event}','Yomia',
        reject("NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1)", 'Active subaccount required'))

for event in ('UPDATE','DELETE'):
    trigger(f'movement_immutable_{event}',f'BEFORE {event}','InventoryMovements',"SELECT RAISE(ABORT,'Inventory movements are immutable');")
    trigger(f'audit_immutable_{event}',f'BEFORE {event}','AuditLogs',"SELECT RAISE(ABORT,'Audit log is append only');")

trigger('movement_source','BEFORE INSERT','InventoryMovements',
 reject('''NOT EXISTS(SELECT 1 FROM Trans t JOIN InvoiceLineAmounts d ON t.TransId=d.TransId AND t.Typ=d.Typ
 WHERE t.TransId=NEW.TransId AND t.Typ=NEW.Typ AND d.LineNo=NEW.LineNo AND t.Status='Posted'
 AND t.WarehouseId=NEW.WarehouseId AND d.ItemId=NEW.ItemId AND d.ItemUnitId=NEW.ItemUnitId
 AND d.BatchId IS NEW.BatchId AND t.CreatedBy=NEW.CreatedBy AND t.TransDate=NEW.MovementDate
 AND NEW.QuantityChange=d.QtyBase*CASE WHEN t.Typ IN (1,3) THEN 1 ELSE -1 END
 AND NEW.ValueChange=d.CostAmount*CASE WHEN t.Typ IN (1,3) THEN 1 ELSE -1 END)''','Inventory source mismatch')+
 reject('''coalesce((SELECT QtyBase FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.QuantityChange NOT BETWEEN 0 AND 1000000000''','Insufficient stock or quantity limit')+
 reject('''coalesce((SELECT StockValue FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.ValueChange NOT BETWEEN 0 AND 1000000000''','Insufficient stock value or value limit')+
 reject('''coalesce((SELECT QtyBase FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.QuantityChange=0 AND coalesce((SELECT StockValue FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.ValueChange<>0''','Zero stock must have zero value'))

trigger('invoice_validate','BEFORE UPDATE OF Status','Trans',r'''
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM UserPermissions WHERE UserId=NEW.CreatedBy AND PermissionCode='post')
 THEN RAISE(ABORT,'Posting permission required') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM FiscalPeriods p JOIN FiscalYears y USING(FiscalYearId)
 WHERE NEW.TransDate BETWEEN p.StartDate AND p.EndDate AND p.Status='Open' AND y.Status='Open')
 THEN RAISE(ABORT,'No open fiscal period') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Users u JOIN Warehouses w ON u.BranchId=w.BranchId WHERE u.UserId=NEW.CreatedBy AND w.WarehouseId=NEW.WarehouseId)
 OR (NEW.CashboxId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Cashboxes c JOIN Users u USING(BranchId) WHERE c.CashboxId=NEW.CashboxId AND u.UserId=NEW.CreatedBy))
 THEN RAISE(ABORT,'Document belongs to another branch') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM TransDt WHERE TransId=NEW.TransId AND Typ=NEW.Typ)
 THEN RAISE(ABORT,'Invoice requires lines') END;
 SELECT CASE WHEN NEW.TransDate<coalesce((SELECT max(TransDate) FROM Trans WHERE WarehouseId=NEW.WarehouseId AND Status='Posted'),NEW.TransDate)
 THEN RAISE(ABORT,'Backdated stock posting is not supported') END;
 SELECT CASE WHEN NEW.Total<=0 OR NEW.Subtotal<>(SELECT sum(GrossAmount) FROM TransDt WHERE TransId=NEW.TransId AND Typ=NEW.Typ)
 OR NEW.Discount<>(SELECT sum(Discount) FROM TransDt WHERE TransId=NEW.TransId AND Typ=NEW.Typ)
 OR NEW.Tax<>(SELECT sum(Tax) FROM TransDt WHERE TransId=NEW.TransId AND Typ=NEW.Typ)
 THEN RAISE(ABORT,'Invoice totals do not match lines') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM TransDt d JOIN Stk_Item i USING(ItemId) JOIN Stk_ItemUnit u USING(ItemUnitId)
 WHERE d.TransId=NEW.TransId AND d.Typ=NEW.Typ AND (i.IsActive<>1 OR i.ItemType<>'Item' OR d.Qty*u.PackingQty%1000<>0
 OR d.Qty*u.PackingQty/1000 NOT BETWEEN 1 AND 1000000000 OR NOT EXISTS(SELECT 1 FROM Stk_ItemUnit b WHERE b.ItemId=d.ItemId AND b.IsBase=1)))
 THEN RAISE(ABORT,'Invalid item or quantity precision') END;
 SELECT CASE WHEN NEW.Typ IN (2,4) AND EXISTS(SELECT d.ItemId FROM InvoiceLineAmounts d
 WHERE d.TransId=NEW.TransId AND d.Typ=NEW.Typ GROUP BY d.ItemId,d.BatchId
 HAVING sum(d.QtyBase)>coalesce((SELECT s.QtyBase FROM StockBalances s WHERE s.WarehouseId=NEW.WarehouseId AND s.ItemId=d.ItemId AND s.BatchId IS d.BatchId),0))
 THEN RAISE(ABORT,'Insufficient stock') END;
 SELECT CASE WHEN NEW.Typ IN (3,4) AND NOT EXISTS(SELECT 1 FROM Trans o WHERE o.TransId=NEW.OriginalTransId AND o.Typ=NEW.OriginalTyp
 AND o.Status='Posted' AND o.TransDate<=NEW.TransDate AND o.CustomerId IS NEW.CustomerId AND o.SupplierId IS NEW.SupplierId
 AND o.WarehouseId=NEW.WarehouseId AND o.PaymentMethod=NEW.PaymentMethod AND o.CashboxId IS NEW.CashboxId)
 THEN RAISE(ABORT,'Return must match a posted original invoice') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM TransDt d WHERE d.TransId=NEW.TransId AND d.Typ=NEW.Typ AND
 ((NEW.Typ IN (1,2) AND (d.OriginalLineNo IS NOT NULL OR d.GrossAmount<>(d.Qty*d.Price+500)/1000)) OR (NEW.Typ IN (3,4) AND NOT EXISTS(
 SELECT 1 FROM TransDt o WHERE o.TransId=NEW.OriginalTransId AND o.Typ=NEW.OriginalTyp AND o.LineNo=d.OriginalLineNo
 AND o.ItemId=d.ItemId AND o.ItemUnitId=d.ItemUnitId AND o.BatchId IS d.BatchId AND o.Price=d.Price
 AND EXISTS(SELECT 1 FROM ReturnExpectedAmounts e WHERE e.TransId=d.TransId AND e.Typ=d.Typ AND e.LineNo=d.LineNo AND e.GrossAmount=d.GrossAmount AND e.Discount=d.Discount AND e.Tax=d.Tax)))))
 THEN RAISE(ABORT,'Return line does not match original') END;
 SELECT CASE WHEN NEW.Typ IN (3,4) AND EXISTS(SELECT 1 FROM TransDt o WHERE o.TransId=NEW.OriginalTransId AND o.Typ=NEW.OriginalTyp AND
 o.Qty < coalesce((SELECT sum(r.Qty) FROM TransDt r JOIN Trans h ON h.TransId=r.TransId AND h.Typ=r.Typ
 WHERE h.OriginalTransId=NEW.OriginalTransId AND h.OriginalTyp=NEW.OriginalTyp AND r.OriginalLineNo=o.LineNo
 AND (h.Status='Posted' OR (h.TransId=NEW.TransId AND h.Typ=NEW.Typ))),0))
 THEN RAISE(ABORT,'Return exceeds original quantity') END;
 SELECT CASE WHEN NEW.Typ IN (3,4) AND NEW.PaymentMethod='Credit' AND NEW.Total>
 coalesce((SELECT Outstanding FROM InvoiceOutstanding WHERE TransId=NEW.OriginalTransId AND Typ=NEW.OriginalTyp),0)
 THEN RAISE(ABORT,'Credit return exceeds unpaid balance') END;
 -- Freeze carrying costs before source becomes posted. Marginal cumulative rounding handles repeated item lines.
 UPDATE TransDt SET CostAmount=CASE
 WHEN NEW.Typ=1 THEN (Qty*Price+500)/1000-Discount
 WHEN NEW.Typ=3 THEN (
  SELECT (o.CostAmount*(coalesce((SELECT sum(r.Qty) FROM TransDt r JOIN Trans h ON h.TransId=r.TransId AND h.Typ=r.Typ
    WHERE h.OriginalTransId=NEW.OriginalTransId AND h.OriginalTyp=NEW.OriginalTyp AND h.Status='Posted' AND r.OriginalLineNo=o.LineNo),0)
    +coalesce((SELECT sum(n.Qty) FROM TransDt n WHERE n.TransId=NEW.TransId AND n.Typ=NEW.Typ AND n.OriginalLineNo=o.LineNo AND n.LineNo<=TransDt.LineNo),0))+o.Qty/2)/o.Qty
  -(o.CostAmount*(coalesce((SELECT sum(r.Qty) FROM TransDt r JOIN Trans h ON h.TransId=r.TransId AND h.Typ=r.Typ
    WHERE h.OriginalTransId=NEW.OriginalTransId AND h.OriginalTyp=NEW.OriginalTyp AND h.Status='Posted' AND r.OriginalLineNo=o.LineNo),0)
    +coalesce((SELECT sum(n.Qty) FROM TransDt n WHERE n.TransId=NEW.TransId AND n.Typ=NEW.Typ AND n.OriginalLineNo=o.LineNo AND n.LineNo<TransDt.LineNo),0))+o.Qty/2)/o.Qty
  FROM TransDt o WHERE o.TransId=NEW.OriginalTransId AND o.Typ=NEW.OriginalTyp AND o.LineNo=TransDt.OriginalLineNo)
 ELSE coalesce((SELECT
   (s.StockValue*coalesce((SELECT sum(n.QtyBase) FROM InvoiceLineAmounts n WHERE n.TransId=NEW.TransId AND n.Typ=NEW.Typ AND n.ItemId=TransDt.ItemId AND n.BatchId IS TransDt.BatchId AND n.LineNo<=TransDt.LineNo),0)+s.QtyBase/2)/s.QtyBase
  -(s.StockValue*coalesce((SELECT sum(n.QtyBase) FROM InvoiceLineAmounts n WHERE n.TransId=NEW.TransId AND n.Typ=NEW.Typ AND n.ItemId=TransDt.ItemId AND n.BatchId IS TransDt.BatchId AND n.LineNo<TransDt.LineNo),0)+s.QtyBase/2)/s.QtyBase
 FROM StockBalances s WHERE s.WarehouseId=NEW.WarehouseId AND s.ItemId=TransDt.ItemId AND s.BatchId IS TransDt.BatchId AND s.QtyBase>0),0) END
 WHERE TransId=NEW.TransId AND Typ=NEW.Typ;
''', "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")

trigger('invoice_post','AFTER UPDATE OF Status','Trans',r'''
 INSERT INTO InventoryMovements(WarehouseId,ItemId,BatchId,TransId,Typ,LineNo,ItemUnitId,QuantityChange,ValueChange,MovementDate,CreatedBy)
 SELECT NEW.WarehouseId,ItemId,BatchId,TransId,Typ,LineNo,ItemUnitId,QtyBase*CASE WHEN NEW.Typ IN (1,3) THEN 1 ELSE -1 END,
 CostAmount*CASE WHEN NEW.Typ IN (1,3) THEN 1 ELSE -1 END,NEW.TransDate,NEW.CreatedBy
 FROM InvoiceLineAmounts WHERE TransId=NEW.TransId AND Typ=NEW.Typ ORDER BY LineNo;
 INSERT INTO JournalEntries(PeriodId,Typ,InvoiceId,InvoiceTyp,EntryDate,Description,CreatedBy)
 SELECT PeriodId,NEW.Typ,NEW.TransId,NEW.Typ,NEW.TransDate,NEW.Notes,NEW.CreatedBy
 FROM FiscalPeriods WHERE NEW.TransDate BETWEEN StartDate AND EndDate;
 INSERT INTO Yomia(JournalId,LineNo,AccountId,Debit,Credit)
 SELECT j.JournalId,l.Slot,l.AccountId,l.Debit,l.Credit FROM InvoicePostingLines l
 JOIN JournalEntries j ON j.InvoiceId=l.TransId AND j.InvoiceTyp=l.Typ
 WHERE l.TransId=NEW.TransId AND l.Typ=NEW.Typ AND (l.Debit>0 OR l.Credit>0);
 UPDATE JournalEntries SET Status='Posted' WHERE InvoiceId=NEW.TransId AND InvoiceTyp=NEW.Typ;
 INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(NEW.CreatedBy,'Trans',NEW.TransId||':'||NEW.Typ,'post');
''', "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")

trigger('voucher_validate','BEFORE UPDATE OF Status','Mstndat',r'''
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM UserPermissions WHERE UserId=NEW.CreatedBy AND PermissionCode='post') THEN RAISE(ABORT,'Posting permission required') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM FiscalPeriods p JOIN FiscalYears y USING(FiscalYearId) WHERE NEW.VoucherDate BETWEEN p.StartDate AND p.EndDate AND p.Status='Open' AND y.Status='Open') THEN RAISE(ABORT,'No open fiscal period') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Users u JOIN Cashboxes c USING(BranchId) WHERE u.UserId=NEW.CreatedBy AND c.CashboxId=NEW.CashboxId) THEN RAISE(ABORT,'Cashbox belongs to another branch') END;
 SELECT CASE WHEN NEW.Amount<>coalesce((SELECT sum(Amount) FROM VoucherDt WHERE VoucherId=NEW.VoucherId AND Typ=NEW.Typ),0) THEN RAISE(ABORT,'Voucher totals do not match') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM VoucherDt d JOIN Accounts a USING(AccountId) WHERE d.VoucherId=NEW.VoucherId AND d.Typ=NEW.Typ AND (a.AccountType<>'Sub' OR a.IsActive<>1 OR a.AccountId=(SELECT AccountId FROM Cashboxes WHERE CashboxId=NEW.CashboxId) OR a.AccountId=(SELECT InventoryAccount FROM PostingSettings))) THEN RAISE(ABORT,'Invalid voucher account') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM PaymentAllocation p JOIN Trans t ON t.TransId=p.TransId AND t.Typ=p.TransTyp
 WHERE p.VoucherId=NEW.VoucherId AND p.VoucherTyp=NEW.Typ AND (t.Status<>'Posted' OR t.PaymentMethod<>'Credit' OR t.TransDate>NEW.VoucherDate OR
 (NEW.Typ=6 AND t.Typ<>2) OR (NEW.Typ=5 AND t.Typ<>1) OR p.Amount>(SELECT Outstanding FROM InvoiceOutstanding WHERE TransId=t.TransId AND Typ=t.Typ) OR
 t.WarehouseId NOT IN (SELECT WarehouseId FROM Warehouses WHERE BranchId=(SELECT BranchId FROM Cashboxes WHERE CashboxId=NEW.CashboxId)))) THEN RAISE(ABORT,'Invalid invoice allocation or overpayment') END;
 SELECT CASE WHEN coalesce((SELECT sum(Amount) FROM PaymentAllocation WHERE VoucherId=NEW.VoucherId AND VoucherTyp=NEW.Typ),0)>NEW.Amount THEN RAISE(ABORT,'Allocation exceeds voucher') END;
 SELECT CASE WHEN EXISTS(SELECT a.AccountId FROM PaymentAllocation p JOIN InvoiceTotals a ON a.TransId=p.TransId AND a.Typ=p.TransTyp
 WHERE p.VoucherId=NEW.VoucherId AND p.VoucherTyp=NEW.Typ GROUP BY a.AccountId
 HAVING sum(p.Amount)>coalesce((SELECT sum(d.Amount) FROM VoucherDt d WHERE d.VoucherId=NEW.VoucherId AND d.Typ=NEW.Typ AND d.AccountId=a.AccountId),0)) THEN RAISE(ABORT,'Allocation party does not match voucher lines') END;
'''.replace('SELECT a.AccountId FROM PaymentAllocation','SELECT a.PartyAccount AS AccountId FROM PaymentAllocation').replace('GROUP BY a.AccountId','GROUP BY a.PartyAccount').replace('d.AccountId=a.AccountId','d.AccountId=a.PartyAccount'), "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")

trigger('voucher_post','AFTER UPDATE OF Status','Mstndat',r'''
 INSERT INTO JournalEntries(PeriodId,Typ,VoucherId,VoucherTyp,EntryDate,Description,CreatedBy)
 SELECT PeriodId,NEW.Typ,NEW.VoucherId,NEW.Typ,NEW.VoucherDate,NEW.Description,NEW.CreatedBy FROM FiscalPeriods WHERE NEW.VoucherDate BETWEEN StartDate AND EndDate;
 INSERT INTO Yomia(JournalId,LineNo,AccountId,Debit,Credit)
 SELECT j.JournalId,1,c.AccountId,CASE WHEN NEW.Typ=6 THEN NEW.Amount ELSE 0 END,CASE WHEN NEW.Typ=5 THEN NEW.Amount ELSE 0 END
 FROM JournalEntries j JOIN Cashboxes c ON c.CashboxId=NEW.CashboxId WHERE j.VoucherId=NEW.VoucherId AND j.VoucherTyp=NEW.Typ;
 INSERT INTO Yomia(JournalId,LineNo,AccountId,Debit,Credit)
 SELECT j.JournalId,d.LineNo+1,d.AccountId,CASE WHEN NEW.Typ=5 THEN d.Amount ELSE 0 END,CASE WHEN NEW.Typ=6 THEN d.Amount ELSE 0 END
 FROM VoucherDt d JOIN JournalEntries j ON j.VoucherId=d.VoucherId AND j.VoucherTyp=d.Typ WHERE d.VoucherId=NEW.VoucherId AND d.Typ=NEW.Typ;
 UPDATE JournalEntries SET Status='Posted' WHERE VoucherId=NEW.VoucherId AND VoucherTyp=NEW.Typ;
 INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(NEW.CreatedBy,'Mstndat',NEW.VoucherId||':'||NEW.Typ,'post');
''', "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")

trigger('journal_validate','BEFORE UPDATE OF Status','JournalEntries',r'''
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM UserPermissions WHERE UserId=NEW.CreatedBy AND PermissionCode='post') THEN RAISE(ABORT,'Posting permission required') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM FiscalPeriods p JOIN FiscalYears y USING(FiscalYearId) WHERE p.PeriodId=NEW.PeriodId AND NEW.EntryDate BETWEEN p.StartDate AND p.EndDate AND p.Status='Open' AND y.Status='Open') THEN RAISE(ABORT,'No open fiscal period') END;
 SELECT CASE WHEN (SELECT count(*) FROM Yomia WHERE JournalId=NEW.JournalId)<2 OR (SELECT sum(Debit)-sum(Credit) FROM Yomia WHERE JournalId=NEW.JournalId)<>0 THEN RAISE(ABORT,'Journal must balance with at least two lines') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM Yomia y JOIN Accounts a USING(AccountId) WHERE y.JournalId=NEW.JournalId AND (a.AccountType<>'Sub' OR a.IsActive<>1)) THEN RAISE(ABORT,'Active subaccount required') END;
 SELECT CASE WHEN NEW.Typ=7 AND EXISTS(SELECT 1 FROM Yomia WHERE JournalId=NEW.JournalId AND AccountId=(SELECT InventoryAccount FROM PostingSettings)) THEN RAISE(ABORT,'Inventory account requires an inventory document') END;
 SELECT CASE WHEN EXISTS(SELECT c.LineNo FROM YomiaCostCenters c JOIN Yomia y ON y.JournalId=c.JournalId AND y.LineNo=c.LineNo WHERE c.JournalId=NEW.JournalId GROUP BY c.LineNo HAVING sum(c.Amount)<>max(y.Debit+y.Credit)) THEN RAISE(ABORT,'Cost center split must equal journal line') END;
 SELECT CASE WHEN NEW.Typ BETWEEN 1 AND 4 AND NOT EXISTS(SELECT 1 FROM Trans WHERE TransId=NEW.InvoiceId AND Typ=NEW.Typ AND Status='Posted' AND TransDate=NEW.EntryDate AND CreatedBy=NEW.CreatedBy) THEN RAISE(ABORT,'Invoice source mismatch') END;
 SELECT CASE WHEN NEW.Typ BETWEEN 1 AND 4 AND (EXISTS(
 SELECT Slot,AccountId,Debit,Credit FROM InvoicePostingLines WHERE TransId=NEW.InvoiceId AND Typ=NEW.Typ AND (Debit>0 OR Credit>0)
 EXCEPT SELECT LineNo,AccountId,Debit,Credit FROM Yomia WHERE JournalId=NEW.JournalId) OR EXISTS(
 SELECT LineNo,AccountId,Debit,Credit FROM Yomia WHERE JournalId=NEW.JournalId
 EXCEPT SELECT Slot,AccountId,Debit,Credit FROM InvoicePostingLines WHERE TransId=NEW.InvoiceId AND Typ=NEW.Typ AND (Debit>0 OR Credit>0))) THEN RAISE(ABORT,'Invoice journal does not match source') END;
 SELECT CASE WHEN NEW.Typ IN (5,6) AND NOT EXISTS(SELECT 1 FROM Mstndat WHERE VoucherId=NEW.VoucherId AND Typ=NEW.Typ AND Status='Posted' AND VoucherDate=NEW.EntryDate AND CreatedBy=NEW.CreatedBy) THEN RAISE(ABORT,'Voucher source mismatch') END;
 SELECT CASE WHEN NEW.Typ IN (5,6) AND (
 (SELECT count(*) FROM Yomia WHERE JournalId=NEW.JournalId)<>1+(SELECT count(*) FROM VoucherDt WHERE VoucherId=NEW.VoucherId AND Typ=NEW.Typ) OR
 NOT EXISTS(SELECT 1 FROM Yomia y JOIN Mstndat v ON v.VoucherId=NEW.VoucherId AND v.Typ=NEW.Typ JOIN Cashboxes c ON c.CashboxId=v.CashboxId
 WHERE y.JournalId=NEW.JournalId AND y.LineNo=1 AND y.AccountId=c.AccountId AND y.Debit=CASE WHEN NEW.Typ=6 THEN v.Amount ELSE 0 END AND y.Credit=CASE WHEN NEW.Typ=5 THEN v.Amount ELSE 0 END) OR
 EXISTS(SELECT 1 FROM VoucherDt d WHERE d.VoucherId=NEW.VoucherId AND d.Typ=NEW.Typ AND NOT EXISTS(SELECT 1 FROM Yomia y WHERE y.JournalId=NEW.JournalId AND y.LineNo=d.LineNo+1 AND y.AccountId=d.AccountId AND y.Debit=CASE WHEN NEW.Typ=5 THEN d.Amount ELSE 0 END AND y.Credit=CASE WHEN NEW.Typ=6 THEN d.Amount ELSE 0 END))) THEN RAISE(ABORT,'Voucher journal does not match source') END;
''', "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")
trigger('journal_audit','AFTER UPDATE OF Status','JournalEntries',"INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(NEW.CreatedBy,'JournalEntries',NEW.JournalId,'post');", "WHEN OLD.Status='Draft' AND NEW.Status='Posted'")
for event in ('INSERT','UPDATE'):
    trigger(f'opening_check_{event}',f'BEFORE {event}','AccountOpeningBalances',reject("NOT EXISTS(SELECT 1 FROM Yomia l JOIN JournalEntries j USING(JournalId) JOIN FiscalYears y ON y.FiscalYearId=NEW.FiscalYearId WHERE l.JournalId=NEW.JournalId AND l.LineNo=NEW.LineNo AND l.AccountId=NEW.AccountId AND j.Typ=7 AND j.Status='Posted' AND j.EntryDate=y.StartDate)",'Opening balance requires posted opening journal'))

(ROOT/'database/migrations/002_integrity_posting.sql').write_text('\n'.join(sql), encoding='utf-8')
