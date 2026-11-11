import 'package:flutter/material.dart';
import '../core/fixed.dart';
import '../data/accounting_repository.dart';
import 'common.dart';
import 'document_detail.dart';

const invoiceNames={1:'فواتير المشتريات',2:'فواتير المبيعات',3:'مردود المبيعات',4:'مردود المشتريات'};

class InvoicesPage extends StatefulWidget {
  final AccountingRepository repository;final bool purchase;
  const InvoicesPage(this.repository,{super.key,this.purchase=false});
  @override State<InvoicesPage> createState()=>_InvoicesPageState();
}
class _InvoicesPageState extends State<InvoicesPage>{
  late int typ;
  @override void initState(){super.initState();typ=widget.purchase?1:2;}
  @override Widget build(BuildContext context)=>DataListPage(key:ValueKey(typ),title:invoiceNames[typ]!,load:(s)=>widget.repository.invoices(typ,s),heading:(r)=>'فاتورة ${r['TransId']} · ${formatFixed(r['Total'] as int)}',subtitle:(r)=>'${r['TransDate']} · ${statusLabel(r['Status'])} · ${r['Notes']}',actions:[PopupMenuButton<int>(tooltip:'نوع الفاتورة',onSelected:(v)=>setState(()=>typ=v),itemBuilder:(_)=>[for(final type in widget.purchase?[1,4]:[2,3])PopupMenuItem(value:type,child:Text(invoiceNames[type]!))])],onAdd:(c)async{await openPage<void>(c,InvoiceEditor(widget.repository,typ));},onOpen:(c,r)async{await openPage<void>(c,DocumentDetail(widget.repository,r,'invoice',typ,editor:()=>InvoiceEditor(widget.repository,typ,header:r)));});
}

class InvoiceEditor extends StatefulWidget {
  final AccountingRepository repository;final int typ;final DbRow? header;
  const InvoiceEditor(this.repository,this.typ,{super.key,this.header});
  @override State<InvoiceEditor> createState()=>_InvoiceEditorState();
}
class _InvoiceEditorState extends State<InvoiceEditor>{
  final form=GlobalKey<FormState>();
  final date=TextEditingController();final notes=TextEditingController();
  late Future<void> ready;
  List<DbRow> lines=[],parties=[],warehouses=[],cashboxes=[],originals=[];
  int? party,original;
  int warehouse=1,cashbox=1;String method='Cash';bool busy=false;
  bool get returning=>widget.typ==3||widget.typ==4;
  bool get purchase=>widget.typ==1||widget.typ==4;
  int get originalTyp=>widget.typ==3?2:1;
  @override void initState(){super.initState();ready=load();}
  Future<void> load()async{
    final h=widget.header;
    date.text=h?['TransDate'] as String? ?? today();notes.text=h?['Notes'] as String? ?? '';
    party=h?[purchase?'SupplierId':'CustomerId'] as int?;original=h?['OriginalTransId'] as int?;
    warehouse=h?['WarehouseId'] as int? ?? 1;cashbox=h?['CashboxId'] as int? ?? 1;method=h?['PaymentMethod'] as String? ?? 'Cash';
    parties=await widget.repository.lookup(purchase?'Suppliers':'Customers');warehouses=await widget.repository.lookup('Warehouses');cashboxes=await widget.repository.lookup('Cashboxes');
    if(returning){originals=(await widget.repository.invoices(originalTyp)).where((r)=>r['Status']=='Posted').toList();}
    if(h!=null){lines=await widget.repository.invoiceLines(h['TransId'] as int,widget.typ);}
  }
  @override void dispose(){date.dispose();notes.dispose();super.dispose();}
  Future<void> addParty()async{
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:Text(purchase?'إضافة مورد':'إضافة عميل'),content:TextField(controller:controller,decoration:const InputDecoration(labelText:'الاسم')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('إضافة'))]));
    controller.dispose();if(name==null){return;}
    try{final key=await widget.repository.addParty(purchase,name);final updated=await widget.repository.lookup(purchase?'Suppliers':'Customers');if(mounted){setState((){party=key;parties=updated;});}}catch(e){if(mounted){showError(context,e);}}
  }
  Future<void> addLine({int? index})async{
    try{
      if(returning&&original==null){throw const FormatException('اختر الفاتورة الأصلية أولًا');}
      final DbRow? line;
      if(returning){final source=await widget.repository.invoiceLines(original!,originalTyp);if(!mounted){return;}line=await returnLineDialog(context,source,existing:index==null?null:lines[index]);}
      else{line=await invoiceLineDialog(context,widget.repository,existing:index==null?null:lines[index]);}
      if(line!=null&&mounted){setState((){if(index==null){lines.add(line);}else{lines[index]=line;}});}
    }catch(e){if(mounted){showError(context,e);}}
  }
  Future<void> save()async{
    if(!form.currentState!.validate()){return;}
    setState(()=>busy=true);
    try{
      final header=<String,Object?>{'TransDate':date.text.trim(),'Notes':notes.text.trim(),'WarehouseId':warehouse,'PaymentMethod':method,'CashboxId':method=='Cash'?cashbox:null,'CustomerId':purchase?null:party,'SupplierId':purchase?party:null,'OriginalTransId':returning?original:null,'OriginalTyp':returning?originalTyp:null};
      await widget.repository.saveInvoice(widget.typ,header,lines,id:widget.header?['TransId'] as int?);
      if(mounted){Navigator.pop(context);}
    }catch(e){if(mounted){showError(context,e);setState(()=>busy=false);}}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('${invoiceNames[widget.typ]} · مسودة')),body:FutureBuilder<void>(future:ready,builder:(context,snapshot){
    if(snapshot.hasError){return Center(child:Text(errorMessage(snapshot.error!)));}
    if(snapshot.connectionState!=ConnectionState.done){return const Center(child:CircularProgressIndicator());}
    return Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
      formField(date,'التاريخ YYYY-MM-DD'),formField(notes,'البيان',mandatory:false),
      if(returning)idDropdown(label:'الفاتورة الأصلية',rows:originals,idKey:'TransId',nameKey:'TransId',value:original,onChanged:(v){if(v==null){return;}final h=originals.firstWhere((r)=>r['TransId']==v);setState((){original=v;party=h[purchase?'SupplierId':'CustomerId'] as int?;warehouse=h['WarehouseId'] as int;method=h['PaymentMethod'] as String;cashbox=h['CashboxId'] as int? ?? 1;lines.clear();});}),
      if(!returning)...[
        DropdownButtonFormField<String>(initialValue:method,decoration:const InputDecoration(labelText:'طريقة السداد'),items:const[DropdownMenuItem(value:'Cash',child:Text('نقدي')),DropdownMenuItem(value:'Credit',child:Text('آجل'))],onChanged:(v)=>setState(()=>method=v!)),
        Row(children:[Expanded(child:idDropdown(label:purchase?'المورد':'العميل',rows:parties,idKey:purchase?'SupplierId':'CustomerId',nameKey:purchase?'SupplierName':'CustomerName',value:party??0,optional:true,onChanged:(v)=>setState(()=>party=v==0?null:v))),IconButton(tooltip:purchase?'إضافة مورد':'إضافة عميل',onPressed:addParty,icon:const Icon(Icons.person_add))]),
        idDropdown(label:'المستودع',rows:warehouses,idKey:'WarehouseId',nameKey:'WarehouseName',value:warehouse,onChanged:(v)=>setState(()=>warehouse=v!)),
        if(method=='Cash')idDropdown(label:'الصندوق',rows:cashboxes,idKey:'CashboxId',nameKey:'CashboxName',value:cashbox,onChanged:(v)=>setState(()=>cashbox=v!)),
      ],
      if(returning)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('تُعكس الكميات من الفاتورة الأصلية مع أسعارها وتكلفتها.')),
      const Divider(),
      for(var i=0;i<lines.length;i++)Card(child:ListTile(title:Text('${lines[i]['ItemName']??lines[i]['ItemId']}'),subtitle:Text('${formatFixed(lines[i]['Qty'] as int,3)} ${lines[i]['UnitName']??''} × ${formatFixed(lines[i]['Price'] as int)}'),onTap:busy?null:()=>addLine(index:i),trailing:IconButton(tooltip:'حذف السطر',onPressed:busy?null:()=>setState(()=>lines.removeAt(i)),icon:const Icon(Icons.delete_outline)))),
      OutlinedButton.icon(onPressed:busy?null:()=>addLine(),icon:const Icon(Icons.add),label:const Text('إضافة صنف')),
      const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.save),label:Text(busy?'جارٍ الحفظ…':'حفظ المسودة')),
    ]));
  }));
}

Future<DbRow?> invoiceLineDialog(BuildContext context,AccountingRepository repo,{DbRow? existing})async{
  final items=(await repo.items()).where((r)=>r['ItemType']=='Item'&&r['IsActive']==1).toList();
  if(!context.mounted){return null;}
  if(items.isEmpty){throw const FormatException('أضف صنفًا في دليل الأصناف أولًا');}
  var itemId=existing?['ItemId'] as int? ?? items.first['ItemId'] as int;
  var units=await repo.itemUnits(itemId);
  if(!context.mounted){return null;}
  int? unit=existing?['ItemUnitId'] as int? ?? (units.isEmpty?null:units.first['ItemUnitId'] as int);
  final qty=TextEditingController(text:formatFixed(existing?['Qty'] as int? ?? 1000,3));
  final price=TextEditingController(text:formatFixed(existing?['Price'] as int? ?? 0));
  final discount=TextEditingController(text:formatFixed(existing?['Discount'] as int? ?? 0));
  final tax=TextEditingController(text:formatFixed(existing?['Tax'] as int? ?? 0));
  final form=GlobalKey<FormState>();bool loading=false;
  final result=await showDialog<DbRow>(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:const Text('تفاصيل الصنف'),content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    idDropdown(label:'الصنف',rows:items,idKey:'ItemId',nameKey:'ItemName',value:itemId,onChanged:(v)async{if(v==null){return;}setLocal(()=>loading=true);final loaded=await repo.itemUnits(v);if(dialog.mounted){setLocal((){itemId=v;units=loaded;unit=units.isEmpty?null:units.first['ItemUnitId'] as int;loading=false;});}}),
    if(loading)const LinearProgressIndicator()else idDropdown(label:'الوحدة',rows:units,idKey:'ItemUnitId',nameKey:'UnitName',value:unit,onChanged:(v)=>setLocal(()=>unit=v)),
    formField(qty,'الكمية',numeric:true),formField(price,'سعر الوحدة',numeric:true),formField(discount,'الخصم (مبلغ)',numeric:true),formField(tax,'الضريبة (مبلغ)',numeric:true),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:loading?null:(){try{if(!form.currentState!.validate()){return;}if(unit==null){throw const FormatException('اختر الوحدة');}final q=parseFixed(qty.text,3);if(q==0){throw const FormatException('الكمية يجب أن تكون موجبة');}Navigator.pop(dialog,<String,Object?>{'ItemId':itemId,'ItemUnitId':unit,'Qty':q,'Price':parseFixed(price.text,2),'Discount':parseFixed(discount.text,2),'Tax':parseFixed(tax.text,2),'BatchId':existing?['BatchId'],'ItemName':items.firstWhere((r)=>r['ItemId']==itemId)['ItemName'],'UnitName':units.firstWhere((r)=>r['ItemUnitId']==unit)['UnitName']});}catch(e){showError(dialog,e);}},child:const Text('اعتماد السطر'))])));
  qty.dispose();price.dispose();discount.dispose();tax.dispose();return result;
}

Future<DbRow?> returnLineDialog(BuildContext context,List<DbRow> source,{DbRow? existing})async{
  if(source.isEmpty){throw const FormatException('الفاتورة الأصلية لا تحتوي أسطرًا');}
  var selected=existing?['OriginalLineNo'] as int? ?? source.first['LineNo'] as int;
  final qty=TextEditingController(text:formatFixed(existing?['Qty'] as int? ?? 1000,3));
  final result=await showDialog<DbRow>(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:const Text('الصنف المرتجع'),content:Column(mainAxisSize:MainAxisSize.min,children:[idDropdown(label:'سطر الفاتورة الأصلية',rows:source,idKey:'LineNo',nameKey:'ItemName',value:selected,onChanged:(v)=>setLocal(()=>selected=v!)),formField(qty,'الكمية المرتجعة',numeric:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:(){try{final original=source.firstWhere((r)=>r['LineNo']==selected);final q=parseFixed(qty.text,3);if(q==0){throw const FormatException('الكمية يجب أن تكون موجبة');}Navigator.pop(dialog,<String,Object?>{'ItemId':original['ItemId'],'ItemUnitId':original['ItemUnitId'],'BatchId':original['BatchId'],'Qty':q,'Price':original['Price'],'OriginalLineNo':selected,'ItemName':original['ItemName'],'UnitName':original['UnitName']});}catch(e){showError(dialog,e);}},child:const Text('اعتماد السطر'))])));
  qty.dispose();return result;
}
