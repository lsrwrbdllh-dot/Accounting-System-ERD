# 08 — المخطط التفصيلي: البيانات الأساسية والأصناف
هذا امتداد للمخططات 01 و02 و03، دون استبدالها. PK أساسي، FK أجنبي، UK فريد.
```mermaid
erDiagram
 Stk_Item ||--o{ Stk_Item : parent
 Stk_Item ||--o{ Stk_ItemUnit : units
 Units ||--o{ Stk_ItemUnit : definition
 Stk_Item ||--o{ ItemBatches : batches
 Accounts ||--o{ Accounts : parent
 Accounts ||--o{ Customers : receivable
 Accounts ||--o{ Suppliers : payable
 Branches ||--o{ Warehouses : owns
 Branches ||--o{ Users : employs
 Stk_Item {
  INTEGER ItemId PK
  INTEGER ParentId FK
  TEXT ItemName
  TEXT ItemType
  TEXT Barcode UK
  INTEGER IsActive
 }
 Units {
  INTEGER UnitId PK
  TEXT UnitName UK
 }
 Stk_ItemUnit {
  INTEGER ItemUnitId PK
  INTEGER ItemId FK
  INTEGER UnitId FK
  TEXT PackQty
  INTEGER IsBase
  TEXT Barcode UK
 }
 ItemBatches {
  INTEGER BatchId PK
  INTEGER ItemId FK
  TEXT LotNumber
  TEXT ProductionDate
  TEXT ExpiryDate
 }
 Accounts {
  INTEGER AccountId PK
  INTEGER ParentId FK
  TEXT AccountName
  TEXT AccountType
  TEXT NormalBalance
  INTEGER IsActive
 }
 Customers {
  INTEGER CustomerId PK
  INTEGER AccountId FK,UK
  TEXT CustomerName
  TEXT Phone
  TEXT Address
 }
 Suppliers {
  INTEGER SupplierId PK
  INTEGER AccountId FK,UK
  TEXT SupplierName
  TEXT Phone
  TEXT Address
 }
 Branches {
  INTEGER BranchId PK
  TEXT BranchName
 }
 Warehouses {
  INTEGER WarehouseId PK
  INTEGER BranchId FK
  TEXT WarehouseName
 }
```
## قواعد ملزمة
- (ItemId,UnitId) فريد، ووحدة أساسية واحدة لكل صنف؛ PackQty عدد عشري موجب مخزن بدقة، لا REAL للأموال.
- لا يُسمح ببيع صنف من نوع Group، ولا إنشاء دورة أب/ابن في شجرة الحسابات أو الأصناف.
- (ItemId,LotNumber) فريد عند وجود رقم دفعة؛ صلاحية الدفعة اختيارية حسب الصنف.
- حساب العميل/المورد حساب ترحيل فرعي؛ الحساب الرئيسي لا يُرحّل عليه.
- حقول ParentId تقبل NULL للجذر، ويجب منع حذف سجل مرجعي مستخدم.
- هذه أسماء الحقول المقترحة للمخطط النهائي، وقد تختلف عن النسخة التنفيذية القديمة.
