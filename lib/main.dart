import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); await ShopDb.instance.database; runApp(const ShopApp()); }
final money = NumberFormat('#,##0.##', 'en_US');

class ShopDb {
  ShopDb._(); static final instance = ShopDb._(); Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(p.join(base, 'offline_shop.db'), version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,unit TEXT NOT NULL,stock REAL NOT NULL DEFAULT 0,buy REAL NOT NULL DEFAULT 0,sell REAL NOT NULL DEFAULT 0,updated TEXT NOT NULL)');
      await db.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER,product_name TEXT NOT NULL,type TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE cash(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,balance REAL NOT NULL DEFAULT 0)');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
      await db.insert('settings', {'key':'seer_grams','value':'1000'});
    });
    return _db!;
  }
  Future<List<Map<String,Object?>>> rows(String table,{String? order}) async => (await database).query(table,orderBy:order);
}
class ShopApp extends StatelessWidget {
  const ShopApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'مدیریت مغازه',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff087f5b)),scaffoldBackgroundColor:const Color(0xfff5f7f6)),home:const HomePage());
}
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0,revision=0; void reload()=>setState(()=>revision++);
  @override Widget build(BuildContext context) {
    final pages=[Dashboard(key:ValueKey('d$revision')),ProductsPage(key:ValueKey('p$revision'),onChanged:reload),EntriesPage(key:ValueKey('e$revision'),onChanged:reload),CashPage(key:ValueKey('c$revision'),onChanged:reload),SettingsPage(key:ValueKey('s$revision'))];
    return Directionality(textDirection:ui.TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('مدیریت مغازه',style:TextStyle(fontWeight:FontWeight.bold)),actions:[Padding(padding:const EdgeInsetsDirectional.only(end:16),child:Center(child:Text('AFN',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))))]),body:IndexedStack(index:tab,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'خانه'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'کالاها'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'خرید و فروش'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'صندوق'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'تنظیمات')])));
  }
}
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Future<Map<String,double>> stats() async {
    final db=await ShopDb.instance.database; final today=DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future<double> q(String sql,List<Object?> args) async {final r=await db.rawQuery(sql,args);return ((r.first.values.first as num?)??0).toDouble();}
    return {'sales':await q("SELECT COALESCE(SUM(total),0) FROM entries WHERE type='فروش' AND substr(created,1,10)=?",[today]),'purchases':await q("SELECT COALESCE(SUM(total),0) FROM entries WHERE type='خرید' AND substr(created,1,10)=?",[today]),'withdraw':await q("SELECT COALESCE(SUM(amount),0) FROM cash WHERE type='برداشت' AND substr(created,1,10)=?",[today]),'products':await q('SELECT COUNT(*) FROM products',[]),'cash':await q("SELECT COALESCE((SELECT SUM(total) FROM entries WHERE type='فروش'),0)-COALESCE((SELECT SUM(total) FROM entries WHERE type='خرید'),0)-COALESCE((SELECT SUM(amount) FROM cash WHERE type='برداشت'),0)+COALESCE((SELECT SUM(amount) FROM cash WHERE type='دریافت'),0)",[])};
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,double>>(future:stats(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());final v=s.data!;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff087f5b),Color(0xff16a078)]),borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('خلاصه امروز',style:TextStyle(color:Colors.white70)),const SizedBox(height:8),Text('${money.format(v['sales'])} افغانی',style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),const Text('مجموع فروش ثبت‌شده امروز',style:TextStyle(color:Colors.white70))])),
      const SizedBox(height:16),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.55,crossAxisSpacing:12,mainAxisSpacing:12,children:[StatCard('خرید امروز',v['purchases']!,Icons.shopping_bag_outlined,Colors.blue),StatCard('برداشت امروز',v['withdraw']!,Icons.south_west,Colors.red),StatCard('تعداد کالاها',v['products']!,Icons.inventory_2_outlined,Colors.teal,isMoney:false),StatCard('مانده تقریبی صندوق',v['cash']!,Icons.account_balance_wallet_outlined,Colors.green)]),
      const SizedBox(height:18),const Card(child:Padding(padding:EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('یادآوری',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),SizedBox(height:8),Text('اطلاعات روی همین دستگاه و بدون اینترنت ذخیره می‌شود. همگام‌سازی با کامپیوتر و پشتیبان‌گیری هنوز تکمیل نشده است.')])))
    ]);
  });
}
class StatCard extends StatelessWidget {
  final String title;final double value;final IconData icon;final Color color;final bool isMoney;
  const StatCard(this.title,this.value,this.icon,this.color,{this.isMoney=true});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:color),Text(title,style:const TextStyle(color:Colors.black54,fontSize:12)),Text(isMoney?'${money.format(value)} AFN':money.format(value),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])));
}
Widget field(TextEditingController c,String label,{bool number=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextField(controller:c,keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
class ProductsPage extends StatefulWidget {final VoidCallback onChanged;const ProductsPage({super.key,required this.onChanged});@override State<ProductsPage> createState()=>_ProductsPageState();}
class _ProductsPageState extends State<ProductsPage> {
  Future<void> add() async {
    final n=TextEditingController(),u=TextEditingController(text:'عدد'),q=TextEditingController(text:'0'),b=TextEditingController(text:'0'),s=TextEditingController(text:'0');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('افزودن کالا'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(n,'نام کالا'),field(u,'واحد (کیلو، گرم، سیر، عدد...)'),field(q,'موجودی اولیه',number:true),field(b,'قیمت خرید هر واحد',number:true),field(s,'قیمت فروش هر واحد',number:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));
    if(ok==true&&n.text.trim().isNotEmpty){await (await ShopDb.instance.database).insert('products',{'name':n.text.trim(),'unit':u.text.trim(),'stock':double.tryParse(q.text)??0,'buy':double.tryParse(b.text)??0,'sell':double.tryParse(s.text)??0,'updated':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('کالای جدید')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('products',order:'name COLLATE NOCASE'),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('هنوز کالایی ثبت نشده است'));return ListView.builder(padding:const EdgeInsets.only(bottom:90),itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(leading:const CircleAvatar(child:Icon(Icons.inventory_2_outlined)),title:Text('${x['name']}'),subtitle:Text('قیمت فروش: ${money.format(x['sell'])} AFN • ${x['unit']}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('${x['stock']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const Text('موجودی',style:TextStyle(fontSize:10))])));});}));
}
class EntriesPage extends StatefulWidget {final VoidCallback onChanged;const EntriesPage({super.key,required this.onChanged});@override State<EntriesPage> createState()=>_EntriesPageState();}
class _EntriesPageState extends State<EntriesPage> {
  String type='فروش';
  Future<void> add() async {
    final db=await ShopDb.instance.database;final products=await db.query('products',orderBy:'name');if(products.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا یک کالا ثبت کنید')));return;}
    int? selected=products.first['id'] as int;final qty=TextEditingController(text:'1'),price=TextEditingController(text:'${products.first[type=='فروش'?'sell':'buy']}'),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(title:Text('ثبت $type'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب کالا'),items:products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} (${x['unit']})'))).toList(),onChanged:(v){refresh(()=>selected=v);final x=products.firstWhere((e)=>e['id']==v);price.text='${x[type=='فروش'?'sell':'buy']}';}),field(qty,'مقدار',number:true),field(price,'قیمت هر واحد',number:true),field(note,'یادداشت')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))])));
    if(ok==true&&selected!=null){final x=products.firstWhere((e)=>e['id']==selected);final amount=double.tryParse(qty.text)??0,unitPrice=double.tryParse(price.text)??0;if(amount<=0)return;final stock=(x['stock'] as num).toDouble()+(type=='خرید'?amount:-amount);await db.update('products',{'stock':stock,'updated':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[selected]);await db.insert('entries',{'product_id':selected,'product_name':x['name'],'type':type,'qty':amount,'price':unitPrice,'total':amount*unitPrice,'note':note.text,'created':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}
  }
  @override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<String>(segments:const [ButtonSegment(value:'فروش',label:Text('ثبت فروش'),icon:Icon(Icons.trending_up)),ButtonSegment(value:'خرید',label:Text('ثبت خرید'),icon:Icon(Icons.shopping_cart))],selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first))),Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('entries',order:'id DESC'),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('هنوز خرید یا فروشی ثبت نشده است'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];final sale=x['type']=='فروش';return ListTile(leading:Icon(sale?Icons.arrow_upward:Icons.arrow_downward,color:sale?Colors.green:Colors.blue),title:Text('${x['product_name']} • ${x['type']}'),subtitle:Text('${x['qty']} × ${money.format(x['price'])}'),trailing:Text('${money.format(x['total'])} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:sale?Colors.green:Colors.blue)));});})),Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:Text('ثبت $type'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(48))))]);
}
class CashPage extends StatefulWidget {final VoidCallback onChanged;const CashPage({super.key,required this.onChanged});@override State<CashPage> createState()=>_CashPageState();}
class _CashPageState extends State<CashPage> {
  Future<void> add() async {String type='برداشت';final amount=TextEditingController(),note=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(title:const Text('ثبت تراکنش صندوق'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,items:const [DropdownMenuItem(value:'برداشت',child:Text('برداشت شخصی / هزینه')),DropdownMenuItem(value:'دریافت',child:Text('دریافت پول'))],onChanged:(v)=>refresh(()=>type=v!),decoration:const InputDecoration(labelText:'نوع تراکنش')),field(amount,'مبلغ افغانی',number:true),field(note,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))])));if(ok==true&&(double.tryParse(amount.text)??0)>0){await (await ShopDb.instance.database).insert('cash',{'type':type,'amount':double.parse(amount.text),'note':note.text,'created':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('ثبت صندوق')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('cash',order:'id DESC'),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('تراکنش صندوقی ثبت نشده است'));return ListView(children:s.data!.map((x)=>ListTile(leading:Icon(x['type']=='دریافت'?Icons.add_circle:Icons.remove_circle,color:x['type']=='دریافت'?Colors.green:Colors.red),title:Text('${x['type']}'),subtitle:Text('${x['note']??''}'),trailing:Text('${money.format(x['amount'])} AFN'))).toList());}));
}
class SettingsPage extends StatefulWidget {const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage> {
  final seer=TextEditingController();
  @override void initState(){super.initState();ShopDb.instance.database.then((db)=>db.query('settings',where:'key=?',whereArgs:['seer_grams']).then((r){if(r.isNotEmpty&&mounted)seer.text='${r.first['value']}';}));}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('تنظیمات مغازه',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('واحدها',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),TextField(controller:seer,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'هر سیر چند گرم است؟',suffixText:'گرم')),const SizedBox(height:8),FilledButton(onPressed:()async{await (await ShopDb.instance.database).update('settings',{'value':seer.text},where:'key=?',whereArgs:['seer_grams']);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تنظیم ذخیره شد')));},child:const Text('ذخیره تنظیمات'))]))),const Card(child:ListTile(leading:Icon(Icons.wifi_off),title:Text('حالت آفلاین'),subtitle:Text('ثبت کالا، خرید، فروش و صندوق بدون اینترنت ذخیره می‌شود.'))),const Card(child:ListTile(leading:Icon(Icons.currency_exchange),title:Text('واحد پول'),subtitle:Text('افغانی (AFN)'))),const Card(child:ListTile(leading:Icon(Icons.sync),title:Text('همگام‌سازی گوشی و کامپیوتر'),subtitle:Text('هنوز پیاده‌سازی نشده؛ داده‌ها فعلاً فقط روی همین دستگاه هستند.'))),const Card(child:ListTile(leading:Icon(Icons.backup_outlined),title:Text('پشتیبان‌گیری و بازیابی'),subtitle:Text('هنوز پیاده‌سازی نشده؛ قبل از استفاده روزمره باید اضافه شود.')))]);
}
