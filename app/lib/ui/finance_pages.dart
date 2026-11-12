import 'package:flutter/material.dart';
import '../core/fixed.dart';
import '../data/accounting_repository.dart';
import 'common.dart';
import 'document_detail.dart';

class VouchersPage extends StatefulWidget {
  final AccountingRepository repository;
  const VouchersPage(this.repository,{super.key});
  @override State<VouchersPage> createState()=>_VouchersPageState();
}
class _VouchersPageState extends State<VouchersPage>{
  int typ=6;
  @override Widget build(BuildContext context)=>DataListPage(key:ValueKey(typ),title:typ==6?'سندات القبض':'سندات الصرف',load:(s)=>widget.repository.vouchers(typ,s),heading:(r)=>'سند ${r['VoucherId']} · ${formatFixed(r['Amount'] as int)}',subtitle:(r)=>'${r['VoucherDate']} · ${statusLabel(r['Status'])} · ${r['Description']}',actions:[PopupMenuButton<int>(tooltip:'نوع السند',onSelected:(v)=>setState(()=>typ=v),itemBuilder:(_)=>const[PopupMenuItem(value:6,child:Text('سندات القبض')),PopupMenuItem(value:5,child:Text('سندات الصرف'))])],onAdd:(c)async{await openPage<void>(c,FinanceEditor(widget.repository,typ));},onOpen:(c,r)async{await openPage<void>(c,DocumentDetail(widget.repository,r,'voucher',typ,editor:()=>FinanceEditor(widget.repository,typ,header:r)));});
}

class JournalsPage extends StatelessWidget {
  final AccountingRepository repository;
  const JournalsPage(this.repository,{super.key});
  @override Widget build(BuildContext context)=>DataListPage(title:'القيود اليومية',load:repository.journals,heading:(r)=>'قيد ${r['JournalId']} · ${formatFixed(r['Amount'] as int)}',subtitle:(r)=>'${r['EntryDate']} · ${statusLabel(r['Status'])} · ${r['Typ']==7?'يدوي':'من مستند'}',onAdd:(c)async{await openPage<void>(c,FinanceEditor(repository,7));},onOpen:(c,r)async{await openPage<void>(c,DocumentDetail(repository,r,'journal',r['Typ'] as int,editor:r['Typ']==7?()=>FinanceEditor(repository,7,header:r):null));});
}

class FinanceEditor extends StatefulWidget {
  final AccountingRepository repository;final int typ;final DbRow? header;
  const FinanceEditor(this.repository,this.typ,{super.key,this.header});
  @override State<FinanceEditor> createState()=>_FinanceEditorState();
}
class _FinanceEditorState extends State<FinanceEditor>{
  final form=GlobalKey<FormState>();
  final date=TextEditingController();final description=TextEditingController();
  late Future<void> ready;
  List<DbRow> lines=[],allocations=[],cashboxes=[];
  int cashbox=1;bool busy=false;
  bool get journal=>widget.typ==7;
  @override void initState(){super.initState();ready=load();}
  Future<void> load()async{
    final h=widget.header;
    date.text=h?[journal?'EntryDate':'VoucherDate'] as String? ?? today();description.text=h?['Description'] as String? ?? '';
    if(!journal){cashboxes=await widget.repository.lookup('Cashboxes');cashbox=h?['CashboxId'] as int? ?? 1;}
    if(h!=null){final id=h[journal?'JournalId':'VoucherId'] as int;lines=await widget.repository.documentLines(journal?'journal':'voucher',id,widget.typ);if(!journal){allocations=await widget.repository.allocations(id,widget.typ);}}
  }
  @override void dispose(){date.dispose();description.dispose();super.dispose();}
  Future<void> addLine({int? index})async{
    try{
      final accounts=(await widget.repository.accounts()).where((r)=>r['AccountType']=='Sub'&&r['IsActive']==1&&r['AccountId']!=1130).toList();
      if(!mounted){return;}
      if(accounts.isEmpty){throw const FormatException('أضف حساب ترحيل أولًا');}
      final line=await entryLineDialog(context,accounts,journal,existing:index==null?null:lines[index]);
      if(line!=null&&mounted){setState((){if(index==null){lines.add(line);}else{lines[index]=line;}});}
    }catch(e){if(mounted){showError(context,e);}}
  }
  Future<void> addAllocation()async{
    try{
      final invoices=await widget.repository.outstanding(widget.typ==6?2:1);
      if(!mounted){return;}
      if(invoices.isEmpty){throw const FormatException('لا توجد فواتير آجلة مرحّلة لها رصيد متبقٍ');}
      var selected=invoices.first['TransId'] as int;
      final amount=TextEditingController();
      final result=await showControllerDialog<DbRow>(context:context,controllers:[amount],builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:const Text('توزيع السداد على فاتورة'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(value:selected,isExpanded:true,decoration:const InputDecoration(labelText:'الفاتورة والمتبقي'),items:[for(final r in invoices)DropdownMenuItem(value:r['TransId'] as int,child:Text('${r['TransId']} · ${formatFixed(r['Outstanding'] as int)}'))],onChanged:(v)=>setLocal(()=>selected=v!)),formField(amount,'مبلغ السداد',numeric:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:(){try{final value=parseFixed(amount.text,2);if(value==0){throw const FormatException('المبلغ يجب أن يكون موجبًا');}Navigator.pop(dialog,<String,Object?>{'TransId':selected,'TransTyp':widget.typ==6?2:1,'Amount':value});}catch(e){showError(dialog,e);}},child:const Text('إضافة'))])));
      if(result!=null&&mounted){setState(()=>allocations.add(result));}
    }catch(e){if(mounted){showError(context,e);}}
  }
  Future<void> save()async{
    if(!form.currentState!.validate()){return;}
    setState(()=>busy=true);
    try{
      if(journal){await widget.repository.saveJournal({'EntryDate':date.text.trim(),'Description':description.text.trim()},lines,id:widget.header?['JournalId'] as int?);}
      else{await widget.repository.saveVoucher(widget.typ,{'VoucherDate':date.text.trim(),'Description':description.text.trim(),'CashboxId':cashbox},lines,allocations,id:widget.header?['VoucherId'] as int?);}
      if(mounted){Navigator.pop(context);}
    }catch(e){if(mounted){showError(context,e);setState(()=>busy=false);}}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(journal?'قيد يومية يدوي':widget.typ==6?'سند قبض':'سند صرف')),body:FutureBuilder<void>(future:ready,builder:(context,snapshot){
    if(snapshot.hasError){return Center(child:Text(errorMessage(snapshot.error!)));}
    if(snapshot.connectionState!=ConnectionState.done){return const Center(child:CircularProgressIndicator());}
    final debit=journal?lines.fold<int>(0,(a,b)=>a+(b['Debit'] as int)):0;
    final credit=journal?lines.fold<int>(0,(a,b)=>a+(b['Credit'] as int)):0;
    return Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[formField(date,'التاريخ YYYY-MM-DD'),formField(description,'البيان',mandatory:false),
      if(!journal)idDropdown(label:'الصندوق',rows:cashboxes,idKey:'CashboxId',nameKey:'CashboxName',value:cashbox,onChanged:(v)=>setState(()=>cashbox=v!)),
      for(var i=0;i<lines.length;i++)Card(child:ListTile(title:Text('${lines[i]['AccountName']??lines[i]['AccountId']}'),subtitle:Text(journal?'مدين ${formatFixed(lines[i]['Debit'] as int)} · دائن ${formatFixed(lines[i]['Credit'] as int)}':formatFixed(lines[i]['Amount'] as int)),onTap:busy?null:()=>addLine(index:i),trailing:IconButton(tooltip:'حذف السطر',onPressed:busy?null:()=>setState(()=>lines.removeAt(i)),icon:const Icon(Icons.delete_outline)))),
      OutlinedButton.icon(onPressed:busy?null:()=>addLine(),icon:const Icon(Icons.add),label:const Text('إضافة سطر')),
      if(journal)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text('المدين ${formatFixed(debit)} · الدائن ${formatFixed(credit)} · الفرق ${formatFixed(debit-credit)}')),
      if(!journal)...[const Divider(),const Text('تخصيص السداد (اختياري)'),
        for(var i=0;i<allocations.length;i++)ListTile(title:Text('فاتورة ${allocations[i]['TransId']}'),subtitle:Text(formatFixed(allocations[i]['Amount'] as int)),trailing:IconButton(tooltip:'إزالة التخصيص',onPressed:busy?null:()=>setState(()=>allocations.removeAt(i)),icon:const Icon(Icons.close))),
        OutlinedButton(onPressed:busy?null:addAllocation,child:const Text('إضافة تخصيص لفاتورة')),
      ],const SizedBox(height:16),FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.save),label:Text(busy?'جارٍ الحفظ…':'حفظ المسودة')),
    ]));
  }));
}

Future<DbRow?> entryLineDialog(BuildContext context,List<DbRow> accounts,bool journal,{DbRow? existing})async{
  var account=existing?['AccountId'] as int? ?? accounts.first['AccountId'] as int;
  final amount=TextEditingController(text:formatFixed(existing?['Amount'] as int? ?? 0));
  final debit=TextEditingController(text:formatFixed(existing?['Debit'] as int? ?? 0));
  final credit=TextEditingController(text:formatFixed(existing?['Credit'] as int? ?? 0));
  final result=await showControllerDialog<DbRow>(context:context,controllers:[amount,debit,credit],builder:(dialog)=>StatefulBuilder(builder:(dialog,setLocal)=>AlertDialog(title:const Text('سطر محاسبي'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[idDropdown(label:'الحساب',rows:accounts,idKey:'AccountId',nameKey:'AccountName',value:account,onChanged:(v)=>setLocal(()=>account=v!)),if(journal)...[formField(debit,'مدين',numeric:true),formField(credit,'دائن',numeric:true)]else formField(amount,'المبلغ',numeric:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('إلغاء')),FilledButton(onPressed:(){try{final row=<String,Object?>{'AccountId':account,'AccountName':accounts.firstWhere((r)=>r['AccountId']==account)['AccountName']};if(journal){row['Debit']=parseFixed(debit.text,2);row['Credit']=parseFixed(credit.text,2);if(!((row['Debit'] as int)>0&&row['Credit']==0||(row['Credit'] as int)>0&&row['Debit']==0)){throw const FormatException('أدخل مبلغًا في طرف واحد فقط');}}else{row['Amount']=parseFixed(amount.text,2);if(row['Amount']==0){throw const FormatException('المبلغ يجب أن يكون موجبًا');}}Navigator.pop(dialog,row);}catch(e){showError(dialog,e);}},child:const Text('اعتماد السطر'))])));
  return result;
}
