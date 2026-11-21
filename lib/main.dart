import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); await ShopDb.instance.database; runApp(const ShopApp()); }
String faDigits(String value) => value.replaceAll('0','۰').replaceAll('1','۱').replaceAll('2','۲').replaceAll('3','۳').replaceAll('4','۴').replaceAll('5','۵').replaceAll('6','۶').replaceAll('7','۷').replaceAll('8','۸').replaceAll('9','۹');
double? parseNum(String? value) { if(value==null)return null; final normalized=value.trim().replaceAll('٬','').replaceAll(',','').replaceAll('٫','.').replaceAll('۰','0').replaceAll('۱','1').replaceAll('۲','2').replaceAll('۳','3').replaceAll('۴','4').replaceAll('۵','5').replaceAll('۶','6').replaceAll('۷','7').replaceAll('۸','8').replaceAll('۹','9').replaceAll('٠','0').replaceAll('١','1').replaceAll('٢','2').replaceAll('٣','3').replaceAll('٤','4').replaceAll('٥','5').replaceAll('٦','6').replaceAll('٧','7').replaceAll('٨','8').replaceAll('٩','9'); return double.tryParse(normalized); }
class PersianMoneyFormat { String format(Object? value) => faDigits(NumberFormat('#,##0.##','en_US').format(value is num ? value : num.tryParse('$value') ?? 0)); }
final money = PersianMoneyFormat();

class ShopDb {
  ShopDb._(); static final instance = ShopDb._(); Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(p.join(base, 'offline_shop.db'), version: 8, onCreate: (db, v) async {
      await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,unit TEXT NOT NULL,stock REAL NOT NULL DEFAULT 0,buy REAL NOT NULL DEFAULT 0,sell REAL NOT NULL DEFAULT 0,updated TEXT NOT NULL)');
      await db.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER,product_name TEXT NOT NULL,type TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,note TEXT,created TEXT NOT NULL,customer_id INTEGER,paid REAL NOT NULL DEFAULT 0,supplier_id INTEGER,cash_id INTEGER)');
      await db.execute('CREATE TABLE cash(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,balance REAL NOT NULL DEFAULT 0,opening_balance REAL NOT NULL DEFAULT 0)');
      await db.execute("CREATE TABLE customer_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL,cash_id INTEGER,type TEXT NOT NULL DEFAULT 'دریافت')");
      await db.execute('CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,opening_balance REAL NOT NULL DEFAULT 0)');
      await db.execute('CREATE TABLE supplier_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,supplier_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
      await db.execute('CREATE TABLE price_history(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,buy REAL NOT NULL,sell REAL NOT NULL,changed TEXT NOT NULL)');
      await db.insert('settings', {'key':'seer_grams','value':'1000'});
    }, onUpgrade: (db, oldVersion, newVersion) async { if (oldVersion < 2) { await db.execute('ALTER TABLE entries ADD COLUMN customer_id INTEGER'); } if (oldVersion < 3) { await db.execute('CREATE TABLE price_history(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,buy REAL NOT NULL,sell REAL NOT NULL,changed TEXT NOT NULL)'); await db.execute('INSERT INTO price_history(product_id,buy,sell,changed) SELECT id,buy,sell,updated FROM products'); } if (oldVersion < 4) { await db.execute('ALTER TABLE entries ADD COLUMN paid REAL NOT NULL DEFAULT 0'); await db.execute('ALTER TABLE customers ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0'); await db.execute('CREATE TABLE customer_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)'); await db.execute('UPDATE customers SET opening_balance=-balance'); } if (oldVersion < 5) { await db.execute('ALTER TABLE entries ADD COLUMN supplier_id INTEGER'); await db.execute('CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,opening_balance REAL NOT NULL DEFAULT 0)'); await db.execute('CREATE TABLE supplier_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,supplier_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');  } if (oldVersion < 6) {
      await db.execute('ALTER TABLE entries ADD COLUMN cash_id INTEGER');
      final oldEntries = await db.query('entries', where: 'paid > 0');
      for (final entry in oldEntries) {
        final cashId = await db.insert('cash', {
          'type': entry['type'] == 'فروش' ? 'دریافت' : 'برداشت',
          'amount': entry['paid'],
          'note': 'ثبت خودکار از سند شماره ${entry['id']}',
          'created': entry['created'],
        });
        await db.update('entries', {'cash_id': cashId}, where: 'id=?', whereArgs: [entry['id']]);
      }
    }
    if (oldVersion < 7) { await db.execute('ALTER TABLE customer_payments ADD COLUMN cash_id INTEGER'); }
      if (oldVersion < 8) { await db.execute("ALTER TABLE customer_payments ADD COLUMN type TEXT NOT NULL DEFAULT 'دریافت'"); }
    } });
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
    final pages=[Dashboard(key:ValueKey('d$revision')),ProductsPage(key:ValueKey('p$revision'),onChanged:reload),EntriesPage(key:ValueKey('e$revision'),onChanged:reload),CashPage(key:ValueKey('c$revision'),onChanged:reload),AccountsPage(key:ValueKey('u$revision')),SettingsPage(key:ValueKey('s$revision'))];
    return Directionality(textDirection:ui.TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('مدیریت مغازه',style:TextStyle(fontWeight:FontWeight.bold)),actions:[Padding(padding:const EdgeInsetsDirectional.only(end:16),child:Center(child:Text('افغانی',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))))]),body:IndexedStack(index:tab,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'خانه'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'کالاها'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'خرید و فروش'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'صندوق'),NavigationDestination(icon:Icon(Icons.groups_outlined),label:'حساب‌ها'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'تنظیمات')])));
  }
}
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  Future<Map<String,double>> stats() async {
    final db=await ShopDb.instance.database; final today=DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future<double> q(String sql,List<Object?> args) async {final r=await db.rawQuery(sql,args);return ((r.first.values.first as num?)??0).toDouble();}
    return {'sales':await q("SELECT COALESCE(SUM(total),0) FROM entries WHERE type='فروش' AND substr(created,1,10)=?",[today]),'purchases':await q("SELECT COALESCE(SUM(total),0) FROM entries WHERE type='خرید' AND substr(created,1,10)=?",[today]),'withdraw':await q("SELECT COALESCE(SUM(amount),0) FROM cash WHERE type='برداشت' AND substr(created,1,10)=?",[today]),'products':await q('SELECT COUNT(*) FROM products',[]),'cash':await q("SELECT COALESCE(SUM(CASE WHEN type='دریافت' THEN amount ELSE -amount END),0) FROM cash",[])};
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
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:color),Text(title,style:const TextStyle(color:Colors.black54,fontSize:12)),Text(isMoney?'${money.format(value)} افغانی':money.format(value),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])));
}
Widget field(TextEditingController c,String label,{bool number=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextField(controller:c,keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

Future<double> configuredSeerGrams() async {
  final db = await ShopDb.instance.database;
  final rows = await db.query('settings', where: 'key=?', whereArgs: ['seer_grams'], limit: 1);
  final value = rows.isEmpty ? 1000 : (parseNum(rows.first['value'].toString()) ?? 1000);
  return value > 0 ? value.toDouble() : 1000.0;
}
double gramsPerUnit(String unit, double seerGrams) {
  final u = unit.trim().toLowerCase();
  if (u.contains('کیلو') || u == 'kg' || u == 'kilogram') return 1000;
  if (u.contains('سیر') || u == 'seer' || u == 'sir') return seerGrams;
  if (u.contains('گرم') || u == 'g' || u == 'gram') return 1;
  return 0;
}
List<Map<String,Object>> quantityPresets(String unit, double seerGrams) {
  final factor = gramsPerUnit(unit, seerGrams);
  if (factor <= 0) return [
    {'label':'۱', 'value':1.0}, {'label':'۲', 'value':2.0},
    {'label':'۵', 'value':5.0}, {'label':'۱۰', 'value':10.0},
  ];
  final options = <Map<String,Object>>[
    {'label':'۱ کیلو', 'grams':1000.0}, {'label':'۲ کیلو', 'grams':2000.0},
    {'label':'۱ کیلو و ۱ سیر', 'grams':1000.0 + seerGrams},
    {'label':'۱ سیر', 'grams':seerGrams}, {'label':'۲ سیر', 'grams':2 * seerGrams},
    {'label':'۱۰۰ گرم', 'grams':100.0}, {'label':'۲۵۰ گرم', 'grams':250.0},
    {'label':'۵۰۰ گرم', 'grams':500.0},
  ];
  return options.map((e)=>{'label':e['label']!, 'value':(e['grams'] as double)/factor}).toList();
}

class ProductsPage extends StatefulWidget {final VoidCallback onChanged;const ProductsPage({super.key,required this.onChanged});@override State<ProductsPage> createState()=>_ProductsPageState();}
class _ProductsPageState extends State<ProductsPage> {
  final units = const ['کیلوگرم','کیلو','سیر','گرم','عدد','بسته','کارتن'];
  String cleanQty(double v)=>v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'),'');
  Future<List<Map<String,Object?>>> productRows() async {
    final db=await ShopDb.instance.database;
    return db.rawQuery("SELECT products.*, (SELECT suppliers.name FROM entries LEFT JOIN suppliers ON suppliers.id=entries.supplier_id WHERE entries.product_id=products.id AND entries.type='خرید' AND entries.supplier_id IS NOT NULL ORDER BY entries.id DESC LIMIT 1) AS source_name FROM products ORDER BY products.name COLLATE NOCASE");
  }
  Future<void> add() async {
    final db=await ShopDb.instance.database;
    final suppliers=await db.query('suppliers',orderBy:'name');
    final seerGrams=await configuredSeerGrams();
    final n=TextEditingController(),q=TextEditingController(text:'0'),b=TextEditingController(text:'0'),s=TextEditingController(text:'0'),paid=TextEditingController();
    String unit='عدد'; int? supplierId;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final buyPrice=parseNum(b.text)??0, sellPrice=parseNum(s.text)??0, stock=parseNum(q.text)??0;
      return AlertDialog(title:const Text('افزودن کالای جدید'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(n,'نام کالا'),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'واحد اصلی کالا'),items:units.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:(v)=>refresh(()=>unit=v??unit)),
        const SizedBox(height:8),TextField(controller:q,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'موجودی اولیه',border:OutlineInputBorder())),
        Align(alignment:Alignment.centerRight,child:Text('مقدارهای آماده برای '+unit,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))),
        Wrap(spacing:5,runSpacing:4,children:quantityPresets(unit,seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>refresh(()=>q.text=cleanQty(p['value'] as double)))).toList()),
        TextField(controller:b,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'قیمت خرید هر '+unit+' (AFN)',border:const OutlineInputBorder())),TextField(controller:s,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'قیمت فروش هر '+unit+' (AFN)',border:const OutlineInputBorder())),
        Container(width:double.infinity,margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('سود هر واحد: '+money.format(sellPrice-buyPrice)+' افغانی',style:TextStyle(color:sellPrice>=buyPrice?Colors.green:Colors.red,fontWeight:FontWeight.bold)),
          Text('سود احتمالی موجودی: '+money.format(stock*(sellPrice-buyPrice))+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold)),
        ])),
        const Divider(height:20),
        const Align(alignment:Alignment.centerRight,child:Text('منبع خرید موجودی اولیه',style:TextStyle(fontWeight:FontWeight.bold))),
        DropdownButtonFormField<int>(value:supplierId,decoration:const InputDecoration(labelText:'از کدام مغازه / فروشنده خرید شده؟'),items:suppliers.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text(x['name'].toString()))).toList(),onChanged:(v)=>refresh(()=>supplierId=v)),
        if(suppliers.isEmpty) const Padding(padding:EdgeInsets.only(top:6),child:Text('ابتدا فروشنده را از بخش حساب‌ها ثبت کنید.',style:TextStyle(color:Colors.red,fontSize:12))),
        field(paid,'مبلغ پرداخت نقدی به فروشنده (خالی = تسویه کامل)',number:true),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت کالا و خرید اولیه'))]);
    }));
    final stock=parseNum(q.text)??0,buyPrice=parseNum(b.text)??0,sellPrice=parseNum(s.text)??0,total=stock*buyPrice;
    final paidAmount=paid.text.trim().isEmpty?total:(parseNum(paid.text)??0);
    if(ok==true&&n.text.trim().isNotEmpty){
      if(stock<0||buyPrice<0||sellPrice<0||paidAmount<0||paidAmount>total||(stock>0&&supplierId==null)){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی، قیمت، فروشنده یا مبلغ پرداختی را بررسی کنید.')));return;
      }
      await db.transaction((t)async{
        final now=DateTime.now().toIso8601String();
        final id=await t.insert('products',{'name':n.text.trim(),'unit':unit,'stock':stock,'buy':buyPrice,'sell':sellPrice,'updated':now});
        await t.insert('price_history',{'product_id':id,'buy':buyPrice,'sell':sellPrice,'changed':now});
        if(stock>0){
          final entryId=await t.insert('entries',{'product_id':id,'product_name':n.text.trim(),'type':'خرید','qty':stock,'price':buyPrice,'total':total,'note':'موجودی اولیه کالا','created':now,'supplier_id':supplierId,'paid':paidAmount});
          if(paidAmount>0){final cashId=await t.insert('cash',{'type':'برداشت','amount':paidAmount,'note':'پرداخت نقدی خرید اولیه • سند #'+entryId.toString(),'created':now});await t.update('entries',{'cash_id':cashId},where:'id=?',whereArgs:[entryId]);}
        }
      });
      widget.onChanged();if(mounted)setState((){});
    }
  }
  Future<void> editProduct(Map<String,Object?> x) async {
    final db=await ShopDb.instance.database;final used=await db.query('entries',where:'product_id=?',whereArgs:[x['id']],limit:1);
    final n=TextEditingController(text:x['name'].toString()),q=TextEditingController(text:x['stock'].toString()),b=TextEditingController(text:x['buy'].toString()),s=TextEditingController(text:x['sell'].toString());
    String unit=x['unit'].toString();final editUnits=[...units];if(!editUnits.contains(unit))editUnits.add(unit);
    final seerGrams=await configuredSeerGrams();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final buyPrice=parseNum(b.text)??0,sellPrice=parseNum(s.text)??0,stock=parseNum(q.text)??0;
      return AlertDialog(title:const Text('ویرایش کالا'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(n,'نام کالا'),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'واحد کالا'),items:editUnits.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:used.isNotEmpty?null:(v)=>refresh(()=>unit=v??unit)),
        if(used.isNotEmpty)const Text('به دلیل وجود سابقه خرید و فروش، واحد اصلی این کالا قابل تغییر نیست.',style:TextStyle(color:Colors.orange,fontSize:12)),
        field(q,'موجودی فعلی',number:true),
        Wrap(spacing:5,children:quantityPresets(unit,seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>refresh(()=>q.text=cleanQty(p['value'] as double)))).toList()),
        field(b,'قیمت خرید هر '+unit,number:true),field(s,'قیمت فروش هر '+unit,number:true),
        Text('سود احتمالی موجودی: '+money.format(stock*(sellPrice-buyPrice))+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.green)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره تغییرات'))]);
    }));
    if(ok==true&&n.text.trim().isNotEmpty){
      final buyPrice=parseNum(b.text)??0,sellPrice=parseNum(s.text)??0,stock=parseNum(q.text)??0;
      if(stock<0||buyPrice<0||sellPrice<0)return;
      await db.update('products',{'name':n.text.trim(),'unit':unit,'stock':stock,'buy':buyPrice,'sell':sellPrice,'updated':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[x['id']]);
      if(buyPrice!=(x['buy'] as num).toDouble()||sellPrice!=(x['sell'] as num).toDouble())await db.insert('price_history',{'product_id':x['id'],'buy':buyPrice,'sell':sellPrice,'changed':DateTime.now().toIso8601String()});
      widget.onChanged();if(mounted)setState((){});
    }
  }
  Future<void> showPriceHistory(Map<String,Object?> product) async {final db=await ShopDb.instance.database;final rows=await db.query('price_history',where:'product_id=?',whereArgs:[product['id']],orderBy:'id DESC');if(!mounted)return;showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('تاریخچه قیمت '+product['name'].toString()),content:SizedBox(width:360,child:rows.isEmpty?const Text('تاریخچه‌ای ثبت نشده است'):ListView(shrinkWrap:true,children:rows.map((r)=>ListTile(dense:true,title:Text('خرید: '+money.format(r['buy'])+' • فروش: '+money.format(r['sell'])+' افغانی'),subtitle:Text(DateFormat('yyyy/MM/dd  HH:mm').format(DateTime.parse(r['changed'].toString()))))).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))]));}
  Future<void> deleteProduct(Map<String,Object?> x) async {
    final db=await ShopDb.instance.database;final used=await db.query('entries',where:'product_id=?',whereArgs:[x['id']],limit:1);
    if(used.isNotEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این کالا سابقه خرید یا فروش دارد؛ حذف آن مجاز نیست.')));return;}
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف کالا'),content:Text('کالای «'+x['name'].toString()+'» حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(ok==true){await db.delete('products',where:'id=?',whereArgs:[x['id']]);widget.onChanged();if(mounted)setState((){});}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,body:FutureBuilder<List<Map<String,Object?>>>(future:productRows(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());final products=s.data!;
    final stockValue=products.fold<double>(0,(a,x)=>a+((x['stock'] as num).toDouble()*(x['buy'] as num).toDouble()));
    final saleValue=products.fold<double>(0,(a,x)=>a+((x['stock'] as num).toDouble()*(x['sell'] as num).toDouble()));
    final profit=saleValue-stockValue;
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,8,12,2),child:SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:add,icon:const Icon(Icons.add),label:const Text('ثبت کالای جدید')))),
      Expanded(child:products.isEmpty?const Center(child:Text('هنوز کالایی ثبت نشده است')):ListView.builder(padding:const EdgeInsets.fromLTRB(10,8,10,12),itemCount:products.length,itemBuilder:(c,i){
        final x=products[i];final stock=(x['stock'] as num).toDouble(),buy=(x['buy'] as num).toDouble(),sell=(x['sell'] as num).toDouble();
        return Card(margin:const EdgeInsets.symmetric(vertical:4),child:ListTile(leading:const CircleAvatar(child:Icon(Icons.inventory_2_outlined)),title:Text(x['name'].toString()),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
          Text('موجودی: '+money.format(stock)+' '+x['unit'].toString()+' • خرید: '+money.format(buy)+' • فروش: '+money.format(sell)+' AFN'),
          Text('سود هر واحد: '+money.format(sell-buy)+' • سود موجودی: '+money.format(stock*(sell-buy))+' AFN',style:TextStyle(fontSize:11,color:sell>=buy?Colors.green:Colors.red)),
          Text('آخرین خرید از: '+(x['source_name']?.toString()??'ثبت نشده'),style:const TextStyle(fontSize:11,color:Colors.blueGrey)),
        ]),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')editProduct(x);else if(v=='history')showPriceHistory(x);else deleteProduct(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش کالا و قیمت')),PopupMenuItem(value:'history',child:Text('تاریخچه تغییر قیمت')),PopupMenuItem(value:'delete',child:Text('حذف کالا'))])));
      })),
      Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(12,9,12,10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,boxShadow:[BoxShadow(color:Colors.black.withOpacity(.06),blurRadius:8,offset:const Offset(0,-2))]),child:Column(children:[
        Row(children:[Expanded(child:Text('ارزش خرید موجودی: '+money.format(stockValue)+' AFN',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),Expanded(child:Text('ارزش فروش: '+money.format(saleValue)+' AFN',textAlign:TextAlign.end,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)))]),
        const SizedBox(height:4),Text('سود احتمالی کل موجودی: '+money.format(profit)+' افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:profit>=0?Colors.green:Colors.red)),
      ]))
    ]);
  }));
}
class EntriesPage extends StatefulWidget {final VoidCallback onChanged;const EntriesPage({super.key,required this.onChanged});@override State<EntriesPage> createState()=>_EntriesPageState();}
class _EntriesPageState extends State<EntriesPage> {
  String type='فروش';
  Future<List<Map<String,Object?>>> entryRows() async {
    final db=await ShopDb.instance.database;
    return db.rawQuery("SELECT entries.*, customers.name AS customer_name, suppliers.name AS supplier_name, products.unit AS product_unit FROM entries LEFT JOIN customers ON customers.id=entries.customer_id LEFT JOIN suppliers ON suppliers.id=entries.supplier_id LEFT JOIN products ON products.id=entries.product_id ORDER BY entries.id DESC");
  }
  Future<double> currentCustomerBalance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM customers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE customer_id=? AND type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='دریافت'),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='پرداخت'),0) AS b",[id,id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
  Future<void> add() async {
    final db=await ShopDb.instance.database;
    final products=await db.query('products',orderBy:'name');
    if(products.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا یک کالا ثبت کنید')));return;}
    final customers=type=='فروش'?await db.query('customers',orderBy:'name'):<Map<String,Object?>>[];
    final seerGrams=await configuredSeerGrams();
    final suppliers=type=='خرید'?await db.query('suppliers',orderBy:'name'):<Map<String,Object?>>[];
    int? selected=products.first['id'] as int;
    int? selectedCustomer; int? selectedSupplier;
    final qty=TextEditingController(text:'1'),price=TextEditingController(text:'${products.first[type=='فروش'?'sell':'buy']}'),note=TextEditingController(),customerSearch=TextEditingController(),paid=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final filtered=customers.where((x)=>'${x['name']} ${x['phone']??''}'.toLowerCase().contains(customerSearch.text.toLowerCase())).toList();
      return AlertDialog(title:Text('ثبت $type'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب کالا'),items:products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} (${x['unit']})'))).toList(),onChanged:(v){refresh(()=>selected=v);final x=products.firstWhere((e)=>e['id']==v);price.text='${x[type=='فروش'?'sell':'buy']}';}),
        if(type=='خرید') ...[
          const SizedBox(height:10),TextField(controller:customerSearch,decoration:const InputDecoration(labelText:'جستجوی مغازه / فروشنده',prefixIcon:Icon(Icons.search)),onChanged:(_)=>refresh((){})),
          if(customerSearch.text.isNotEmpty) ...suppliers.where((x)=>' ${x['name']} ${x['phone']??''}'.toLowerCase().contains(customerSearch.text.toLowerCase())).take(5).map((x)=>ListTile(dense:true,selected:selectedSupplier==x['id'],leading:const Icon(Icons.storefront_outlined),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}'),onTap:()=>refresh(()=>selectedSupplier=x['id'] as int))),
          if(selectedSupplier!=null) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>refresh(()=>selectedSupplier=null),child:Text('فروشنده: ${suppliers.firstWhere((x)=>x['id']==selectedSupplier)['name']} • حذف انتخاب'))),
          if(suppliers.isEmpty) const Text('برای ثبت حساب خرید، ابتدا فروشنده را در بخش حساب‌ها اضافه کنید.'),
        ],
        if(type=='فروش') ...[
          const SizedBox(height:10),TextField(controller:customerSearch,decoration:const InputDecoration(labelText:'جستجوی مشتری (اختیاری)',prefixIcon:Icon(Icons.search)),onChanged:(_)=>refresh((){})),
          if(customerSearch.text.isNotEmpty) ...filtered.take(5).map((x)=>ListTile(dense:true,selected:selectedCustomer==x['id'],leading:const Icon(Icons.person_outline),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}'),onTap:()=>refresh((){selectedCustomer=x['id'] as int;if(paid.text.trim().isEmpty)paid.text='0';}))),
          if(selectedCustomer!=null) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>refresh((){selectedCustomer=null;if(paid.text.trim()=='0')paid.clear();}),child:Text('مشتری: ${customers.firstWhere((x)=>x['id']==selectedCustomer)['name']} • حذف انتخاب'))),
          if(selectedCustomer!=null) FutureBuilder<double>(future:currentCustomerBalance(selectedCustomer!),builder:(ctx,bal){if(!bal.hasData)return const SizedBox.shrink();final value=bal.data!;return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(10)),child:Text('مانده فعلی: ${money.format(value.abs())} افغانی • ${value>0?'بدهکار':value<0?'طلبکار':'تسویه'}\nمبلغ پرداخت‌نشده این فروش به حساب مشتری اضافه می‌شود.',style:TextStyle(fontSize:11,color:value>0?Colors.red:value<0?Colors.green:Colors.blueGrey)));}),
          if(customers.isEmpty) const Text('هنوز مشتری ثبت نشده است؛ می‌توانید فروش را بدون انتخاب مشتری ثبت کنید.'),
        ],
        field(qty,'مقدار کالا',number:true),
        Align(alignment:Alignment.centerRight,child:Text('مقدارهای آماده',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))),
        Wrap(spacing:5,runSpacing:3,children:quantityPresets(products.firstWhere((e)=>e['id']==selected)['unit'].toString(),seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>refresh(()=>qty.text=(p['value'] as double).toStringAsFixed(3)))).toList()),
        field(paid,type=='فروش'?'مبلغ نقدی همان لحظه (۰ = تمام مبلغ نسیه؛ خالی = نقدی کامل)':'مبلغ نقدی پرداخت‌شده به فروشنده (خالی = تمام مبلغ)',number:true),
        field(note,'یادداشت')
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))]);
    }));
    if(ok==true&&selected!=null){
      final x=products.firstWhere((e)=>e['id']==selected);
      final amount=parseNum(qty.text)??0,unitPrice=parseNum(price.text)??0,total=amount*unitPrice;
      final paidAmount=paid.text.trim().isEmpty?total:(parseNum(paid.text)??0);
      if(amount<=0||unitPrice<0||paidAmount<0||paidAmount>total){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مقدار، قیمت یا مبلغ نقدی معتبر نیست.')));return;} if(type=='خرید'&&selectedSupplier==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای ثبت خرید، فروشنده را انتخاب کنید.')));return;} if(type=='فروش'&&paidAmount<total&&selectedCustomer==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای ثبت نسیه، ابتدا مشتری را جستجو و انتخاب کنید.')));return;}
      final currentStock=(x['stock'] as num).toDouble();
      if(type=='فروش'&&amount>currentStock){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی کالا کافی نیست.')));return;}
      await db.transaction((t)async{
        final stock=currentStock+(type=='خرید'?amount:-amount);
        await t.update('products',{'stock':stock,'updated':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[selected]);
        final entryId=await t.insert('entries',{'product_id':selected,'product_name':x['name'],'type':type,'qty':amount,'price':unitPrice,'total':total,'note':note.text,'created':DateTime.now().toIso8601String(),'customer_id':type=='فروش'?selectedCustomer:null,'supplier_id':type=='خرید'?selectedSupplier:null,'paid':paidAmount});
        if(paidAmount>0){final cashId=await t.insert('cash',{'type':type=='فروش'?'دریافت':'برداشت','amount':paidAmount,'note':'${type=='فروش'?'دریافت نقدی فروش':'پرداخت نقدی خرید'} • سند #$entryId','created':DateTime.now().toIso8601String()});await t.update('entries',{'cash_id':cashId},where:'id=?',whereArgs:[entryId]);}
      });
      widget.onChanged();setState((){});
    }
  }

  Future<void> editEntry(Map<String,Object?> x) async {
    final seerGrams=await configuredSeerGrams();
    final qty=TextEditingController(text:'${x['qty']}'),price=TextEditingController(text:'${x['price']}'),note=TextEditingController(text:'${x['note']??''}'),paid=TextEditingController(text:'${x['paid']??0}');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('ویرایش ${x['type']}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(qty,'مقدار '+(x['product_unit']?.toString()??''),number:true),Wrap(spacing:5,children:quantityPresets(x['product_unit']?.toString()??'عدد',seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>qty.text=(p['value'] as double).toStringAsFixed(3))).toList()),field(price,'قیمت هر واحد',number:true),field(paid,x['type']=='فروش'?'مبلغ نقدی پرداخت‌شده':'مبلغ نقدی پرداخت‌شده به فروشنده',number:true),field(note,'یادداشت')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));
    if(ok!=true)return;final q=parseNum(qty.text)??0,pv=parseNum(price.text)??0,paidValue=parseNum(paid.text)??0;if(q<=0||pv<0||paidValue<0||paidValue>q*pv)return;
    final db=await ShopDb.instance.database;await db.transaction((t)async{
      final oldQty=(x['qty'] as num).toDouble();final delta=q-oldQty;final sign=x['type']=='خرید'?1.0:-1.0;
      await t.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?',[delta*sign,x['product_id']]);
      await t.update('entries',{'qty':q,'price':pv,'total':q*pv,'paid':paidValue,'note':note.text},where:'id=?',whereArgs:[x['id']]);
      final cashId=x['cash_id'];
      if(cashId!=null){if(paidValue>0){await t.update('cash',{'amount':paidValue},where:'id=?',whereArgs:[cashId]);}else{await t.delete('cash',where:'id=?',whereArgs:[cashId]);await t.update('entries',{'cash_id':null},where:'id=?',whereArgs:[x['id']]);}}
      else if(paidValue>0){final newCashId=await t.insert('cash',{'type':x['type']=='فروش'?'دریافت':'برداشت','amount':paidValue,'note':'ثبت پرداخت ویرایش‌شده از سند #${x['id']}','created':x['created']});await t.update('entries',{'cash_id':newCashId},where:'id=?',whereArgs:[x['id']]);}
    });widget.onChanged();setState((){});
  }
  Future<void> deleteEntry(Map<String,Object?> x) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف سند'),content:const Text('با حذف این سند، موجودی کالا نیز به حالت قبل برمی‌گردد. ادامه می‌دهید؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(ok!=true)return;final db=await ShopDb.instance.database;await db.transaction((t)async{final q=(x['qty'] as num).toDouble();final sign=x['type']=='خرید'?-1.0:1.0;await t.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?',[q*sign,x['product_id']]);if(x['cash_id']!=null)await t.delete('cash',where:'id=?',whereArgs:[x['cash_id']]);await t.delete('entries',where:'id=?',whereArgs:[x['id']]);});widget.onChanged();setState((){});
  }
  @override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<String>(segments:const [ButtonSegment(value:'فروش',label:Text('ثبت فروش'),icon:Icon(Icons.trending_up)),ButtonSegment(value:'خرید',label:Text('ثبت خرید'),icon:Icon(Icons.shopping_cart))],selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first))),Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:entryRows(),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('هنوز خرید یا فروشی ثبت نشده است'));return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];final sale=x['type']=='فروش';return ListTile(leading:Icon(sale?Icons.arrow_upward:Icons.arrow_downward,color:sale?Colors.green:Colors.blue),title:Text('${x['product_name']} • ${x['type']}${sale&&x['customer_name']!=null?' • ${x['customer_name']}':(!sale&&x['supplier_name']!=null?' • ${x['supplier_name']}':'')}'),subtitle:Text('${faDigits(money.format(x['qty']))} ${x['product_unit']??''} × ${money.format(x['price'])} افغانی • نقدی: ${money.format(x['paid']??0)} • مانده: ${money.format((x['total'] as num)-(x['paid'] as num))} • ${(x['total'] as num)-(x['paid'] as num)<=0?'تسویه نقدی':(x['paid'] as num)>0?'پرداخت بخشی':'نسیه کامل'}'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')editEntry(x);else deleteEntry(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش سند')),PopupMenuItem(value:'delete',child:Text('حذف سند'))],child:Text('${money.format(x['total'])} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:sale?Colors.green:Colors.blue))));});})),Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:Text('ثبت $type'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(48))))]);
}
class CashPage extends StatefulWidget {final VoidCallback onChanged;const CashPage({super.key,required this.onChanged});@override State<CashPage> createState()=>_CashPageState();}
class _CashPageState extends State<CashPage> {
  Future<void> editCash(Map<String,Object?> x) async {final a=TextEditingController(text:'${x['amount']}'),n=TextEditingController(text:'${x['note']??''}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ویرایش تراکنش'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(a,'مبلغ',number:true),field(n,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&(parseNum(a.text)??0)>0){await (await ShopDb.instance.database).update('cash',{'amount':parseNum(a.text),'note':n.text},where:'id=?',whereArgs:[x['id']]);widget.onChanged();setState((){});}}
  Future<void> deleteCash(Map<String,Object?> x) async {final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف تراکنش'),content:const Text('این تراکنش حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await (await ShopDb.instance.database).delete('cash',where:'id=?',whereArgs:[x['id']]);widget.onChanged();setState((){});}}

  Future<void> add() async {String type='برداشت';final amount=TextEditingController(),note=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(title:const Text('ثبت تراکنش صندوق'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,items:const [DropdownMenuItem(value:'برداشت',child:Text('برداشت شخصی / هزینه')),DropdownMenuItem(value:'دریافت',child:Text('دریافت پول'))],onChanged:(v)=>refresh(()=>type=v!),decoration:const InputDecoration(labelText:'نوع تراکنش')),field(amount,'مبلغ افغانی',number:true),field(note,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))])));if(ok==true&&(parseNum(amount.text)??0)>0){await (await ShopDb.instance.database).insert('cash',{'type':type,'amount':parseNum(amount.text),'note':note.text,'created':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}}
  Future<Map<String,double>> summary() async {
    final db=await ShopDb.instance.database;
    final r=await db.rawQuery("SELECT COALESCE(SUM(CASE WHEN type='دریافت' THEN amount ELSE 0 END),0) AS incoming, COALESCE(SUM(CASE WHEN type='برداشت' THEN amount ELSE 0 END),0) AS outgoing FROM cash");
    final row=r.first;
    final incoming=((row['incoming'] as num?)??0).toDouble();
    final outgoing=((row['outgoing'] as num?)??0).toDouble();
    return {'incoming':incoming,'outgoing':outgoing,'balance':incoming-outgoing};
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('ثبت صندوق')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('cash',order:'id DESC'),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final rows=s.data!;
    return Column(children:[
      FutureBuilder<Map<String,double>>(future:summary(),builder:(ctx,b){
        if(!b.hasData)return const SizedBox(height:4);
        final v=b.data!;
        return Padding(padding:const EdgeInsets.fromLTRB(8,8,8,4),child:Row(children:[
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('دریافتی',style:TextStyle(fontSize:11)),Text('${money.format(v['incoming'])} AFN',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('برداشتی',style:TextStyle(fontSize:11)),Text('${money.format(v['outgoing'])} AFN',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('مانده صندوق',style:TextStyle(fontSize:11)),Text('${money.format(v['balance'])} AFN',style:const TextStyle(fontWeight:FontWeight.bold))]))))
        ]));
      }),
      Expanded(child:rows.isEmpty?const Center(child:Text('تراکنش صندوقی ثبت نشده است')):ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){
        final x=rows[i];final note='${x['note']??''}';
        final linked=note.startsWith('دریافت از مشتری')||note.startsWith('پرداخت به مشتری')||note.startsWith('پرداخت به فروشنده')||note.contains('سند #')||note.startsWith('ثبت خودکار از سند');
        return ListTile(leading:Icon(x['type']=='دریافت'?Icons.add_circle:Icons.remove_circle,color:x['type']=='دریافت'?Colors.green:Colors.red),title:Text('${x['type']}'),subtitle:Text(note),trailing:linked?Text('${money.format(x['amount'])} افغانی'):PopupMenuButton<String>(onSelected:(v){if(v=='edit')editCash(x);else deleteCash(x);},itemBuilder:(ctx)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))],child:Text('${money.format(x['amount'])} افغانی')));
      }))
    ]);
  }));

}

class CustomersPage extends StatefulWidget {const CustomersPage({super.key});@override State<CustomersPage> createState()=>_CustomersPageState();}
class _CustomersPageState extends State<CustomersPage>{
 String selectedFilter='همه';
 final searchController=TextEditingController();
 @override void dispose(){searchController.dispose();super.dispose();}
 Future<Map<String,double>> totals(List<Map<String,Object?>> customers) async {double debtor=0,creditor=0;for(final x in customers){final b=await balance(x['id'] as int);if(b>0)debtor+=b;else if(b<0)creditor+=b.abs();}return {'debtor':debtor,'creditor':creditor};}
 Future<double> balance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM customers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE customer_id=? AND type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='دریافت'),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='پرداخت'),0) AS b",[id,id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
 Future<void> form([Map<String,Object?>? x]) async {final n=TextEditingController(text:'${x?['name']??''}'),p=TextEditingController(text:'${x?['phone']??''}'),b=TextEditingController(text:'${x?['opening_balance']??x?['balance']??'0'}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(x==null?'مشتری جدید':'ویرایش مشتری'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(n,'نام مشتری'),field(p,'شماره تماس (اختیاری)'),field(b,'مانده اول دوره (مثبت=بدهکار مشتری)',number:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&n.text.trim().isNotEmpty){final db=await ShopDb.instance.database;final v={'name':n.text.trim(),'phone':p.text.trim(),'opening_balance':parseNum(b.text)??0.0};if(x==null){await db.insert('customers',v);}else{await db.update('customers',v,where:'id=?',whereArgs:[x['id']]);}setState((){});}}
 Future<void> account(Map<String,Object?> customer) async { if(!mounted)return; await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CustomerAccountPage(customer:customer,onChanged:()=>setState((){})))); }
 Future<void> receive(Map<String,Object?> customer) async {final a=TextEditingController(),n=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('دریافت از ${customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(a,'مبلغ دریافتی (افغانی)',number:true),field(n,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت دریافت'))]));final amount=parseNum(a.text)??0;if(ok==true&&amount>0){final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{final paymentId=await t.insert('customer_payments',{'customer_id':customer['id'],'amount':amount,'type':'دریافت','note':n.text,'created':created});final cashId=await t.insert('cash',{'type':'دریافت','amount':amount,'note':'دریافت از مشتری ${customer['name']} • ${n.text}','created':created});await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);});setState((){});}}
 Future<void> receiveAny(List<Map<String,Object?>> customers) async {
   if(customers.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا مشتری ثبت کنید.')));return;}
   int? selected=customers.first['id'] as int;final amount=TextEditingController(),note=TextEditingController();
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:const Text('دریافت پول از مشتری'),content:Column(mainAxisSize:MainAxisSize.min,children:[
     DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب مشتری'),items:customers.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']}'))).toList(),onChanged:(v)=>refresh(()=>selected=v)),
     field(amount,'مبلغ دریافتی (AFN)',number:true),field(note,'توضیحات')
   ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ثبت دریافت'))])));
   final value=parseNum(amount.text)??0;if(ok==true&&selected!=null&&value>0){final customer=customers.firstWhere((x)=>x['id']==selected);await receiveFor(customer,value,note.text);setState((){});}
 }
 Future<void> receiveFor(Map<String,Object?> customer,double amount,String note) async {
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{
     final paymentId=await t.insert('customer_payments',{'customer_id':customer['id'],'amount':amount,'type':'دریافت','note':note,'created':created});
     final cashId=await t.insert('cash',{'type':'دریافت','amount':amount,'note':'دریافت از مشتری ${customer['name']} • $note','created':created});
     await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);
   });
 }
 Future<void> remove(Map<String,Object?> x) async {final db=await ShopDb.instance.database;final used=await db.query('entries',where:'customer_id=?',whereArgs:[x['id']],limit:1);final paid=await db.query('customer_payments',where:'customer_id=?',whereArgs:[x['id']],limit:1);if(used.isNotEmpty||paid.isNotEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این مشتری سابقه حساب دارد و حذف نمی‌شود.')));return;}final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف مشتری'),content:Text('مشتری ${x['name']} حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await db.delete('customers',where:'id=?',whereArgs:[x['id']]);setState((){});}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>form(),icon:const Icon(Icons.person_add_alt),label:const Text('مشتری جدید')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('customers',order:'name COLLATE NOCASE'),builder:(c,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());final customers=s.data!;
   return StatefulBuilder(builder:(context,refresh){
     final visibleCustomers=customers.where((x)=>'${x['name']} ${x['phone']??''}'.toLowerCase().contains(searchController.text.toLowerCase())).toList();
     return Column(children:[
       Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:TextField(controller:searchController,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'جستجوی نام یا شماره مشتری',border:OutlineInputBorder()),onChanged:(_)=>refresh((){}))),
       FutureBuilder<Map<String,double>>(future:totals(customers),builder:(ctx,summary){if(!summary.hasData)return const SizedBox(height:4);final v=summary.data!;return Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:Row(children:[
         Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('جمع بدهی مشتریان',style:TextStyle(fontSize:11)),Text('${money.format(v['debtor'])} AFN',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold))])))),
         Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('جمع طلب مشتریان',style:TextStyle(fontSize:11)),Text('${money.format(v['creditor'])} AFN',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold))]))))
       ]));}),
       Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:Wrap(spacing:8,runSpacing:6,alignment:WrapAlignment.center,children:[
         FilledButton.tonalIcon(onPressed:()=>receiveAny(customers),icon:const Icon(Icons.payments_outlined),label:const Text('دریافت پول از مشتری')),
         for(final f in ['همه','بدهکار','طلبکار','تسویه']) ChoiceChip(label:Text(f),selected:selectedFilter==f,onSelected:(_){refresh(()=>selectedFilter=f);})
       ])),
       Expanded(child:customers.isEmpty?const Center(child:Text('هنوز مشتری ثبت نشده است')):visibleCustomers.isEmpty?const Center(child:Text('مشتری با این مشخصات پیدا نشد')):ListView.builder(padding:const EdgeInsets.only(bottom:90),itemCount:visibleCustomers.length,itemBuilder:(c,i){
         final x=visibleCustomers[i];return FutureBuilder<double>(future:balance(x['id'] as int),builder:(c,b){
           final bal=b.data??0;final status=bal>0.005?'بدهکار':bal< -0.005?'طلبکار':'تسویه';
           if(selectedFilter!='همه'&&selectedFilter!=status)return const SizedBox.shrink();
           final color=status=='بدهکار'?Colors.red:status=='طلبکار'?Colors.green:Colors.blueGrey;
           return Card(child:ListTile(onTap:()=>account(x),leading:CircleAvatar(child:Icon(Icons.person_outline,color:color)),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''} • $status'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')form(x);else if(v=='delete')remove(x);else receive(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'receive',child:Text('ثبت دریافت پول')),PopupMenuItem(value:'edit',child:Text('ویرایش مشتری')),PopupMenuItem(value:'delete',child:Text('حذف مشتری'))],child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${money.format(bal.abs())} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:color)),Text(status,style:TextStyle(fontSize:11,color:color,fontWeight:FontWeight.bold))]))));
         });
       }))
     ]);
   });
 }));
}

class CustomerAccountPage extends StatefulWidget {
 final Map<String,Object?> customer; final VoidCallback onChanged;
 const CustomerAccountPage({super.key,required this.customer,required this.onChanged});
 @override State<CustomerAccountPage> createState()=>_CustomerAccountPageState();
}
class _CustomerAccountPageState extends State<CustomerAccountPage> {
 Future<Map<String,Object?>> loadLedger() async {
  final db=await ShopDb.instance.database,id=widget.customer['id'];
  final cr=await db.query('customers',where:'id=?',whereArgs:[id],limit:1);
  final opening=cr.isEmpty?0.0:((cr.first['opening_balance'] as num?)??0).toDouble();
  final sales=await db.rawQuery("SELECT entries.*, COALESCE(products.unit,'') AS product_unit FROM entries LEFT JOIN products ON products.id=entries.product_id WHERE entries.customer_id=? AND entries.type='فروش' ORDER BY entries.created ASC, entries.id ASC",[id]);
  final payments=await db.query('customer_payments',where:'customer_id=?',whereArgs:[id],orderBy:'created ASC, id ASC');
  final events=<Map<String,Object?>>[];
  for(final x in sales){events.add({'kind':'sale','id':x['id'],'created':x['created'],'title':x['product_name'],'qty':x['qty'],'unit':x['product_unit'],'price':x['price'],'total':x['total'],'paid':x['paid'],'note':x['note']});}
  for(final x in payments){events.add({'kind':'payment','direction':x['type']??'دریافت','id':x['id'],'created':x['created'],'title':x['type']=='پرداخت'?'پرداخت بدهی به مشتری':x['type']=='برگشت'?'برگشت وجه به مشتری':'دریافت از مشتری','amount':x['amount'],'note':x['note']});}
  events.sort((a,b){final d=DateTime.parse(a['created'].toString()).compareTo(DateTime.parse(b['created'].toString()));if(d!=0)return d;return (a['id'] as int).compareTo(b['id'] as int);});
  double salesTotal=0,paidAtSale=0,creditSales=0,received=0,paidToCustomer=0,running=opening;
  for(final e in events){if(e['kind']=='sale'){final total=(e['total'] as num).toDouble(),paid=(e['paid'] as num).toDouble(),debt=total-paid;salesTotal+=total;paidAtSale+=paid;creditSales+=debt;running+=debt;e['delta']=debt;e['running']=running;}else{final amount=(e['amount'] as num).toDouble();if(e['direction']=='پرداخت'){paidToCustomer+=amount;running+=amount;e['delta']=amount;}else if(e['direction']=='برگشت'){paidToCustomer+=amount;running-=amount;e['delta']=-amount;}else{received+=amount;running-=amount;e['delta']=-amount;}e['running']=running;}}
  return {'opening':opening,'sales':salesTotal,'paid':paidAtSale,'creditSales':creditSales,'received':received,'paidToCustomer':paidToCustomer,'balance':running,'events':events};
 }
 String status(double b)=>b>0.005?'مشتری بدهکار است':b< -0.005?'مغازه به مشتری بدهکار است':'حساب تسویه است';
 Color statusColor(double b)=>b>0.005?Colors.red:b< -0.005?Colors.green:Colors.blueGrey;
 Future<void> receive() async {
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('دریافت پول از ${widget.customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(amount,'مبلغ دریافتی (AFN)',number:true),field(note,'توضیحات / شماره رسید')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت دریافت'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{
   final paymentId=await t.insert('customer_payments',{'customer_id':widget.customer['id'],'amount':value,'type':'دریافت','note':note.text.trim(),'created':created});
   final cashId=await t.insert('cash',{'type':'دریافت','amount':value,'note':'دریافت از مشتری ${widget.customer['name']} • ${note.text.trim()}','created':created});
   await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);
  });widget.onChanged();if(mounted)setState((){});}
 }

 Future<void> payCustomer() async {
  final current=await loadLedger();final currentBalance=(current['balance'] as num).toDouble();final direction=currentBalance< -0.005?'پرداخت':'برگشت';
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('پرداخت پول به ${widget.customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(amount,'مبلغ پرداختی (AFN)',number:true),field(note,'توضیحات / دلیل پرداخت')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت پرداخت'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{
   final paymentId=await t.insert('customer_payments',{'customer_id':widget.customer['id'],'amount':value,'type':direction,'note':note.text.trim(),'created':created});
   final cashId=await t.insert('cash',{'type':'برداشت','amount':value,'note':'پرداخت به مشتری ${widget.customer['name']} • ${note.text.trim()}','created':created});
   await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);
  });widget.onChanged();if(mounted)setState((){});}
 }

 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text('حساب مشتری: ${widget.customer['name']}'),actions:[IconButton(tooltip:'پرداخت به مشتری',onPressed:payCustomer,icon:const Icon(Icons.outbound)),IconButton(tooltip:'ثبت دریافت',onPressed:receive,icon:const Icon(Icons.add_card))]),
  floatingActionButton:FloatingActionButton.extended(onPressed:receive,icon:const Icon(Icons.payments_outlined),label:const Text('ثبت دریافت پول')),
  body:FutureBuilder<Map<String,Object?>>(future:loadLedger(),builder:(context,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final v=s.data!,balance=(v['balance'] as num).toDouble(),events=v['events'] as List<Map<String,Object?>>,color=statusColor(balance);
   Widget metric(String label,Object? value,{Color? tint})=>Expanded(child:Container(margin:const EdgeInsets.all(4),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:5),Text('${money.format(value)} AFN',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:tint),maxLines:1,overflow:TextOverflow.ellipsis)])));
   return Column(children:[
    Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(12,10,12,5),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:color.withOpacity(.09),borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(.35))),child:Column(children:[const Text('مانده نهایی حساب',style:TextStyle(fontSize:12,color:Colors.blueGrey)),const SizedBox(height:4),Text('${money.format(balance.abs())} افغانی',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:color)),Text(status(balance),style:TextStyle(color:color,fontWeight:FontWeight.bold)),if(widget.customer['phone']!=null&&widget.customer['phone'].toString().isNotEmpty)Text(widget.customer['phone'].toString(),style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Row(children:[metric('جمع خرید مشتری',v['sales']),metric('پرداخت نقدی خرید',v['paid'])]),
    Row(children:[metric('بدهی ایجادشده',v['creditSales'],tint:Colors.red),metric('دریافت از مشتری',v['received'],tint:Colors.green)]),
    Row(children:[metric('پرداخت به مشتری',v['paidToCustomer'],tint:Colors.orange),metric('مانده اول دوره',v['opening'])]),
    Padding(padding:const EdgeInsets.fromLTRB(14,8,14,4),child:Row(children:[const Expanded(child:Text('گردش حساب مشتری',style:TextStyle(fontWeight:FontWeight.bold,fontSize:15))),Text('${events.length} سند',style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Expanded(child:events.isEmpty?ListView(children:[if((v['opening'] as num)!=0)Card(child:ListTile(leading:const Icon(Icons.flag_outlined),title:const Text('مانده اول دوره'),subtitle:const Text('مانده انتقالی حساب'),trailing:Text('${money.format((v['opening'] as num).abs())} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:statusColor((v['opening'] as num).toDouble()))))),const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('هنوز خرید یا دریافتی دیگری ثبت نشده است')))]):ListView.builder(padding:const EdgeInsets.fromLTRB(10,2,10,90),itemCount:events.length+(v['opening']==0?0:1),itemBuilder:(context,index){
     if(index==events.length){final opening=(v['opening'] as num).toDouble();return Card(child:ListTile(dense:true,leading:const Icon(Icons.flag_outlined),title:const Text('مانده اول دوره'),subtitle:const Text('مانده انتقالی حساب'),trailing:Text('${money.format(opening.abs())} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:statusColor(opening)))));}
     final e=events[events.length-1-index],sale=e['kind']=='sale',incoming=e['direction']=='دریافت',delta=(e['delta'] as num).toDouble(),running=(e['running'] as num).toDouble(),created=DateTime.parse(e['created'].toString());
     final date=DateFormat('yyyy/MM/dd  HH:mm').format(created);
     return Card(margin:const EdgeInsets.symmetric(vertical:3),child:ListTile(dense:true,leading:CircleAvatar(radius:17,backgroundColor:(sale?Colors.red:(incoming?Colors.green:Colors.orange)).withOpacity(.10),child:Icon(sale?Icons.shopping_bag_outlined:Icons.payments_outlined,size:18,color:sale?Colors.red:(incoming?Colors.green:Colors.orange))),title:Text(sale?'خرید مشتری: ${e['title']}':e['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),subtitle:Text(sale?'${money.format(e['qty'])} ${e['unit']} × ${money.format(e['price'])} • کل: ${money.format(e['total'])} • نقدی: ${money.format(e['paid'])} • به حساب: ${money.format(delta)}\n$date':'${e['note']??''} • $date\nمانده پس از ثبت: ${money.format(running.abs())} ${running>0?'بدهکار':running<0?'طلبکار':'تسویه'}',style:const TextStyle(fontSize:11)),isThreeLine:true,trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${delta>0?'+':delta<0?'-':''}${money.format(delta.abs())}',style:TextStyle(fontWeight:FontWeight.bold,color:sale?Colors.red:(incoming?Colors.green:Colors.orange))),Text('مانده ${money.format(running.abs())}',style:TextStyle(fontSize:10,color:statusColor(running)))])));
    })),
   ]);
  })
 );
}

class SuppliersPage extends StatefulWidget {const SuppliersPage({super.key});@override State<SuppliersPage> createState()=>_SuppliersPageState();}
class _SuppliersPageState extends State<SuppliersPage>{
 Future<double> balance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM suppliers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE supplier_id=? AND type='خرید'),0)-COALESCE((SELECT SUM(amount) FROM supplier_payments WHERE supplier_id=?),0) AS b",[id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
 Future<void> form([Map<String,Object?>? x]) async {final n=TextEditingController(text:'${x?['name']??''}'),p=TextEditingController(text:'${x?['phone']??''}'),a=TextEditingController(text:'${x?['address']??''}'),b=TextEditingController(text:'${x?['opening_balance']??'0'}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(x==null?'فروشنده / مغازه جدید':'ویرایش فروشنده'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(n,'نام مغازه یا فروشنده'),field(p,'شماره تماس (اختیاری)'),field(a,'آدرس یا محل خرید (اختیاری)'),field(b,'بدهی قبلی به این فروشنده',number:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&n.text.trim().isNotEmpty){final db=await ShopDb.instance.database;final v={'name':n.text.trim(),'phone':p.text.trim(),'address':a.text.trim(),'opening_balance':parseNum(b.text)??0.0};if(x==null){await db.insert('suppliers',v);}else{await db.update('suppliers',v,where:'id=?',whereArgs:[x['id']]);}setState((){});}}
 Future<void> account(Map<String,Object?> supplier) async {final id=supplier['id'] as int;final db=await ShopDb.instance.database;final purchases=await db.query('entries',where:"supplier_id=? AND type='خرید'",whereArgs:[id],orderBy:'id DESC');final payments=await db.query('supplier_payments',where:'supplier_id=?',whereArgs:[id],orderBy:'id DESC');final bal=await balance(id);if(!mounted)return;await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('حساب ${supplier['name']}'),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('بدهی ما به فروشنده: ${money.format(bal)} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:bal>0?Colors.red:Colors.green)),const Divider(),Flexible(child:ListView(shrinkWrap:true,children:[...purchases.map((x)=>ListTile(dense:true,leading:const Icon(Icons.shopping_bag_outlined),title:Text('${x['product_name']} • خرید'),subtitle:Text('مبلغ: ${money.format(x['total'])} • پرداخت نقدی: ${money.format(x['paid'])} • مانده: ${money.format((x['total'] as num)-(x['paid'] as num))}'),trailing:Text(DateFormat('MM/dd').format(DateTime.parse('${x['created']}'))))),...payments.map((x)=>ListTile(dense:true,leading:const Icon(Icons.payments_outlined,color:Colors.green),title:Text('پرداخت به فروشنده: ${money.format(x['amount'])} افغانی'),subtitle:Text('${x['note']??''}')))]))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن')),FilledButton.icon(onPressed:(){Navigator.pop(c);pay(supplier);},icon:const Icon(Icons.add),label:const Text('ثبت پرداخت به فروشنده'))]));}
 Future<void> pay(Map<String,Object?> supplier) async {final a=TextEditingController(),n=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('پرداخت به ${supplier['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(a,'مبلغ پرداختی (افغانی)',number:true),field(n,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت پرداخت'))]));final amount=parseNum(a.text)??0;if(ok==true&&amount>0){final db=await ShopDb.instance.database;await db.transaction((t)async{await t.insert('supplier_payments',{'supplier_id':supplier['id'],'amount':amount,'note':n.text,'created':DateTime.now().toIso8601String()});await t.insert('cash',{'type':'برداشت','amount':amount,'note':'پرداخت به فروشنده ${supplier['name']} • ${n.text}','created':DateTime.now().toIso8601String()});});setState((){});}}
 Future<void> remove(Map<String,Object?> x) async {final db=await ShopDb.instance.database;final used=await db.query('entries',where:'supplier_id=?',whereArgs:[x['id']],limit:1);final paid=await db.query('supplier_payments',where:'supplier_id=?',whereArgs:[x['id']],limit:1);if(used.isNotEmpty||paid.isNotEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این فروشنده سابقه حساب دارد و حذف نمی‌شود.')));return;}final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف فروشنده'),content:Text('فروشنده ${x['name']} حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await db.delete('suppliers',where:'id=?',whereArgs:[x['id']]);setState((){});}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>form(),icon:const Icon(Icons.store_mall_directory_outlined),label:const Text('فروشنده جدید')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('suppliers',order:'name COLLATE NOCASE'),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('هنوز فروشنده‌ای ثبت نشده است'));return ListView.builder(padding:const EdgeInsets.only(bottom:90),itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return FutureBuilder<double>(future:balance(x['id'] as int),builder:(c,b){final bal=b.data??0;return Card(child:ListTile(onTap:()=>account(x),leading:const CircleAvatar(child:Icon(Icons.storefront_outlined)),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''} • لمس برای مشاهده خریدها و پرداخت‌ها'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')form(x);else if(v=='delete')remove(x);else pay(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'pay',child:Text('ثبت پرداخت به فروشنده')),PopupMenuItem(value:'edit',child:Text('ویرایش فروشنده')),PopupMenuItem(value:'delete',child:Text('حذف فروشنده'))],child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${money.format(bal)} AFN',style:TextStyle(fontWeight:FontWeight.bold,color:bal>0?Colors.red:Colors.green)),Text(bal>0?'بدهی ما':'تسویه / طلب ما',style:const TextStyle(fontSize:10))]))));});});}));
}
class AccountsPage extends StatefulWidget {const AccountsPage({super.key});@override State<AccountsPage> createState()=>_AccountsPageState();}
class _AccountsPageState extends State<AccountsPage>{bool suppliers=false;@override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('مشتریان'),icon:Icon(Icons.people_outline)),ButtonSegment(value:true,label:Text('فروشندگان'),icon:Icon(Icons.storefront_outlined))],selected:{suppliers},onSelectionChanged:(v)=>setState(()=>suppliers=v.first))),Expanded(child:suppliers?const SuppliersPage():const CustomersPage())]);}

class SettingsPage extends StatefulWidget {const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage> {
  final seer=TextEditingController();
  @override void initState(){super.initState();ShopDb.instance.database.then((db)=>db.query('settings',where:'key=?',whereArgs:['seer_grams']).then((r){if(r.isNotEmpty&&mounted)seer.text='${r.first['value']}';}));}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('تنظیمات مغازه',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('واحدها',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),TextField(controller:seer,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'هر سیر چند گرم است؟',suffixText:'گرم')),const SizedBox(height:8),FilledButton(onPressed:()async{final grams=parseNum(seer.text)??0;if(grams<=0){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مقدار هر سیر باید بیشتر از صفر باشد.')));return;}await (await ShopDb.instance.database).update('settings',{'value':grams.toString()},where:'key=?',whereArgs:['seer_grams']);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تنظیم ذخیره شد')));},child:const Text('ذخیره تنظیمات'))]))),const Card(child:ListTile(leading:Icon(Icons.wifi_off),title:Text('حالت آفلاین'),subtitle:Text('ثبت کالا، خرید، فروش و صندوق بدون اینترنت ذخیره می‌شود.'))),const Card(child:ListTile(leading:Icon(Icons.currency_exchange),title:Text('واحد پول'),subtitle:Text('افغانی (AFN)'))),const Card(child:ListTile(leading:Icon(Icons.sync),title:Text('همگام‌سازی گوشی و کامپیوتر'),subtitle:Text('هنوز پیاده‌سازی نشده؛ داده‌ها فعلاً فقط روی همین دستگاه هستند.'))),const Card(child:ListTile(leading:Icon(Icons.backup_outlined),title:Text('پشتیبان‌گیری و بازیابی'),subtitle:Text('هنوز پیاده‌سازی نشده؛ قبل از استفاده روزمره باید اضافه شود.')))]);
}
