# 09 — المخطط التفصيلي: الفواتير والسندات والقيود
يحافظ على أسماء المهندس صلاح: DocTyp, Trans, TransDt, Mstndat, Yomia. يضاف رأس القيد JournalEntries والتخصيص PaymentAllocation.
```mermaid
erDiagram
 DocTyp ||--o{ Trans : classifies
 DocTyp ||--o{ Mstndat : classifies
 Trans ||--|{ TransDt : lines
 Stk_Item ||--o{ TransDt : item
 Stk_ItemUnit ||--o{ TransDt : unit
 Customers o|--o{ Trans : sales
 Suppliers o|--o{ Trans : purchases
 Mstndat ||--o{ PaymentAllocation : pays
 Trans ||--o{ PaymentAllocation : settles
 FiscalPeriods ||--o{ JournalEntries : period
 JournalEntries ||--|{ Yomia : lines
 Accounts ||--o{ Yomia : account
 DocTyp ||--o{ JournalEntries : sourceType
 Trans ||--o| JournalEntries : optionalPosting
 DocTyp {
  INTEGER Typ PK
  TEXT TypName UK
  TEXT DocumentFamily
 }
 Trans {
  INTEGER TransId PK
  INTEGER Typ PK,FK
  TEXT TransDate
  INTEGER CustomerId FK
  INTEGER SupplierId FK
  INTEGER WarehouseId FK
  INTEGER CurrencyId FK
  TEXT ExchangeRate
  TEXT Subtotal
  TEXT Discount
  TEXT Tax
  TEXT Total
  TEXT Status
  INTEGER OriginalTransId
  INTEGER OriginalTyp
  TEXT Notes
 }
 TransDt {
  INTEGER TransId PK,FK
  INTEGER Typ PK,FK
  INTEGER LineNo PK
  INTEGER ItemId FK
  INTEGER ItemUnitId FK
  INTEGER BatchId FK
  TEXT Qty
  TEXT Price
  TEXT Discount
  TEXT Tax
  TEXT LineTotal
 }
 Mstndat {
  INTEGER VoucherId PK
  INTEGER Typ PK,FK
  TEXT VoucherDate
  INTEGER AccountId FK
  INTEGER CurrencyId FK
  TEXT Amount
  TEXT Description
  TEXT Status
 }
 VoucherDt {
  INTEGER VoucherId PK,FK
  INTEGER Typ PK,FK
  INTEGER LineNo PK
  INTEGER AccountId FK
  TEXT Amount
 }
 PaymentAllocation {
  INTEGER AllocationId PK
  INTEGER VoucherId FK
  INTEGER VoucherTyp FK
  INTEGER TransId FK
  INTEGER TransTyp FK
  TEXT Amount
 }
 JournalEntries {
  INTEGER JournalId PK
  INTEGER PeriodId FK
  INTEGER SourceId
  INTEGER SourceTyp FK
  TEXT EntryDate
  TEXT Description
  TEXT Status
 }
 Yomia {
  INTEGER JournalId PK,FK
  INTEGER LineNo PK
  INTEGER AccountId FK
  TEXT Debit
  TEXT Credit
  TEXT Description
 }
```
## مفاتيح مركبة وقواعد
- PK(TransId,Typ) في Trans، وPK(TransId,Typ,LineNo) في TransDt؛ FK(TransId,Typ) مرجعه Trans.
- PK(VoucherId,Typ) في Mstndat؛ FK(VoucherId,Typ) في VoucherDt وPaymentAllocation.
- FK(ItemUnitId,ItemId) إلى مفتاح فريد مطابق في Stk_ItemUnit؛ لضمان الوحدة تخص الصنف.
- القيد PK(JournalId,LineNo)؛ JournalId وحده يتكرر على الأسطر. لا يلزم FK مباشر من Trans إلى JournalEntries إذا اعتمدنا الربط الموحد بمصدر القيد.
- SourceId+SourceTyp علاقة متعددة الأهداف؛ لا يمكن فرض FK عادي واحد على Trans وMstndat معًا. يُفرض بالترحيل والتحقق، أو جدول مصدر موحد DocumentRegistry.
- ينبغي تثبيت أنواع DocTyp الحالية قبل التنفيذ وعدم تغيير دلالتها؛ السند 5 صرف و6 قبض بحسب المخطط السابق.
- لا يتجاوز تخصيص الدفعات مبلغ السند أو رصيد الفاتورة؛ ويمنع الجمع بين CustomerId وSupplierId في نفس الفاتورة إلا بتصميم موثق.
- تحقق توازن القيد، ومنع التعديل بعد الترحيل، وعكس القيد عند التصحيح، وترحيل المستند والقيد والمخزون داخل transaction واحدة.
- جميع المبالغ والكميات المعروضة TEXT هنا لتمثيل عشري مضبوط في طبقة التطبيق؛ يلزم تعريف تحقق عددي دقيق عند تنفيذ SQLite، أو اختيار INTEGER بوحدة قياس صغرى ثابتة.
