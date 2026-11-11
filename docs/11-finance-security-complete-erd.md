# 11 — المخطط التفصيلي: المالية والمستخدمون والصلاحيات
```mermaid
erDiagram
 FiscalYears ||--|{ FiscalPeriods : periods
 FiscalPeriods ||--o{ JournalEntries : journals
 Accounts ||--o{ AccountOpeningBalances : opening
 FiscalYears ||--o{ AccountOpeningBalances : year
 Currencies ||--o{ ExchangeRates : rates
 Currencies ||--o{ Trans : currency
 Users ||--o{ UserRoles : assigned
 Roles ||--o{ UserRoles : members
 Roles ||--o{ RolePermissions : grants
 Permissions ||--o{ RolePermissions : permission
 Users ||--o{ AuditLogs : actor
 CostCenters ||--o{ YomiaCostCenters : split
 Yomia ||--o{ YomiaCostCenters : allocated
 FiscalYears {
  INTEGER FiscalYearId PK
  TEXT YearName UK
  TEXT StartDate
  TEXT EndDate
  TEXT Status
 }
 FiscalPeriods {
  INTEGER PeriodId PK
  INTEGER FiscalYearId FK
  TEXT PeriodName
  TEXT StartDate
  TEXT EndDate
  TEXT Status
 }
 AccountOpeningBalances {
  INTEGER FiscalYearId PK,FK
  INTEGER AccountId PK,FK
  TEXT Debit
  TEXT Credit
 }
 Currencies {
  INTEGER CurrencyId PK
  TEXT CurrencyCode UK
  TEXT CurrencyName
  INTEGER DecimalPlaces
 }
 ExchangeRates {
  INTEGER RateId PK
  INTEGER CurrencyId FK
  TEXT RateDate
  TEXT RateToBase
 }
 CostCenters {
  INTEGER CostCenterId PK
  TEXT CenterName
 }
 YomiaCostCenters {
  INTEGER JournalId PK,FK
  INTEGER LineNo PK,FK
  INTEGER CostCenterId PK,FK
  TEXT Amount
 }
 Users {
  INTEGER UserId PK
  INTEGER BranchId FK
  TEXT Username UK
  TEXT PasswordHash
  INTEGER IsActive
 }
 Roles {
  INTEGER RoleId PK
  TEXT RoleName UK
 }
 Permissions {
  INTEGER PermissionId PK
  TEXT PermissionCode UK
 }
 UserRoles {
  INTEGER UserId PK,FK
  INTEGER RoleId PK,FK
 }
 RolePermissions {
  INTEGER RoleId PK,FK
  INTEGER PermissionId PK,FK
 }
 AuditLogs {
  INTEGER AuditId PK
  INTEGER UserId FK
  TEXT EntityName
  TEXT EntityKey
  TEXT Action
  TEXT EventTime
  TEXT Details
 }
 AppSettings {
  TEXT SettingKey PK
  TEXT SettingValue
 }
```
## قواعد
- لا تداخل بين الفترات المالية داخل السنة؛ يمنع ترحيل المستند في فترة مغلقة.
- القيود الافتتاحية على الحسابات الفرعية فقط؛ منع إدخال مدين ودائن موجبين معًا في نفس سطر.
- سعر الصرف يجب أن يكون موجبًا، ويثبت سعر المستند وقت الترحيل.
- كلمات المرور تخزن hash آمنًا لا نصًا واضحًا؛ التحقق من الصلاحيات في طبقة الأعمال وليس الواجهة فقط.
- YomiaCostCenters جدول اختياري لتوزيع السطر على أكثر من مركز تكلفة.
- سجلات التدقيق تحفظ التغييرات المهمة دون تخزين كلمات مرور أو أسرار.
