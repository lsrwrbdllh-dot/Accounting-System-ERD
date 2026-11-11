-- Safe reference data only: NO demo user, demo parties, transactions or opening funds.
INSERT INTO DocTyp VALUES
 (1,'فاتورة مشتريات','Invoice'),(2,'فاتورة مبيعات','Invoice'),
 (3,'مردود مبيعات','Invoice'),(4,'مردود مشتريات','Invoice'),
 (5,'سند صرف','Voucher'),(6,'سند قبض','Voucher'),(7,'قيد يومية يدوي','Journal');
INSERT INTO Units VALUES(1,'حبة'),(2,'كرتون'),(3,'كيلو'),(4,'لتر');
INSERT INTO Accounts(AccountId,Code,ParentAccountId,AccountName,AccountType,NormalBalance) VALUES
 (1000,'1',NULL,'الأصول','Main','Debit'),
 (1100,'11',1000,'النقد والبنوك','Main','Debit'),
 (1110,'111',1100,'الصندوق الرئيسي','Sub','Debit'),
 (1120,'112',1100,'الحساب البنكي','Sub','Debit'),
 (1130,'113',1000,'مخزون البضاعة','Sub','Debit'),
 (1140,'114',1000,'ذمم العملاء','Main','Debit'),
 (1150,'115',1000,'ضريبة المدخلات القابلة للاسترداد','Sub','Debit'),
 (1200,'12',1000,'الأصول الثابتة','Main','Debit'),
 (1210,'121',1200,'معدات وأثاث','Sub','Debit'),
 (1220,'122',1200,'مجمع الاستهلاك','Sub','Credit'),
 (2000,'2',NULL,'الالتزامات','Main','Credit'),
 (2100,'21',2000,'ذمم الموردين','Main','Credit'),
 (2200,'22',2000,'ضريبة المخرجات','Sub','Credit'),
 (2300,'23',2000,'مصروفات مستحقة','Sub','Credit'),
 (3000,'3',NULL,'حقوق الملكية','Main','Credit'),
 (3100,'31',3000,'رأس المال','Sub','Credit'),
 (3200,'32',3000,'الأرباح المحتجزة','Sub','Credit'),
 (4000,'4',NULL,'الإيرادات','Main','Credit'),
 (4100,'41',4000,'المبيعات','Sub','Credit'),
 (4200,'42',4000,'مردود المبيعات','Sub','Debit'),
 (4300,'43',4000,'إيرادات أخرى','Sub','Credit'),
 (5000,'5',NULL,'المصروفات والتكلفة','Main','Debit'),
 (5100,'51',5000,'تكلفة البضاعة المباعة','Sub','Debit'),
 (5102,'512',5000,'فروق تكلفة مردود المشتريات','Sub','Debit'),
 (5200,'52',5000,'الإيجارات','Sub','Debit'),
 (5300,'53',5000,'الأجور والرواتب','Sub','Debit'),
 (5400,'54',5000,'الماء والكهرباء','Sub','Debit'),
 (5500,'55',5000,'الاستهلاك','Sub','Debit'),
 (5600,'56',5000,'رسوم بنكية','Sub','Debit');
INSERT INTO Branches VALUES(1,'الفرع الرئيسي');
INSERT INTO Warehouses VALUES(1,1,'المستودع الرئيسي');
INSERT INTO Cashboxes VALUES(1,1,1110,'الصندوق الرئيسي');
INSERT INTO Currencies VALUES(1,'BASE','العملة الأساسية',2);
INSERT INTO FiscalYears(FiscalYearId,YearName,StartDate,EndDate)
 VALUES(1,strftime('%Y','now'),strftime('%Y-01-01','now'),strftime('%Y-12-31','now'));
INSERT INTO FiscalPeriods(PeriodId,FiscalYearId,PeriodName,StartDate,EndDate)
 SELECT 1,1,'الفترة السنوية',StartDate,EndDate FROM FiscalYears WHERE FiscalYearId=1;
INSERT INTO Permissions VALUES(1,'read'),(2,'write'),(3,'post'),(4,'admin');
INSERT INTO Roles VALUES(1,'مدير النظام'),(2,'محاسب'),(3,'قارئ');
INSERT INTO RolePermissions VALUES(1,1),(1,2),(1,3),(1,4),(2,1),(2,2),(2,3),(3,1);
INSERT INTO AppSettings VALUES
 ('environment','production'),('inventory_account','1130'),('sales_account','4100'),
 ('sales_returns_account','4200'),('cogs_account','5100'),('input_tax_account','1150'),
 ('output_tax_account','2200'),('variance_account','5102'),('money_scale','100'),('quantity_scale','1000');
