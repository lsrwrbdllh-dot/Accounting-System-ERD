-- Opt in only; separate accounting_demo.db. Never seed a production database.
UPDATE AppSettings SET SettingValue='demo' WHERE SettingKey='environment';
INSERT INTO Users(UserId,BranchId,Username,PasswordHash) VALUES(1,1,'demo','pbkdf2_sha256$600000$YWNjb3VudGluZy1kZW1vMDE=$nZnymZwR7YcBX7Zgeag4avpotHm+QO0CTFbMyNPiZxM=');
INSERT INTO UserRoles VALUES(1,2);
INSERT INTO Accounts(AccountId,Code,ParentAccountId,AccountName,AccountType,NormalBalance) VALUES
(1141,'11401',1140,'عميل تجريبي','Sub','Debit'),(2101,'21001',2100,'مورد تجريبي','Sub','Credit');
INSERT INTO Customers VALUES(1,1141,'العميل التجريبي',NULL,NULL);
INSERT INTO Suppliers VALUES(1,2101,'المورد التجريبي',NULL,NULL);
INSERT INTO Stk_Item(ItemId,Code,ItemName,ItemType) VALUES(1,'G01','مواد غذائية','Group');
INSERT INTO Stk_Item(ItemId,Code,ParentItemId,ItemName,ItemType) VALUES(101,'I101',1,'حليب','Item'),(102,'I102',1,'بسكويت','Item');
INSERT INTO Stk_ItemUnit(ItemUnitId,ItemId,UnitId,PackingQty,IsBase) VALUES
(1011,101,1,1000,1),(1012,101,2,24000,0),(1021,102,1,1000,1),(1022,102,2,12000,0);
