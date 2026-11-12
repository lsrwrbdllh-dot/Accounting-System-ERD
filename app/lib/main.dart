import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/app_database.dart';
import 'data/accounting_repository.dart';
import 'ui/common.dart';
import 'ui/home_page.dart';

void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const AccountingApp());}

class AccountingApp extends StatefulWidget{
  final AccountingRepository? repository;
  const AccountingApp({super.key,this.repository});
  @override State<AccountingApp> createState()=>_AccountingAppState();
}
class _AccountingAppState extends State<AccountingApp>{
  late Future<AccountingRepository> ready;
  bool signedIn=false;
  @override void initState(){super.initState();ready=initialize();}
  Future<AccountingRepository> initialize() async {
    try {
      return widget.repository ?? AccountingRepository(await AppDatabase.open(
        demo:const String.fromEnvironment('APP_ENV',defaultValue:'production')=='demo',
      ));
    } catch (error) {
      // Keep a non-sensitive marker for device startup checks, including release.
      debugPrint('ACCOUNTING_STARTUP_FAILURE ${error.runtimeType}');
      rethrow;
    }
  }
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'النظام المحاسبي',locale:const Locale('ar'),supportedLocales:const[Locale('ar')],localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff115e59)),inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder()),appBarTheme:const AppBarTheme(centerTitle:false)),home:FutureBuilder<AccountingRepository>(future:ready,builder:(context,snapshot){
    if(snapshot.hasError){
      assert(() {
        debugPrint('Startup database initialization failed: ${snapshot.error}');
        debugPrintStack(stackTrace: snapshot.stackTrace);
        return true;
      }());
      return Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(
        kDebugMode
          ? 'تعذر بدء تشغيل النظام.\n\nتفاصيل التشخيص (نسخة التطوير):\n${snapshot.error}'
          : errorMessage(snapshot.error!),
        textDirection:TextDirection.rtl,
      ),const SizedBox(height:16),FilledButton(onPressed:(){setState((){ready=initialize();});},child:const Text('إعادة المحاولة'))])))));
    }
    if(!snapshot.hasData){return const Scaffold(body:Center(child:CircularProgressIndicator()));}
    final repo=snapshot.data!;
    if(signedIn){return HomePage(repo,onLogout:(){repo.logout();setState(()=>signedIn=false);});}
    return LoginPage(repo,onLogin:()=>setState(()=>signedIn=true));
  }));
}

class LoginPage extends StatefulWidget{
  final AccountingRepository repository;final VoidCallback onLogin;
  const LoginPage(this.repository,{super.key,required this.onLogin});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final username=TextEditingController();final password=TextEditingController();final form=GlobalKey<FormState>();
  late Future<bool> setup;bool busy=false;
  @override void initState(){super.initState();setup=widget.repository.needsSetup();}
  @override void dispose(){username.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:FutureBuilder<bool>(future:setup,builder:(context,snapshot){
    if(snapshot.hasError){return Text(errorMessage(snapshot.error!));}if(!snapshot.hasData){return const CircularProgressIndicator();}
    final firstRun=snapshot.data!;
    return Form(key:form,child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[const Icon(Icons.account_balance,size:64),const SizedBox(height:16),Text(firstRun?'إعداد مدير النظام':'تسجيل الدخول',style:Theme.of(context).textTheme.headlineMedium,textAlign:TextAlign.center),const SizedBox(height:24),
      if(widget.repository.database.demo)const Padding(padding:EdgeInsets.only(bottom:16),child:Text('بيئة التجربة\nالمستخدم demo · كلمة المرور Demo@2026!')),
      formField(username,'اسم المستخدم'),TextFormField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور'),validator:(v)=>v==null||v.isEmpty?'كلمة المرور مطلوبة':firstRun&&v.length<10?'استخدم 10 أحرف على الأقل':null,onFieldSubmitted:(_){if(!busy){submit(firstRun);}}),
      const SizedBox(height:24),FilledButton(onPressed:busy?null:()=>submit(firstRun),child:Text(busy?'جارٍ التحقق…':firstRun?'إنشاء المدير':'دخول')),
    ]));
  }))));
  Future<void> submit(bool firstRun)async{
    if(!form.currentState!.validate()){return;}
    setState(()=>busy=true);
    try{if(firstRun){await widget.repository.createAdministrator(username.text,password.text);}await widget.repository.login(username.text,password.text);if(mounted){widget.onLogin();}}
    catch(e){if(mounted){showError(context,e);setState(()=>busy=false);}}
  }
}
