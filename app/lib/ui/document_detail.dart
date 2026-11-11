import 'package:flutter/material.dart';
import '../core/fixed.dart';
import '../data/accounting_repository.dart';
import 'common.dart';

class DocumentDetail extends StatefulWidget {
  final AccountingRepository repository;final DbRow header;final String family;final int typ;
  final Widget Function()? editor;
  const DocumentDetail(this.repository,this.header,this.family,this.typ,{super.key,this.editor});
  @override State<DocumentDetail> createState()=>_DocumentDetailState();
}
class _DocumentDetailState extends State<DocumentDetail>{
  bool busy=false;
  late final int id;
  late final Future<List<DbRow>> lines;
  @override void initState(){super.initState();id=widget.header[widget.family=='invoice'?'TransId':widget.family=='voucher'?'VoucherId':'JournalId'] as int;lines=widget.family=='invoice'?widget.repository.invoiceLines(id,widget.typ):widget.repository.documentLines(widget.family,id,widget.typ);}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('مستند $id · ${statusLabel(widget.header['Status'])}')),body:FutureBuilder<List<DbRow>>(future:lines,builder:(context,snapshot){
    if(snapshot.hasError){return Center(child:Text(errorMessage(snapshot.error!)));}
    if(!snapshot.hasData){return const Center(child:CircularProgressIndicator());}
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text('${widget.header['TransDate']??widget.header['VoucherDate']??widget.header['EntryDate']}',style:Theme.of(context).textTheme.titleMedium),
      Text('${widget.header['Notes']??widget.header['Description']??''}'),
      if(widget.header['Total']!=null||widget.header['Amount']!=null)Text('الإجمالي ${formatFixed((widget.header['Total']??widget.header['Amount']) as int)}',style:Theme.of(context).textTheme.headlineSmall),
      if(widget.header['Outstanding']!=null)Text('المتبقي ${formatFixed(widget.header['Outstanding'] as int)}'),
      const Divider(),
      for(final line in snapshot.data!)Card(child:ListTile(title:Text('${line['ItemName']??line['AccountName']}'),subtitle:Text(widget.family=='invoice'?'${formatFixed(line['Qty'] as int,3)} ${line['UnitName']} × ${formatFixed(line['Price'] as int)}\nخصم ${formatFixed(line['Discount'] as int)} · ضريبة ${formatFixed(line['Tax'] as int)}':widget.family=='journal'?'مدين ${formatFixed(line['Debit'] as int)} · دائن ${formatFixed(line['Credit'] as int)}':'المبلغ ${formatFixed(line['Amount'] as int)}'))),
      if(widget.header['Status']=='Draft')...[
        const SizedBox(height:16),
        if(widget.editor!=null)OutlinedButton.icon(onPressed:busy?null:()async{await openPage<void>(context,widget.editor!());if(context.mounted){Navigator.pop(context);}},icon:const Icon(Icons.edit),label:const Text('تعديل المسودة')),
        FilledButton.icon(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.repository.post(widget.family,id,widget.typ);if(context.mounted){Navigator.pop(context);}}catch(e){if(context.mounted){showError(context,e);setState(()=>busy=false);}}},icon:const Icon(Icons.check_circle),label:Text(busy?'جارٍ الترحيل…':'ترحيل المستند')),
        const Text('الحفظ لا يغيّر الحسابات أو المخزون. الترحيل يعتمد العملية كاملة.',textAlign:TextAlign.center),
      ],
    ]);
  }));
}
