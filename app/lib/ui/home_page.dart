import 'package:flutter/material.dart';
import '../core/fixed.dart';
import '../data/accounting_repository.dart';
import 'common.dart';
import 'finance_pages.dart';
import 'invoice_pages.dart';
import 'master_pages.dart';

class HomePage extends StatefulWidget{
  final AccountingRepository repository;final VoidCallback onLogout;
  const HomePage(this.repository,{super.key,required this.onLogout});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  late Future<DbRow> summary;
  @override void initState(){super.initState();summary=widget.repository.summary();}
  Future<void> navigate(Widget page)async{await openPage<void>(context,page);if(mounted){setState(()=>summary=widget.repository.summary());}}
  @override Widget build(BuildContext context){
    final repo=widget.repository;
    final destinations=<({String name,IconData icon,Widget page})>[
      (name:'دليل الحسابات',icon:Icons.account_tree,page:AccountsPage(repo)),
      (name:'دليل الأصناف',icon:Icons.category,page:ItemsPage(repo)),
      (name:'فواتير المبيعات',icon:Icons.point_of_sale,page:InvoicesPage(repo)),
      (name:'فواتير المشتريات',icon:Icons.shopping_cart,page:InvoicesPage(repo,purchase:true)),
      (name:'سندات القبض والصرف',icon:Icons.payments,page:VouchersPage(repo)),
      (name:'القيود اليومية',icon:Icons.menu_book,page:JournalsPage(repo)),
      (name:'المخزون',icon:Icons.warehouse,page:DataListPage(title:'المخزون',load:repo.inventory,heading:(r)=>'${r['ItemName']} · ${formatFixed(r['QtyBase'] as int,3)}',subtitle:(r)=>'${r['WarehouseName']} · القيمة ${formatFixed(r['StockValue'] as int)}${r['LotNumber']==null?'':' · دفعة ${r['LotNumber']}'}')),
    ];
    return Scaffold(appBar:AppBar(title:const Text('النظام المحاسبي'),actions:[IconButton(tooltip:'تسجيل الخروج',onPressed:widget.onLogout,icon:const Icon(Icons.logout))]),body:ListView(padding:const EdgeInsets.all(16),children:[
      if(repo.database.demo)const Card(color:Color(0xffffedcc),child:Padding(padding:EdgeInsets.all(12),child:Text('بيئة التجربة · بيانات منفصلة عن الإنتاج'))),
      FutureBuilder<DbRow>(future:summary,builder:(context,snapshot){if(snapshot.hasError){return Text(errorMessage(snapshot.error!));}if(!snapshot.hasData){return const LinearProgressIndicator();}final r=snapshot.data!;return Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الصندوق ${formatFixed(r['Cash'] as int)}',style:Theme.of(context).textTheme.headlineSmall),Text('قيمة المخزون ${formatFixed(r['StockValue'] as int)}'),Text('فواتير مرحّلة ${r['Posted']} · مسودات ${r['Drafts']}')])));}),
      const SizedBox(height:12),for(final destination in destinations)Card(child:ListTile(leading:Icon(destination.icon),title:Text(destination.name),trailing:const Icon(Icons.chevron_left),onTap:()=>navigate(destination.page))),
    ]));
  }
}
