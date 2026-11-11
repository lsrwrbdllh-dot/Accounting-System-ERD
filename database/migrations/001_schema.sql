-- Money: INTEGER minor units (2 decimals). Quantities and pack factors: INTEGER /1000.
-- No REAL arithmetic. Numeric limits keep multiplication inside signed int64.
CREATE TABLE Units (
 UnitId INTEGER PRIMARY KEY, UnitName TEXT NOT NULL UNIQUE CHECK(length(trim(UnitName))>0)
);
CREATE TABLE Accounts (
 AccountId INTEGER PRIMARY KEY, Code TEXT NOT NULL UNIQUE CHECK(length(trim(Code))>0),
 ParentAccountId INTEGER REFERENCES Accounts(AccountId) ON DELETE RESTRICT,
 AccountName TEXT NOT NULL CHECK(length(trim(AccountName))>0),
 AccountType TEXT NOT NULL CHECK(AccountType IN ('Main','Sub')),
 NormalBalance TEXT NOT NULL CHECK(NormalBalance IN ('Debit','Credit')),
 IsActive INTEGER NOT NULL DEFAULT 1 CHECK(IsActive IN (0,1)),
 CHECK(ParentAccountId IS NULL OR ParentAccountId<>AccountId)
);
CREATE TABLE Stk_Item (
 ItemId INTEGER PRIMARY KEY, Code TEXT NOT NULL UNIQUE CHECK(length(trim(Code))>0),
 ParentItemId INTEGER REFERENCES Stk_Item(ItemId) ON DELETE RESTRICT,
 ItemName TEXT NOT NULL CHECK(length(trim(ItemName))>0),
 ItemType TEXT NOT NULL CHECK(ItemType IN ('Group','Item')),
 Barcode TEXT UNIQUE, IsActive INTEGER NOT NULL DEFAULT 1 CHECK(IsActive IN (0,1)),
 CHECK(ParentItemId IS NULL OR ParentItemId<>ItemId)
);
CREATE TABLE Stk_ItemUnit (
 ItemUnitId INTEGER PRIMARY KEY, ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId),
 UnitId INTEGER NOT NULL REFERENCES Units(UnitId),
 PackingQty INTEGER NOT NULL CHECK(typeof(PackingQty)='integer' AND PackingQty BETWEEN 1 AND 1000000),
 IsBase INTEGER NOT NULL DEFAULT 0 CHECK(IsBase IN (0,1)), Barcode TEXT UNIQUE,
 UNIQUE(ItemId,UnitId), UNIQUE(ItemId,ItemUnitId), CHECK(IsBase=0 OR PackingQty=1000)
);
CREATE UNIQUE INDEX ux_item_base ON Stk_ItemUnit(ItemId) WHERE IsBase=1;
CREATE TABLE Branches (
 BranchId INTEGER PRIMARY KEY, BranchName TEXT NOT NULL UNIQUE CHECK(length(trim(BranchName))>0)
);
CREATE TABLE Warehouses (
 WarehouseId INTEGER PRIMARY KEY, BranchId INTEGER NOT NULL REFERENCES Branches(BranchId),
 WarehouseName TEXT NOT NULL CHECK(length(trim(WarehouseName))>0), UNIQUE(BranchId,WarehouseName)
);
CREATE TABLE Customers (
 CustomerId INTEGER PRIMARY KEY, AccountId INTEGER NOT NULL UNIQUE REFERENCES Accounts(AccountId),
 CustomerName TEXT NOT NULL CHECK(length(trim(CustomerName))>0), Phone TEXT, Address TEXT
);
CREATE TABLE Suppliers (
 SupplierId INTEGER PRIMARY KEY, AccountId INTEGER NOT NULL UNIQUE REFERENCES Accounts(AccountId),
 SupplierName TEXT NOT NULL CHECK(length(trim(SupplierName))>0), Phone TEXT, Address TEXT
);
CREATE TABLE ItemBatches (
 BatchId INTEGER PRIMARY KEY, ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId),
 LotNumber TEXT NOT NULL CHECK(length(trim(LotNumber))>0), ProductionDate TEXT, ExpiryDate TEXT,
 UNIQUE(ItemId,LotNumber), UNIQUE(ItemId,BatchId),
 CHECK(ProductionDate IS NULL OR (date(ProductionDate,'+0 days') IS NOT NULL AND date(ProductionDate,'+0 days')=ProductionDate)),
 CHECK(ExpiryDate IS NULL OR (date(ExpiryDate,'+0 days') IS NOT NULL AND date(ExpiryDate,'+0 days')=ExpiryDate)),
 CHECK(ProductionDate IS NULL OR ExpiryDate IS NULL OR ExpiryDate>=ProductionDate)
);
CREATE TABLE Currencies (
 CurrencyId INTEGER PRIMARY KEY, CurrencyCode TEXT NOT NULL UNIQUE,
 CurrencyName TEXT NOT NULL, DecimalPlaces INTEGER NOT NULL DEFAULT 2 CHECK(DecimalPlaces=2)
);
CREATE TABLE ExchangeRates (
 RateId INTEGER PRIMARY KEY, CurrencyId INTEGER NOT NULL REFERENCES Currencies(CurrencyId),
 RateDate TEXT NOT NULL CHECK(date(RateDate,'+0 days') IS NOT NULL AND date(RateDate,'+0 days')=RateDate),
 RateToBase INTEGER NOT NULL CHECK(typeof(RateToBase)='integer' AND RateToBase>0), UNIQUE(CurrencyId,RateDate)
);
CREATE TABLE FiscalYears (
 FiscalYearId INTEGER PRIMARY KEY, YearName TEXT NOT NULL UNIQUE,
 StartDate TEXT NOT NULL CHECK(date(StartDate,'+0 days') IS NOT NULL AND date(StartDate,'+0 days')=StartDate),
 EndDate TEXT NOT NULL CHECK(date(EndDate,'+0 days') IS NOT NULL AND date(EndDate,'+0 days')=EndDate),
 Status TEXT NOT NULL DEFAULT 'Open' CHECK(Status IN ('Open','Closed')), CHECK(StartDate<=EndDate)
);
CREATE TABLE FiscalPeriods (
 PeriodId INTEGER PRIMARY KEY, FiscalYearId INTEGER NOT NULL REFERENCES FiscalYears(FiscalYearId),
 PeriodName TEXT NOT NULL, StartDate TEXT NOT NULL, EndDate TEXT NOT NULL,
 Status TEXT NOT NULL DEFAULT 'Open' CHECK(Status IN ('Open','Closed')),
 UNIQUE(FiscalYearId,PeriodName),
 CHECK(date(StartDate,'+0 days') IS NOT NULL AND date(StartDate,'+0 days')=StartDate),
 CHECK(date(EndDate,'+0 days') IS NOT NULL AND date(EndDate,'+0 days')=EndDate), CHECK(StartDate<=EndDate)
);
CREATE TABLE Users (
 UserId INTEGER PRIMARY KEY, BranchId INTEGER NOT NULL REFERENCES Branches(BranchId),
 Username TEXT NOT NULL UNIQUE CHECK(length(trim(Username))>0),
 PasswordHash TEXT NOT NULL CHECK(PasswordHash LIKE 'pbkdf2_sha256$600000$%'),
 IsActive INTEGER NOT NULL DEFAULT 1 CHECK(IsActive IN (0,1))
);
CREATE TABLE Roles (RoleId INTEGER PRIMARY KEY, RoleName TEXT NOT NULL UNIQUE);
CREATE TABLE Permissions (PermissionId INTEGER PRIMARY KEY, PermissionCode TEXT NOT NULL UNIQUE);
CREATE TABLE UserRoles (
 UserId INTEGER NOT NULL REFERENCES Users(UserId), RoleId INTEGER NOT NULL REFERENCES Roles(RoleId),
 PRIMARY KEY(UserId,RoleId)
);
CREATE TABLE RolePermissions (
 RoleId INTEGER NOT NULL REFERENCES Roles(RoleId), PermissionId INTEGER NOT NULL REFERENCES Permissions(PermissionId),
 PRIMARY KEY(RoleId,PermissionId)
);
CREATE TABLE Cashboxes (
 CashboxId INTEGER PRIMARY KEY, BranchId INTEGER NOT NULL REFERENCES Branches(BranchId),
 AccountId INTEGER NOT NULL UNIQUE REFERENCES Accounts(AccountId), CashboxName TEXT NOT NULL UNIQUE
);
CREATE TABLE DocTyp (
 Typ INTEGER PRIMARY KEY CHECK(Typ BETWEEN 1 AND 7), TypName TEXT NOT NULL UNIQUE,
 DocumentFamily TEXT NOT NULL CHECK(DocumentFamily IN ('Invoice','Voucher','Journal')),
 CHECK((Typ BETWEEN 1 AND 4 AND DocumentFamily='Invoice') OR (Typ IN (5,6) AND DocumentFamily='Voucher') OR (Typ=7 AND DocumentFamily='Journal'))
);
CREATE TABLE Trans (
 TransId INTEGER NOT NULL CHECK(TransId>0), Typ INTEGER NOT NULL REFERENCES DocTyp(Typ) CHECK(Typ BETWEEN 1 AND 4),
 TransDate TEXT NOT NULL CHECK(date(TransDate,'+0 days') IS NOT NULL AND date(TransDate,'+0 days')=TransDate),
 CustomerId INTEGER REFERENCES Customers(CustomerId), SupplierId INTEGER REFERENCES Suppliers(SupplierId),
 WarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId),
 CurrencyId INTEGER NOT NULL REFERENCES Currencies(CurrencyId) CHECK(CurrencyId=1),
 ExchangeRate INTEGER NOT NULL DEFAULT 1000000 CHECK(ExchangeRate=1000000),
 PaymentMethod TEXT NOT NULL CHECK(PaymentMethod IN ('Cash','Credit')),
 CashboxId INTEGER REFERENCES Cashboxes(CashboxId),
 Subtotal INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Subtotal)='integer' AND Subtotal BETWEEN 0 AND 1000000000),
 Discount INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Discount)='integer' AND Discount BETWEEN 0 AND Subtotal),
 Tax INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Tax)='integer' AND Tax BETWEEN 0 AND 1000000000),
 Total INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Total)='integer' AND Total BETWEEN 0 AND 1000000000 AND Total=Subtotal-Discount+Tax),
 Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status IN ('Draft','Posted')),
 OriginalTransId INTEGER, OriginalTyp INTEGER,
 Notes TEXT NOT NULL DEFAULT '', CreatedBy INTEGER NOT NULL REFERENCES Users(UserId),
 PRIMARY KEY(TransId,Typ), FOREIGN KEY(OriginalTransId,OriginalTyp) REFERENCES Trans(TransId,Typ),
 CHECK(NOT(CustomerId IS NOT NULL AND SupplierId IS NOT NULL)),
 CHECK((Typ IN (1,4) AND CustomerId IS NULL) OR (Typ IN (2,3) AND SupplierId IS NULL)),
 CHECK((PaymentMethod='Cash' AND CashboxId IS NOT NULL) OR (PaymentMethod='Credit' AND CashboxId IS NULL AND ((Typ IN (1,4) AND SupplierId IS NOT NULL) OR (Typ IN (2,3) AND CustomerId IS NOT NULL)))),
 CHECK((Typ IN (1,2) AND OriginalTransId IS NULL AND OriginalTyp IS NULL) OR (Typ=3 AND OriginalTransId IS NOT NULL AND OriginalTyp=2) OR (Typ=4 AND OriginalTransId IS NOT NULL AND OriginalTyp=1))
);
CREATE TABLE TransDt (
 TransId INTEGER NOT NULL, Typ INTEGER NOT NULL, LineNo INTEGER NOT NULL CHECK(LineNo BETWEEN 1 AND 1000),
 ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId), ItemUnitId INTEGER NOT NULL, BatchId INTEGER,
 Qty INTEGER NOT NULL CHECK(typeof(Qty)='integer' AND Qty BETWEEN 1 AND 1000000000),
 Price INTEGER NOT NULL CHECK(typeof(Price)='integer' AND Price BETWEEN 0 AND 1000000000),
 GrossAmount INTEGER NOT NULL CHECK(typeof(GrossAmount)='integer' AND GrossAmount BETWEEN 0 AND 1000000000),
 Discount INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Discount)='integer' AND Discount BETWEEN 0 AND GrossAmount),
 Tax INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Tax)='integer' AND Tax BETWEEN 0 AND 1000000000),
 OriginalLineNo INTEGER, CostAmount INTEGER NOT NULL DEFAULT 0 CHECK(typeof(CostAmount)='integer' AND CostAmount BETWEEN 0 AND 1000000000),
 PRIMARY KEY(TransId,Typ,LineNo), FOREIGN KEY(TransId,Typ) REFERENCES Trans(TransId,Typ),
 FOREIGN KEY(ItemId,ItemUnitId) REFERENCES Stk_ItemUnit(ItemId,ItemUnitId),
 FOREIGN KEY(ItemId,BatchId) REFERENCES ItemBatches(ItemId,BatchId)
);
CREATE TABLE Mstndat (
 VoucherId INTEGER NOT NULL CHECK(VoucherId>0), Typ INTEGER NOT NULL REFERENCES DocTyp(Typ) CHECK(Typ IN (5,6)),
 VoucherDate TEXT NOT NULL CHECK(date(VoucherDate,'+0 days') IS NOT NULL AND date(VoucherDate,'+0 days')=VoucherDate),
 CashboxId INTEGER NOT NULL REFERENCES Cashboxes(CashboxId),
 CurrencyId INTEGER NOT NULL REFERENCES Currencies(CurrencyId) CHECK(CurrencyId=1),
 Amount INTEGER NOT NULL CHECK(typeof(Amount)='integer' AND Amount BETWEEN 1 AND 1000000000),
 Description TEXT NOT NULL DEFAULT '', Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status IN ('Draft','Posted')),
 CreatedBy INTEGER NOT NULL REFERENCES Users(UserId), PRIMARY KEY(VoucherId,Typ)
);
CREATE TABLE VoucherDt (
 VoucherId INTEGER NOT NULL, Typ INTEGER NOT NULL, LineNo INTEGER NOT NULL CHECK(LineNo BETWEEN 1 AND 1000),
 AccountId INTEGER NOT NULL REFERENCES Accounts(AccountId),
 Amount INTEGER NOT NULL CHECK(typeof(Amount)='integer' AND Amount BETWEEN 1 AND 1000000000),
 PRIMARY KEY(VoucherId,Typ,LineNo), FOREIGN KEY(VoucherId,Typ) REFERENCES Mstndat(VoucherId,Typ)
);
CREATE TABLE PaymentAllocation (
 AllocationId INTEGER PRIMARY KEY, VoucherId INTEGER NOT NULL, VoucherTyp INTEGER NOT NULL,
 TransId INTEGER NOT NULL, TransTyp INTEGER NOT NULL CHECK(TransTyp IN (1,2)),
 Amount INTEGER NOT NULL CHECK(typeof(Amount)='integer' AND Amount BETWEEN 1 AND 1000000000),
 FOREIGN KEY(VoucherId,VoucherTyp) REFERENCES Mstndat(VoucherId,Typ),
 FOREIGN KEY(TransId,TransTyp) REFERENCES Trans(TransId,Typ), UNIQUE(VoucherId,VoucherTyp,TransId,TransTyp)
);
-- Explicit typed source FKs replace the unsafe polymorphic SourceId.
CREATE TABLE JournalEntries (
 JournalId INTEGER PRIMARY KEY, PeriodId INTEGER NOT NULL REFERENCES FiscalPeriods(PeriodId),
 Typ INTEGER NOT NULL REFERENCES DocTyp(Typ), InvoiceId INTEGER, InvoiceTyp INTEGER,
 VoucherId INTEGER, VoucherTyp INTEGER,
 EntryDate TEXT NOT NULL CHECK(date(EntryDate,'+0 days') IS NOT NULL AND date(EntryDate,'+0 days')=EntryDate),
 Description TEXT NOT NULL DEFAULT '', Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status IN ('Draft','Posted')),
 CreatedBy INTEGER NOT NULL REFERENCES Users(UserId),
 FOREIGN KEY(InvoiceId,InvoiceTyp) REFERENCES Trans(TransId,Typ),
 FOREIGN KEY(VoucherId,VoucherTyp) REFERENCES Mstndat(VoucherId,Typ),
 UNIQUE(InvoiceId,InvoiceTyp), UNIQUE(VoucherId,VoucherTyp),
 CHECK((Typ BETWEEN 1 AND 4 AND InvoiceId IS NOT NULL AND InvoiceTyp IS NOT NULL AND InvoiceTyp=Typ AND VoucherId IS NULL AND VoucherTyp IS NULL) OR
 (Typ IN (5,6) AND VoucherId IS NOT NULL AND VoucherTyp IS NOT NULL AND VoucherTyp=Typ AND InvoiceId IS NULL AND InvoiceTyp IS NULL) OR
 (Typ=7 AND InvoiceId IS NULL AND InvoiceTyp IS NULL AND VoucherId IS NULL AND VoucherTyp IS NULL))
);
CREATE TABLE Yomia (
 JournalId INTEGER NOT NULL REFERENCES JournalEntries(JournalId), LineNo INTEGER NOT NULL CHECK(LineNo BETWEEN 1 AND 5000),
 AccountId INTEGER NOT NULL REFERENCES Accounts(AccountId),
 Debit INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Debit)='integer' AND Debit BETWEEN 0 AND 1000000000),
 Credit INTEGER NOT NULL DEFAULT 0 CHECK(typeof(Credit)='integer' AND Credit BETWEEN 0 AND 1000000000),
 Description TEXT NOT NULL DEFAULT '', PRIMARY KEY(JournalId,LineNo),
 CHECK((Debit>0 AND Credit=0) OR (Credit>0 AND Debit=0))
);
CREATE TABLE InventoryMovements (
 MovementId INTEGER PRIMARY KEY, WarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId),
 ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId), BatchId INTEGER,
 TransId INTEGER NOT NULL, Typ INTEGER NOT NULL, LineNo INTEGER NOT NULL,
 ItemUnitId INTEGER NOT NULL,
 QuantityChange INTEGER NOT NULL CHECK(typeof(QuantityChange)='integer' AND QuantityChange<>0 AND abs(QuantityChange)<=1000000000),
 ValueChange INTEGER NOT NULL CHECK(typeof(ValueChange)='integer' AND abs(ValueChange)<=1000000000),
 MovementDate TEXT NOT NULL, CreatedBy INTEGER NOT NULL REFERENCES Users(UserId),
 FOREIGN KEY(TransId,Typ,LineNo) REFERENCES TransDt(TransId,Typ,LineNo),
 FOREIGN KEY(ItemId,ItemUnitId) REFERENCES Stk_ItemUnit(ItemId,ItemUnitId),
 FOREIGN KEY(ItemId,BatchId) REFERENCES ItemBatches(ItemId,BatchId), UNIQUE(TransId,Typ,LineNo)
);
CREATE TABLE CostCenters (CostCenterId INTEGER PRIMARY KEY, CenterName TEXT NOT NULL UNIQUE);
CREATE TABLE YomiaCostCenters (
 JournalId INTEGER NOT NULL, LineNo INTEGER NOT NULL, CostCenterId INTEGER NOT NULL REFERENCES CostCenters(CostCenterId),
 Amount INTEGER NOT NULL CHECK(typeof(Amount)='integer' AND Amount BETWEEN 1 AND 1000000000),
 PRIMARY KEY(JournalId,LineNo,CostCenterId), FOREIGN KEY(JournalId,LineNo) REFERENCES Yomia(JournalId,LineNo)
);
-- Opening balances are tied to a posted manual journal; never added a second time to balances.
CREATE TABLE AccountOpeningBalances (
 FiscalYearId INTEGER NOT NULL REFERENCES FiscalYears(FiscalYearId), AccountId INTEGER NOT NULL REFERENCES Accounts(AccountId),
 JournalId INTEGER NOT NULL, LineNo INTEGER NOT NULL,
 PRIMARY KEY(FiscalYearId,AccountId), UNIQUE(JournalId,LineNo), FOREIGN KEY(JournalId,LineNo) REFERENCES Yomia(JournalId,LineNo)
);
-- Proposed expansion documents are safely stored as drafts until their workflows are implemented.
CREATE TABLE WarehouseTransfers (
 TransferId INTEGER PRIMARY KEY, FromWarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId),
 ToWarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId), TransferDate TEXT NOT NULL,
 Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status='Draft'), CHECK(FromWarehouseId<>ToWarehouseId)
);
CREATE TABLE WarehouseTransferDt (
 TransferId INTEGER NOT NULL REFERENCES WarehouseTransfers(TransferId), LineNo INTEGER NOT NULL,
 ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId), BatchId INTEGER,
 QtySent INTEGER NOT NULL CHECK(typeof(QtySent)='integer' AND QtySent>0),
 QtyReceived INTEGER NOT NULL CHECK(typeof(QtyReceived)='integer' AND QtyReceived BETWEEN 0 AND QtySent),
 PRIMARY KEY(TransferId,LineNo), FOREIGN KEY(ItemId,BatchId) REFERENCES ItemBatches(ItemId,BatchId)
);
CREATE TABLE InventoryCounts (
 CountId INTEGER PRIMARY KEY, WarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId), CountDate TEXT NOT NULL,
 Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status='Draft')
);
CREATE TABLE InventoryCountDt (
 CountId INTEGER NOT NULL REFERENCES InventoryCounts(CountId), LineNo INTEGER NOT NULL,
 ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId), BatchId INTEGER,
 SystemQty INTEGER NOT NULL CHECK(typeof(SystemQty)='integer' AND SystemQty>=0),
 CountedQty INTEGER NOT NULL CHECK(typeof(CountedQty)='integer' AND CountedQty>=0),
 PRIMARY KEY(CountId,LineNo), FOREIGN KEY(ItemId,BatchId) REFERENCES ItemBatches(ItemId,BatchId)
);
CREATE TABLE StockAdjustments (
 AdjustmentId INTEGER PRIMARY KEY, WarehouseId INTEGER NOT NULL REFERENCES Warehouses(WarehouseId),
 CountId INTEGER UNIQUE REFERENCES InventoryCounts(CountId), AdjustmentDate TEXT NOT NULL,
 Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status='Draft')
);
CREATE TABLE StockAdjustmentDt (
 AdjustmentId INTEGER NOT NULL REFERENCES StockAdjustments(AdjustmentId), LineNo INTEGER NOT NULL,
 ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId), BatchId INTEGER,
 QtyDifference INTEGER NOT NULL CHECK(typeof(QtyDifference)='integer' AND QtyDifference<>0),
 UnitCost INTEGER NOT NULL CHECK(typeof(UnitCost)='integer' AND UnitCost>=0),
 PRIMARY KEY(AdjustmentId,LineNo), FOREIGN KEY(ItemId,BatchId) REFERENCES ItemBatches(ItemId,BatchId)
);
CREATE TABLE AuditLogs (
 AuditId INTEGER PRIMARY KEY, UserId INTEGER NOT NULL REFERENCES Users(UserId),
 EntityName TEXT NOT NULL, EntityKey TEXT NOT NULL, Action TEXT NOT NULL,
 EventTime TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), Details TEXT NOT NULL DEFAULT ''
);
CREATE TABLE AppSettings (SettingKey TEXT PRIMARY KEY, SettingValue TEXT NOT NULL);
CREATE INDEX ix_accounts_parent ON Accounts(ParentAccountId);
CREATE INDEX ix_items_parent ON Stk_Item(ParentItemId);
CREATE INDEX ix_trans_date ON Trans(TransDate,Status);
CREATE INDEX ix_trans_customer ON Trans(CustomerId,Status);
CREATE INDEX ix_trans_supplier ON Trans(SupplierId,Status);
CREATE INDEX ix_trans_original ON Trans(OriginalTransId,OriginalTyp);
CREATE INDEX ix_voucher_date ON Mstndat(VoucherDate,Status);
CREATE INDEX ix_yomia_account ON Yomia(AccountId,JournalId);
CREATE INDEX ix_journal_date ON JournalEntries(EntryDate,Status);
CREATE INDEX ix_movements_stock ON InventoryMovements(WarehouseId,ItemId,BatchId,MovementId);
CREATE INDEX ix_allocation_invoice ON PaymentAllocation(TransId,TransTyp);
CREATE INDEX ix_audit_entity ON AuditLogs(EntityName,EntityKey,AuditId);
