import 'package:flutter/material.dart';
import '../core/fixed.dart';
import '../data/accounting_repository.dart';
import 'common.dart';

class AccountsPage extends StatelessWidget {
  final AccountingRepository repository;
  const AccountsPage(this.repository,{super.key});
  @override Widget build(BuildContext context)=>DataListPage(title:'دليل الحسابات',load:repository.accounts,heading:(r)=>'${r['Code']} — ${r['AccountName']}',subtitle:(r)=>'${r['AccountType']=='Main'?'تجميعي':'حساب ترحيل'} · الرصيد ${formatFixed(r['Balance'] as int)}',onAdd:(c)=>editMaster(c,repository,true),onOpen:(c,r)=>editMaster(c,repository,true,row:r));
}

class ItemsPage extends StatelessWidget {
  final AccountingRepository repository;
  const ItemsPage(this.repository,{super.key});
  @override Widget build(BuildContext context)=>DataListPage(title:'دليل الأصناف',load:repository.items,heading:(r)=>'${r['Code']} — ${r['ItemName']}',subtitle:(r)=>r['ItemType']=='Group'?'مجموعة أصناف':'صنف · اضغط للعرض والتعديل والوحدات',onAdd:(c)=>editMaster(c,repository,false),onOpen:(c,r)=>openPage<void>(c,ItemDetail(repository,r)));
}

Future<void> editMaster(BuildContext context,AccountingRepository repo,bool account,{DbRow? row}) async {
  final records=account?await repo.accounts():await repo.items();
  final units=account?<DbRow>[]:await repo.lookup('Units');
  if(!context.mounted){return;}
  final name=TextEditingController(text:row?[account?'AccountName':'ItemName'] as String? ?? '');
  final code=TextEditingController(text:row?['Code'] as String? ?? '');
  final barcode=TextEditingController(text:row?['Barcode'] as String? ?? '');
  final key=account?'AccountId':'ItemId';
  final parentKey=account?'ParentAccountId':'ParentItemId';
  final typeKey=account?'AccountType':'ItemType';
  final group=account?'Main':'Group';
  final leaf=account?'Sub':'Item';
  var type=row?[typeKey] as String? ?? leaf;
  var parent=row?[parentKey] as int? ?? 0;
  var normal=row?['NormalBalance'] as String? ?? 'Debit';
  var baseUnit=units.isEmpty?1:units.first['UnitId'] as int;
  final form=GlobalKey<FormState>();
  var busy=false;
  await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:Text(account?'بيانات الحساب':'بيانات الصنف'),content:SingleChildScrollView(child:SizedBox(width:440,child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    formField(code,'الرمز'),formField(name,'الاسم'),
    DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'النوع'),items:[DropdownMenuItem(value:group,child:const Text('تجميعي / مجموعة')),DropdownMenuItem(value:leaf,child:const Text('تفصيلي'))],onChanged:(v)=>setLocal(()=>type=v!)),
    idDropdown(label:'الأب',rows:records.where((r)=>r[typeKey]==group&&r[key]!=row?[key]).toList(),idKey:key,nameKey:account?'AccountName':'ItemName',value:parent,onChanged:(v)=>setLocal(()=>parent=v??0),optional:true),
    if(account)DropdownButtonFormField<String>(initialValue:normal,decoration:const InputDecoration(labelText:'طبيعة الرصيد'),items:const[DropdownMenuItem(value:'Debit',child:Text('مدين')),DropdownMenuItem(value:'Credit',child:Text('دائن'))],onChanged:(v)=>setLocal(()=>normal=v!)),
    if(!account)formField(barcode,'باركود (اختياري)',mandatory:false),
    if(!account&&row==null&&type==leaf)idDropdown(label:'الوحدة الأساسية',rows:units,idKey:'UnitId',nameKey:'UnitName',value:baseUnit,onChanged:(v)=>setLocal(()=>baseUnit=v!)),
  ])))) ,actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:() async {
    if(!form.currentState!.validate()){return;}
    setLocal(()=>busy=true);
    try{
      final values=<String,Object?>{'Code':code.text.trim(),account?'AccountName':'ItemName':name.text.trim(),parentKey:parent==0?null:parent,typeKey:type};
      if(account){values['NormalBalance']=normal;await repo.saveAccount(values,id:row?[key] as int?);}
      else{values['Barcode']=barcode.text.trim().isEmpty?null:barcode.text.trim();await repo.saveItem(values,id:row?[key] as int?,baseUnitId:baseUnit);}
      if(dialog.mounted){Navigator.pop(dialog);}
    }catch(e){if(dialog.mounted){showError(dialog,e);setLocal(()=>busy=false);}}
  },child:const Text('حفظ'))])));
  name.dispose();code.dispose();barcode.dispose();
}

class ItemDetail extends StatefulWidget {
  final AccountingRepository repository;final DbRow row;
  const ItemDetail(this.repository,this.row,{super.key});
  @override State<ItemDetail> createState()=>_ItemDetailState();
}
class _ItemDetailState extends State<ItemDetail>{
  late Future<List<DbRow>> units;
  @override void initState(){super.initState();load();}
  void load(){units=widget.repository.itemUnits(widget.row['ItemId'] as int);}
  Future<void> addUnit() async {
    final all=await widget.repository.lookup('Units');
    if(!mounted){return;}
    final pack=TextEditingController(text:'1');int? selected;
    await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:const Text('إضافة وحدة للصنف'),content:Column(mainAxisSize:MainAxisSize.min,children:[idDropdown(label:'الوحدة',rows:all,idKey:'UnitId',nameKey:'UnitName',value:selected,onChanged:(v)=>setLocal(()=>selected=v)),formField(pack,'عدد الوحدات الأساسية',numeric:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:()async{try{if(selected==null){throw const FormatException('اختر الوحدة');}await widget.repository.addItemUnit(widget.row['ItemId'] as int,selected!,parseFixed(pack.text,3));if(dialog.mounted){Navigator.pop(dialog);}}catch(e){if(dialog.mounted){showError(dialog,e);}}},child:const Text('حفظ'))])));
    pack.dispose();if(mounted){setState(load);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('${widget.row['ItemName']}'),actions:[IconButton(tooltip:'تعديل',icon:const Icon(Icons.edit),onPressed:()async{await editMaster(context,widget.repository,false,row:widget.row);if(context.mounted){Navigator.pop(context);}})]),floatingActionButton:widget.row['ItemType']=='Group'?null:FloatingActionButton(onPressed:addUnit,tooltip:'إضافة وحدة',child:const Icon(Icons.add)),body:FutureBuilder<List<DbRow>>(future:units,builder:(context,snapshot){if(snapshot.hasError){return Center(child:Text(errorMessage(snapshot.error!)));}if(!snapshot.hasData){return const Center(child:CircularProgressIndicator());}return ListView(children:[const ListTile(title:Text('وحدات الصنف')),for(final unit in snapshot.data!)ListTile(title:Text('${unit['UnitName']}'),subtitle:Text('${formatFixed(unit['PackingQty'] as int,3)} وحدة أساسية ${unit['IsBase']==1?'· الأساسية':''}'))]);}));
}
