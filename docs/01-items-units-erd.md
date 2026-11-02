# ERD — المرحلة الأولى: الأصناف والوحدات

هذا المخطط يغطي أول طلب للمهندس صلاح فقط.

```mermaid
erDiagram
    Stk_Item ||--o{ Stk_Item : "parent of"
    Stk_Item ||--o{ Stk_ItemUnit : "has units"
    Units ||--o{ Stk_ItemUnit : "used in"

    Stk_Item {
        INTEGER ItemId PK
        TEXT ItemName
        INTEGER ParentId FK "nullable; references Stk_Item.ItemId"
        TEXT ItemType "Group or Item"
    }
    Units {
        INTEGER UnitId PK
        TEXT UnitName
    }
    Stk_ItemUnit {
        INTEGER ItemUnitId PK
        INTEGER ItemId FK
        INTEGER UnitId FK
        REAL PackQty "number of base units"
        INTEGER IsBase "1=base unit, 0=other"
    }
```

## العلاقات
- **Stk_Item → Stk_Item:** علاقة ذاتية؛ مجموعة واحدة قد تضم أصنافًا عديدة، وParentId يشير إلى ItemId.
- **Stk_Item → Stk_ItemUnit:** الصنف الواحد قد يمتلك عدة وحدات.
- **Units → Stk_ItemUnit:** اسم الوحدة العام مثل «حبة» أو «كرتون» يمكن استخدامه مع أصناف متعددة.

## مثال
| ItemId | الصنف | الوحدة | PackQty | IsBase |
|---|---|---|---|---|
| 101 | حليب | حبة | 1 | 1 |
| 101 | حليب | كرتون | 24 | 0 |
| 102 | بسكويت | حبة | 1 | 1 |
| 102 | بسكويت | كرتون | 12 | 0 |

بيع 3 كراتين حليب يعني 3 × 24 = **72 حبة**.

## ملاحظات تصميمية
- هذه أسماء أعمدة مقترحة لتجسيد وصف المهندس، وليست مخططًا نهائيًا معتمدًا.
- ينبغي فرض عدم تكرار الزوج (ItemId, UnitId)، ووحدة أساسية واحدة فقط لكل صنف، وأن PackQty أكبر من الصفر.
- يجب منع الدورات في شجرة الأصناف، ومنع استخدام سجل المجموعة كصنف في الفواتير.
- لا يُضاف جدول الحسابات أو الفواتير إلى هذه المرحلة حتى الانتهاء من شرحها.
