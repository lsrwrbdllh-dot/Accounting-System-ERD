CREATE TRIGGER Accounts_tree_INSERT BEFORE INSERT ON Accounts
BEGIN
SELECT CASE WHEN NEW.ParentAccountId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.ParentAccountId AND AccountType='Main') THEN RAISE(ABORT,'Parent must be a group') END;SELECT CASE WHEN EXISTS(WITH RECURSIVE ancestors(id) AS (SELECT NEW.ParentAccountId UNION SELECT t.ParentAccountId FROM Accounts t JOIN ancestors a ON t.AccountId=a.id WHERE t.ParentAccountId IS NOT NULL) SELECT 1 FROM ancestors WHERE id=NEW.AccountId) THEN RAISE(ABORT,'Hierarchy cycle') END;SELECT CASE WHEN NEW.AccountType='Sub' AND EXISTS(SELECT 1 FROM Accounts WHERE ParentAccountId=NEW.AccountId) THEN RAISE(ABORT,'Group has children') END;
END;

CREATE TRIGGER Accounts_tree_UPDATE BEFORE UPDATE ON Accounts
BEGIN
SELECT CASE WHEN NEW.ParentAccountId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.ParentAccountId AND AccountType='Main') THEN RAISE(ABORT,'Parent must be a group') END;SELECT CASE WHEN EXISTS(WITH RECURSIVE ancestors(id) AS (SELECT NEW.ParentAccountId UNION SELECT t.ParentAccountId FROM Accounts t JOIN ancestors a ON t.AccountId=a.id WHERE t.ParentAccountId IS NOT NULL) SELECT 1 FROM ancestors WHERE id=NEW.AccountId) THEN RAISE(ABORT,'Hierarchy cycle') END;SELECT CASE WHEN NEW.AccountType='Sub' AND EXISTS(SELECT 1 FROM Accounts WHERE ParentAccountId=NEW.AccountId) THEN RAISE(ABORT,'Group has children') END;
END;

CREATE TRIGGER Stk_Item_tree_INSERT BEFORE INSERT ON Stk_Item
BEGIN
SELECT CASE WHEN NEW.ParentItemId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Stk_Item WHERE ItemId=NEW.ParentItemId AND ItemType='Group') THEN RAISE(ABORT,'Parent must be a group') END;SELECT CASE WHEN EXISTS(WITH RECURSIVE ancestors(id) AS (SELECT NEW.ParentItemId UNION SELECT t.ParentItemId FROM Stk_Item t JOIN ancestors a ON t.ItemId=a.id WHERE t.ParentItemId IS NOT NULL) SELECT 1 FROM ancestors WHERE id=NEW.ItemId) THEN RAISE(ABORT,'Hierarchy cycle') END;SELECT CASE WHEN NEW.ItemType='Item' AND EXISTS(SELECT 1 FROM Stk_Item WHERE ParentItemId=NEW.ItemId) THEN RAISE(ABORT,'Group has children') END;
END;

CREATE TRIGGER Stk_Item_tree_UPDATE BEFORE UPDATE ON Stk_Item
BEGIN
SELECT CASE WHEN NEW.ParentItemId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Stk_Item WHERE ItemId=NEW.ParentItemId AND ItemType='Group') THEN RAISE(ABORT,'Parent must be a group') END;SELECT CASE WHEN EXISTS(WITH RECURSIVE ancestors(id) AS (SELECT NEW.ParentItemId UNION SELECT t.ParentItemId FROM Stk_Item t JOIN ancestors a ON t.ItemId=a.id WHERE t.ParentItemId IS NOT NULL) SELECT 1 FROM ancestors WHERE id=NEW.ItemId) THEN RAISE(ABORT,'Hierarchy cycle') END;SELECT CASE WHEN NEW.ItemType='Item' AND EXISTS(SELECT 1 FROM Stk_Item WHERE ParentItemId=NEW.ItemId) THEN RAISE(ABORT,'Group has children') END;
END;

CREATE TRIGGER accounts_identity BEFORE UPDATE ON Accounts
BEGIN
SELECT CASE WHEN (NEW.AccountId<>OLD.AccountId OR NEW.AccountType<>OLD.AccountType OR NEW.NormalBalance<>OLD.NormalBalance) AND (EXISTS(SELECT 1 FROM Yomia WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Customers WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Suppliers WHERE AccountId=OLD.AccountId) OR EXISTS(SELECT 1 FROM Cashboxes WHERE AccountId=OLD.AccountId)) THEN RAISE(ABORT,'Used account identity is locked') END;
END;

CREATE TRIGGER Customers_account_INSERT BEFORE INSERT ON Customers
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER Customers_account_UPDATE BEFORE UPDATE ON Customers
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER Suppliers_account_INSERT BEFORE INSERT ON Suppliers
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER Suppliers_account_UPDATE BEFORE UPDATE ON Suppliers
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER Cashboxes_account_INSERT BEFORE INSERT ON Cashboxes
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER Cashboxes_account_UPDATE BEFORE UPDATE ON Cashboxes
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Posting account required') END;
END;

CREATE TRIGGER item_identity BEFORE UPDATE ON Stk_Item
BEGIN
SELECT CASE WHEN (NEW.ItemId<>OLD.ItemId OR NEW.ItemType<>OLD.ItemType) AND EXISTS(SELECT 1 FROM Stk_ItemUnit WHERE ItemId=OLD.ItemId) THEN RAISE(ABORT,'Item identity in use') END;
END;

CREATE TRIGGER Customers_identity BEFORE UPDATE ON Customers
BEGIN
SELECT CASE WHEN NEW.AccountId<>OLD.AccountId AND EXISTS(SELECT 1 FROM Trans WHERE CustomerId=OLD.CustomerId) THEN RAISE(ABORT,'Used party account is locked') END;
END;

CREATE TRIGGER Suppliers_identity BEFORE UPDATE ON Suppliers
BEGIN
SELECT CASE WHEN NEW.AccountId<>OLD.AccountId AND EXISTS(SELECT 1 FROM Trans WHERE SupplierId=OLD.SupplierId) THEN RAISE(ABORT,'Used party account is locked') END;
END;

CREATE TRIGGER Cashboxes_identity BEFORE UPDATE ON Cashboxes
BEGIN
SELECT CASE WHEN NEW.AccountId<>OLD.AccountId AND EXISTS(SELECT 1 FROM Trans WHERE CashboxId=OLD.CashboxId) THEN RAISE(ABORT,'Used party account is locked') END;
END;

CREATE TRIGGER cashbox_voucher_identity BEFORE UPDATE ON Cashboxes
BEGIN
SELECT CASE WHEN (NEW.AccountId<>OLD.AccountId OR NEW.BranchId<>OLD.BranchId) AND EXISTS(SELECT 1 FROM Mstndat WHERE CashboxId=OLD.CashboxId) THEN RAISE(ABORT,'Used cashbox identity is locked') END;
END;

CREATE TRIGGER warehouse_identity BEFORE UPDATE ON Warehouses
BEGIN
SELECT CASE WHEN NEW.BranchId<>OLD.BranchId AND EXISTS(SELECT 1 FROM Trans WHERE WarehouseId=OLD.WarehouseId) THEN RAISE(ABORT,'Used warehouse branch is locked') END;
END;

CREATE TRIGGER batch_identity_UPDATE BEFORE UPDATE ON ItemBatches
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM TransDt WHERE BatchId=OLD.BatchId) THEN RAISE(ABORT,'Used batch identity is locked') END;
END;

CREATE TRIGGER doctype_identity_UPDATE BEFORE UPDATE ON DocTyp
BEGIN
SELECT RAISE(ABORT,'Document type semantics are fixed');
END;

CREATE TRIGGER settings_lock_UPDATE BEFORE UPDATE ON AppSettings
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM JournalEntries WHERE Status='Posted') THEN RAISE(ABORT,'Posting settings are locked after first posting') END;
END;

CREATE TRIGGER batch_identity_DELETE BEFORE DELETE ON ItemBatches
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM TransDt WHERE BatchId=OLD.BatchId) THEN RAISE(ABORT,'Used batch identity is locked') END;
END;

CREATE TRIGGER doctype_identity_DELETE BEFORE DELETE ON DocTyp
BEGIN
SELECT RAISE(ABORT,'Document type semantics are fixed');
END;

CREATE TRIGGER settings_lock_DELETE BEFORE DELETE ON AppSettings
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM JournalEntries WHERE Status='Posted') THEN RAISE(ABORT,'Posting settings are locked after first posting') END;
END;

CREATE TRIGGER unit_item_INSERT BEFORE INSERT ON Stk_ItemUnit
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Stk_Item WHERE ItemId=NEW.ItemId AND ItemType='Item' AND IsActive=1) THEN RAISE(ABORT,'Unit requires an active item') END;
END;

CREATE TRIGGER unit_item_UPDATE BEFORE UPDATE ON Stk_ItemUnit
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Stk_Item WHERE ItemId=NEW.ItemId AND ItemType='Item' AND IsActive=1) THEN RAISE(ABORT,'Unit requires an active item') END;
END;

CREATE TRIGGER unit_lock BEFORE UPDATE ON Stk_ItemUnit
BEGIN
SELECT CASE WHEN (NEW.ItemId<>OLD.ItemId OR NEW.PackingQty<>OLD.PackingQty OR NEW.IsBase<>OLD.IsBase OR NEW.UnitId<>OLD.UnitId OR NEW.ItemUnitId<>OLD.ItemUnitId) AND EXISTS(SELECT 1 FROM TransDt WHERE ItemUnitId=OLD.ItemUnitId) THEN RAISE(ABORT,'Used unit conversion is locked') END;
END;

CREATE TRIGGER FiscalYears_dates_INSERT BEFORE INSERT ON FiscalYears
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM FiscalYears WHERE FiscalYearId<>NEW.FiscalYearId AND StartDate<=NEW.EndDate AND EndDate>=NEW.StartDate) THEN RAISE(ABORT,'Overlapping fiscal dates') END;
END;

CREATE TRIGGER FiscalYears_dates_UPDATE BEFORE UPDATE ON FiscalYears
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM FiscalYears WHERE FiscalYearId<>NEW.FiscalYearId AND StartDate<=NEW.EndDate AND EndDate>=NEW.StartDate) THEN RAISE(ABORT,'Overlapping fiscal dates') END;
END;

CREATE TRIGGER FiscalYears_boundaries BEFORE UPDATE ON FiscalYears
BEGIN
SELECT CASE WHEN NEW.StartDate<>OLD.StartDate OR NEW.EndDate<>OLD.EndDate THEN RAISE(ABORT,'Fiscal boundaries are immutable') END;
END;

CREATE TRIGGER FiscalPeriods_dates_INSERT BEFORE INSERT ON FiscalPeriods
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM FiscalPeriods WHERE PeriodId<>NEW.PeriodId AND StartDate<=NEW.EndDate AND EndDate>=NEW.StartDate) THEN RAISE(ABORT,'Overlapping fiscal dates') END;SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM FiscalYears WHERE FiscalYearId=NEW.FiscalYearId AND NEW.StartDate>=StartDate AND NEW.EndDate<=EndDate) THEN RAISE(ABORT,'Period outside fiscal year') END;
END;

CREATE TRIGGER FiscalPeriods_dates_UPDATE BEFORE UPDATE ON FiscalPeriods
BEGIN
SELECT CASE WHEN EXISTS(SELECT 1 FROM FiscalPeriods WHERE PeriodId<>NEW.PeriodId AND StartDate<=NEW.EndDate AND EndDate>=NEW.StartDate) THEN RAISE(ABORT,'Overlapping fiscal dates') END;SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM FiscalYears WHERE FiscalYearId=NEW.FiscalYearId AND NEW.StartDate>=StartDate AND NEW.EndDate<=EndDate) THEN RAISE(ABORT,'Period outside fiscal year') END;
END;

CREATE TRIGGER FiscalPeriods_boundaries BEFORE UPDATE ON FiscalPeriods
BEGIN
SELECT CASE WHEN NEW.StartDate<>OLD.StartDate OR NEW.EndDate<>OLD.EndDate THEN RAISE(ABORT,'Fiscal boundaries are immutable') END;
END;

CREATE VIEW UserPermissions AS
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

CREATE TRIGGER Trans_draft_insert BEFORE INSERT ON Trans
BEGIN
SELECT CASE WHEN NEW.Status<>'Draft' THEN RAISE(ABORT,'Insert a draft first') END;
END;

CREATE TRIGGER Trans_posted_UPDATE BEFORE UPDATE ON Trans WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER Trans_posted_DELETE BEFORE DELETE ON Trans WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER Trans_key_lock BEFORE UPDATE ON Trans
BEGIN
SELECT CASE WHEN NEW.TransId<>OLD.TransId OR NEW.Typ<>OLD.Typ THEN RAISE(ABORT,'Document identity is immutable') END;
END;

CREATE TRIGGER Mstndat_draft_insert BEFORE INSERT ON Mstndat
BEGIN
SELECT CASE WHEN NEW.Status<>'Draft' THEN RAISE(ABORT,'Insert a draft first') END;
END;

CREATE TRIGGER Mstndat_posted_UPDATE BEFORE UPDATE ON Mstndat WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER Mstndat_posted_DELETE BEFORE DELETE ON Mstndat WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER Mstndat_key_lock BEFORE UPDATE ON Mstndat
BEGIN
SELECT CASE WHEN NEW.VoucherId<>OLD.VoucherId OR NEW.Typ<>OLD.Typ THEN RAISE(ABORT,'Document identity is immutable') END;
END;

CREATE TRIGGER JournalEntries_draft_insert BEFORE INSERT ON JournalEntries
BEGIN
SELECT CASE WHEN NEW.Status<>'Draft' THEN RAISE(ABORT,'Insert a draft first') END;
END;

CREATE TRIGGER JournalEntries_posted_UPDATE BEFORE UPDATE ON JournalEntries WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER JournalEntries_posted_DELETE BEFORE DELETE ON JournalEntries WHEN OLD.Status='Posted'
BEGIN
SELECT RAISE(ABORT,'Posted document is immutable');
END;

CREATE TRIGGER JournalEntries_key_lock BEFORE UPDATE ON JournalEntries
BEGIN
SELECT CASE WHEN NEW.JournalId<>OLD.JournalId OR NEW.Typ<>OLD.Typ THEN RAISE(ABORT,'Document identity is immutable') END;
END;

CREATE TRIGGER TransDt_draft_INSERT BEFORE INSERT ON TransDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Trans WHERE TransId=NEW.TransId AND Typ=NEW.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER TransDt_draft_UPDATE BEFORE UPDATE ON TransDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Trans WHERE TransId=OLD.TransId AND Typ=OLD.Typ),'Missing')<>'Draft' OR coalesce((SELECT Status FROM Trans WHERE TransId=NEW.TransId AND Typ=NEW.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER TransDt_draft_DELETE BEFORE DELETE ON TransDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Trans WHERE TransId=OLD.TransId AND Typ=OLD.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER VoucherDt_draft_INSERT BEFORE INSERT ON VoucherDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=NEW.VoucherId AND Typ=NEW.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER VoucherDt_draft_UPDATE BEFORE UPDATE ON VoucherDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=OLD.VoucherId AND Typ=OLD.Typ),'Missing')<>'Draft' OR coalesce((SELECT Status FROM Mstndat WHERE VoucherId=NEW.VoucherId AND Typ=NEW.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER VoucherDt_draft_DELETE BEFORE DELETE ON VoucherDt
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=OLD.VoucherId AND Typ=OLD.Typ),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER PaymentAllocation_draft_INSERT BEFORE INSERT ON PaymentAllocation
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=NEW.VoucherId AND Typ=NEW.VoucherTyp),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER PaymentAllocation_draft_UPDATE BEFORE UPDATE ON PaymentAllocation
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=OLD.VoucherId AND Typ=OLD.VoucherTyp),'Missing')<>'Draft' OR coalesce((SELECT Status FROM Mstndat WHERE VoucherId=NEW.VoucherId AND Typ=NEW.VoucherTyp),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER PaymentAllocation_draft_DELETE BEFORE DELETE ON PaymentAllocation
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM Mstndat WHERE VoucherId=OLD.VoucherId AND Typ=OLD.VoucherTyp),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER Yomia_draft_INSERT BEFORE INSERT ON Yomia
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=NEW.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER Yomia_draft_UPDATE BEFORE UPDATE ON Yomia
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId),'Missing')<>'Draft' OR coalesce((SELECT Status FROM JournalEntries WHERE JournalId=NEW.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER Yomia_draft_DELETE BEFORE DELETE ON Yomia
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER YomiaCostCenters_draft_INSERT BEFORE INSERT ON YomiaCostCenters
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=NEW.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER YomiaCostCenters_draft_UPDATE BEFORE UPDATE ON YomiaCostCenters
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId),'Missing')<>'Draft' OR coalesce((SELECT Status FROM JournalEntries WHERE JournalId=NEW.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER YomiaCostCenters_draft_DELETE BEFORE DELETE ON YomiaCostCenters
BEGIN
SELECT CASE WHEN coalesce((SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId),'Missing')<>'Draft' THEN RAISE(ABORT,'Lines require a draft parent') END;
END;

CREATE TRIGGER yomia_account_INSERT BEFORE INSERT ON Yomia
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Active subaccount required') END;
END;

CREATE TRIGGER yomia_account_UPDATE BEFORE UPDATE ON Yomia
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Accounts WHERE AccountId=NEW.AccountId AND AccountType='Sub' AND IsActive=1) THEN RAISE(ABORT,'Active subaccount required') END;
END;

CREATE TRIGGER movement_immutable_UPDATE BEFORE UPDATE ON InventoryMovements
BEGIN
SELECT RAISE(ABORT,'Inventory movements are immutable');
END;

CREATE TRIGGER audit_immutable_UPDATE BEFORE UPDATE ON AuditLogs
BEGIN
SELECT RAISE(ABORT,'Audit log is append only');
END;

CREATE TRIGGER movement_immutable_DELETE BEFORE DELETE ON InventoryMovements
BEGIN
SELECT RAISE(ABORT,'Inventory movements are immutable');
END;

CREATE TRIGGER audit_immutable_DELETE BEFORE DELETE ON AuditLogs
BEGIN
SELECT RAISE(ABORT,'Audit log is append only');
END;

CREATE TRIGGER movement_source BEFORE INSERT ON InventoryMovements
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Trans t JOIN InvoiceLineAmounts d ON t.TransId=d.TransId AND t.Typ=d.Typ
 WHERE t.TransId=NEW.TransId AND t.Typ=NEW.Typ AND d.LineNo=NEW.LineNo AND t.Status='Posted'
 AND t.WarehouseId=NEW.WarehouseId AND d.ItemId=NEW.ItemId AND d.ItemUnitId=NEW.ItemUnitId
 AND d.BatchId IS NEW.BatchId AND t.CreatedBy=NEW.CreatedBy AND t.TransDate=NEW.MovementDate
 AND NEW.QuantityChange=d.QtyBase*CASE WHEN t.Typ IN (1,3) THEN 1 ELSE -1 END
 AND NEW.ValueChange=d.CostAmount*CASE WHEN t.Typ IN (1,3) THEN 1 ELSE -1 END) THEN RAISE(ABORT,'Inventory source mismatch') END;SELECT CASE WHEN coalesce((SELECT QtyBase FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.QuantityChange NOT BETWEEN 0 AND 1000000000 THEN RAISE(ABORT,'Insufficient stock or quantity limit') END;SELECT CASE WHEN coalesce((SELECT StockValue FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.ValueChange NOT BETWEEN 0 AND 1000000000 THEN RAISE(ABORT,'Insufficient stock value or value limit') END;SELECT CASE WHEN coalesce((SELECT QtyBase FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.QuantityChange=0 AND coalesce((SELECT StockValue FROM StockBalances WHERE WarehouseId=NEW.WarehouseId AND ItemId=NEW.ItemId AND BatchId IS NEW.BatchId),0)+NEW.ValueChange<>0 THEN RAISE(ABORT,'Zero stock must have zero value') END;
END;

CREATE TRIGGER invoice_validate BEFORE UPDATE OF Status ON Trans WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN

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

END;

CREATE TRIGGER invoice_post AFTER UPDATE OF Status ON Trans WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN

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

END;

CREATE TRIGGER voucher_validate BEFORE UPDATE OF Status ON Mstndat WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN

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
 SELECT CASE WHEN EXISTS(SELECT a.PartyAccount AS AccountId FROM PaymentAllocation p JOIN InvoiceTotals a ON a.TransId=p.TransId AND a.Typ=p.TransTyp
 WHERE p.VoucherId=NEW.VoucherId AND p.VoucherTyp=NEW.Typ GROUP BY a.PartyAccount
 HAVING sum(p.Amount)>coalesce((SELECT sum(d.Amount) FROM VoucherDt d WHERE d.VoucherId=NEW.VoucherId AND d.Typ=NEW.Typ AND d.AccountId=a.PartyAccount),0)) THEN RAISE(ABORT,'Allocation party does not match voucher lines') END;

END;

CREATE TRIGGER voucher_post AFTER UPDATE OF Status ON Mstndat WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN

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

END;

CREATE TRIGGER journal_validate BEFORE UPDATE OF Status ON JournalEntries WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN

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

END;

CREATE TRIGGER journal_audit AFTER UPDATE OF Status ON JournalEntries WHEN OLD.Status='Draft' AND NEW.Status='Posted'
BEGIN
INSERT INTO AuditLogs(UserId,EntityName,EntityKey,Action) VALUES(NEW.CreatedBy,'JournalEntries',NEW.JournalId,'post');
END;

CREATE TRIGGER opening_check_INSERT BEFORE INSERT ON AccountOpeningBalances
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Yomia l JOIN JournalEntries j USING(JournalId) JOIN FiscalYears y ON y.FiscalYearId=NEW.FiscalYearId WHERE l.JournalId=NEW.JournalId AND l.LineNo=NEW.LineNo AND l.AccountId=NEW.AccountId AND j.Typ=7 AND j.Status='Posted' AND j.EntryDate=y.StartDate) THEN RAISE(ABORT,'Opening balance requires posted opening journal') END;
END;

CREATE TRIGGER opening_check_UPDATE BEFORE UPDATE ON AccountOpeningBalances
BEGIN
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM Yomia l JOIN JournalEntries j USING(JournalId) JOIN FiscalYears y ON y.FiscalYearId=NEW.FiscalYearId WHERE l.JournalId=NEW.JournalId AND l.LineNo=NEW.LineNo AND l.AccountId=NEW.AccountId AND j.Typ=7 AND j.Status='Posted' AND j.EntryDate=y.StartDate) THEN RAISE(ABORT,'Opening balance requires posted opening journal') END;
END;
