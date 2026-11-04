-- Accounting System ERD -> SQLite schema (initial single-stock design)
-- Run with SQLite 3. PRAGMA foreign_keys must be enabled on EACH connection.
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS Units (
  UnitId INTEGER PRIMARY KEY,
  UnitName TEXT NOT NULL UNIQUE CHECK(length(trim(UnitName)) > 0)
);
CREATE TABLE IF NOT EXISTS Stk_Item (
  ItemId INTEGER PRIMARY KEY,
  ParentItemId INTEGER REFERENCES Stk_Item(ItemId) ON DELETE RESTRICT,
  ItemName TEXT NOT NULL CHECK(length(trim(ItemName)) > 0),
  ItemType TEXT NOT NULL CHECK(ItemType IN ('Group','Item')),
  CHECK(ParentItemId IS NULL OR ParentItemId <> ItemId)
);
CREATE TABLE IF NOT EXISTS Stk_ItemUnit (
  ItemUnitId INTEGER PRIMARY KEY,
  ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId) ON DELETE RESTRICT,
  UnitId INTEGER NOT NULL REFERENCES Units(UnitId) ON DELETE RESTRICT,
  PackingQty NUMERIC NOT NULL CHECK(PackingQty > 0),
  UNIQUE(ItemId, UnitId),
  UNIQUE(ItemId, ItemUnitId)
);
CREATE TABLE IF NOT EXISTS Accounts (
  AccountId INTEGER PRIMARY KEY,
  ParentAccountId INTEGER REFERENCES Accounts(AccountId) ON DELETE RESTRICT,
  AccountName TEXT NOT NULL CHECK(length(trim(AccountName)) > 0),
  AccountType TEXT NOT NULL CHECK(AccountType IN ('Main','Sub')),
  CHECK(ParentAccountId IS NULL OR ParentAccountId <> AccountId)
);
CREATE TABLE IF NOT EXISTS DocTyp (
  Typ INTEGER PRIMARY KEY CHECK(Typ BETWEEN 1 AND 7),
  TypName TEXT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS Trans (
  TransId INTEGER NOT NULL,
  Typ INTEGER NOT NULL CHECK(Typ BETWEEN 1 AND 4),
  TransDate TEXT NOT NULL DEFAULT (date('now')),
  Total NUMERIC NOT NULL DEFAULT 0 CHECK(Total >= 0),
  Notes TEXT,
  Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status IN ('Draft','Posted')),
  PRIMARY KEY(TransId, Typ),
  FOREIGN KEY(Typ) REFERENCES DocTyp(Typ) ON DELETE RESTRICT
);
CREATE TABLE IF NOT EXISTS TransDt (
  TransId INTEGER NOT NULL,
  Typ INTEGER NOT NULL,
  LineNo INTEGER NOT NULL CHECK(LineNo > 0),
  ItemId INTEGER NOT NULL REFERENCES Stk_Item(ItemId) ON DELETE RESTRICT,
  ItemUnitId INTEGER NOT NULL,
  Qty NUMERIC NOT NULL CHECK(Qty > 0),
  Price NUMERIC NOT NULL CHECK(Price >= 0),
  PRIMARY KEY(TransId, Typ, LineNo),
  FOREIGN KEY(TransId, Typ) REFERENCES Trans(TransId, Typ) ON DELETE RESTRICT,
  FOREIGN KEY(ItemId, ItemUnitId) REFERENCES Stk_ItemUnit(ItemId, ItemUnitId) ON DELETE RESTRICT,
  UNIQUE(TransId, Typ, LineNo, ItemId, ItemUnitId)
);
CREATE TABLE IF NOT EXISTS Mstndat (
  VoucherId INTEGER NOT NULL,
  Typ INTEGER NOT NULL CHECK(Typ IN (5,6)),
  VoucherDate TEXT NOT NULL DEFAULT (date('now')),
  Amount NUMERIC NOT NULL CHECK(Amount > 0),
  Description TEXT,
  PRIMARY KEY(VoucherId, Typ),
  FOREIGN KEY(Typ) REFERENCES DocTyp(Typ) ON DELETE RESTRICT
);
CREATE TABLE IF NOT EXISTS JournalEntries (
  JournalId INTEGER PRIMARY KEY,
  EntryDate TEXT NOT NULL DEFAULT (date('now')),
  Typ INTEGER NOT NULL REFERENCES DocTyp(Typ) ON DELETE RESTRICT,
  SourceId INTEGER,
  Status TEXT NOT NULL DEFAULT 'Draft' CHECK(Status IN ('Draft','Posted')),
  CHECK((Typ = 7 AND SourceId IS NULL) OR (Typ <> 7 AND SourceId IS NOT NULL)),
  UNIQUE(Typ, SourceId)
);
CREATE TABLE IF NOT EXISTS Yomia (
  JournalId INTEGER NOT NULL REFERENCES JournalEntries(JournalId) ON DELETE RESTRICT,
  LineNo INTEGER NOT NULL CHECK(LineNo > 0),
  AccountId INTEGER NOT NULL REFERENCES Accounts(AccountId) ON DELETE RESTRICT,
  Debit NUMERIC NOT NULL DEFAULT 0 CHECK(Debit >= 0),
  Credit NUMERIC NOT NULL DEFAULT 0 CHECK(Credit >= 0),
  Description TEXT,
  PRIMARY KEY(JournalId, LineNo),
  CHECK((Debit > 0 AND Credit = 0) OR (Credit > 0 AND Debit = 0))
);
CREATE TABLE IF NOT EXISTS InventoryMovements (
  MovementId INTEGER PRIMARY KEY,
  TransId INTEGER NOT NULL,
  Typ INTEGER NOT NULL,
  LineNo INTEGER NOT NULL,
  ItemId INTEGER NOT NULL,
  ItemUnitId INTEGER NOT NULL,
  QuantityChange NUMERIC NOT NULL CHECK(QuantityChange <> 0),
  MovementDate TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(TransId, Typ, LineNo, ItemId, ItemUnitId)
    REFERENCES TransDt(TransId, Typ, LineNo, ItemId, ItemUnitId) ON DELETE RESTRICT,
  UNIQUE(TransId, Typ, LineNo)
);

INSERT OR IGNORE INTO DocTyp(Typ,TypName) VALUES
 (1,'فاتورة مشتريات'),(2,'فاتورة مبيعات'),
 (3,'مردود مبيعات'),(4,'مردود مشتريات'),
 (5,'سند صرف'),(6,'سند قبض'),(7,'قيد يومية يدوي');
INSERT OR IGNORE INTO Units(UnitId,UnitName) VALUES
 (1,'حبة'),(2,'كرتون'),(3,'كيلو'),(4,'لتر');

-- Prevent editing posted invoices and their details.
CREATE TRIGGER IF NOT EXISTS trg_trans_posted_update
BEFORE UPDATE ON Trans WHEN OLD.Status = 'Posted'
BEGIN SELECT RAISE(ABORT,'Posted invoice cannot be edited'); END;
CREATE TRIGGER IF NOT EXISTS trg_trans_posted_delete
BEFORE DELETE ON Trans WHEN OLD.Status = 'Posted'
BEGIN SELECT RAISE(ABORT,'Posted invoice cannot be deleted'); END;
CREATE TRIGGER IF NOT EXISTS trg_transdt_insert_posted
BEFORE INSERT ON TransDt
WHEN (SELECT Status FROM Trans WHERE TransId=NEW.TransId AND Typ=NEW.Typ) <> 'Draft'
BEGIN SELECT RAISE(ABORT,'Invoice is not draft'); END;
CREATE TRIGGER IF NOT EXISTS trg_transdt_update_posted
BEFORE UPDATE ON TransDt
WHEN (SELECT Status FROM Trans WHERE TransId=OLD.TransId AND Typ=OLD.Typ) <> 'Draft'
BEGIN SELECT RAISE(ABORT,'Posted invoice lines cannot be edited'); END;
CREATE TRIGGER IF NOT EXISTS trg_transdt_delete_posted
BEFORE DELETE ON TransDt
WHEN (SELECT Status FROM Trans WHERE TransId=OLD.TransId AND Typ=OLD.Typ) <> 'Draft'
BEGIN SELECT RAISE(ABORT,'Posted invoice lines cannot be deleted'); END;

-- Prevent direct changes to posted journal lines and header.
CREATE TRIGGER IF NOT EXISTS trg_yomia_insert_posted
BEFORE INSERT ON Yomia
WHEN (SELECT Status FROM JournalEntries WHERE JournalId=NEW.JournalId)='Posted'
BEGIN SELECT RAISE(ABORT,'Posted journal is immutable'); END;
CREATE TRIGGER IF NOT EXISTS trg_yomia_update_posted
BEFORE UPDATE ON Yomia
WHEN (SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId)='Posted'
BEGIN SELECT RAISE(ABORT,'Posted journal is immutable'); END;
CREATE TRIGGER IF NOT EXISTS trg_yomia_delete_posted
BEFORE DELETE ON Yomia
WHEN (SELECT Status FROM JournalEntries WHERE JournalId=OLD.JournalId)='Posted'
BEGIN SELECT RAISE(ABORT,'Posted journal is immutable'); END;
CREATE TRIGGER IF NOT EXISTS trg_journal_update_posted
BEFORE UPDATE ON JournalEntries WHEN OLD.Status='Posted'
BEGIN SELECT RAISE(ABORT,'Posted journal is immutable'); END;
CREATE TRIGGER IF NOT EXISTS trg_journal_delete_posted
BEFORE DELETE ON JournalEntries WHEN OLD.Status='Posted'
BEGIN SELECT RAISE(ABORT,'Posted journal is immutable'); END;
CREATE TRIGGER IF NOT EXISTS trg_journal_post_check
BEFORE UPDATE OF Status ON JournalEntries
WHEN NEW.Status='Posted' AND OLD.Status='Draft'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM Yomia WHERE JournalId=NEW.JournalId)<2
 THEN RAISE(ABORT,'Journal requires at least two lines') END;
 SELECT CASE WHEN
  (SELECT coalesce(sum(Debit),0)-coalesce(sum(Credit),0)
   FROM Yomia WHERE JournalId=NEW.JournalId) <> 0
 THEN RAISE(ABORT,'Journal is not balanced') END;
END;

COMMIT;
-- LIMITATIONS: This is a schema foundation, not a working accounting app.
-- Posting must be implemented in application code as one transaction:
-- validate source/stock, write journal & movements, set Posted, COMMIT or ROLLBACK.
-- JournalEntries.SourceId is polymorphic and not FK-enforced here.
-- No multi-warehouse, tax, currency, audit log, or inventory valuation yet.
