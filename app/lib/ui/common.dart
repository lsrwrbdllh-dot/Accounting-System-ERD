import 'package:flutter/material.dart';
import '../data/accounting_repository.dart';

String errorMessage(Object error) {
  final text=error.toString();
  const messages={
    'Insufficient stock':'كمية المخزون أو قيمته غير كافية.',
    'immutable':'المستند مرحّل؛ التصحيح بمرتجع، ولا يمكن تعديله.',
    'balance':'القيد غير متوازن. راجع المدين والدائن.',
    'open fiscal':'الفترة المالية مغلقة أو غير موجودة.',
    'original quantity':'الكمية المرتجعة تتجاوز الكمية الأصلية.',
    'Return line':'تفاصيل المرتجع لا تطابق الفاتورة الأصلية.',
    'unpaid':'قيمة المرتجع تتجاوز الجزء غير المسدد.',
    'overpayment':'التخصيص يتجاوز المتبقي أو لا يطابق الفاتورة.',
    'Allocation':'راجع قيمة تخصيص السداد وحساب العميل أو المورد.',
    'totals':'الإجمالي لا يطابق مجموع التفاصيل.',
    'UNIQUE':'الرمز أو السجل موجود مسبقًا.',
    'FOREIGN KEY':'السجل مرتبط ببيانات أخرى أو المرجع غير موجود.',
    'Backdated':'لا يمكن ترحيل حركة بتاريخ أقدم من آخر حركة في المستودع.',
    'locked':'هذا الإعداد مستخدم في عمليات مالية ولا يمكن تغييره.',
    'CHECK constraint':'راجع القيم والحقول المطلوبة وحدود الأرقام.',
    'Permission':'ليست لديك صلاحية لهذه العملية.',
  };
  for (final entry in messages.entries) { if (text.contains(entry.key)) { return entry.value; } }
  if (error is FormatException) { return error.message; }
  if (error is StateError) { return '${error.message}'; }
  return 'تعذر إتمام العملية. راجع البيانات ثم أعد المحاولة.';
}

void showError(BuildContext context,Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(errorMessage(error))));

String statusLabel(Object? status)=>status=='Posted'?'مرحّلة':'مسودة';

class DataListPage extends StatefulWidget {
  final String title;
  final Future<List<DbRow>> Function(String) load;
  final String Function(DbRow) heading;
  final String Function(DbRow) subtitle;
  final Future<void> Function(BuildContext,DbRow)? onOpen;
  final Future<void> Function(BuildContext)? onAdd;
  final List<Widget> actions;
  const DataListPage({super.key,required this.title,required this.load,required this.heading,required this.subtitle,this.onOpen,this.onAdd,this.actions=const []});
  @override State<DataListPage> createState()=>_DataListPageState();
}

class _DataListPageState extends State<DataListPage> {
  final search=TextEditingController();
  late Future<List<DbRow>> rows;
  @override void initState(){super.initState();refresh();}
  void refresh(){rows=widget.load(search.text);}
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.title),actions:widget.actions),
    floatingActionButton:widget.onAdd==null?null:FloatingActionButton(tooltip:'إضافة',onPressed:() async {await widget.onAdd!(context);if(mounted){setState(refresh);}},child:const Icon(Icons.add)),
    body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:TextField(controller:search,decoration:const InputDecoration(labelText:'بحث',prefixIcon:Icon(Icons.search)),onChanged:(_)=>setState(refresh))),Expanded(child:FutureBuilder<List<DbRow>>(future:rows,builder:(context,snapshot){
      if(snapshot.hasError){return Center(child:Text(errorMessage(snapshot.error!)));}
      if(!snapshot.hasData){return const Center(child:CircularProgressIndicator());}
      final data=snapshot.data!;
      if(data.isEmpty){return const Center(child:Text('لا توجد بيانات. أضف سجلًا للبدء.'));}
      return RefreshIndicator(onRefresh:() async {setState(refresh);await rows;},child:ListView.separated(padding:const EdgeInsets.only(bottom:96),itemCount:data.length,separatorBuilder:(_,index)=>const Divider(height:1),itemBuilder:(context,index)=>ListTile(title:Text(widget.heading(data[index])),subtitle:Text(widget.subtitle(data[index])),trailing:widget.onOpen==null?null:const Icon(Icons.chevron_left),onTap:widget.onOpen==null?null:() async {await widget.onOpen!(context,data[index]);if(mounted){setState(refresh);}})));
    }))]),
  );
}

Future<T?> openPage<T>(BuildContext context,Widget page)=>Navigator.of(context).push<T>(MaterialPageRoute(builder:(_)=>page));

Widget formField(TextEditingController controller,String label,{bool numeric=false,bool mandatory=true,bool readOnly=false})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:controller,readOnly:readOnly,decoration:InputDecoration(labelText:label),keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,validator:mandatory?(v)=>(v==null||v.trim().isEmpty)?'الحقل مطلوب':null:null));

DropdownButtonFormField<int> idDropdown({required String label,required List<DbRow> rows,required String idKey,required String nameKey,required int? value,required ValueChanged<int?> onChanged,bool optional=false})=>DropdownButtonFormField<int>(initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label),items:[if(optional)const DropdownMenuItem<int>(value:0,child:Text('بدون')),for(final row in rows)DropdownMenuItem<int>(value:row[idKey] as int,child:Text('${row[nameKey]}',overflow:TextOverflow.ellipsis))],onChanged:onChanged,validator:optional?null:(v)=>v==null?'اختر قيمة':null);
