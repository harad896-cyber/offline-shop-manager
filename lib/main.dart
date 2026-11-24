import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android keeps the native sqflite driver. Windows uses SQLite FFI and a
  // stable per-user application-data directory (never the current folder).
  if (!kIsWeb && Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final support = await getApplicationSupportDirectory();
    await databaseFactory.setDatabasesPath(p.join(support.path, 'databases'));
  }
  await ShopDb.instance.database;
  runApp(const ShopApp());
}
String afghanDate(DateTime date,{bool withTime=true}) {
  final gy=date.year, gm=date.month, gd=date.day;
  const gdm=<int>[0,31,59,90,120,151,181,212,243,273,304,334];
  var gy2=gy;
  if(gm>2) gy2++;
  var days=355666+365*gy+(gy2+3)~/4-(gy2+99)~/100+(gy2+399)~/400+gd+gdm[gm-1];
  var jy=-1595+33*(days~/12053);
  days%=12053;
  jy+=4*(days~/1461);
  days%=1461;
  if(days>365){jy+=(days-1)~/365;days=(days-1)%365;}
  final jm=days<186?1+days~/31:7+(days-186)~/30;
  final jd=1+(days<186?days%31:(days-186)%30);
  const months=['حمل','ثور','جوزا','سرطان','اسد','سنبله','میزان','عقرب','قوس','جدی','دلو','حوت'];
  final dateText='${jd.toString().padLeft(2,'0')} ${months[jm-1]} ${jy}';
  return withTime?'$dateText  ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}':dateText;
}
double? parseNum(String? value) { if(value==null)return null; final normalized=value.trim().replaceAll('٬','').replaceAll(',','').replaceAll('٫','.').replaceAll('۰','0').replaceAll('۱','1').replaceAll('۲','2').replaceAll('۳','3').replaceAll('۴','4').replaceAll('۵','5').replaceAll('۶','6').replaceAll('۷','7').replaceAll('۸','8').replaceAll('۹','9').replaceAll('٠','0').replaceAll('١','1').replaceAll('٢','2').replaceAll('٣','3').replaceAll('٤','4').replaceAll('٥','5').replaceAll('٦','6').replaceAll('٧','7').replaceAll('٨','8').replaceAll('٩','9'); return double.tryParse(normalized); }
class PersianMoneyFormat { String format(Object? value) => NumberFormat('#,##0.##','en_US').format(value is num ? value : num.tryParse('$value') ?? 0); }
final money = PersianMoneyFormat();
double cartonPiecePrice(double cartonPrice, int piecesPerCarton) => piecesPerCarton > 0 ? cartonPrice / piecesPerCarton : 0;

class ShopDb {
  ShopDb._(); static final instance = ShopDb._(); Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(p.join(base, 'offline_shop.db'), version: 19, onCreate: (db, v) async {
      await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,unit TEXT NOT NULL,stock REAL NOT NULL DEFAULT 0,buy REAL NOT NULL DEFAULT 0,sell REAL NOT NULL DEFAULT 0,pieces_per_carton INTEGER NOT NULL DEFAULT 1,updated TEXT NOT NULL)');
      await db.execute("CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER,product_name TEXT NOT NULL,type TEXT NOT NULL,qty REAL NOT NULL,price REAL NOT NULL,total REAL NOT NULL,note TEXT,created TEXT NOT NULL,customer_id INTEGER,paid REAL NOT NULL DEFAULT 0,supplier_id INTEGER,cash_id INTEGER,fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه',cost_price REAL NOT NULL DEFAULT 0,display_qty REAL,display_unit TEXT)");
      await db.execute('CREATE TABLE cash(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,balance REAL NOT NULL DEFAULT 0,opening_balance REAL NOT NULL DEFAULT 0)');
      await db.execute("CREATE TABLE customer_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,customer_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL,cash_id INTEGER,type TEXT NOT NULL DEFAULT 'دریافت',fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه')");
      await db.execute('CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT,address TEXT,opening_balance REAL NOT NULL DEFAULT 0)');
      await db.execute("CREATE TABLE supplier_payments(id INTEGER PRIMARY KEY AUTOINCREMENT,supplier_id INTEGER NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL,cash_id INTEGER,type TEXT NOT NULL DEFAULT 'پرداخت',fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه')");
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
      await db.execute('CREATE TABLE price_history(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,buy REAL NOT NULL,sell REAL NOT NULL,changed TEXT NOT NULL)');
      await db.execute('CREATE TABLE account_settlements(id INTEGER PRIMARY KEY AUTOINCREMENT,account_type TEXT NOT NULL,account_id INTEGER NOT NULL,balance REAL NOT NULL,settled_at TEXT NOT NULL,note TEXT)');
      await db.execute('CREATE TABLE account_adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,account_type TEXT NOT NULL,account_id INTEGER NOT NULL,direction TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE cash_closings(id INTEGER PRIMARY KEY AUTOINCREMENT,closing_date TEXT NOT NULL,opening_cash REAL NOT NULL,received REAL NOT NULL,withdrawn REAL NOT NULL,expected_cash REAL NOT NULL,counted_cash REAL NOT NULL,difference REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE stock_adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,product_name TEXT NOT NULL,quantity REAL NOT NULL,unit TEXT NOT NULL,reason TEXT NOT NULL,cost_value REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
      await db.execute('CREATE TABLE audit_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,table_name TEXT NOT NULL,record_id INTEGER,action TEXT NOT NULL,summary TEXT,created TEXT NOT NULL)');
      await db.insert('settings', {'key':'seer_grams','value':'7000'});
      await db.insert('settings', {'key':'cash_opening_balance','value':'0'});
      await installAuditTriggers(db);
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
      if (oldVersion < 9) { await db.execute('ALTER TABLE supplier_payments ADD COLUMN cash_id INTEGER'); }
      if (oldVersion < 10) { await db.execute('ALTER TABLE products ADD COLUMN pieces_per_carton INTEGER NOT NULL DEFAULT 1'); }
      if (oldVersion < 11) { await db.execute('CREATE TABLE account_settlements(id INTEGER PRIMARY KEY AUTOINCREMENT,account_type TEXT NOT NULL,account_id INTEGER NOT NULL,balance REAL NOT NULL,settled_at TEXT NOT NULL,note TEXT)'); }
      if (oldVersion < 12) { await db.execute('CREATE TABLE account_adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,account_type TEXT NOT NULL,account_id INTEGER NOT NULL,direction TEXT NOT NULL,amount REAL NOT NULL,note TEXT,created TEXT NOT NULL)'); }
      if (oldVersion < 13) { await db.execute("ALTER TABLE supplier_payments ADD COLUMN type TEXT NOT NULL DEFAULT 'پرداخت'"); }
      if (oldVersion < 14) { await db.execute("UPDATE settings SET value='7000' WHERE key='seer_grams' AND value='1000'"); }
      if (oldVersion < 15) { await db.execute("ALTER TABLE customer_payments ADD COLUMN fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه'"); await db.execute("ALTER TABLE supplier_payments ADD COLUMN fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه'"); }
      if (oldVersion < 16) { await db.execute("ALTER TABLE entries ADD COLUMN fund_source TEXT NOT NULL DEFAULT 'صندوق مغازه'"); }
      if (oldVersion < 17) {
        await db.execute('ALTER TABLE entries ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
        await db.execute("UPDATE entries SET cost_price=COALESCE((SELECT ph.buy FROM price_history ph WHERE ph.product_id=entries.product_id AND ph.changed<=entries.created ORDER BY ph.changed DESC,ph.id DESC LIMIT 1),(SELECT p.buy FROM products p WHERE p.id=entries.product_id),0) WHERE type='فروش'");
        await db.execute('CREATE TABLE cash_closings(id INTEGER PRIMARY KEY AUTOINCREMENT,closing_date TEXT NOT NULL,opening_cash REAL NOT NULL,received REAL NOT NULL,withdrawn REAL NOT NULL,expected_cash REAL NOT NULL,counted_cash REAL NOT NULL,difference REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
        await db.execute('CREATE TABLE stock_adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,product_name TEXT NOT NULL,quantity REAL NOT NULL,unit TEXT NOT NULL,reason TEXT NOT NULL,cost_value REAL NOT NULL,note TEXT,created TEXT NOT NULL)');
        await db.execute('CREATE TABLE audit_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,table_name TEXT NOT NULL,record_id INTEGER,action TEXT NOT NULL,summary TEXT,created TEXT NOT NULL)');
      }
      if (oldVersion < 18) { await db.insert('settings', {'key':'cash_opening_balance','value':'0'}, conflictAlgorithm: ConflictAlgorithm.ignore); }
      if (oldVersion < 19) { await db.execute('ALTER TABLE entries ADD COLUMN display_qty REAL'); await db.execute('ALTER TABLE entries ADD COLUMN display_unit TEXT'); await db.execute("UPDATE entries SET display_qty=qty, display_unit=COALESCE((SELECT unit FROM products WHERE products.id=entries.product_id),'عدد') WHERE display_qty IS NULL OR display_unit IS NULL"); }
      await installAuditTriggers(db);
    });
    return _db!;
  }

  Future<void> installAuditTriggers(DatabaseExecutor db) async {
    const tables = <String,Map<String,String>>{
      'entries': {'insert':"'نوع: '||NEW.type||' • کالا: '||NEW.product_name||' • مبلغ: '||NEW.total",'update':"'سند ویرایش شد • '||NEW.product_name||' • مبلغ: '||NEW.total",'delete':"'سند حذف شد • '||OLD.product_name||' • مبلغ: '||OLD.total"},
      'cash': {'insert':"'نوع: '||NEW.type||' • مبلغ: '||NEW.amount",'update':"'مبلغ صندوق: '||OLD.amount||' ← '||NEW.amount",'delete':"'تراکنش صندوق حذف شد • مبلغ: '||OLD.amount"},
      'products': {'insert':"'کالای جدید: '||NEW.name||' • موجودی: '||NEW.stock",'update':"'کالا: '||NEW.name||' • موجودی: '||OLD.stock||' ← '||NEW.stock",'delete':"'کالا حذف شد: '||OLD.name"},
      'customer_payments': {'insert':"'مشتری • مبلغ: '||NEW.amount",'update':"'پرداخت مشتری ویرایش شد • '||OLD.amount||' ← '||NEW.amount",'delete':"'پرداخت مشتری حذف شد • '||OLD.amount"},
      'supplier_payments': {'insert':"'فروشنده • مبلغ: '||NEW.amount",'update':"'پرداخت فروشنده ویرایش شد • '||OLD.amount||' ← '||NEW.amount",'delete':"'پرداخت فروشنده حذف شد • '||OLD.amount"},
      'account_adjustments': {'insert':"'اصلاح حساب: '||NEW.account_type||' • مبلغ: '||NEW.amount",'update':"'اصلاح حساب ویرایش شد • '||OLD.amount||' ← '||NEW.amount",'delete':"'اصلاح حساب حذف شد • مبلغ: '||OLD.amount"},
      'account_settlements': {'insert':"'تسویه حساب: '||NEW.account_type||' • مانده: '||NEW.balance",'update':"'تسویه ویرایش شد • '||OLD.balance||' ← '||NEW.balance",'delete':"'تسویه حذف شد • مانده: '||OLD.balance"},
      'cash_closings': {'insert':"'بستن صندوق • تفاوت: '||NEW.difference",'update':"'بستن صندوق ویرایش شد • '||OLD.difference||' ← '||NEW.difference",'delete':"'بستن صندوق حذف شد • تفاوت: '||OLD.difference"},
      'stock_adjustments': {'insert':"'اصلاح موجودی: '||NEW.product_name||' • مقدار: '||NEW.quantity",'update':"'اصلاح موجودی ویرایش شد • '||OLD.quantity||' ← '||NEW.quantity",'delete':"'اصلاح موجودی حذف شد • '||OLD.product_name"},
      'customers': {'insert':"'مشتری جدید: '||NEW.name",'update':"'مشتری ویرایش شد: '||NEW.name",'delete':"'مشتری حذف شد: '||OLD.name"},
      'suppliers': {'insert':"'فروشنده جدید: '||NEW.name",'update':"'فروشنده ویرایش شد: '||NEW.name",'delete':"'فروشنده حذف شد: '||OLD.name"},
    };
    for(final entry in tables.entries){
      final table=entry.key;
      for(final action in ['insert','update','delete']){
        final isDelete=action=='delete';
        final row=isDelete?'OLD':'NEW';
        final summary=entry.value[action]!;
        await db.execute("CREATE TRIGGER IF NOT EXISTS audit_${table}_${action} AFTER ${action.toUpperCase()} ON $table BEGIN INSERT INTO audit_logs(table_name,record_id,action,summary,created) VALUES('$table',$row.id,'${action=='insert'?'ثبت':action=='update'?'ویرایش':'حذف'}',$summary,datetime('now')); END");
      }
    }
  }

  static const backupTables = <String>['products','entries','cash','customers','customer_payments','suppliers','supplier_payments','settings','price_history','account_settlements','account_adjustments','cash_closings','stock_adjustments','audit_logs'];
  Future<Map<String,Object?>> createBackup() async {
    final db=await database; final data=<String,dynamic>{};
    for(final table in backupTables){data[table]=await db.query(table);}
    return {'format':'offline-shop-manager-backup','version':1,'createdAt':DateTime.now().toIso8601String(),'tables':data};
  }
  Future<void> restoreBackup(Map<String,dynamic> backup) async {
    if(backup['format']!='offline-shop-manager-backup'||backup['version']!=1||backup['tables'] is! Map) throw const FormatException('فایل پشتیبان معتبر نیست یا نسخه آن پشتیبانی نمی‌شود.');
    final tables=Map<String,dynamic>.from(backup['tables'] as Map);
    for(final table in backupTables){if(tables[table] is! List){if(['account_adjustments','cash_closings','stock_adjustments','audit_logs'].contains(table)){tables[table]=<dynamic>[];}else{throw const FormatException('اطلاعات فایل پشتیبان کامل نیست.');}}}
    final db=await database;
    await db.transaction((txn) async {
      for(final table in backupTables.reversed){await txn.delete(table);}
      for(final table in backupTables){for(final raw in (tables[table] as List)){if(raw is! Map) throw const FormatException('ساختار اطلاعات پشتیبان خراب است.');await txn.insert(table,Map<String,Object?>.from(raw),conflictAlgorithm:ConflictAlgorithm.replace);}}
      final seer=await txn.query('settings',where:'key=?',whereArgs:['seer_grams'],limit:1);
      if(seer.isEmpty) await txn.insert('settings',{'key':'seer_grams','value':'1000'});
    });
  }
  Future<List<Map<String,Object?>>> rows(String table,{String? order}) async => (await database).query(table,orderBy:order);
}
class ShopApp extends StatelessWidget {
  const ShopApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'مدیریت دوکان',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff087f5b)),scaffoldBackgroundColor:const Color(0xfff5f7f6)),home:const HomePage());
}
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0,revision=0,financeSection=0; String entryType='فروش'; DateTime? _lastBackPressed; void reload()=>setState(()=>revision++);
  Future<bool> _confirmExit() async {
    final now=DateTime.now();
    if(_lastBackPressed==null || now.difference(_lastBackPressed!)>const Duration(seconds:2)){
      _lastBackPressed=now;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای بستن برنامه، یک‌بار دیگر دکمه برگشت را بزنید.'),duration:Duration(seconds:2)));
      return false;
    }
    return true;
  }
  @override Widget build(BuildContext context) {
    final pages=[Dashboard(key:ValueKey('d$revision'),onOpenTab:(v)=>setState(()=>tab=v),onOpenFinance:(v)=>setState((){financeSection=v;tab=3;}),onOpenEntries:(v)=>setState((){entryType=v;tab=2;})),ProductsPage(key:ValueKey('p$revision'),onChanged:reload),EntriesPage(key:ValueKey('e$revision'),onChanged:reload,initialType:entryType),FinancePage(key:ValueKey('f$revision'),onChanged:reload,initialSection:financeSection),SettingsPage(key:ValueKey('s$revision'))];
    const destinations=<NavigationDestination>[NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'خانه'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'کالاها'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'خرید و فروش'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'حسابداری'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'تنظیمات')];
    return WillPopScope(onWillPop:_confirmExit,child:Directionality(textDirection:ui.TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('مدیریت دوکان',style:TextStyle(fontWeight:FontWeight.bold)),actions:[Padding(padding:const EdgeInsetsDirectional.only(end:16),child:Center(child:Text('افغانی',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))))]),body:LayoutBuilder(builder:(context,constraints){final desktop=constraints.maxWidth>=850;if(desktop){return Row(children:[NavigationRail(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),labelType:NavigationRailLabelType.all,backgroundColor:Theme.of(context).colorScheme.surface,destinations:const [NavigationRailDestination(icon:Icon(Icons.dashboard_outlined),label:Text('خانه')),NavigationRailDestination(icon:Icon(Icons.inventory_2_outlined),label:Text('کالاها')),NavigationRailDestination(icon:Icon(Icons.receipt_long_outlined),label:Text('خرید و فروش')),NavigationRailDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:Text('حسابداری')),NavigationRailDestination(icon:Icon(Icons.settings_outlined),label:Text('تنظیمات'))]),const VerticalDivider(width:1),Expanded(child:IndexedStack(index:tab,children:pages))]);}return IndexedStack(index:tab,children:pages);}),bottomNavigationBar:LayoutBuilder(builder:(context,constraints)=>constraints.maxWidth>=850?const SizedBox.shrink():NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:destinations)))));
  }
}
class Dashboard extends StatefulWidget {
 final ValueChanged<int> onOpenTab; final ValueChanged<int> onOpenFinance; final ValueChanged<String> onOpenEntries;
 const Dashboard({super.key,required this.onOpenTab,required this.onOpenFinance,required this.onOpenEntries});
 @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
 String period='امروز';
 Future<Map<String,double>> stats() async {
  final db=await ShopDb.instance.database,now=DateTime.now(),today=DateTime(now.year,now.month,now.day);
  final start=period=='هفته'?today.subtract(const Duration(days:6)):period=='ماه'?DateTime(now.year,now.month,1):today,end=today.add(const Duration(days:1));
  Future<double> sum(String table,String column,String where,List<Object?> args) async {final r=await db.rawQuery('SELECT COALESCE(SUM($column),0) AS total FROM $table WHERE $where',args);return ((r.first['total'] as num?)??0).toDouble();}
  final from=start.toIso8601String(),to=end.toIso8601String();
  final sales=await sum('entries','total',"type='فروش' AND created>=? AND created<?",[from,to]),purchases=await sum('entries','total',"type='خرید' AND created>=? AND created<?",[from,to]);
  final received=await sum('cash','amount',"type='دریافت' AND created>=? AND created<?",[from,to]),paid=await sum('cash','amount',"type='برداشت' AND created>=? AND created<?",[from,to]);
  final allReceived=await sum('cash','amount',"type='دریافت'",[]),allPaid=await sum('cash','amount',"type='برداشت'",[]);
  final inventory=await db.rawQuery('SELECT COALESCE(SUM(stock*buy),0) AS value FROM products'),productCount=await db.rawQuery('SELECT COUNT(*) AS count FROM products');
  final cr=await db.rawQuery("SELECT COALESCE(SUM(opening_balance),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE type IN ('دریافت','برگشت')),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE type='پرداخت'),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='customer'),0) AS balance FROM customers");
  final sr=await db.rawQuery("SELECT COALESCE(SUM(opening_balance),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE type='خرید'),0)-COALESCE((SELECT SUM(CASE WHEN type='دریافت' THEN -amount ELSE amount END) FROM supplier_payments),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='supplier'),0) AS balance FROM suppliers");
  final cb=((cr.first['balance'] as num?)??0).toDouble(),sb=((sr.first['balance'] as num?)??0).toDouble();
  final pr=await db.rawQuery("SELECT COALESCE(SUM(e.total-(e.qty*e.cost_price)),0) AS value FROM entries e WHERE e.type='فروش' AND e.created>=? AND e.created<?",[from,to]);
  final inv=((inventory.first['value'] as num?)??0).toDouble();
  return {'sales':sales,'purchases':purchases,'received':received,'paid':paid,'cash':allReceived-allPaid,'allReceived':allReceived,'allPaid':allPaid,'stockValue':inv,'products':((productCount.first['count'] as num?)??0).toDouble(),'customerDebt':cb>0?cb:0,'customerCredit':cb<0?cb.abs():0,'supplierDebt':sb>0?sb:0,'supplierCredit':sb<0?sb.abs():0,'profit':((pr.first['value'] as num?)??0).toDouble()};
 }
 Widget metric(String label,double value,IconData icon,Color color,{VoidCallback? onTap,bool isMoney=true,String? hint})=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[CircleAvatar(radius:18,backgroundColor:color.withOpacity(.10),child:Icon(icon,color:color,size:19)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:4),Text(isMoney?'${money.format(value)} افغانی':money.format(value),style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold),maxLines:1,overflow:TextOverflow.ellipsis),if(hint!=null)Text(hint,style:const TextStyle(fontSize:10,color:Colors.blueGrey))])),const Icon(Icons.chevron_left,color:Colors.blueGrey,size:18)]))));
 @override Widget build(BuildContext context)=>FutureBuilder<Map<String,double>>(future:stats(),builder:(c,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());final v=s.data!;
  return ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
   InkWell(onTap:()=>widget.onOpenFinance(0),borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff087f5b),Color(0xff16a078)]),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('موجودی فعلی صندوق دوکان • لمس برای جزئیات صندوق',style:TextStyle(color:Colors.white70,fontSize:12)),const SizedBox(height:5),Text('${money.format(v['cash'])} افغانی',style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text('مجموع دریافت: ${money.format(v['allReceived'])}  •  مجموع برداشت: ${money.format(v['allPaid'])}',style:const TextStyle(color:Colors.white70,fontSize:11))]))),
   const SizedBox(height:12),SegmentedButton<String>(segments:const [ButtonSegment(value:'امروز',label:Text('امروز')),ButtonSegment(value:'هفته',label:Text('۷ روز')),ButtonSegment(value:'ماه',label:Text('این ماه'))],selected:{period},onSelectionChanged:(x)=>setState(()=>period=x.first)),
   const SizedBox(height:8),Text('گزارش ${period=='امروز'?'امروز':period=='هفته'?'هفت روز اخیر':'ماه جاری'} • برای دیدن فهرست، روی هر مورد بزنید',style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold)),
   metric('مجموع فروش',v['sales']!,Icons.trending_up,Colors.green,onTap:()=>widget.onOpenEntries('فروش')),
   metric('مجموع خرید',v['purchases']!,Icons.shopping_bag_outlined,Colors.blue,onTap:()=>widget.onOpenEntries('خرید')),
   metric('دریافت نقدی صندوق',v['received']!,Icons.call_received,Colors.teal,onTap:()=>widget.onOpenFinance(0)),
   metric('برداشت از صندوق',v['paid']!,Icons.call_made,Colors.red,onTap:()=>widget.onOpenFinance(0)),
   metric('سود ناخالص فروش',v['profit']!,Icons.account_balance,Colors.deepPurple,onTap:()=>widget.onOpenEntries('فروش'),hint:'بر اساس قیمت خرید ثبت‌شده هنگام فروش'),
   const SizedBox(height:8),const Text('حساب مشتریان و فروشندگان',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
   metric('مشتریان بدهکار به دوکان',v['customerDebt']!,Icons.person_search,Colors.red,onTap:()=>widget.onOpenFinance(1)),
   metric('طلب مشتریان از دوکان',v['customerCredit']!,Icons.person_outline,Colors.green,onTap:()=>widget.onOpenFinance(1)),
   metric('بدهی دوکان به فروشندگان',v['supplierDebt']!,Icons.storefront,Colors.orange,onTap:()=>widget.onOpenFinance(2)),
   metric('طلب دوکان از فروشندگان',v['supplierCredit']!,Icons.store,Colors.teal,onTap:()=>widget.onOpenFinance(2)),
   const SizedBox(height:8),const Text('وضعیت دوکان',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
   metric('ارزش خرید موجودی کالا',v['stockValue']!,Icons.inventory_2_outlined,Colors.indigo,onTap:()=>widget.onOpenTab(1)),
   metric('تعداد کالاها',v['products']!,Icons.category_outlined,Colors.blueGrey,isMoney:false,onTap:()=>widget.onOpenTab(1)),
   const Card(child:Padding(padding:EdgeInsets.all(12),child:Text('تمام کارت‌ها بازشدنی هستند. سود ناخالص فروش از قیمت خرید ذخیره‌شده در زمان ثبت هر فروش محاسبه می‌شود؛ هزینه‌های جانبی دوکان در این رقم شامل نیست.',style:TextStyle(fontSize:11,color:Colors.blueGrey))))
  ]);
 });
}
class StatCard extends StatelessWidget {
  final String title;final double value;final IconData icon;final Color color;final bool isMoney;
  const StatCard(this.title,this.value,this.icon,this.color,{this.isMoney=true});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:color),Text(title,style:const TextStyle(color:Colors.black54,fontSize:12)),Text(isMoney?'${money.format(value)} افغانی':money.format(value),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])));
}
Widget field(TextEditingController c,String label,{bool number=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextField(controller:c,keyboardType:number?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

Future<String?> chooseFundSource(BuildContext context,{required String title,String initial='صندوق مغازه'}) async {
  String selected=initial=='پول شخصی'?'پول شخصی':'صندوق مغازه';
  return showDialog<String>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
    title:Text(title),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      RadioListTile<String>(value:'صندوق مغازه',groupValue:selected,title:const Text('صندوق دوکان'),subtitle:const Text('این مبلغ در موجودی صندوق دوکان حساب می‌شود.'),onChanged:(v)=>refresh(()=>selected=v!)),
      RadioListTile<String>(value:'پول شخصی',groupValue:selected,title:const Text('پول شخصی'),subtitle:const Text('در حساب طرف ثبت می‌شود، اما موجودی صندوق دوکان تغییر نمی‌کند.'),onChanged:(v)=>refresh(()=>selected=v!)),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,selected),child:const Text('تأیید منبع پول'))],
  )));
}

Future<double> configuredSeerGrams() async {
  final db = await ShopDb.instance.database;
  final rows = await db.query('settings', where: 'key=?', whereArgs: ['seer_grams'], limit: 1);
  final value = rows.isEmpty ? 1000 : (parseNum(rows.first['value'].toString()) ?? 1000);
  return value > 0 ? value.toDouble() : 1000.0;
}
double gramsPerUnit(String unit, double seerGrams) {
  final u = unit.trim().toLowerCase().replaceAll('‌',' ');
  if (u == '۱۰ گرم' || u == '10 گرم') return 10;
  if (u == '۱۰۰ گرم' || u == '100 گرم') return 100;
  if (u.contains('کیلو') || u == 'kg' || u == 'kilogram') return 1000;
  if (u.contains('چارک')) return seerGrams/4;
  if (u.contains('نیم سیر')) return seerGrams/2;
  if (u == 'گرم' || u == 'g' || u == 'gram') return 1;
  if (u.contains('سیر') || u == 'seer' || u == 'sir') return seerGrams;
  return 0;
}
List<String> saleWeightUnits(String baseUnit, double seerGrams) {
  if (gramsPerUnit(baseUnit, seerGrams) <= 0) return [baseUnit];
  return ['گرم','۱۰ گرم','۱۰۰ گرم','چارک','نیم سیر','سیر','کیلوگرم'];
}
List<Map<String,Object>> quantityPresets(String unit, double seerGrams) {
  final u=unit.trim();
  if(u.contains('کیلو') || u=='kg') return [
    {'label':'۱۰ گرم','value':0.01},{'label':'¼ کیلو','value':0.25},{'label':'نیم کیلو','value':0.5},
    {'label':'۱ کیلو','value':1.0},{'label':'۱٫۵ کیلو','value':1.5},
    {'label':'۲ کیلو','value':2.0},{'label':'۳ کیلو','value':3.0},
    {'label':'۵ کیلو','value':5.0},{'label':'۱۰ کیلو','value':10.0},
  ];
  if(u.contains('نیم سیر') || u.contains('نیم‌سیر')) return [
    {'label':'نیم سیر','value':1.0},{'label':'۱ سیر','value':2.0},
    {'label':'۱٫۵ سیر','value':3.0},{'label':'۲ سیر','value':4.0},
    {'label':'۳ سیر','value':6.0},{'label':'۴ سیر','value':8.0},
  ];
  if(u.contains('چارک')) return [
    {'label':'¼ سیر','value':1.0},{'label':'نیم سیر','value':2.0},
    {'label':'۱ سیر','value':4.0},{'label':'۱٫۵ سیر','value':6.0},
    {'label':'۲ سیر','value':8.0},
  ];
  if(u.contains('سیر') || u=='seer' || u=='sir') return [
    {'label':'۱۰ گرم','value':10/seerGrams},{'label':'¼ سیر','value':0.25},{'label':'نیم سیر','value':0.5},
    {'label':'۱ سیر','value':1.0},{'label':'۱٫۵ سیر','value':1.5},
    {'label':'۲ سیر','value':2.0},{'label':'۳ سیر','value':3.0},
    {'label':'۴ سیر','value':4.0},
  ];
  if(u.contains('گرم') || u=='g' || u=='gram') return [
    {'label':'۱۰ گرم','value':10.0},{'label':'۲۰ گرم','value':20.0},
    {'label':'۵۰ گرم','value':50.0},{'label':'۱۰۰ گرم','value':100.0},
    {'label':'۲۵۰ گرم','value':250.0},{'label':'۵۰۰ گرم','value':500.0},
    {'label':'۷۵۰ گرم','value':750.0},{'label':'۱۰۰۰ گرم','value':1000.0},
    {'label':'۲ کیلو','value':2000.0},
  ];
  return [
    {'label':'۱','value':1.0},{'label':'۲','value':2.0},
    {'label':'۵','value':5.0},{'label':'۱۰','value':10.0},
    {'label':'۲۰','value':20.0},{'label':'۵۰','value':50.0},
  ];
}

class ProductsPage extends StatefulWidget {final VoidCallback onChanged;const ProductsPage({super.key,required this.onChanged});@override State<ProductsPage> createState()=>_ProductsPageState();}
class _ProductsPageState extends State<ProductsPage> {
  final units = const ['کیلوگرم','سیر','نیم سیر','چارک','گرم','عدد','بسته','کارتن'];
  String cleanQty(double v){final s=v.toStringAsFixed(8);return s.contains('.')?s.replaceFirst(RegExp(r'0+$'),'').replaceFirst(RegExp(r'\.$'),''):s;}
  Future<List<Map<String,Object?>>> productRows() async {
    final db=await ShopDb.instance.database;
    return db.rawQuery("SELECT products.*, (SELECT suppliers.name FROM entries LEFT JOIN suppliers ON suppliers.id=entries.supplier_id WHERE entries.product_id=products.id AND entries.type='خرید' AND entries.supplier_id IS NOT NULL ORDER BY entries.id DESC LIMIT 1) AS source_name FROM products ORDER BY products.name COLLATE NOCASE");
  }
  Future<void> add() async {
    final db=await ShopDb.instance.database;
    final suppliers=await db.query('suppliers',orderBy:'name');
    final seerGrams=await configuredSeerGrams();
    final n=TextEditingController(),q=TextEditingController(text:'0'),b=TextEditingController(text:'0'),s=TextEditingController(text:'0'),paid=TextEditingController(),pieces=TextEditingController(text:'1');
    String unit='عدد'; int? supplierId;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final buyPrice=parseNum(b.text)??0, sellPrice=parseNum(s.text)??0, stock=parseNum(q.text)??0;
      return AlertDialog(title:const Text('افزودن کالای جدید'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(n,'نام کالا'),
        Align(alignment:Alignment.centerRight,child:Text('نام‌های آماده (برای پرکردن سریع)',style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant))),
        Wrap(spacing:6,children:['شفتالو','وارزی'].map((name)=>ActionChip(label:Text(name),onPressed:()=>refresh(()=>n.text=name))).toList()),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'واحد اصلی کالا'),items:units.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:(v)=>refresh(()=>unit=v??unit)),
        if(unit=='کارتن') field(pieces,'تعداد عدد داخل هر کارتن',number:true),
        const SizedBox(height:8),TextField(controller:q,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'موجودی اولیه',border:OutlineInputBorder())),
        Align(alignment:Alignment.centerRight,child:Text('مقدارهای آماده برای '+unit,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))),
        Wrap(spacing:5,runSpacing:4,children:quantityPresets(unit,seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>refresh(()=>q.text=cleanQty(p['value'] as double)))).toList()),
        TextField(controller:b,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'قیمت خرید هر '+unit+' (افغانی)',border:const OutlineInputBorder())),TextField(controller:s,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'قیمت فروش هر '+unit+' (افغانی)',border:const OutlineInputBorder())),
        Container(width:double.infinity,margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('سود هر واحد: '+money.format(sellPrice-buyPrice)+' افغانی',style:TextStyle(color:sellPrice>=buyPrice?Colors.green:Colors.red,fontWeight:FontWeight.bold)),
          Text('سود احتمالی موجودی: '+money.format(stock*(sellPrice-buyPrice))+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold)),
        ])),
        const Divider(height:20),
        const Align(alignment:Alignment.centerRight,child:Text('منبع خرید موجودی اولیه',style:TextStyle(fontWeight:FontWeight.bold))),
        DropdownButtonFormField<int>(value:supplierId,decoration:const InputDecoration(labelText:'از کدام دوکان‌دار یا فروشنده خرید شده؟'),items:suppliers.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text(x['name'].toString()))).toList(),onChanged:(v)=>refresh(()=>supplierId=v)),
        if(suppliers.isEmpty) const Padding(padding:EdgeInsets.only(top:6),child:Text('ابتدا فروشنده را از بخش حساب‌ها ثبت کنید.',style:TextStyle(color:Colors.red,fontSize:12))),
        field(paid,'مبلغ پرداخت نقدی به فروشنده (خالی = تسویه کامل)',number:true),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت کالا و خرید اولیه'))]);
    }));
    final stock=parseNum(q.text)??0,buyPrice=parseNum(b.text)??0,sellPrice=parseNum(s.text)??0,total=stock*buyPrice;
    final paidAmount=paid.text.trim().isEmpty?total:(parseNum(paid.text)??0);
    if(ok==true&&n.text.trim().isNotEmpty){
      if(stock<0||buyPrice<0||sellPrice<0||paidAmount<0||paidAmount>total||(unit=='کارتن'&&(int.tryParse(pieces.text.trim())??0)<=0)||(stock>0&&supplierId==null)){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی، قیمت، فروشنده یا مبلغ پرداختی را بررسی کنید.')));return;
      }
      var initialFundSource='صندوق مغازه';
      if(stock>0&&paidAmount>0){final selectedSource=await chooseFundSource(context,title:'پول خرید اولیه کالا از کجا پرداخت شده؟');if(selectedSource==null)return;initialFundSource=selectedSource;}
      await db.transaction((t)async{
        final now=DateTime.now().toIso8601String();
        final id=await t.insert('products',{'name':n.text.trim(),'unit':unit,'stock':stock,'buy':buyPrice,'sell':sellPrice,'pieces_per_carton':unit=='کارتن'?(int.tryParse(pieces.text.trim())??1):1,'updated':now});
        await t.insert('price_history',{'product_id':id,'buy':buyPrice,'sell':sellPrice,'changed':now});
        if(stock>0){
          final entryId=await t.insert('entries',{'product_id':id,'product_name':n.text.trim(),'type':'خرید','qty':stock,'price':buyPrice,'total':total,'note':'موجودی اولیه کالا','created':now,'supplier_id':supplierId,'paid':paidAmount,'fund_source':initialFundSource,'cost_price':buyPrice});
          if(paidAmount>0&&initialFundSource=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'برداشت','amount':paidAmount,'note':'پرداخت نقدی خرید اولیه • سند #'+entryId.toString(),'created':now});await t.update('entries',{'cash_id':cashId},where:'id=?',whereArgs:[entryId]);}
        }
      });
      widget.onChanged();if(mounted)setState((){});
    }
  }
  Future<void> editProduct(Map<String,Object?> x) async {
    final db=await ShopDb.instance.database;
    final used=await db.query('entries',where:'product_id=?',whereArgs:[x['id']],limit:1);
    final oldStock=(x['stock'] as num).toDouble();
    final n=TextEditingController(text:x['name'].toString()),q=TextEditingController(text:x['stock'].toString()),b=TextEditingController(text:x['buy'].toString()),s=TextEditingController(text:x['sell'].toString()),pieces=TextEditingController(text:'${x['pieces_per_carton']??1}');
    String unit=x['unit'].toString();final editUnits=[...units];if(!editUnits.contains(unit))editUnits.add(unit);
    final seerGrams=await configuredSeerGrams();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final buyPrice=parseNum(b.text)??0,sellPrice=parseNum(s.text)??0,stock=parseNum(q.text)??0;
      return AlertDialog(title:const Text('ویرایش کالا'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(n,'نام کالا'),
        DropdownButtonFormField<String>(value:unit,decoration:const InputDecoration(labelText:'واحد کالا'),items:editUnits.map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:used.isNotEmpty?null:(v)=>refresh(()=>unit=v??unit)),
        if(used.isNotEmpty)const Text('واحد کالای دارای سابقه قابل تغییر نیست.',style:TextStyle(color:Colors.orange,fontSize:12)),
        if(unit=='کارتن') field(pieces,'تعداد عدد داخل هر کارتن',number:true),
        field(q,'موجودی فعلی',number:true),
        Wrap(spacing:5,children:quantityPresets(unit,seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>refresh(()=>q.text=cleanQty(p['value'] as double)))).toList()),
        field(b,'قیمت خرید هر '+unit,number:true),field(s,'قیمت فروش هر '+unit,number:true),
        Text('سود احتمالی موجودی: '+money.format(stock*(sellPrice-buyPrice))+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.green)),
        if(used.isNotEmpty)const Padding(padding:EdgeInsets.only(top:8),child:Text('هر تغییر موجودی به‌صورت سند اصلاح موجودی ثبت می‌شود تا سابقه انبار و حسابداری حفظ شود.',style:TextStyle(fontSize:11,color:Colors.blueGrey))),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره تغییرات'))]);
    }));
    if(ok==true&&n.text.trim().isNotEmpty){
      final parsedStock=parseNum(q.text),parsedBuy=parseNum(b.text),parsedSell=parseNum(s.text);
      if(parsedStock==null||parsedBuy==null||parsedSell==null||parsedStock<0||parsedBuy<0||parsedSell<0||(unit=='کارتن'&&(int.tryParse(pieces.text.trim())??0)<=0)){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی و قیمت‌ها باید عدد معتبر و غیرمنفی باشند.')));
        return;
      }
      final stock=parsedStock,buyPrice=parsedBuy,sellPrice=parsedSell,now=DateTime.now().toIso8601String();
      await db.transaction((t)async{
        await t.update('products',{'name':n.text.trim(),'unit':unit,'stock':stock,'buy':buyPrice,'sell':sellPrice,'pieces_per_carton':unit=='کارتن'?(int.tryParse(pieces.text.trim())??1):1,'updated':now},where:'id=?',whereArgs:[x['id']]);
        if((buyPrice-(x['buy'] as num).toDouble()).abs()>0.000001||(sellPrice-(x['sell'] as num).toDouble()).abs()>0.000001){
          await t.insert('price_history',{'product_id':x['id'],'buy':buyPrice,'sell':sellPrice,'changed':now});
        }
        final delta=stock-oldStock;
        if(delta.abs()>0.000001){
          await t.insert('entries',{'product_id':x['id'],'product_name':n.text.trim(),'type':'اصلاح موجودی','qty':delta.abs(),'price':0,'total':0,'paid':0,'note':'اصلاح موجودی از ${money.format(oldStock)} به ${money.format(stock)} ${unit}','created':now});
        }
      });
      widget.onChanged();if(mounted)setState((){});
    }
  }
  Future<void> recordStockLoss() async {
    final db=await ShopDb.instance.database;final products=await db.query('products',orderBy:'name');if(products.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا کالا ثبت کنید.')));return;}
    int selected=products.first['id'] as int;String reason='خراب‌شدن';final qty=TextEditingController(),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){final product=products.firstWhere((x)=>x['id']==selected);final stock=(product['stock'] as num).toDouble();final amount=parseNum(qty.text)??0;return AlertDialog(title:const Text('ثبت جنس خراب، گم‌شده یا ضایعات'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب کالا'),items:products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} • موجودی ${money.format(x['stock'])} ${x['unit']}'))).toList(),onChanged:(v)=>refresh(()=>selected=v??selected)),field(qty,'مقدار ضایعات',number:true),DropdownButtonFormField<String>(value:reason,decoration:const InputDecoration(labelText:'دلیل'),items:const [DropdownMenuItem(value:'خراب‌شدن',child:Text('جنس خراب شده')),DropdownMenuItem(value:'گم‌شدن',child:Text('جنس گم شده')),DropdownMenuItem(value:'تاریخ‌گذشته',child:Text('تاریخ‌گذشته')),DropdownMenuItem(value:'مصرف شخصی',child:Text('برداشت برای مصرف شخصی')),DropdownMenuItem(value:'سایر',child:Text('سایر'))],onChanged:(v)=>refresh(()=>reason=v??reason)),field(note,'توضیحات (اختیاری)'),Align(alignment:Alignment.centerRight,child:Text('موجودی فعلی: ${money.format(stock)} ${product['unit']} • ارزش ضایعات: ${money.format(amount*(product['buy'] as num).toDouble())} افغانی',style:const TextStyle(fontSize:12,color:Colors.blueGrey))) ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:amount>0&&amount<=stock?()=>Navigator.pop(c,true):null,child:const Text('ثبت و کم‌کردن موجودی'))]);}));
    final amount=parseNum(qty.text)??0;if(ok==true&&amount>0){final product=products.firstWhere((x)=>x['id']==selected);final now=DateTime.now().toIso8601String();await db.transaction((t)async{await t.rawUpdate('UPDATE products SET stock=stock-?,updated=? WHERE id=? AND stock>=?',[amount,now,selected,amount]);await t.insert('stock_adjustments',{'product_id':selected,'product_name':product['name'],'quantity':amount,'unit':product['unit'],'reason':reason,'cost_value':amount*(product['buy'] as num).toDouble(),'note':note.text.trim(),'created':now});await t.insert('entries',{'product_id':selected,'product_name':product['name'],'type':'ضایعات','qty':amount,'price':0,'total':0,'paid':0,'note':'$reason • ${note.text.trim()}','created':now,'cost_price':(product['buy'] as num).toDouble()});});widget.onChanged();if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ضایعات ثبت شد و از موجودی کم شد.')));setState((){});}}
  }
  Future<void> showPriceHistory(Map<String,Object?> product) async {final db=await ShopDb.instance.database;final rows=await db.query('price_history',where:'product_id=?',whereArgs:[product['id']],orderBy:'id DESC');if(!mounted)return;showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('تاریخچه قیمت '+product['name'].toString()),content:SizedBox(width:360,child:rows.isEmpty?const Text('تاریخچه‌ای ثبت نشده است'):ListView(shrinkWrap:true,children:rows.map((r)=>ListTile(dense:true,title:Text('خرید: '+money.format(r['buy'])+' • فروش: '+money.format(r['sell'])+' افغانی'),subtitle:Text(afghanDate(DateTime.parse(r['changed'].toString()))))).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))]));}
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
      Padding(padding:const EdgeInsets.fromLTRB(12,8,12,2),child:Row(children:[Expanded(child:FilledButton.tonalIcon(onPressed:add,icon:const Icon(Icons.add),label:const Text('ثبت کالای جدید'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:recordStockLoss,icon:const Icon(Icons.remove_shopping_cart_outlined),label:const Text('جنس خراب / ضایعات')))])),
      Expanded(child:products.isEmpty?const Center(child:Text('هنوز کالایی ثبت نشده است')):ListView.builder(padding:const EdgeInsets.fromLTRB(10,8,10,12),itemCount:products.length,itemBuilder:(c,i){
        final x=products[i];final stock=(x['stock'] as num).toDouble(),buy=(x['buy'] as num).toDouble(),sell=(x['sell'] as num).toDouble();
        return Card(margin:const EdgeInsets.symmetric(vertical:4),child:ListTile(leading:const CircleAvatar(child:Icon(Icons.inventory_2_outlined)),title:Text(x['name'].toString()),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
          Text('موجودی: '+money.format(stock)+' '+x['unit'].toString()+' • خرید: '+money.format(buy)+' • فروش: '+money.format(sell)+' افغانی'),
          Text('سود هر واحد: '+money.format(sell-buy)+' • سود موجودی: '+money.format(stock*(sell-buy))+' افغانی',style:TextStyle(fontSize:11,color:sell>=buy?Colors.green:Colors.red)),
          Text('آخرین خرید از: '+(x['source_name']?.toString()??'ثبت نشده'),style:const TextStyle(fontSize:11,color:Colors.blueGrey)),
        ]),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')editProduct(x);else if(v=='history')showPriceHistory(x);else deleteProduct(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش کالا و قیمت')),PopupMenuItem(value:'history',child:Text('تاریخچه تغییر قیمت')),PopupMenuItem(value:'delete',child:Text('حذف کالا'))])));
      })),
      Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(12,9,12,10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,boxShadow:[BoxShadow(color:Colors.black.withOpacity(.06),blurRadius:8,offset:const Offset(0,-2))]),child:Column(children:[
        Row(children:[Expanded(child:Text('ارزش خرید موجودی: '+money.format(stockValue)+' افغانی',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),Expanded(child:Text('ارزش فروش: '+money.format(saleValue)+' افغانی',textAlign:TextAlign.end,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)))]),
        const SizedBox(height:4),Text('سود احتمالی کل موجودی: '+money.format(profit)+' افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:profit>=0?Colors.green:Colors.red)),
      ]))
    ]);
  }));
}
class EntriesPage extends StatefulWidget {final VoidCallback onChanged;final String initialType;const EntriesPage({super.key,required this.onChanged,this.initialType='فروش'});@override State<EntriesPage> createState()=>_EntriesPageState();}
class _EntriesPageState extends State<EntriesPage> {
  String type='فروش';
  Future<List<Map<String,Object?>>> entryRows() async {
    final db=await ShopDb.instance.database;
    return db.rawQuery("SELECT entries.*, customers.name AS customer_name, suppliers.name AS supplier_name, products.unit AS product_unit FROM entries LEFT JOIN customers ON customers.id=entries.customer_id LEFT JOIN suppliers ON suppliers.id=entries.supplier_id LEFT JOIN products ON products.id=entries.product_id ORDER BY entries.created DESC, entries.id DESC");
  }
  Future<double> currentCustomerBalance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM customers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE customer_id=? AND type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type IN ('دریافت','برگشت')),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='پرداخت'),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='customer' AND account_id=?),0) AS b",[id,id,id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
  Future<void> add() async {
    final db=await ShopDb.instance.database;
    final products=await db.query('products',orderBy:'name');
    if(products.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا یک کالا ثبت کنید')));return;}
    final customers=type=='فروش'?await db.query('customers',orderBy:'name'):<Map<String,Object?>>[];
    final seerGrams=await configuredSeerGrams();
    final suppliers=type=='خرید'?await db.query('suppliers',orderBy:'name'):<Map<String,Object?>>[];
    int? selected=products.first['id'] as int;
    String quantityUnit=products.first['unit'].toString();
    int? selectedCustomer; int? selectedSupplier;
    final qty=TextEditingController(text:'1'),tare=TextEditingController(text:'0'),price=TextEditingController(text:'${products.first[type=='فروش'?'sell':'buy']}'),note=TextEditingController(),customerSearch=TextEditingController(),paid=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh){
      final filtered=customers.where((x)=>'${x['name']} ${x['phone']??''}'.toLowerCase().contains(customerSearch.text.toLowerCase())).toList();
      final selectedProduct=products.firstWhere((e)=>e['id']==selected);
      final baseUnit=selectedProduct['unit'].toString();
      final baseFactor=gramsPerUnit(baseUnit,seerGrams);
      final selectedFactor=gramsPerUnit(quantityUnit,seerGrams);
      final gross=parseNum(qty.text)??0, tareGrams=parseNum(tare.text)??0;
      final netQty=selectedFactor>0?gross-(tareGrams/selectedFactor):gross;
      final baseAmount=baseFactor>0&&selectedFactor>0?netQty*selectedFactor/baseFactor:netQty;
      return AlertDialog(title:Text('ثبت $type'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب کالا'),items:products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} (${x['unit']})'))).toList(),onChanged:(v){final x=products.firstWhere((e)=>e['id']==v);refresh((){selected=v;quantityUnit=x['unit'].toString();});price.text='${x[type=='فروش'?'sell':'buy']}';}),
        if(type=='خرید') ...[
          const SizedBox(height:10),TextField(controller:customerSearch,decoration:const InputDecoration(labelText:'جستجوی دوکان / فروشنده',prefixIcon:Icon(Icons.search)),onChanged:(_)=>refresh((){})),
          if(customerSearch.text.isNotEmpty) ...suppliers.where((x)=>' ${x['name']} ${x['phone']??''}'.toLowerCase().contains(customerSearch.text.toLowerCase())).take(5).map((x)=>ListTile(dense:true,selected:selectedSupplier==x['id'],leading:const Icon(Icons.storefront_outlined),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}'),onTap:()=>refresh(()=>selectedSupplier=x['id'] as int))),
          if(selectedSupplier!=null) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>refresh(()=>selectedSupplier=null),child:Text('فروشنده: ${suppliers.firstWhere((x)=>x['id']==selectedSupplier)['name']} • حذف انتخاب'))),
          if(suppliers.isEmpty) const Text('برای ثبت حساب خرید، ابتدا فروشنده را در بخش حساب‌ها اضافه کنید.'),
        ],
        if(type=='فروش') ...[
          const SizedBox(height:10),TextField(controller:customerSearch,decoration:const InputDecoration(labelText:'جستجوی مشتری (برای ثبت هر فروش الزامی است)',prefixIcon:Icon(Icons.search)),onChanged:(_)=>refresh((){})),
          if(customerSearch.text.isNotEmpty) ...filtered.take(5).map((x)=>ListTile(dense:true,selected:selectedCustomer==x['id'],leading:const Icon(Icons.person_outline),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''}'),onTap:()=>refresh((){selectedCustomer=x['id'] as int;if(paid.text.trim().isEmpty)paid.text='0';}))),
          if(selectedCustomer!=null) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>refresh((){selectedCustomer=null;if(paid.text.trim()=='0')paid.clear();}),child:Text('مشتری: ${customers.firstWhere((x)=>x['id']==selectedCustomer)['name']} • حذف انتخاب'))),
          if(selectedCustomer!=null) FutureBuilder<double>(future:currentCustomerBalance(selectedCustomer!),builder:(ctx,bal){if(!bal.hasData)return const SizedBox.shrink();final value=bal.data!;return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(10)),child:Text('مانده فعلی: ${money.format(value.abs())} افغانی • ${value>0?'بدهکار':value<0?'طلبکار':'تسویه'}\nمبلغ پرداخت‌نشده این فروش به حساب مشتری اضافه می‌شود.',style:TextStyle(fontSize:11,color:value>0?Colors.red:value<0?Colors.green:Colors.blueGrey)));}),
          if(selectedCustomer==null) Container(width:double.infinity,margin:const EdgeInsets.only(top:6),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Colors.red.withOpacity(.08),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.red.withOpacity(.45))),child:Text(customers.isEmpty?'برای ثبت فروش ابتدا از بخش حساب‌ها یک مشتری بسازید.':'برای ثبت فروش، یک مشتری را جستجو و انتخاب کنید.',style:const TextStyle(color:Colors.red,fontSize:12,fontWeight:FontWeight.w600))),
        ],
        Row(children:[Expanded(child:TextField(controller:qty,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:(baseFactor>0?'وزن ناخالص':'مقدار')+' ($quantityUnit)',border:const OutlineInputBorder()))),const SizedBox(width:8),if(baseFactor>0)OutlinedButton.icon(onPressed:()async{final picked=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(sheet)=>SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:8,runSpacing:8,children:saleWeightUnits(baseUnit,seerGrams).map((u)=>ActionChip(label:Text(u),onPressed:()=>Navigator.pop(sheet,u))).toList()))));if(picked!=null){final ratio=gramsPerUnit(picked,seerGrams)/baseFactor;final basePrice=(selectedProduct[type=='فروش'?'sell':'buy'] as num).toDouble();refresh(()=>quantityUnit=picked);price.text=(basePrice*ratio).toStringAsFixed(4);refresh((){});}},icon:const Icon(Icons.scale_outlined),label:Text(quantityUnit))]),
        if(baseFactor>0) TextField(controller:tare,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'وزن ظرف / بسته‌بندی (گرام)',helperText:'وزن ظرف از وزن ناخالص کم می‌شود.',border:OutlineInputBorder())),
        if(baseFactor>0) Align(alignment:Alignment.centerRight,child:Text('وزن خالص: '+money.format(netQty)+' '+quantityUnit+'  •  معادل '+money.format(baseAmount)+' '+baseUnit,style:TextStyle(fontWeight:FontWeight.bold,color:netQty>0?Colors.green:Colors.red))),
        TextField(controller:price,onChanged:(_)=>refresh((){}),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'قیمت هر '+quantityUnit+' (افغانی)',border:const OutlineInputBorder())),
        if(products.firstWhere((e)=>e['id']==selected)['unit']=='کارتن') Builder(builder:(ctx){final p=products.firstWhere((e)=>e['id']==selected);final count=(p['pieces_per_carton'] as num?)?.toInt()??1;final cartonPrice=parseNum(price.text)??0;final buy=(p['buy'] as num).toDouble();return Container(width:double.infinity,padding:const EdgeInsets.all(9),margin:const EdgeInsets.only(top:5),decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('هر کارتن: $count عدد'),Text('قیمت هر عدد برای مشتری: '+money.format(cartonPiecePrice(cartonPrice,count))+' افغانی'),Text('قیمت تمام‌شده هر عدد برای شما: '+money.format(cartonPiecePrice(buy,count))+' افغانی'),Text('سود هر عدد: '+money.format(cartonPiecePrice(cartonPrice-buy,count))+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold))]));}),
        Builder(builder:(ctx){final product=products.firstWhere((e)=>e['id']==selected);final q=netQty,pv=parseNum(price.text)??0,subtotal=q*pv;final baseCost=(product['buy'] as num).toDouble();final baseSell=(product['sell'] as num).toDouble();final ratio=baseFactor>0?selectedFactor/baseFactor:1.0;final margin=q*(type=='فروش'?pv-baseCost*ratio:baseSell*ratio-pv);final stock=(product['stock'] as num).toDouble();return Container(width:double.infinity,margin:const EdgeInsets.symmetric(vertical:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('جمع سند: '+money.format(subtotal)+' افغانی',style:const TextStyle(fontWeight:FontWeight.bold)),Text((type=='فروش'?'سود تقریبی این فروش: ':'سود احتمالی پس از خرید: ')+money.format(margin)+' افغانی',style:TextStyle(color:margin>=0?Colors.green:Colors.red,fontWeight:FontWeight.w600)),if(type=='فروش')Text('موجودی فعلی: '+money.format(stock)+' '+product['unit'].toString()+' • مقدار مورد نیاز: '+money.format(baseAmount)+' '+baseUnit,style:TextStyle(fontSize:11,color:baseAmount>stock?Colors.red:Colors.blueGrey)),if(product['unit']=='کارتن')Text('تعداد عدد در فروش: '+money.format(q*(product['pieces_per_carton'] as num? ?? 1))+' عدد',style:const TextStyle(fontSize:11))]));}),
        field(paid,type=='فروش'?'مبلغ نقدی همان لحظه (۰ = تمام مبلغ نسیه؛ خالی = نقدی کامل)':'مبلغ نقدی پرداخت‌شده به فروشنده (خالی = تمام مبلغ)',number:true),
        field(note,'یادداشت')
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:(){if(type=='فروش'&&selectedCustomer==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای ثبت فروش ابتدا مشتری را انتخاب کنید.'),backgroundColor:Colors.red));refresh((){});return;}Navigator.pop(c,true);},child:const Text('ثبت'))]);
    }));
    if(ok==true&&selected!=null){
      final x=products.firstWhere((e)=>e['id']==selected);
      final grossAmount=parseNum(qty.text)??0,tareGrams=parseNum(tare.text)??0,baseFactor=gramsPerUnit(x['unit'].toString(),seerGrams),selectedFactor=gramsPerUnit(quantityUnit,seerGrams);
      final displayAmount=selectedFactor>0?grossAmount-(tareGrams/selectedFactor):grossAmount;
      final amount=baseFactor>0&&selectedFactor>0?displayAmount*selectedFactor/baseFactor:displayAmount;
      final displayPrice=parseNum(price.text)??0,total=displayAmount*displayPrice;
      final unitPrice=amount>0?total/amount:0;
      final paidAmount=paid.text.trim().isEmpty?total:(parseNum(paid.text)??0);
      if(amount<=0||grossAmount<=0||tareGrams<0||(selectedFactor>0&&tareGrams>=grossAmount*selectedFactor)||displayPrice<0||paidAmount<0||paidAmount>total){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مقدار، قیمت یا مبلغ نقدی معتبر نیست.')));return;} if(type=='خرید'&&selectedSupplier==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای ثبت خرید، فروشنده را انتخاب کنید.')));return;} if(type=='فروش'&&selectedCustomer==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای ثبت فروش ابتدا مشتری را انتخاب کنید.'),backgroundColor:Colors.red));return;}
      final currentStock=(x['stock'] as num).toDouble();
      if(type=='فروش'&&amount>currentStock){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی کالا کافی نیست.')));return;}
      var purchaseFundSource='صندوق مغازه';
      if(type=='خرید'&&paidAmount>0){final selectedSource=await chooseFundSource(context,title:'پول پرداختی خرید از کجا پرداخت شده؟');if(selectedSource==null)return;purchaseFundSource=selectedSource;}
      await db.transaction((t)async{
        final stock=currentStock+(type=='خرید'?amount:-amount);
        await t.update('products',{'stock':stock,'updated':DateTime.now().toIso8601String()},where:'id=?',whereArgs:[selected]);
        final entryId=await t.insert('entries',{'product_id':selected,'product_name':x['name'],'type':type,'qty':amount,'price':unitPrice,'total':total,'note':[note.text.trim(),if(selectedFactor>0)'مقدار فروش: '+money.format(displayAmount)+' '+quantityUnit,if(selectedFactor>0&&tareGrams>0)'وزن ظرف: '+money.format(tareGrams)+' گرام'].where((v)=>v.isNotEmpty).join(' • '),'created':DateTime.now().toIso8601String(),'customer_id':type=='فروش'?selectedCustomer:null,'supplier_id':type=='خرید'?selectedSupplier:null,'paid':paidAmount,'fund_source':type=='خرید'?purchaseFundSource:'صندوق مغازه','cost_price':type=='فروش'?(x['buy'] as num).toDouble():unitPrice,'display_qty':displayAmount,'display_unit':quantityUnit});
        if(paidAmount>0&&(type=='فروش'||purchaseFundSource=='صندوق مغازه')){final cashId=await t.insert('cash',{'type':type=='فروش'?'دریافت':'برداشت','amount':paidAmount,'note':'${type=='فروش'?'دریافت نقدی فروش':'پرداخت نقدی خرید'} • سند #$entryId','created':DateTime.now().toIso8601String()});await t.update('entries',{'cash_id':cashId},where:'id=?',whereArgs:[entryId]);}
      });
      widget.onChanged();setState((){});
    }
  }

  String receiptText(Map<String,Object?> x) {
    final sale=x['type']=='فروش';
    final created=DateTime.tryParse('${x['created']}')??DateTime.now();
    final total=(x['total'] as num? ?? 0).toDouble();
    final paid=(x['paid'] as num? ?? 0).toDouble();
    final qty=(x['qty'] as num? ?? 0).toDouble();
    final price=(x['price'] as num? ?? 0).toDouble();
    final party=x[sale?'customer_name':'supplier_name']?.toString();
    return [
      'رسید ${sale?'فروش':'خرید'} دوکان',
      'شماره سند: ${x['id']}',
      'تاریخ: ${afghanDate(created)}',
      if(party!=null&&party.isNotEmpty) '${sale?'مشتری':'فروشنده'}: $party',
      'کالا: ${x['product_name']}',
      'مقدار: ${money.format((x['display_qty'] as num?)?.toDouble()??qty)} ${x['display_unit']??x['product_unit']??''}',
      'قیمت واحد: ${money.format(((x['display_qty'] as num?)?.toDouble()??qty)>0?total/((x['display_qty'] as num?)?.toDouble()??qty):price)} افغانی',
      'مجموع: ${money.format(total)} افغانی',
      'پرداخت‌شده: ${money.format(paid)} افغانی',
      'باقی‌مانده: ${money.format(total-paid)} افغانی',
      if('${x['note']??''}'.trim().isNotEmpty) 'یادداشت: ${x['note']}',
      'با تشکر',
    ].join('\n');
  }
  Future<void> showReceipt(Map<String,Object?> x) async {
    final text=receiptText(x);
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(
      title:Text('رسید سند #${x['id']}'),
      content:SingleChildScrollView(child:SelectableText(text,textDirection:ui.TextDirection.rtl)),
      actions:[
        TextButton.icon(onPressed:(){Clipboard.setData(ClipboardData(text:text));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رسید کپی شد')));},icon:const Icon(Icons.copy),label:const Text('کپی')),
        TextButton.icon(onPressed:()async{await Share.share(text,subject:'رسید دوکان');},icon:const Icon(Icons.share_outlined),label:const Text('اشتراک‌گذاری')),
        FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن')),
      ],
    ));
  }

  Future<void> editEntry(Map<String,Object?> x) async {
    final seerGrams=await configuredSeerGrams();
    final qty=TextEditingController(text:'${x['qty']}'),price=TextEditingController(text:'${x['price']}'),note=TextEditingController(text:'${x['note']??''}'),paid=TextEditingController(text:'${x['paid']??0}');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('ویرایش ${x['type']}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(qty,'مقدار '+(x['product_unit']?.toString()??''),number:true),Wrap(spacing:5,children:quantityPresets(x['product_unit']?.toString()??'عدد',seerGrams).map((p)=>ActionChip(label:Text(p['label'].toString()),onPressed:()=>qty.text=(p['value'] as double).toStringAsFixed(3))).toList()),field(price,'قیمت هر واحد',number:true),field(paid,x['type']=='فروش'?'مبلغ نقد دریافت‌شده هنگام فروش':'مبلغ نقد پرداخت‌شده هنگام خرید',number:true),field(note,'یادداشت')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));
    if(ok!=true)return;final q=parseNum(qty.text)??0,pv=parseNum(price.text)??0,paidValue=parseNum(paid.text)??0;if(q<=0||pv<0||paidValue<0||paidValue>q*pv)return;
    var editedFundSource='صندوق مغازه';
    if(x['type']=='خرید'&&paidValue>0){final selectedSource=await chooseFundSource(context,title:'پول پرداختی خرید از کجا پرداخت شده؟',initial:'${x['fund_source']??'صندوق مغازه'}');if(selectedSource==null)return;editedFundSource=selectedSource;}
    final db=await ShopDb.instance.database;
    try { await db.transaction((t)async{
      final oldQty=(x['qty'] as num).toDouble();final delta=q-oldQty;final sign=x['type']=='خرید'?1.0:-1.0;
      final productRows=await t.query('products',where:'id=?',whereArgs:[x['product_id']],limit:1);
      if(productRows.isEmpty)throw StateError('کالای این سند پیدا نشد.');
      final currentStock=(productRows.first['stock'] as num).toDouble();
      if(currentStock+delta*sign < -0.000001)throw StateError('موجودی کافی نیست؛ مقدار فروش را کاهش دهید.');
      await t.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?',[delta*sign,x['product_id']]);
      await t.update('entries',{'qty':q,'price':pv,'total':q*pv,'paid':paidValue,'note':note.text,'fund_source':x['type']=='خرید'?editedFundSource:'صندوق مغازه','display_qty':q,'display_unit':x['product_unit']??'عدد'},where:'id=?',whereArgs:[x['id']]);
      final cashId=x['cash_id'];
      final affectsCash=paidValue>0&&(x['type']=='فروش'||editedFundSource=='صندوق مغازه');
      if(cashId!=null){if(affectsCash){await t.update('cash',{'amount':paidValue,'type':x['type']=='فروش'?'دریافت':'برداشت'},where:'id=?',whereArgs:[cashId]);}else{await t.delete('cash',where:'id=?',whereArgs:[cashId]);await t.update('entries',{'cash_id':null},where:'id=?',whereArgs:[x['id']]);}}
      else if(affectsCash){final newCashId=await t.insert('cash',{'type':x['type']=='فروش'?'دریافت':'برداشت','amount':paidValue,'note':'ثبت پرداخت ویرایش‌شده از سند #${x['id']}','created':x['created']});await t.update('entries',{'cash_id':newCashId},where:'id=?',whereArgs:[x['id']]);}
    }); } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Bad state: ','')))); return; }
    widget.onChanged();setState((){});
  }
  Future<void> deleteEntry(Map<String,Object?> x) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف سند'),content:const Text('با حذف این سند، موجودی کالا نیز به حالت قبل برمی‌گردد. ادامه می‌دهید؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(ok!=true)return;final db=await ShopDb.instance.database;await db.transaction((t)async{final q=(x['qty'] as num).toDouble();final sign=x['type']=='خرید'?-1.0:1.0;await t.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?',[q*sign,x['product_id']]);if(x['cash_id']!=null)await t.delete('cash',where:'id=?',whereArgs:[x['cash_id']]);await t.delete('entries',where:'id=?',whereArgs:[x['id']]);});widget.onChanged();setState((){});
  }
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(12,8,12,5),child:SegmentedButton<String>(segments:const [ButtonSegment(value:'فروش',label:Text('فروش'),icon:Icon(Icons.trending_up)),ButtonSegment(value:'خرید',label:Text('خرید'),icon:Icon(Icons.shopping_cart))],selected:{type},onSelectionChanged:(s)=>setState(()=>type=s.first))),
    Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:entryRows(),builder:(c,s){
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final allRows=s.data!;
      final salesCount=allRows.where((x)=>x['type']=='فروش').length;
      final purchasesCount=allRows.where((x)=>x['type']=='خرید').length;
      final rows=allRows.where((x)=>x['type']==type||x['type']=='اصلاح موجودی').toList();
      return Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(10,4,10,6),child:Row(children:[
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),child:Row(children:[const Icon(Icons.trending_up,color:Colors.green,size:17),const SizedBox(width:6),Text('فروش: $salesCount سند',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),child:Row(children:[const Icon(Icons.shopping_bag_outlined,color:Colors.blue,size:17),const SizedBox(width:6),Text('خرید: $purchasesCount سند',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))]))))
        ])),
        Expanded(child:rows.isEmpty?Center(child:Text(type=='فروش'?'هنوز فروشی ثبت نشده است':'هنوز خریدی ثبت نشده است')):ListView.separated(padding:const EdgeInsets.fromLTRB(10,2,10,12),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:2),itemBuilder:(c,i){
        final x=rows[i],sale=x['type']=='فروش',adjustment=x['type']=='اصلاح موجودی';
        final total=(x['total'] as num?)?.toDouble()??0,paid=(x['paid'] as num?)?.toDouble()??0;
        final left=total-paid;
        final party=sale?x['customer_name']:x['supplier_name'];
        final date=afghanDate(DateTime.parse(x['created'].toString()));
        return Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:Row(children:[
          CircleAvatar(radius:18,backgroundColor:(adjustment?Colors.orange:(sale?Colors.green:Colors.blue)).withOpacity(.10),child:Text('${i+1}',style:TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:adjustment?Colors.orange:(sale?Colors.green:Colors.blue)))),
          const SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${x['product_name']}  ${adjustment?'(اصلاح موجودی)':sale?'(فروش)':'(خرید)'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13),maxLines:1,overflow:TextOverflow.ellipsis),
            Text(adjustment?'${x['note']??''} • $date':'${party??(sale?'مشتری نقدی':'فروشنده نامشخص')} • ${money.format((x['display_qty'] as num?)?.toDouble()??(x['qty'] as num).toDouble())} ${x['display_unit']??x['product_unit']??''} × ${money.format(((x['display_qty'] as num?)?.toDouble()??(x['qty'] as num).toDouble())>0?(x['total'] as num).toDouble()/((x['display_qty'] as num?)?.toDouble()??(x['qty'] as num).toDouble()):(x['price'] as num).toDouble())} • $date',style:const TextStyle(fontSize:10,color:Colors.blueGrey),maxLines:2,overflow:TextOverflow.ellipsis),
            if(!adjustment)Text('پرداخت‌شده: ${money.format(paid)}  •  باقی: ${money.format(left)}',style:TextStyle(fontSize:10,color:left>0?Colors.orange:Colors.green))
          ])),
          const SizedBox(width:4),
          Column(crossAxisAlignment:CrossAxisAlignment.end,mainAxisAlignment:MainAxisAlignment.center,children:[
            Text('${money.format(total)}',style:TextStyle(fontWeight:FontWeight.bold,color:sale?Colors.green:Colors.blue,fontSize:13)),
            const Text('افغانی',style:TextStyle(fontSize:9,color:Colors.blueGrey)),
            if(!adjustment)Row(mainAxisSize:MainAxisSize.min,children:[
              IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:32,height:32),tooltip:'مشاهده و اشتراک رسید',onPressed:()=>showReceipt(x),icon:const Icon(Icons.receipt_long_outlined,size:17)),
              IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:32,height:32),tooltip:'ویرایش سند',onPressed:()=>editEntry(x),icon:const Icon(Icons.edit_outlined,size:17)),
            ])
          ])
        ])));
      })),
      ]);
    })),
    Padding(padding:const EdgeInsets.fromLTRB(12,5,12,10),child:FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:Text('ثبت $type'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(46))))
  ]);

}
class CashPage extends StatefulWidget {final VoidCallback onChanged;const CashPage({super.key,required this.onChanged});@override State<CashPage> createState()=>_CashPageState();}
class _CashPageState extends State<CashPage> {
  Future<void> showCashReceipt(Map<String,Object?> x) async {
    final created=DateTime.tryParse('${x['created']}')??DateTime.now();
    final text=[
      'دوکان',
      'رسید تراکنش صندوق',
      'شماره سند: ${x['id']}',
      'تاریخ: ${afghanDate(created)}',
      'نوع تراکنش: ${x['type']}',
      'مبلغ: ${money.format(x['amount'])} افغانی',
      'منبع: صندوق دوکان',
      if('${x['note']??''}'.trim().isNotEmpty)'توضیحات: ${x['note']}',
      'واحد پول: افغانی (AFN)',
      'با تشکر'
    ].join('\\n');
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(
      title:const Text('رسید صندوق'),
      content:SingleChildScrollView(child:SelectableText(text,textDirection:ui.TextDirection.rtl)),
      actions:[
        TextButton.icon(onPressed:(){Clipboard.setData(ClipboardData(text:text));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رسید کپی شد')));},icon:const Icon(Icons.copy),label:const Text('کپی')),
        TextButton.icon(onPressed:()=>Share.share(text,subject:'رسید صندوق'),icon:const Icon(Icons.share_outlined),label:const Text('اشتراک‌گذاری')),
        FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))
      ]
    ));
  }
  Future<void> editCash(Map<String,Object?> x) async {final a=TextEditingController(text:'${x['amount']}'),n=TextEditingController(text:'${x['note']??''}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ویرایش تراکنش'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(a,'مبلغ',number:true),field(n,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&(parseNum(a.text)??0)>0){await (await ShopDb.instance.database).update('cash',{'amount':parseNum(a.text),'note':n.text},where:'id=?',whereArgs:[x['id']]);widget.onChanged();setState((){});}}
  Future<void> deleteCash(Map<String,Object?> x) async {final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف تراکنش'),content:const Text('این تراکنش حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await (await ShopDb.instance.database).delete('cash',where:'id=?',whereArgs:[x['id']]);widget.onChanged();setState((){});}}

  Future<void> add() async {String type='برداشت';final amount=TextEditingController(),note=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(title:const Text('ثبت تراکنش صندوق'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,items:const [DropdownMenuItem(value:'برداشت',child:Text('برداشت شخصی / هزینه')),DropdownMenuItem(value:'دریافت',child:Text('دریافت پول'))],onChanged:(v)=>refresh(()=>type=v!),decoration:const InputDecoration(labelText:'نوع تراکنش')),field(amount,'مبلغ افغانی',number:true),field(note,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))])));if(ok==true&&(parseNum(amount.text)??0)>0){await (await ShopDb.instance.database).insert('cash',{'type':type,'amount':parseNum(amount.text),'note':note.text,'created':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}}
  Future<void> closeCashDay() async {
    final db=await ShopDb.instance.database;
    final now=DateTime.now(),start=DateTime(now.year,now.month,now.day),end=start.add(const Duration(days:1));
    final from=start.toIso8601String(),to=end.toIso8601String();
    Future<double> total(String where,List<Object?> args) async {final r=await db.rawQuery('SELECT COALESCE(SUM(amount),0) AS v FROM cash WHERE '+where,args);return ((r.first['v'] as num?)??0).toDouble();}
    final openingSetting=await db.query('settings',where:'key=?',whereArgs:['cash_opening_balance'],limit:1);
    final baseOpening=openingSetting.isEmpty?0.0:((parseNum('${openingSetting.first['value']}'))??0.0);
    final opening=baseOpening+await total("created<? AND type='دریافت'",[from])-await total("created<? AND type='برداشت'",[from]);
    final received=await total("type='دریافت' AND created>=? AND created<?",[from,to]);
    final withdrawn=await total("type='برداشت' AND created>=? AND created<?",[from,to]);
    final expected=opening+received-withdrawn;
    final counted=TextEditingController(text:expected.toStringAsFixed(2)),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('بستن حساب روزانه صندوق'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      _cashInfo('موجودی آغاز روز',opening),_cashInfo('دریافت امروز',received),_cashInfo('برداشت امروز',withdrawn),_cashInfo('موجودی مورد انتظار',expected),
      field(counted,'پول نقدی که واقعاً در صندوق شمردید',number:true),field(note,'یادداشت (اختیاری)')
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت بستن روز'))]));
    final actual=parseNum(counted.text);
    if(ok==true&&actual!=null&&actual>=0){final diff=actual-expected;await db.insert('cash_closings',{'closing_date':start.toIso8601String(),'opening_cash':opening,'received':received,'withdrawn':withdrawn,'expected_cash':expected,'counted_cash':actual,'difference':diff,'note':note.text.trim(),'created':DateTime.now().toIso8601String()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(diff.abs()<0.01?'صندوق با حساب برابر است.':diff>0?'اضافه صندوق: ${money.format(diff)} افغانی':'کسری صندوق: ${money.format(diff.abs())} افغانی')));widget.onChanged();setState((){});}
  }
  Widget _cashInfo(String label,double value)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(label),Text('${money.format(value)} افغانی',style:const TextStyle(fontWeight:FontWeight.w600))]));
  Future<Map<String,double>> summary() async {
    final db=await ShopDb.instance.database;
    final r=await db.rawQuery("SELECT COALESCE(SUM(CASE WHEN type='دریافت' THEN amount ELSE 0 END),0) AS incoming, COALESCE(SUM(CASE WHEN type='برداشت' THEN amount ELSE 0 END),0) AS outgoing FROM cash");
    final setting=await db.query('settings',where:'key=?',whereArgs:['cash_opening_balance'],limit:1);
    final opening=setting.isEmpty?0.0:(parseNum('${setting.first['value']}')??0.0);
    final row=r.first;
    final incoming=((row['incoming'] as num?)??0).toDouble();
    final outgoing=((row['outgoing'] as num?)??0).toDouble();
    return {'opening':opening,'incoming':incoming,'outgoing':outgoing,'balance':opening+incoming-outgoing};
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('ثبت صندوق')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('cash',order:'id DESC'),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final rows=s.data!;
    return Column(children:[
      FutureBuilder<Map<String,double>>(future:summary(),builder:(ctx,b){
        if(!b.hasData)return const SizedBox(height:4);
        final v=b.data!;
        return Padding(padding:const EdgeInsets.fromLTRB(8,8,8,4),child:Row(children:[
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('مجموع دریافت نقدی',style:TextStyle(fontSize:11)),Text('${money.format(v['incoming'])} افغانی',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('مجموع برداشت از صندوق',style:TextStyle(fontSize:11)),Text('${money.format(v['outgoing'])} افغانی',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold))])))),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('موجودی نقدی صندوق',style:TextStyle(fontSize:11)),Text('${money.format(v['balance'])} افغانی',style:const TextStyle(fontWeight:FontWeight.bold))]))))
        ]));
      }),
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),child:OutlinedButton.icon(onPressed:closeCashDay,icon:const Icon(Icons.fact_check_outlined),label:const Text('بستن حساب روزانه و شمارش پول صندوق'))),
      FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('cash_closings',order:'id DESC'),builder:(ctx,cs){if(!cs.hasData||cs.data!.isEmpty)return const SizedBox.shrink();final last=cs.data!.first;final diff=(last['difference'] as num).toDouble();return Card(margin:const EdgeInsets.fromLTRB(12,2,12,6),child:ListTile(dense:true,leading:Icon(Icons.receipt_long,color:diff.abs()<0.01?Colors.green:Colors.orange),title:Text('آخرین بستن صندوق • ${afghanDate(DateTime.parse(last['created'].toString()))}'),subtitle:Text('حساب: ${money.format(last['expected_cash'])} • شمارش: ${money.format(last['counted_cash'])} • ${diff.abs()<0.01?'برابر':diff>0?'اضافه':'کسری'} ${money.format(diff.abs())} افغانی')));}),
      Expanded(child:rows.isEmpty?const Center(child:Text('تراکنش صندوقی ثبت نشده است')):ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){
        final x=rows[i];final note='${x['note']??''}';
        final linked=note.startsWith('دریافت از مشتری')||note.startsWith('پرداخت به مشتری')||note.startsWith('پرداخت به فروشنده')||note.contains('سند #')||note.startsWith('ثبت خودکار از سند');
        return ListTile(leading:Icon(x['type']=='دریافت'?Icons.add_circle:Icons.remove_circle,color:x['type']=='دریافت'?Colors.green:Colors.red),title:Text('${x['type']}'),subtitle:Text('${note}\n${afghanDate(DateTime.parse(x['created'].toString()))}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(visualDensity:VisualDensity.compact,tooltip:'کپی یا اشتراک رسید',onPressed:()=>showCashReceipt(x),icon:const Icon(Icons.receipt_long_outlined,size:20)),linked?Text('${money.format(x['amount'])} افغانی'):PopupMenuButton<String>(onSelected:(v){if(v=='edit')editCash(x);else deleteCash(x);},itemBuilder:(ctx)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))],child:Text('${money.format(x['amount'])} افغانی'))]));
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
 Future<double> balance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM customers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE customer_id=? AND type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type IN ('دریافت','برگشت')),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=? AND type='پرداخت'),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='customer' AND account_id=?),0) AS b",[id,id,id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
 Future<void> form([Map<String,Object?>? x]) async {final n=TextEditingController(text:'${x?['name']??''}'),p=TextEditingController(text:'${x?['phone']??''}'),b=TextEditingController(text:'${x?['opening_balance']??x?['balance']??'0'}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(x==null?'مشتری جدید':'ویرایش مشتری'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(n,'نام مشتری'),field(p,'شماره تماس (اختیاری)'),field(b,'مانده اول دوره (مثبت: مشتری بدهکار؛ منفی: دوکان بدهکار)',number:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&n.text.trim().isNotEmpty){final db=await ShopDb.instance.database;final v={'name':n.text.trim(),'phone':p.text.trim(),'opening_balance':parseNum(b.text)??0.0};if(x==null){await db.insert('customers',v);}else{await db.update('customers',v,where:'id=?',whereArgs:[x['id']]);}setState((){});}}
 Future<void> account(Map<String,Object?> customer) async { if(!mounted)return; await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CustomerAccountPage(customer:customer,onChanged:()=>setState((){})))); }
 Future<void> receive(Map<String,Object?> customer) async {final a=TextEditingController(),n=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('دریافت از ${customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(a,'مبلغ دریافتی (افغانی)',number:true),field(n,'توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت دریافت'))]));final amount=parseNum(a.text)??0;if(ok==true&&amount>0){final source=await chooseFundSource(context,title:'پول دریافتی از مشتری به کجا برود؟');if(source==null)return;final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{final paymentId=await t.insert('customer_payments',{'customer_id':customer['id'],'amount':amount,'type':'دریافت','note':n.text,'created':created,'fund_source':source});if(source=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'دریافت','amount':amount,'note':'دریافت از مشتری ${customer['name']} • ${n.text}','created':created});await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);}});setState((){});}}
 Future<void> receiveAny(List<Map<String,Object?>> customers) async {
   if(customers.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا مشتری ثبت کنید.')));return;}
   int? selected=customers.first['id'] as int;final amount=TextEditingController(),note=TextEditingController();
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:const Text('دریافت پول از مشتری'),content:Column(mainAxisSize:MainAxisSize.min,children:[
     DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'انتخاب مشتری'),items:customers.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']}'))).toList(),onChanged:(v)=>refresh(()=>selected=v)),
     field(amount,'مبلغ دریافتی (افغانی)',number:true),field(note,'توضیحات')
   ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ثبت دریافت'))])));
   final value=parseNum(amount.text)??0;if(ok==true&&selected!=null&&value>0){final customer=customers.firstWhere((x)=>x['id']==selected);await receiveFor(customer,value,note.text);setState((){});}
 }
 Future<void> receiveFor(Map<String,Object?> customer,double amount,String note) async {
   final source=await chooseFundSource(context,title:'پول دریافتی از مشتری به کجا برود؟');if(source==null)return;
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();await db.transaction((t)async{
     final paymentId=await t.insert('customer_payments',{'customer_id':customer['id'],'amount':amount,'type':'دریافت','note':note,'created':created,'fund_source':source});
     if(source=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'دریافت','amount':amount,'note':'دریافت از مشتری ${customer['name']} • $note','created':created});await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);}
   });
 }
 Future<void> settleFromList(Map<String,Object?> customer) async {
  final value=await balance(customer['id'] as int);
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تسویه حساب مشتری'),content:Text('گردش‌های قبلی به سوابق تسویه منتقل می‌شوند و مانده ${money.format(value.abs())} افغانی حفظ می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت تسویه'))]));
  if(ok==true){final db=await ShopDb.instance.database;await db.insert('account_settlements',{'account_type':'customer','account_id':customer['id'],'balance':value,'settled_at':DateTime.now().toIso8601String(),'note':'تسویه حساب مشتری'});if(mounted)setState((){});}
 }
 Future<void> remove(Map<String,Object?> x) async {final db=await ShopDb.instance.database;final used=await db.query('entries',where:'customer_id=?',whereArgs:[x['id']],limit:1);final paid=await db.query('customer_payments',where:'customer_id=?',whereArgs:[x['id']],limit:1);final adjusted=await db.query('account_adjustments',where:'account_type=? AND account_id=?',whereArgs:['customer',x['id']],limit:1);if(used.isNotEmpty||paid.isNotEmpty||adjusted.isNotEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این مشتری سابقه حساب دارد و حذف نمی‌شود.')));return;}final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف مشتری'),content:Text('مشتری ${x['name']} حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await db.delete('customers',where:'id=?',whereArgs:[x['id']]);setState((){});}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>form(),icon:const Icon(Icons.person_add_alt),label:const Text('مشتری جدید')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('customers',order:'id DESC'),builder:(c,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());final customers=s.data!;
   return StatefulBuilder(builder:(context,refresh){
     final visibleCustomers=customers.where((x)=>'${x['name']} ${x['phone']??''}'.toLowerCase().contains(searchController.text.toLowerCase())).toList();
     return Column(children:[
       Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:TextField(controller:searchController,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'جستجوی نام یا شماره مشتری',border:OutlineInputBorder()),onChanged:(_)=>refresh((){}))),
       FutureBuilder<Map<String,double>>(future:totals(customers),builder:(ctx,summary){if(!summary.hasData)return const SizedBox(height:4);final v=summary.data!;return Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:Row(children:[
         Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('جمع بدهی مشتریان',style:TextStyle(fontSize:11)),Text('${money.format(v['debtor'])} افغانی',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold))])))),
         Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('جمع طلب مشتریان',style:TextStyle(fontSize:11)),Text('${money.format(v['creditor'])} افغانی',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold))]))))
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
           return Card(child:ListTile(onTap:()=>account(x),leading:CircleAvatar(child:Text('${visibleCustomers.indexOf(x)+1}',style:TextStyle(fontWeight:FontWeight.bold,color:color))),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''} • $status'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')form(x);else if(v=='delete')remove(x);else if(v=='settle')settleFromList(x);else receive(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'receive',child:Text('ثبت دریافت پول')),PopupMenuItem(value:'settle',child:Text('تسویه حساب')),PopupMenuItem(value:'edit',child:Text('ویرایش مشتری')),PopupMenuItem(value:'delete',child:Text('حذف مشتری'))],child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${money.format(bal.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:color)),Text(status,style:TextStyle(fontSize:11,color:color,fontWeight:FontWeight.bold))]))));
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
  final settlements=await db.query('account_settlements',where:'account_type=? AND account_id=?',whereArgs:['customer',id],orderBy:'settled_at DESC,id DESC',limit:1);
  final cutoff=settlements.isEmpty?null:settlements.first['settled_at'].toString();
  final carry=settlements.isEmpty?opening:((settlements.first['balance'] as num?)??0).toDouble();
  final sales=await db.rawQuery("SELECT entries.*, COALESCE(products.unit,'') AS product_unit FROM entries LEFT JOIN products ON products.id=entries.product_id WHERE entries.customer_id=? AND entries.type='فروش' AND (? IS NULL OR entries.created>?) ORDER BY entries.created ASC, entries.id ASC",[id,cutoff,cutoff]);
  final payments=await db.query('customer_payments',where:'customer_id=? AND (? IS NULL OR created>?)',whereArgs:[id,cutoff,cutoff],orderBy:'created ASC, id ASC');
  final adjustments=await db.query('account_adjustments',where:'account_type=? AND account_id=? AND (? IS NULL OR created>?)',whereArgs:['customer',id,cutoff,cutoff],orderBy:'created ASC,id ASC');
  final events=<Map<String,Object?>>[];
  for(final x in sales){events.add({'kind':'sale','id':x['id'],'created':x['created'],'title':x['product_name'],'qty':x['qty'],'unit':x['product_unit'],'display_qty':x['display_qty'],'display_unit':x['display_unit'],'price':x['price'],'total':x['total'],'paid':x['paid'],'note':x['note']});}
  for(final x in payments){events.add({'kind':'payment','direction':x['type']??'دریافت','id':x['id'],'created':x['created'],'title':x['type']=='پرداخت'?'پرداخت نقدی به مشتری':x['type']=='برگشت'?'برگشت وجه به مشتری':'دریافت نقدی از مشتری','amount':x['amount'],'note':x['note'],'cash_id':x['cash_id'],'fund_source':x['fund_source']??'صندوق مغازه'});}
  for(final x in adjustments){events.add({'kind':'adjustment','direction':x['direction'],'id':x['id'],'created':x['created'],'title':x['direction']=='increase'?'افزایش بدهی مشتری':'افزایش طلب مشتری','amount':x['amount'],'note':x['note']});}
  events.sort((a,b){final d=DateTime.parse(a['created'].toString()).compareTo(DateTime.parse(b['created'].toString()));if(d!=0)return d;return (a['id'] as int).compareTo(b['id'] as int);});
  double salesTotal=0,paidAtSale=0,creditSales=0,received=0,paidToCustomer=0,running=carry;
  for(final e in events){if(e['kind']=='sale'){final total=(e['total'] as num).toDouble(),paid=(e['paid'] as num).toDouble(),debt=total-paid;salesTotal+=total;paidAtSale+=paid;creditSales+=debt;running+=debt;e['delta']=debt;e['running']=running;}else if(e['kind']=='adjustment'){final amount=(e['amount'] as num).toDouble(),delta=e['direction']=='increase'?amount:-amount;running+=delta;e['delta']=delta;e['running']=running;}else{final amount=(e['amount'] as num).toDouble();if(e['direction']=='پرداخت'){paidToCustomer+=amount;running+=amount;e['delta']=amount;}else if(e['direction']=='برگشت'){paidToCustomer+=amount;running-=amount;e['delta']=-amount;}else{received+=amount;running-=amount;e['delta']=-amount;}e['running']=running;}}
  return {'opening':carry,'sales':salesTotal,'settlements':await db.query('account_settlements',where:'account_type=? AND account_id=?',whereArgs:['customer',id],orderBy:'settled_at DESC,id DESC'),'paid':paidAtSale,'creditSales':creditSales,'received':received,'paidToCustomer':paidToCustomer,'balance':running,'events':events};
 }
 Future<void> adjustBalance() async {
  String direction='increase';
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
   title:const Text('ثبت بدهی یا طلب دستی'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع ثبت'),items:const [
     DropdownMenuItem(value:'increase',child:Text('افزایش بدهی مشتری به دوکان')),
     DropdownMenuItem(value:'decrease',child:Text('افزایش طلب مشتری از مغازه')),
    ],onChanged:(v)=>refresh(()=>direction=v??'increase')),
    field(amount,'مبلغ به افغانی',number:true),
    field(note,'علت / توضیحات (مثلاً حساب قدیمی)')
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت در حساب'))]
  )));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final db=await ShopDb.instance.database;
   await db.insert('account_adjustments',{'account_type':'customer','account_id':widget.customer['id'],'direction':direction,'amount':value,'note':note.text.trim(),'created':DateTime.now().toIso8601String()});
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<String> ledgerReceiptText(Map<String,Object?> e,{required String partyType,required String partyName}) async {
  final created=DateTime.tryParse('${e['created']}')??DateTime.now();
  final kind=e['kind'];
  final isItem=kind=='sale'||kind=='purchase';
  final itemTotal=(e['total'] as num?)?.toDouble()??0;
  final paid=(e['paid'] as num?)?.toDouble()??0;
  final amount=(e['amount'] as num?)?.toDouble()??0;
  final title=kind=='sale'?'فاکتور فروش':kind=='purchase'?'فاکتور خرید':kind=='adjustment'?'رسید اصلاح حساب':'رسید دریافت و پرداخت';
  return [
   'دوکان',
   title,
   'شماره سند: ${e['id']}',
   'تاریخ: ${afghanDate(created)}',
   '$partyType: $partyName',
   if(isItem)'کالا: ${e['title']}',
   if(isItem)'مقدار: ${money.format((e['display_qty'] as num?)?.toDouble()??(e['qty'] as num).toDouble())} ${e['display_unit']??e['unit']??''}',
   if(isItem)'قیمت واحد: ${money.format(((e['display_qty'] as num?)?.toDouble()??(e['qty'] as num).toDouble())>0?itemTotal/((e['display_qty'] as num?)?.toDouble()??(e['qty'] as num).toDouble()):e['price'])} افغانی',
   if(isItem)'مجموع: ${money.format(itemTotal)} افغانی',
   if(isItem)'پرداخت‌شده: ${money.format(paid)} افغانی',
   if(isItem)'باقی‌مانده: ${money.format(itemTotal-paid)} افغانی',
   if(!isItem)'نوع گردش: ${kind=='adjustment'?(e['direction']=='increase'?'افزایش بدهی':'افزایش طلب'):e['direction']??e['type']??''}',
   if(!isItem)'مبلغ: ${money.format(amount)} افغانی',
   if(!isItem)'منبع پول: ${e['fund_source']??'صندوق مغازه'}',
   if('${e['note']??''}'.trim().isNotEmpty)'توضیحات: ${e['note']}',
   'واحد پول: افغانی (AFN)',
   'با تشکر'
  ].join('\n');
 }
 Future<void> shareLedgerReceipt(Map<String,Object?> e,{required String partyType,required String partyName}) async {
  final receipt=await ledgerReceiptText(e,partyType:partyType,partyName:partyName);
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
   title:const Text('رسید و فاکتور'),
   content:SingleChildScrollView(child:SelectableText(receipt,textDirection:ui.TextDirection.rtl)),
   actions:[
    TextButton.icon(onPressed:(){Clipboard.setData(ClipboardData(text:receipt));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رسید کپی شد')));},icon:const Icon(Icons.copy),label:const Text('کپی')),
    TextButton.icon(onPressed:()=>Share.share(receipt,subject:'رسید دوکان'),icon:const Icon(Icons.share_outlined),label:const Text('اشتراک‌گذاری')),
    FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))
   ]
  ));
 }
 Future<void> editLedgerEvent(Map<String,Object?> e) async {
  final kind=e['kind'];
  String direction=(kind=='adjustment'?e['direction']:e['direction']??'دریافت').toString();
  String fundSource=(e['fund_source']??'صندوق مغازه').toString();
  final amount=TextEditingController(text:'${e['amount']??''}');
  final note=TextEditingController(text:'${e['note']??''}');
  final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
   title:const Text('ویرایش گردش حساب'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    if(kind=='payment') DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع گردش'),items:const [
     DropdownMenuItem(value:'دریافت',child:Text('دریافت پول از مشتری')),
     DropdownMenuItem(value:'پرداخت',child:Text('پرداخت نقدی به مشتری')),
     DropdownMenuItem(value:'برگشت',child:Text('برگشت وجه فروش')),
    ],onChanged:(v)=>refresh(()=>direction=v??'دریافت')),
    if(kind=='payment') DropdownButtonFormField<String>(value:fundSource,decoration:const InputDecoration(labelText:'منبع پول'),items:const [DropdownMenuItem(value:'صندوق مغازه',child:Text('صندوق دوکان (تغییر موجودی صندوق)')),DropdownMenuItem(value:'پول شخصی',child:Text('پول شخصی (بدون تغییر صندوق)'))],onChanged:(v)=>refresh(()=>fundSource=v??'صندوق مغازه')),
    if(kind=='adjustment') DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع اصلاح حساب'),items:const [
     DropdownMenuItem(value:'increase',child:Text('افزایش بدهی مشتری')),
     DropdownMenuItem(value:'decrease',child:Text('افزایش طلب مشتری')),
    ],onChanged:(v)=>refresh(()=>direction=v??'increase')),
    field(amount,'مبلغ (افغانی)',number:true),field(note,'توضیحات')
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره تغییرات'))]
  )));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final db=await ShopDb.instance.database;
   await db.transaction((t)async{
    if(kind=='adjustment'){
     await t.update('account_adjustments',{'direction':direction,'amount':value,'note':note.text.trim()},where:'id=? AND account_type=? AND account_id=?',whereArgs:[e['id'],'customer',widget.customer['id']]);
    }else{
     final cashId=e['cash_id'];
     await t.update('customer_payments',{'type':direction,'amount':value,'note':note.text.trim(),'fund_source':fundSource},where:'id=? AND customer_id=?',whereArgs:[e['id'],widget.customer['id']]);
     if(fundSource=='صندوق مغازه'){
      final cashValues={'type':direction=='دریافت'?'دریافت':'برداشت','amount':value,'note':'${direction=='دریافت'?'دریافت از مشتری':'پرداخت به مشتری'} ${widget.customer['name']} • ${note.text.trim()}'};
      if(cashId!=null){await t.update('cash',cashValues,where:'id=?',whereArgs:[cashId]);}
      else{final newCashId=await t.insert('cash',{...cashValues,'created':e['created']??DateTime.now().toIso8601String()});await t.update('customer_payments',{'cash_id':newCashId},where:'id=?',whereArgs:[e['id']]);}
     }else{
      if(cashId!=null)await t.delete('cash',where:'id=?',whereArgs:[cashId]);
      await t.update('customer_payments',{'cash_id':null},where:'id=?',whereArgs:[e['id']]);
     }
    }
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<void> deleteLedgerEvent(Map<String,Object?> e) async {
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف گردش حساب'),content:const Text('این مورد از سوابق حساب حذف شود؟ اگر دریافت یا پرداخت نقدی باشد، سند متناظر صندوق هم حذف می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
  if(ok==true){
   final db=await ShopDb.instance.database;
   await db.transaction((t)async{
    if(e['kind']=='adjustment'){
     await t.delete('account_adjustments',where:'id=? AND account_type=? AND account_id=?',whereArgs:[e['id'],'customer',widget.customer['id']]);
    }else{
     final cashId=e['cash_id'];
     await t.delete('customer_payments',where:'id=? AND customer_id=?',whereArgs:[e['id'],widget.customer['id']]);
     if(cashId!=null) await t.delete('cash',where:'id=?',whereArgs:[cashId]);
    }
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<void> settleAccount() async {
  final v=await loadLedger();final balance=(v['balance'] as num).toDouble();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تسویه حساب مشتری'),content:Text('گردش‌های فعلی به سوابق تسویه منتقل می‌شوند. مانده ${money.format(balance.abs())} افغانی (${balance>0?'بدهکار':balance<0?'طلبکار':'تسویه'}) بدون تغییر به دوره بعد منتقل می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت تسویه'))]));
  if(ok==true){final db=await ShopDb.instance.database;await db.insert('account_settlements',{'account_type':'customer','account_id':widget.customer['id'],'balance':balance,'settled_at':DateTime.now().toIso8601String(),'note':'تسویه حساب مشتری'});widget.onChanged();if(mounted)setState((){});}
 }
 Future<void> showSettlementHistory() async {
  final v=await loadLedger();final rows=v['settlements'] as List<Map<String,Object?>>;
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('سوابق تسویه حساب'),content:SizedBox(width:360,child:rows.isEmpty?const Text('هنوز تسویه‌ای ثبت نشده است'):ListView(shrinkWrap:true,children:rows.map((x){final b=(x['balance'] as num).toDouble();return ListTile(dense:true,leading:const Icon(Icons.history),title:Text(afghanDate(DateTime.parse(x['settled_at'].toString()))),subtitle:Text(b>0?'مانده بدهی مشتری':b<0?'مانده طلب مشتری':'حساب صفر شده'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'رسید تسویه',onPressed:()=>shareLedgerReceipt({'id':x['id'],'created':x['settled_at'],'kind':'adjustment','direction':b>=0?'increase':'decrease','amount':b.abs(),'note':x['note']},partyType:'مشتری',partyName:'${widget.customer['name']}'),icon:const Icon(Icons.receipt_long_outlined,size:19)),Text('${money.format(b.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:statusColor(b)))]));}).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))]));
 }
 String status(double b)=>b>0.005?'مشتری بدهکار است':b< -0.005?'دوکان به مشتری بدهکار است':'حساب تسویه است';
 Color statusColor(double b)=>b>0.005?Colors.red:b< -0.005?Colors.green:Colors.blueGrey;
 Future<void> receive() async {
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('دریافت پول از ${widget.customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(amount,'مبلغ دریافتی (افغانی)',number:true),field(note,'توضیحات / شماره رسید')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ادامه'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final source=await chooseFundSource(context,title:'پول دریافتی از مشتری به کجا برود؟');if(source==null)return;
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();
   await db.transaction((t)async{
    final paymentId=await t.insert('customer_payments',{'customer_id':widget.customer['id'],'amount':value,'type':'دریافت','note':note.text.trim(),'created':created,'fund_source':source});
    if(source=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'دریافت','amount':value,'note':'دریافت از مشتری ${widget.customer['name']} • ${note.text.trim()}','created':created});await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);}
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 
 Future<void> payCustomer() async {
  final current=await loadLedger();final currentBalance=(current['balance'] as num).toDouble();
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('پرداخت نقدی به مشتری: ${widget.customer['name']}'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(currentBalance< -0.005?'طلب فعلی مشتری: ${money.format(currentBalance.abs())} افغانی':'پرداخت جدید حتی بدون خرید کالا؛ مبلغ پرداختی به حساب مشتری اضافه می‌شود.',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold)),field(amount,'مبلغ پرداختی (افغانی)',number:true),field(note,'توضیحات / شماره رسید')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ادامه'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true){
   if(value<=0){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مبلغ باید بیشتر از صفر باشد.')));return;}
   final source=await chooseFundSource(context,title:'پول پرداختی به مشتری از کجا باشد؟');if(source==null)return;
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();
   await db.transaction((t)async{
    final paymentId=await t.insert('customer_payments',{'customer_id':widget.customer['id'],'amount':value,'type':'پرداخت','note':note.text.trim(),'created':created,'fund_source':source});
    if(source=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'برداشت','amount':value,'note':'پرداخت به مشتری ${widget.customer['name']} • ${note.text.trim()}','created':created});await t.update('customer_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);}
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text('حساب مشتری: ${widget.customer['name']}'),actions:[IconButton(tooltip:'ثبت بدهی یا طلب دستی',onPressed:adjustBalance,icon:const Icon(Icons.edit_note)),IconButton(tooltip:'سوابق تسویه',onPressed:showSettlementHistory,icon:const Icon(Icons.history)),IconButton(tooltip:'تسویه حساب',onPressed:settleAccount,icon:const Icon(Icons.archive_outlined)),IconButton(tooltip:'پرداخت نقدی به مشتری (حتی بدون خرید)',onPressed:payCustomer,icon:const Icon(Icons.outbound)),IconButton(tooltip:'ثبت دریافت',onPressed:receive,icon:const Icon(Icons.add_card))]),
  floatingActionButton:FloatingActionButton.extended(onPressed:receive,icon:const Icon(Icons.payments_outlined),label:const Text('ثبت دریافت پول')),
  body:FutureBuilder<Map<String,Object?>>(future:loadLedger(),builder:(context,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final v=s.data!,balance=(v['balance'] as num).toDouble(),events=v['events'] as List<Map<String,Object?>>,color=statusColor(balance);
   Widget metric(String label,Object? value,{Color? tint})=>Expanded(child:Container(margin:const EdgeInsets.all(4),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:5),Text('${money.format(value)} افغانی',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:tint),maxLines:1,overflow:TextOverflow.ellipsis)])));
   return Column(children:[
    Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(12,10,12,5),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:color.withOpacity(.09),borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(.35))),child:Column(children:[const Text('مانده نهایی حساب',style:TextStyle(fontSize:12,color:Colors.blueGrey)),const SizedBox(height:4),Text('${money.format(balance.abs())} افغانی',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:color)),Text(status(balance),style:TextStyle(color:color,fontWeight:FontWeight.bold)),if(widget.customer['phone']!=null&&widget.customer['phone'].toString().isNotEmpty)Text(widget.customer['phone'].toString(),style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Row(children:[metric('مجموع فروش به مشتری',v['sales']),metric('نقد دریافت‌شده هنگام فروش',v['paid'])]),
    Row(children:[metric('بدهی ایجادشده',v['creditSales'],tint:Colors.red),metric('دریافت‌های بعدی از مشتری',v['received'],tint:Colors.green)]),
    Row(children:[metric('پرداخت‌های بعدی به مشتری',v['paidToCustomer'],tint:Colors.orange),metric('مانده اول دوره',v['opening'])]),
    Padding(padding:const EdgeInsets.fromLTRB(14,8,14,4),child:Row(children:[const Expanded(child:Text('گردش حساب مشتری',style:TextStyle(fontWeight:FontWeight.bold,fontSize:15))),Text('${events.length} سند',style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Expanded(child:events.isEmpty?ListView(children:[if((v['opening'] as num)!=0)Card(child:ListTile(leading:const Icon(Icons.flag_outlined),title:const Text('مانده اول دوره'),subtitle:const Text('مانده انتقالی حساب'),trailing:Text('${money.format((v['opening'] as num).abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:statusColor((v['opening'] as num).toDouble()))))),const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('هنوز خرید یا دریافتی دیگری ثبت نشده است')))]):ListView.builder(padding:const EdgeInsets.fromLTRB(10,2,10,90),itemCount:events.length+(v['opening']==0?0:1),itemBuilder:(context,index){
     if(index==events.length){final opening=(v['opening'] as num).toDouble();return Card(child:ListTile(dense:true,leading:const Icon(Icons.flag_outlined),title:const Text('مانده اول دوره'),subtitle:const Text('مانده انتقالی حساب'),trailing:Text('${money.format(opening.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:statusColor(opening)))));}
     final e=events[events.length-1-index],sale=e['kind']=='sale',incoming=e['direction']=='دریافت',delta=(e['delta'] as num).toDouble(),running=(e['running'] as num).toDouble(),created=DateTime.parse(e['created'].toString());
     final date=afghanDate(created);
     return Card(margin:const EdgeInsets.symmetric(vertical:3),child:ListTile(dense:true,leading:CircleAvatar(radius:17,backgroundColor:(sale?Colors.red:(incoming?Colors.green:Colors.orange)).withOpacity(.10),child:Icon(sale?Icons.shopping_bag_outlined:Icons.payments_outlined,size:18,color:sale?Colors.red:(incoming?Colors.green:Colors.orange))),title:Text(sale?'فروش کالا به مشتری: ${e['title']}':e['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),subtitle:Text(sale?'${money.format(e['qty'])} ${e['unit']} × ${money.format(e['price'])} • جمع فروش: ${money.format(e['total'])} • نقد دریافت‌شده هنگام فروش: ${money.format(e['paid'])} • باقی‌مانده نسیه: ${money.format(delta)}\n$date':'${e['note']??''} • منبع: ${e['fund_source']??'صندوق مغازه'} • $date\nمانده پس از ثبت: ${money.format(running.abs())} ${running>0?'بدهکار':running<0?'طلبکار':'تسویه'}',style:const TextStyle(fontSize:11)),isThreeLine:true,trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(visualDensity:VisualDensity.compact,tooltip:'کپی یا اشتراک رسید',onPressed:()=>shareLedgerReceipt(e,partyType:'مشتری',partyName:'${widget.customer['name']}'),icon:const Icon(Icons.receipt_long_outlined,size:20)),Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${delta>0?'+':delta<0?'-':''}${money.format(delta.abs())}',style:TextStyle(fontWeight:FontWeight.bold,color:sale?Colors.red:(incoming?Colors.green:Colors.orange))),Text('مانده ${money.format(running.abs())}',style:TextStyle(fontSize:10,color:statusColor(running)))]),if(!sale)PopupMenuButton<String>(tooltip:'ویرایش یا حذف گردش',onSelected:(v){if(v=='edit')editLedgerEvent(e);else if(v=='delete')deleteLedgerEvent(e);},itemBuilder:(c)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش گردش')),PopupMenuItem(value:'delete',child:Text('حذف گردش'))])])));
    })),
   ]);
  })
 );
}

class SuppliersPage extends StatefulWidget {const SuppliersPage({super.key});@override State<SuppliersPage> createState()=>_SuppliersPageState();}
class _SuppliersPageState extends State<SuppliersPage>{
 Future<double> balance(int id) async {final db=await ShopDb.instance.database;final r=await db.rawQuery("SELECT COALESCE((SELECT opening_balance FROM suppliers WHERE id=?),0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE supplier_id=? AND type='خرید'),0)-COALESCE((SELECT SUM(CASE WHEN type='دریافت' THEN -amount ELSE amount END) FROM supplier_payments WHERE supplier_id=?),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='supplier' AND account_id=?),0) AS b",[id,id,id,id]);return ((r.first['b'] as num?)??0).toDouble();}
 Future<void> form([Map<String,Object?>? x]) async {final n=TextEditingController(text:'${x?['name']??''}'),p=TextEditingController(text:'${x?['phone']??''}'),a=TextEditingController(text:'${x?['address']??''}'),b=TextEditingController(text:'${x?['opening_balance']??'0'}');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(x==null?'فروشنده / دوکان جدید':'ویرایش فروشنده'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(n,'نام دوکان یا فروشنده'),field(p,'شماره تماس (اختیاری)'),field(a,'آدرس یا محل خرید (اختیاری)'),field(b,'مانده اول دوره (مثبت: ما بدهکار؛ منفی: فروشنده بدهکار)',number:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&n.text.trim().isNotEmpty){final db=await ShopDb.instance.database;final v={'name':n.text.trim(),'phone':p.text.trim(),'address':a.text.trim(),'opening_balance':parseNum(b.text)??0.0};if(x==null){await db.insert('suppliers',v);}else{await db.update('suppliers',v,where:'id=?',whereArgs:[x['id']]);}if(mounted)setState((){});}}
 Future<void> account(Map<String,Object?> supplier) async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>SupplierAccountPage(supplier:supplier,onChanged:(){if(mounted)setState((){});})));if(mounted)setState((){});}
 Future<void> settleFromList(Map<String,Object?> supplier) async {
  final value=await balance(supplier['id'] as int);
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تسویه حساب فروشنده'),content:Text('گردش‌های قبلی به سوابق تسویه منتقل می‌شوند و مانده ${money.format(value.abs())} افغانی حفظ می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت تسویه'))]));
  if(ok==true){final db=await ShopDb.instance.database;await db.insert('account_settlements',{'account_type':'supplier','account_id':supplier['id'],'balance':value,'settled_at':DateTime.now().toIso8601String(),'note':'تسویه حساب فروشنده'});if(mounted)setState((){});}
 }
 Future<void> remove(Map<String,Object?> x) async {final db=await ShopDb.instance.database;final used=await db.query('entries',where:'supplier_id=?',whereArgs:[x['id']],limit:1);final paid=await db.query('supplier_payments',where:'supplier_id=?',whereArgs:[x['id']],limit:1);final adjusted=await db.query('account_adjustments',where:'account_type=? AND account_id=?',whereArgs:['supplier',x['id']],limit:1);if(used.isNotEmpty||paid.isNotEmpty||adjusted.isNotEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این فروشنده سابقه حساب دارد و حذف نمی‌شود.')));return;}final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف فروشنده'),content:Text('فروشنده ${x['name']} حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));if(ok==true){await db.delete('suppliers',where:'id=?',whereArgs:[x['id']]);if(mounted)setState((){});}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,floatingActionButton:FloatingActionButton.extended(onPressed:()=>form(),icon:const Icon(Icons.store_mall_directory_outlined),label:const Text('فروشنده جدید')),body:FutureBuilder<List<Map<String,Object?>>>(future:ShopDb.instance.rows('suppliers',order:'id DESC'),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return const Center(child:Text('هنوز فروشنده‌ای ثبت نشده است'));return ListView.builder(padding:const EdgeInsets.only(bottom:90),itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return FutureBuilder<double>(future:balance(x['id'] as int),builder:(c,b){final bal=b.data??0;final tint=bal>0.005?Colors.red:bal< -0.005?Colors.green:Colors.blueGrey;return Card(child:ListTile(onTap:()=>account(x),leading:CircleAvatar(child:Text('${i+1}',style:const TextStyle(fontWeight:FontWeight.bold))),title:Text('${x['name']}'),subtitle:Text('${x['phone']??''} • لمس برای صفحه حسابداری'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')form(x);else if(v=='delete')remove(x);else if(v=='settle')settleFromList(x);else account(x);},itemBuilder:(c)=>const [PopupMenuItem(value:'account',child:Text('مشاهده صفحه حسابداری')),PopupMenuItem(value:'settle',child:Text('تسویه حساب')),PopupMenuItem(value:'edit',child:Text('ویرایش فروشنده')),PopupMenuItem(value:'delete',child:Text('حذف فروشنده'))],child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${money.format(bal.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:tint)),Text(bal>0.005?'بدهی ما':bal< -0.005?'طلب ما':'تسویه',style:TextStyle(fontSize:10,color:tint))]))));});});}));
}

class SupplierAccountPage extends StatefulWidget {
 final Map<String,Object?> supplier; final VoidCallback onChanged;
 const SupplierAccountPage({super.key,required this.supplier,required this.onChanged});
 @override State<SupplierAccountPage> createState()=>_SupplierAccountPageState();
}
class _SupplierAccountPageState extends State<SupplierAccountPage>{
 int get supplierId=>widget.supplier['id'] as int;
 Future<Map<String,Object?>> loadLedger() async {
  final db=await ShopDb.instance.database;
  final sr=await db.query('suppliers',where:'id=?',whereArgs:[supplierId],limit:1);
  final opening=sr.isEmpty?0.0:((sr.first['opening_balance'] as num?)??0).toDouble();
  final settlements=await db.query('account_settlements',where:'account_type=? AND account_id=?',whereArgs:['supplier',supplierId],orderBy:'settled_at DESC,id DESC',limit:1);
  final cutoff=settlements.isEmpty?null:settlements.first['settled_at'].toString();
  final carry=settlements.isEmpty?opening:((settlements.first['balance'] as num?)??0).toDouble();
  final purchases=await db.rawQuery("SELECT entries.*,COALESCE(products.unit,'') AS product_unit FROM entries LEFT JOIN products ON products.id=entries.product_id WHERE entries.supplier_id=? AND entries.type='خرید' AND (? IS NULL OR entries.created>?) ORDER BY entries.created ASC,entries.id ASC",[supplierId,cutoff,cutoff]);
  final payments=await db.query('supplier_payments',where:'supplier_id=? AND (? IS NULL OR created>?)',whereArgs:[supplierId,cutoff,cutoff],orderBy:'created ASC,id ASC');
  final adjustments=await db.query('account_adjustments',where:'account_type=? AND account_id=? AND (? IS NULL OR created>?)',whereArgs:['supplier',supplierId,cutoff,cutoff],orderBy:'created ASC,id ASC');
  final events=<Map<String,Object?>>[];
  for(final x in purchases){events.add({'kind':'purchase','id':x['id'],'created':x['created'],'title':x['product_name'],'qty':x['qty'],'unit':x['product_unit'],'display_qty':x['display_qty'],'display_unit':x['display_unit'],'price':x['price'],'total':x['total'],'paid':x['paid'],'note':x['note']});}
  for(final x in payments){events.add({'kind':'payment','id':x['id'],'created':x['created'],'amount':x['amount'],'note':x['note'],'type':x['type']??'پرداخت','direction':x['type']??'پرداخت','cash_id':x['cash_id'],'fund_source':x['fund_source']??'صندوق مغازه'});}
  for(final x in adjustments){events.add({'kind':'adjustment','id':x['id'],'created':x['created'],'direction':x['direction'],'amount':x['amount'],'note':x['note']});}
  events.sort((a,b){final d=DateTime.parse(a['created'].toString()).compareTo(DateTime.parse(b['created'].toString()));if(d!=0)return d;return (a['id'] as int).compareTo(b['id'] as int);});
  double purchaseTotal=0,paidAtPurchase=0,purchaseDebt=0,paymentsTotal=0,receivedFromSupplier=0,running=carry;
  for(final e in events){if(e['kind']=='purchase'){final total=(e['total'] as num).toDouble(),paid=(e['paid'] as num).toDouble(),debt=total-paid;purchaseTotal+=total;paidAtPurchase+=paid;purchaseDebt+=debt;running+=debt;e['delta']=debt;}else if(e['kind']=='adjustment'){final amount=(e['amount'] as num).toDouble(),delta=e['direction']=='increase'?amount:-amount;running+=delta;e['delta']=delta;}else{final amount=(e['amount'] as num).toDouble();if(e['direction']=='دریافت'){receivedFromSupplier+=amount;running-=amount;e['delta']=-amount;}else{paymentsTotal+=amount;running-=amount;e['delta']=-amount;}}e['running']=running;}
  return {'opening':carry,'purchases':purchaseTotal,'settlements':await db.query('account_settlements',where:'account_type=? AND account_id=?',whereArgs:['supplier',supplierId],orderBy:'settled_at DESC,id DESC'),'paidAtPurchase':paidAtPurchase,'purchaseDebt':purchaseDebt,'payments':paymentsTotal,'received':receivedFromSupplier,'balance':running,'events':events};
 }
 Future<void> adjustBalance() async {
  String direction='increase';
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
   title:const Text('ثبت بدهی یا طلب دستی'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع ثبت'),items:const [
     DropdownMenuItem(value:'increase',child:Text('افزایش بدهی دوکان به فروشنده')),
     DropdownMenuItem(value:'decrease',child:Text('افزایش طلب دوکان از فروشنده')),
    ],onChanged:(v)=>refresh(()=>direction=v??'increase')),
    field(amount,'مبلغ به افغانی',number:true),
    field(note,'علت / توضیحات (مثلاً خرید یا حساب قدیمی)')
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت در حساب'))]
  )));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final db=await ShopDb.instance.database;
   await db.insert('account_adjustments',{'account_type':'supplier','account_id':supplierId,'direction':direction,'amount':value,'note':note.text.trim(),'created':DateTime.now().toIso8601String()});
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<void> receiveFromSupplier() async {
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('دریافت پول از فروشنده ${widget.supplier['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(amount,'مبلغ دریافتی (افغانی)',number:true),field(note,'علت / توضیحات')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ادامه'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();
   await db.transaction((t)async{
    final id=await t.insert('supplier_payments',{'supplier_id':supplierId,'amount':value,'type':'دریافت','note':note.text.trim(),'created':created,'fund_source':'صندوق مغازه'});
    final cashId=await t.insert('cash',{'type':'دریافت','amount':value,'note':'دریافت از فروشنده ${widget.supplier['name']} • ${note.text.trim()}','created':created});await t.update('supplier_payments',{'cash_id':cashId},where:'id=?',whereArgs:[id]);
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 
 Future<String> ledgerReceiptText(Map<String,Object?> e,{required String partyType,required String partyName}) async {
  final created=DateTime.tryParse('${e['created']}')??DateTime.now();
  final kind=e['kind'];
  final isItem=kind=='sale'||kind=='purchase';
  final itemTotal=(e['total'] as num?)?.toDouble()??0;
  final paid=(e['paid'] as num?)?.toDouble()??0;
  final amount=(e['amount'] as num?)?.toDouble()??0;
  final title=kind=='sale'?'فاکتور فروش':kind=='purchase'?'فاکتور خرید':kind=='adjustment'?'رسید اصلاح حساب':'رسید دریافت و پرداخت';
  return [
   'دوکان',
   title,
   'شماره سند: ${e['id']}',
   'تاریخ: ${afghanDate(created)}',
   '$partyType: $partyName',
   if(isItem)'کالا: ${e['title']}',
   if(isItem)'مقدار: ${money.format(e['qty'])} ${e['unit']??''}',
   if(isItem)'قیمت واحد: ${money.format(e['price'])} افغانی',
   if(isItem)'مجموع: ${money.format(itemTotal)} افغانی',
   if(isItem)'پرداخت‌شده: ${money.format(paid)} افغانی',
   if(isItem)'باقی‌مانده: ${money.format(itemTotal-paid)} افغانی',
   if(!isItem)'نوع گردش: ${kind=='adjustment'?(e['direction']=='increase'?'افزایش بدهی':'افزایش طلب'):e['direction']??e['type']??''}',
   if(!isItem)'مبلغ: ${money.format(amount)} افغانی',
   if(!isItem)'منبع پول: ${e['fund_source']??'صندوق مغازه'}',
   if('${e['note']??''}'.trim().isNotEmpty)'توضیحات: ${e['note']}',
   'واحد پول: افغانی (AFN)',
   'با تشکر'
  ].join('\n');
 }
 Future<void> shareLedgerReceipt(Map<String,Object?> e,{required String partyType,required String partyName}) async {
  final receipt=await ledgerReceiptText(e,partyType:partyType,partyName:partyName);
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
   title:const Text('رسید و فاکتور'),
   content:SingleChildScrollView(child:SelectableText(receipt,textDirection:ui.TextDirection.rtl)),
   actions:[
    TextButton.icon(onPressed:(){Clipboard.setData(ClipboardData(text:receipt));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رسید کپی شد')));},icon:const Icon(Icons.copy),label:const Text('کپی')),
    TextButton.icon(onPressed:()=>Share.share(receipt,subject:'رسید دوکان'),icon:const Icon(Icons.share_outlined),label:const Text('اشتراک‌گذاری')),
    FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))
   ]
  ));
 }
 Future<void> editLedgerEvent(Map<String,Object?> e) async {
  final kind=e['kind'];
  String direction=(kind=='adjustment'?e['direction']:e['direction']??'پرداخت').toString();
  String fundSource=(e['fund_source']??'صندوق مغازه').toString();
  final amount=TextEditingController(text:'${e['amount']??''}');
  final note=TextEditingController(text:'${e['note']??''}');
  final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
   title:const Text('ویرایش گردش حساب فروشنده'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    if(kind=='payment') DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع گردش'),items:const [
     DropdownMenuItem(value:'پرداخت',child:Text('پرداخت پول به فروشنده')),
     DropdownMenuItem(value:'دریافت',child:Text('دریافت پول از فروشنده')),
    ],onChanged:(v)=>refresh(()=>direction=v??'پرداخت')),
    if(kind=='adjustment') DropdownButtonFormField<String>(value:direction,decoration:const InputDecoration(labelText:'نوع اصلاح حساب'),items:const [
     DropdownMenuItem(value:'increase',child:Text('افزایش بدهی دوکان')),
     DropdownMenuItem(value:'decrease',child:Text('افزایش طلب دوکان')),
    ],onChanged:(v)=>refresh(()=>direction=v??'increase')),
    field(amount,'مبلغ (افغانی)',number:true),field(note,'توضیحات')
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره تغییرات'))]
  )));
  final value=parseNum(amount.text)??0;
  if(ok==true&&value>0){
   final db=await ShopDb.instance.database;
   await db.transaction((t)async{
    if(kind=='adjustment'){
     await t.update('account_adjustments',{'direction':direction,'amount':value,'note':note.text.trim()},where:'id=? AND account_type=? AND account_id=?',whereArgs:[e['id'],'supplier',supplierId]);
    }else{
     final cashId=e['cash_id'];
     await t.update('supplier_payments',{'type':direction,'amount':value,'note':note.text.trim(),'fund_source':fundSource},where:'id=? AND supplier_id=?',whereArgs:[e['id'],supplierId]);
     if(fundSource=='صندوق مغازه'){
      final cashValues={'type':direction=='دریافت'?'دریافت':'برداشت','amount':value,'note':'${direction=='دریافت'?'دریافت از فروشنده':'پرداخت به فروشنده'} ${widget.supplier['name']} • ${note.text.trim()}'};
      if(cashId!=null){await t.update('cash',cashValues,where:'id=?',whereArgs:[cashId]);}
      else{final newCashId=await t.insert('cash',{...cashValues,'created':e['created']??DateTime.now().toIso8601String()});await t.update('supplier_payments',{'cash_id':newCashId},where:'id=?',whereArgs:[e['id']]);}
     }else{
      if(cashId!=null)await t.delete('cash',where:'id=?',whereArgs:[cashId]);
      await t.update('supplier_payments',{'cash_id':null},where:'id=?',whereArgs:[e['id']]);
     }
    }
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<void> deleteLedgerEvent(Map<String,Object?> e) async {
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف گردش حساب فروشنده'),content:const Text('این مورد از سوابق حساب حذف شود؟ سند متناظر صندوق هم حذف می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
  if(ok==true){
   final db=await ShopDb.instance.database;
   await db.transaction((t)async{
    if(e['kind']=='adjustment'){
     await t.delete('account_adjustments',where:'id=? AND account_type=? AND account_id=?',whereArgs:[e['id'],'supplier',supplierId]);
    }else{
     final cashId=e['cash_id'];
     await t.delete('supplier_payments',where:'id=? AND supplier_id=?',whereArgs:[e['id'],supplierId]);
     if(cashId!=null) await t.delete('cash',where:'id=?',whereArgs:[cashId]);
    }
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 Future<void> settleAccount() async {
  final v=await loadLedger();final balance=(v['balance'] as num).toDouble();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تسویه حساب فروشنده'),content:Text('گردش‌های فعلی به سوابق تسویه منتقل می‌شوند. مانده ${money.format(balance.abs())} افغانی (${balance>0?'بدهی ما':balance<0?'طلب ما':'تسویه'}) بدون تغییر به دوره بعد منتقل می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت تسویه'))]));
  if(ok==true){final db=await ShopDb.instance.database;await db.insert('account_settlements',{'account_type':'supplier','account_id':supplierId,'balance':balance,'settled_at':DateTime.now().toIso8601String(),'note':'تسویه حساب فروشنده'});widget.onChanged();if(mounted)setState((){});}
 }
 Future<void> showSettlementHistory() async {
  final v=await loadLedger();final rows=v['settlements'] as List<Map<String,Object?>>;
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('سوابق تسویه حساب'),content:SizedBox(width:360,child:rows.isEmpty?const Text('هنوز تسویه‌ای ثبت نشده است'):ListView(shrinkWrap:true,children:rows.map((x){final b=(x['balance'] as num).toDouble();return ListTile(dense:true,leading:const Icon(Icons.history),title:Text(afghanDate(DateTime.parse(x['settled_at'].toString()))),subtitle:Text(b>0?'بدهی ما به فروشنده':b<0?'طلب ما از فروشنده':'حساب صفر شده'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'رسید تسویه',onPressed:()=>shareLedgerReceipt({'id':x['id'],'created':x['settled_at'],'kind':'adjustment','direction':b>=0?'increase':'decrease','amount':b.abs(),'note':x['note']},partyType:'فروشنده',partyName:'${widget.supplier['name']}'),icon:const Icon(Icons.receipt_long_outlined,size:19)),Text('${money.format(b.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:tint(b)))]));}).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))]));
 }
 Color tint(double b)=>b>0.005?Colors.red:b< -0.005?Colors.green:Colors.blueGrey;
 String status(double b)=>b>0.005?'ما به فروشنده بدهکاریم':b< -0.005?'فروشنده به ما بدهکار است':'حساب تسویه است';
 Future<void> pay() async {
  final ledger=await loadLedger();final balance=(ledger['balance'] as num).toDouble();
  final amount=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('پرداخت نقدی به فروشنده ${widget.supplier['name']}'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(balance>0.005?'بدهی فعلی به فروشنده: ${money.format(balance)} افغانی':'پرداخت پیش‌پرداخت حتی بدون خرید کالا؛ در حساب فروشنده ثبت می‌شود.',style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold)),field(amount,'مبلغ پرداختی (افغانی)',number:true),field(note,'توضیحات / شماره رسید')]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ادامه'))]));
  final value=parseNum(amount.text)??0;
  if(ok==true){
   if(value<=0){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مبلغ باید بیشتر از صفر باشد.')));return;}
   final source=await chooseFundSource(context,title:'پول پرداختی به فروشنده از کجا باشد؟');if(source==null)return;
   final db=await ShopDb.instance.database,created=DateTime.now().toIso8601String();
   await db.transaction((t)async{
    final paymentId=await t.insert('supplier_payments',{'supplier_id':supplierId,'amount':value,'note':note.text.trim(),'created':created,'fund_source':source});
    if(source=='صندوق مغازه'){final cashId=await t.insert('cash',{'type':'برداشت','amount':value,'note':'پرداخت به فروشنده ${widget.supplier['name']} • ${note.text.trim()}','created':created});await t.update('supplier_payments',{'cash_id':cashId},where:'id=?',whereArgs:[paymentId]);}
   });
   widget.onChanged();if(mounted)setState((){});
  }
 }
 
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text('حساب فروشنده: ${widget.supplier['name']}'),actions:[IconButton(tooltip:'ثبت بدهی یا طلب دستی',onPressed:adjustBalance,icon:const Icon(Icons.edit_note)),IconButton(tooltip:'سوابق تسویه',onPressed:showSettlementHistory,icon:const Icon(Icons.history)),IconButton(tooltip:'تسویه حساب',onPressed:settleAccount,icon:const Icon(Icons.archive_outlined)),IconButton(tooltip:'دریافت پول از فروشنده',onPressed:receiveFromSupplier,icon:const Icon(Icons.add_card)),IconButton(tooltip:'ثبت پرداخت',onPressed:pay,icon:const Icon(Icons.payments_outlined))]),
  floatingActionButton:FloatingActionButton.extended(onPressed:pay,icon:const Icon(Icons.outbound),label:const Text('ثبت پرداخت به فروشنده')),
  body:FutureBuilder<Map<String,Object?>>(future:loadLedger(),builder:(context,s){
   if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final v=s.data!,balance=(v['balance'] as num).toDouble(),events=v['events'] as List<Map<String,Object?>>;
   Widget metric(String label,Object? value,{Color? color})=>Expanded(child:Container(margin:const EdgeInsets.all(4),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:5),Text('${money.format(value)} افغانی',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:color),maxLines:1,overflow:TextOverflow.ellipsis)])));
   return Column(children:[
    Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(12,10,12,5),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:tint(balance).withOpacity(.09),borderRadius:BorderRadius.circular(16),border:Border.all(color:tint(balance).withOpacity(.35))),child:Column(children:[const Text('مانده نهایی حساب',style:TextStyle(fontSize:12,color:Colors.blueGrey)),const SizedBox(height:4),Text('${money.format(balance.abs())} افغانی',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:tint(balance))),Text(status(balance),style:TextStyle(color:tint(balance),fontWeight:FontWeight.bold)),if('${widget.supplier['phone']??''}'.isNotEmpty)Text('${widget.supplier['phone']}',style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Row(children:[metric('جمع خریدها',v['purchases']),metric('نقد پرداخت‌شده هنگام خرید',v['paidAtPurchase'])]),
    Row(children:[metric('بدهی خریدها',v['purchaseDebt'],color:Colors.red),metric('پرداخت‌های بعدی به فروشنده',v['payments'],color:Colors.green)]),
    Row(children:[metric('مانده اول دوره',v['opening']),metric('تعداد گردش',events.length)]),
    Padding(padding:const EdgeInsets.fromLTRB(14,8,14,4),child:Row(children:[const Expanded(child:Text('گردش حساب فروشنده',style:TextStyle(fontWeight:FontWeight.bold,fontSize:15))),Text('${events.length} سند',style:const TextStyle(fontSize:11,color:Colors.blueGrey))])),
    Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(10,2,10,90),itemCount:events.length+(v['opening']==0?0:1),itemBuilder:(context,index){
     if(index==events.length){final opening=(v['opening'] as num).toDouble();return Card(child:ListTile(dense:true,leading:const Icon(Icons.flag_outlined),title:const Text('مانده اول دوره'),subtitle:const Text('مانده انتقالی حساب'),trailing:Text('${money.format(opening.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:tint(opening)))));}
     final e=events[events.length-1-index],purchase=e['kind']=='purchase',incoming=e['direction']=='دریافت',delta=(e['delta'] as num).toDouble(),running=(e['running'] as num).toDouble(),date=afghanDate(DateTime.parse(e['created'].toString()));
     return Card(margin:const EdgeInsets.symmetric(vertical:3),child:ListTile(dense:true,leading:CircleAvatar(radius:17,backgroundColor:(purchase?Colors.red:Colors.green).withOpacity(.10),child:Icon(purchase?Icons.shopping_bag_outlined:Icons.payments_outlined,size:18,color:purchase?Colors.red:Colors.green)),title:Text(purchase?'خرید کالا از فروشنده: ${e['title']}':e['kind']=='adjustment'?(delta>0?'افزایش بدهی به فروشنده':'افزایش طلب از فروشنده'):incoming?'دریافت نقدی از فروشنده':'پرداخت نقدی به فروشنده',style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),subtitle:Text(purchase?'مقدار: ${money.format(e['qty'])} ${e['unit']} × ${money.format(e['price'])} • جمع خرید: ${money.format(e['total'])} • نقد پرداخت‌شده هنگام خرید: ${money.format(e['paid'])} • باقی‌مانده بدهی: ${money.format(delta)}\n$date':'${e['note']??''} • منبع: ${e['fund_source']??'صندوق مغازه'} • $date\nمانده پس از پرداخت: ${money.format(running.abs())} ${running>0?'بدهکار':running<0?'طلبکار':'تسویه'}',style:const TextStyle(fontSize:11)),isThreeLine:true,trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(visualDensity:VisualDensity.compact,tooltip:'کپی یا اشتراک رسید',onPressed:()=>shareLedgerReceipt(e,partyType:'فروشنده',partyName:'${widget.supplier['name']}'),icon:const Icon(Icons.receipt_long_outlined,size:20)),Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${delta>0?'+':delta<0?'-':''}${money.format(delta.abs())}',style:TextStyle(fontWeight:FontWeight.bold,color:delta>0?Colors.red:Colors.green)),Text('مانده ${money.format(running.abs())}',style:TextStyle(fontSize:10,color:tint(running)))]),if(!purchase)PopupMenuButton<String>(tooltip:'ویرایش یا حذف گردش',onSelected:(v){if(v=='edit')editLedgerEvent(e);else if(v=='delete')deleteLedgerEvent(e);},itemBuilder:(c)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش گردش')),PopupMenuItem(value:'delete',child:Text('حذف گردش'))])])));
    })),
   ]);
  })
 );
}

class FinancePage extends StatefulWidget {
 final VoidCallback onChanged;
 final int initialSection;
 const FinancePage({super.key,required this.onChanged,this.initialSection=0});
 @override State<FinancePage> createState()=>_FinancePageState();
}
class _FinancePageState extends State<FinancePage> {
 late int section;
 @override void initState(){super.initState();section=widget.initialSection;}
 @override Widget build(BuildContext context)=>Column(children:[
  Padding(padding:const EdgeInsets.fromLTRB(10,8,10,4),child:SegmentedButton<int>(segments:const [
   ButtonSegment(value:0,label:Text('صندوق'),icon:Icon(Icons.account_balance_wallet_outlined)),
   ButtonSegment(value:1,label:Text('مشتریان'),icon:Icon(Icons.people_outline)),
   ButtonSegment(value:2,label:Text('فروشندگان'),icon:Icon(Icons.storefront_outlined))
  ],selected:{section},onSelectionChanged:(v)=>setState(()=>section=v.first))),
  Expanded(child:section==0?CashPage(key:const ValueKey('cash'),onChanged:widget.onChanged):section==1?const CustomersPage(key:ValueKey('customers')):const SuppliersPage(key:ValueKey('suppliers')))
 ]);
}

class AccountsPage extends StatefulWidget {const AccountsPage({super.key});@override State<AccountsPage> createState()=>_AccountsPageState();}
class _AccountsPageState extends State<AccountsPage>{bool suppliers=false;@override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('مشتریان'),icon:Icon(Icons.people_outline)),ButtonSegment(value:true,label:Text('فروشندگان'),icon:Icon(Icons.storefront_outlined))],selected:{suppliers},onSelectionChanged:(v)=>setState(()=>suppliers=v.first))),Expanded(child:suppliers?const SuppliersPage():const CustomersPage())]);}


class BusinessReportsPage extends StatefulWidget {const BusinessReportsPage({super.key});@override State<BusinessReportsPage> createState()=>_BusinessReportsPageState();}
class _BusinessReportsPageState extends State<BusinessReportsPage>{
 String section='دفتر کل';
 Future<List<Map<String,Object?>>> ledger() async {final db=await ShopDb.instance.database;return db.rawQuery("""
 SELECT created, type AS kind, product_name AS title, total AS amount, COALESCE(note,'') AS note FROM entries
 UNION ALL
 SELECT c.created, 'صندوق: '||c.type AS kind, 'تراکنش صندوق' AS title, c.amount AS amount, COALESCE(c.note,'') AS note FROM cash c
 WHERE NOT EXISTS(SELECT 1 FROM entries e WHERE e.cash_id=c.id) AND NOT EXISTS(SELECT 1 FROM customer_payments cp WHERE cp.cash_id=c.id) AND NOT EXISTS(SELECT 1 FROM supplier_payments sp WHERE sp.cash_id=c.id)
 UNION ALL
 SELECT cp.created, 'حساب مشتری: '||cp.type AS kind, cu.name AS title, cp.amount AS amount, COALESCE(cp.note,'') AS note FROM customer_payments cp LEFT JOIN customers cu ON cu.id=cp.customer_id
 UNION ALL
 SELECT sp.created, 'حساب فروشنده: '||sp.type AS kind, su.name AS title, sp.amount AS amount, COALESCE(sp.note,'') AS note FROM supplier_payments sp LEFT JOIN suppliers su ON su.id=sp.supplier_id
 ORDER BY created DESC LIMIT 500
 """);}
 Future<List<Map<String,Object?>>> debtors() async {final db=await ShopDb.instance.database;final customers=await db.rawQuery("""SELECT 'مشتری' AS kind,name,phone,COALESCE(opening_balance,0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE customer_id=customers.id AND type='فروش'),0)-COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=customers.id AND type IN ('دریافت','برگشت')),0)+COALESCE((SELECT SUM(amount) FROM customer_payments WHERE customer_id=customers.id AND type='پرداخت'),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='customer' AND account_id=customers.id),0) AS balance FROM customers""");final suppliers=await db.rawQuery("""SELECT 'فروشنده' AS kind,name,phone,COALESCE(opening_balance,0)+COALESCE((SELECT SUM(total-paid) FROM entries WHERE supplier_id=suppliers.id AND type='خرید'),0)-COALESCE((SELECT SUM(CASE WHEN type='دریافت' THEN -amount ELSE amount END) FROM supplier_payments WHERE supplier_id=suppliers.id),0)+COALESCE((SELECT SUM(CASE WHEN direction='increase' THEN amount ELSE -amount END) FROM account_adjustments WHERE account_type='supplier' AND account_id=suppliers.id),0) AS balance FROM suppliers""");return [...customers,...suppliers].where((x)=>(x['balance'] as num).abs()>0.009).toList()..sort((a,b)=>((b['balance'] as num).abs()).compareTo(((a['balance'] as num).abs())));}
 Future<List<Map<String,Object?>>> audit() async => (await ShopDb.instance.database).query('audit_logs',orderBy:'id DESC',limit:300);
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('گزارش‌ها و دفتر حساب')),body:Column(children:[
  Padding(padding:const EdgeInsets.all(10),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<String>(segments:const [ButtonSegment(value:'دفتر کل',label:Text('دفتر کل')),ButtonSegment(value:'بدهکاران',label:Text('حساب‌های باز')),ButtonSegment(value:'تاریخچه',label:Text('تاریخچه تغییرات'))],selected:{section},onSelectionChanged:(v)=>setState(()=>section=v.first)))),
  Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:section=='دفتر کل'?ledger():section=='بدهکاران'?debtors():audit(),builder:(c,s){if(s.hasError)return Center(child:Text('گزارش بارگذاری نشد: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());final rows=s.data!;if(rows.isEmpty)return const Center(child:Text('موردی برای نمایش نیست'));return ListView.separated(itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(c,i){final x=rows[i];if(section=='دفتر کل'){final date=DateTime.tryParse('${x['created']}')??DateTime.now();return ListTile(dense:true,title:Text('${x['kind']} • ${x['title']}'),subtitle:Text('${afghanDate(date)}${'${x['note']??''}'.trim().isEmpty?'':'\n${x['note']}'}'),trailing:Text('${money.format(x['amount'])} افغانی',style:const TextStyle(fontWeight:FontWeight.bold)));}if(section=='بدهکاران'){final balance=(x['balance'] as num).toDouble();final isCustomer=x['kind']=='مشتری';final due=balance>0?(isCustomer?'مشتری بدهکار است':'دوکان به فروشنده بدهکار است'):(isCustomer?'دوکان به مشتری بدهکار است':'فروشنده بدهکار است');return ListTile(leading:Icon(isCustomer?Icons.person_outline:Icons.storefront_outlined),title:Text('${x['name']}'),subtitle:Text('${x['kind']} • ${x['phone']??''}\n$due'),isThreeLine:true,trailing:Text('${money.format(balance.abs())} افغانی',style:TextStyle(fontWeight:FontWeight.bold,color:balance>0?Colors.red:Colors.green)));}final date=DateTime.tryParse('${x['created']}')??DateTime.now();return ListTile(dense:true,leading:Icon(x['action']=='حذف'?Icons.delete_outline:x['action']=='ویرایش'?Icons.edit_outlined:Icons.history),title:Text('${x['table_name']} • ${x['action']} • #${x['record_id']}'),subtitle:Text('${x['summary']??''}\n${afghanDate(date)}'));});}))
 ]));
}

class SettingsPage extends StatefulWidget {const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage> {
  final seer=TextEditingController();
  final openingCash=TextEditingController();
  bool backupBusy=false;
  @override void initState(){super.initState();ShopDb.instance.database.then((db)async{final r=await db.query('settings',where:'key=?',whereArgs:['seer_grams']);final c=await db.query('settings',where:'key=?',whereArgs:['cash_opening_balance']);if(mounted){if(r.isNotEmpty)seer.text='${r.first['value']}';openingCash.text=c.isEmpty?'0':'${c.first['value']}';}});}
  @override void dispose(){seer.dispose();openingCash.dispose();super.dispose();}
  Future<void> openReports() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessReportsPage()));}
  Future<void> exportBackup() async {
    setState(()=>backupBusy=true);
    try {
      final data=await ShopDb.instance.createBackup();
      final bytes=Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final name='offline-shop-backup-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}.json';
      final path=await FilePicker.platform.saveFile(dialogTitle:'ذخیره نسخه پشتیبان دوکان',fileName:name,bytes:bytes,allowedExtensions:['json'],type:FileType.custom);
      if(mounted&&path!=null)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نسخه پشتیبان ذخیره شد. فایل را در جای امن نگه دارید.')));
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('ساخت پشتیبان ناموفق بود: $e')));}
    finally {if(mounted)setState(()=>backupBusy=false);}
  }
  Future<void> importBackup() async {
    try {
      final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
      if(picked==null||picked.files.isEmpty)return;
      final bytes=picked.files.single.bytes;
      if(bytes==null)throw const FormatException('خواندن فایل انتخاب‌شده ممکن نشد.');
      final decoded=jsonDecode(utf8.decode(bytes));
      if(decoded is! Map<String,dynamic>)throw const FormatException('ساختار فایل پشتیبان درست نیست.');
      if(!mounted)return;
      final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
        title:const Text('بازیابی نسخه پشتیبان'),
        content:const Text('با بازیابی، اطلاعات فعلی این گوشی با اطلاعات داخل فایل پشتیبان جایگزین می‌شود. برای جلوگیری از گم‌شدن اطلاعات، ابتدا از وضعیت فعلی نیز نسخه پشتیبان بگیرید. ادامه می‌دهید؟'),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('جایگزینی و بازیابی'))],
      ));
      if(confirmed!=true)return;
      setState(()=>backupBusy=true);
      await ShopDb.instance.restoreBackup(decoded);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اطلاعات نسخه پشتیبان با موفقیت بازیابی شد. برنامه را یک‌بار ببندید و دوباره باز کنید.')));
    } catch(e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('بازیابی انجام نشد؛ اطلاعات قبلی حفظ شد: $e')));}
    finally {if(mounted)setState(()=>backupBusy=false);}
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('تنظیمات دوکان',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('موجودی آغازین صندوق',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:5),const Text('پولی که پیش از شروع ثبت در برنامه داخل صندوق دوکان بوده است. این مبلغ با دریافت‌ها و برداشت‌ها جمع و تفریق می‌شود؛ دوباره به‌عنوان دریافت ثبت نمی‌شود.',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
      const SizedBox(height:8),TextField(controller:openingCash,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'موجودی آغازین صندوق',suffixText:'افغانی')),
      const SizedBox(height:8),FilledButton(onPressed:()async{final value=parseNum(openingCash.text);if(value==null||value<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی آغازین باید صفر یا بیشتر باشد.')));return;}final db=await ShopDb.instance.database;await db.insert('settings',{'key':'cash_opening_balance','value':value.toString()},conflictAlgorithm:ConflictAlgorithm.replace);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی آغازین صندوق ذخیره شد.')));},child:const Text('ذخیره موجودی آغازین'))
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('واحدها',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),
      TextField(controller:seer,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'هر سیر چند گرم است؟',suffixText:'گرم')),
      const SizedBox(height:8),
      FilledButton(onPressed:()async{final grams=parseNum(seer.text)??0;if(grams<=0){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مقدار هر سیر باید بیشتر از صفر باشد.')));return;}await (await ShopDb.instance.database).update('settings',{'value':grams.toString()},where:'key=?',whereArgs:['seer_grams']);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تنظیم ذخیره شد')));},child:const Text('ذخیره تنظیمات'))
    ]))),
    Card(child:ListTile(leading:const Icon(Icons.assessment_outlined),title:const Text('دفتر کل، بدهکاران و تاریخچه تغییرات'),subtitle:const Text('تمام گردش‌های دوکان، حساب‌های باز مشتریان و فروشندگان و ثبت ویرایش‌ها را ببینید.'),trailing:const Icon(Icons.chevron_left),onTap:openReports)),
    const Card(child:ListTile(leading:Icon(Icons.wifi_off),title:Text('حالت آفلاین'),subtitle:Text('ثبت کالا، خرید، فروش و صندوق بدون اینترنت ذخیره می‌شود.'))),
    const Card(child:ListTile(leading:Icon(Icons.currency_exchange),title:Text('واحد پول'),subtitle:Text('فقط افغانی (AFN) • هیچ ارز دیگری در سیستم ثبت نمی‌شود • مبلغ‌ها با اعداد انگلیسی نمایش داده می‌شوند.'))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('پشتیبان‌گیری و انتقال اطلاعات',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:5),const Text('از کالاها، مشتری‌ها، فروش‌ها، خریدها، صندوق و تمام گردش حساب‌ها یک فایل پشتیبان می‌سازد. فایل را به گوشی یا کامپیوتر دیگر منتقل کنید.',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:backupBusy?null:exportBackup,icon:const Icon(Icons.download_outlined),label:const Text('ساخت و ذخیره نسخه پشتیبان')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:backupBusy?null:importBackup,icon:const Icon(Icons.restore),label:const Text('بازیابی از فایل پشتیبان')),
      if(backupBusy)const Padding(padding:EdgeInsets.only(top:10),child:LinearProgressIndicator()),
    ]))),
    const Card(child:ListTile(leading:Icon(Icons.sync),title:Text('همگام‌سازی زنده گوشی و کامپیوتر'),subtitle:Text('فعلاً همگام‌سازی خودکار سروری فعال نیست؛ انتقال اطلاعات با فایل پشتیبان انجام می‌شود.')))
  ]);
}
