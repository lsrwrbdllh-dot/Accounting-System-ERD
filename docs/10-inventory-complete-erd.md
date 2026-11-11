# 10 — المخطط التفصيلي: المخزون والجرد والتحويل
```mermaid
erDiagram
 Warehouses ||--o{ InventoryMovements : location
 Stk_Item ||--o{ InventoryMovements : item
 ItemBatches o|--o{ InventoryMovements : batch
 WarehouseTransfers ||--|{ WarehouseTransferDt : lines
 Warehouses ||--o{ WarehouseTransfers : from
 Stk_Item ||--o{ WarehouseTransferDt : item
 InventoryCounts ||--|{ InventoryCountDt : lines
 Warehouses ||--o{ InventoryCounts : counts
 Stk_Item ||--o{ InventoryCountDt : counted
 StockAdjustments ||--|{ StockAdjustmentDt : lines
 Warehouses ||--o{ StockAdjustments : adjusted
 InventoryMovements {
  INTEGER MovementId PK
  INTEGER WarehouseId FK
  INTEGER ItemId FK
  INTEGER BatchId FK
  TEXT QtyBaseSigned
  TEXT UnitCost
  TEXT MovementDate
  TEXT SourceKind
  INTEGER SourceId
  INTEGER SourceLineNo
  INTEGER CreatedBy FK
 }
 WarehouseTransfers {
  INTEGER TransferId PK
  INTEGER FromWarehouseId FK
  INTEGER ToWarehouseId FK
  TEXT TransferDate
  TEXT Status
 }
 WarehouseTransferDt {
  INTEGER TransferId PK,FK
  INTEGER LineNo PK
  INTEGER ItemId FK
  INTEGER BatchId FK
  TEXT QtySent
  TEXT QtyReceived
 }
 InventoryCounts {
  INTEGER CountId PK
  INTEGER WarehouseId FK
  TEXT CountDate
  TEXT Status
 }
 InventoryCountDt {
  INTEGER CountId PK,FK
  INTEGER LineNo PK
  INTEGER ItemId FK
  INTEGER BatchId FK
  TEXT SystemQty
  TEXT CountedQty
 }
 StockAdjustments {
  INTEGER AdjustmentId PK
  INTEGER WarehouseId FK
  INTEGER CountId FK
  TEXT AdjustmentDate
  TEXT Status
 }
 StockAdjustmentDt {
  INTEGER AdjustmentId PK,FK
  INTEGER LineNo PK
  INTEGER ItemId FK
  INTEGER BatchId FK
  TEXT QtyDifference
  TEXT UnitCost
 }
```
## قواعد
- الكميات تحفظ بالوحدة الأساسية بعد ضرب PackQty، وتستخرج الأرصدة من مجموع الحركات المعتمدة لكل مستودع وصنف ودفعة.
- لا يسمح بالتحويل إلى المستودع نفسه؛ نقل 50 واستلام 45 ينتج فرق 5 قيد المراجعة، لا تسوية صامتة.
- الجرد مسودة ثم اعتماد؛ تسوية الفروقات تنشئ حركة مخزون وقيدًا محاسبيًا متوازنين.
- لا تُحذف حركات مرحّلة؛ الإلغاء بحركات عكسية. منع تكرار ترحيل نفس مصدر الحركة.
- SourceKind/SourceId رابط متعدد الأنواع ويحتاج تحققًا تطبيقيًا أو سجل مستندات موحدًا.
