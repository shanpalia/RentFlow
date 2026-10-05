import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF008F78);
const dark = Color(0xFF006B5A);
const soft = Color(0xFFE4F5F0);
const bg = Color(0xFFF5F8F7);
const line = Color(0xFFD9E5E1);
const ink = Color(0xFF172521);

void startRentFlow() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentFlowApp());
}

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RentFlow',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: green)),
    home: const Splash(),
  );
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState() { super.initState(); Future.delayed(const Duration(milliseconds: 1000), () { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home())); }); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.white, body: Center(child: SizedBox(width: 360, child: SvgPicture.asset('assets/rentflow_splash.svg'))));
}

class DB extends ChangeNotifier {
  SharedPreferences? pref;
  List<Map<String,dynamic>> shops = [];
  int active = 0;
  bool get loaded => pref != null;
  Map<String,dynamic> get shop => shops.isEmpty ? {} : shops[active];
  List<Map<String,dynamic>> list(String key) {
    final x = shop[key];
    if (x is! List) return [];
    return x.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
  }
  Future<void> load() async {
    pref = await SharedPreferences.getInstance();
    try { final x = jsonDecode(pref!.getString('rentflow_data') ?? '[]'); if (x is List) shops = x.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList(); } catch (_) { shops = []; }
    active = pref!.getInt('rentflow_active') ?? 0;
    if (active >= shops.length) active = shops.isEmpty ? 0 : shops.length - 1;
    notifyListeners();
  }
  Future<void> save() async { await pref!.setString('rentflow_data', jsonEncode(shops)); await pref!.setInt('rentflow_active', active); notifyListeners(); }
  Future<void> addShop(Map<String,dynamic> x) async { shops.add({...x, 'items': <Map<String,dynamic>>[], 'customers': <Map<String,dynamic>>[], 'issues': <Map<String,dynamic>>[], 'returns': <Map<String,dynamic>>[]}); active = shops.length - 1; await save(); }
  Future<void> editShop(int i, Map<String,dynamic> x) async { shops[i].addAll(x); await save(); }
  Future<void> deleteShop(int i) async { shops.removeAt(i); active = shops.isEmpty ? 0 : (active >= shops.length ? shops.length - 1 : active); await save(); }
  Future<void> add(String key, Map<String,dynamic> x) async { final v = shop[key]; if (v is List) v.add(x); await save(); }
  Future<void> replace(String key, int i, Map<String,dynamic> x) async { final v = shop[key]; if (v is List && i < v.length) v[i] = x; await save(); }
  Future<void> remove(String key, int i) async { final v = shop[key]; if (v is List && i < v.length) v.removeAt(i); await save(); }
}

final db = DB();
String id() => DateTime.now().microsecondsSinceEpoch.toString();
Future<void> page(BuildContext c, Widget w) async { await Navigator.push(c, MaterialPageRoute(builder: (_) => w)); }

class Header extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const Header({super.key, this.back = false});
  @override Size get preferredSize => const Size.fromHeight(62);
  @override Widget build(BuildContext c) => AppBar(
    backgroundColor: Colors.white, elevation: 0,
    leading: back ? IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.arrow_back_rounded)) : Padding(padding: const EdgeInsets.all(11), child: SvgPicture.asset('assets/rentflow_logo.svg')),
    title: const Text('RentFlow by PaliaAPK HUB', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w900)),
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: line)),
  );
}

class PageShell extends StatelessWidget {
  final String title; final Widget child;
  const PageShell(this.title, this.child, {super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: const Header(back: true), body: ListView(padding: const EdgeInsets.all(16), children: [Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 16), child, const SizedBox(height: 30), Center(child: Text('By PaliaAPK HUB  •  Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)))]));
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeState(); }
class _HomeState extends State<Home> {
  @override void initState() { super.initState(); db.load(); }
  @override Widget build(BuildContext c) => AnimatedBuilder(animation: db, builder: (_,__) {
    if (!db.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Main Menu', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
      const Text('Emerald ERP workspace', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18),
      if (db.shops.isEmpty) ...[
        _box(Icons.store_rounded, 'Register your shop', 'You can skip now. Entry screens will ask for registration.', () => page(c, ShopForm(onSaved: () => setState(() {})))),
      ] else ...[
        _box(Icons.inventory_2_outlined, 'Inventory', 'Item master • multiple entries • quantity', () => page(c, const ItemsPage())),
        _box(Icons.people_alt_outlined, 'Customers', 'Party master • add / edit / delete', () => page(c, const CustomersPage())),
        _box(Icons.outbox_rounded, 'Issued', 'Customer + invoice + multiple inventory rows', () => page(c, const IssuePage())),
        _box(Icons.assignment_return_rounded, 'Return', 'Customer dropdown + issued items + manual amount', () => page(c, const ReturnPage())),
        _box(Icons.table_rows_rounded, 'Inventory Register', 'Tally / Busy style register', () => page(c, const InventoryPage())),
        _box(Icons.receipt_long_rounded, 'Issue / Return Register', 'Saved transactions', () => page(c, const TransactionPage())),
        _box(Icons.store_outlined, 'Shop / Company', 'Edit, delete, add another shop', () => page(c, const ShopsPage())),
        _box(Icons.settings_outlined, 'Settings', 'Check Update + About', () => page(c, const SettingsPage())),
      ],
      const SizedBox(height: 16), const Center(child: Text('RentFlow  •  By PaliaAPK HUB  •  Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
    ]));
  });
}
Widget _box(IconData icon, String title, String sub, VoidCallback on) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(onTap: on, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: dark)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)), subtitle: Text(sub, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.chevron_right_rounded, color: green)));

class ShopForm extends StatefulWidget { final VoidCallback? onSaved; final int? index; const ShopForm({super.key, this.onSaved, this.index}); @override State<ShopForm> createState() => _ShopFormState(); }
class _ShopFormState extends State<ShopForm> {
  late TextEditingController n,o,m,a;
  @override void initState() { super.initState(); final x = widget.index == null ? <String,dynamic>{} : db.shops[widget.index!]; n=TextEditingController(text: '${x['name']??''}'); o=TextEditingController(text: '${x['owner']??''}'); m=TextEditingController(text: '${x['mobile']??''}'); a=TextEditingController(text: '${x['address']??''}'); }
  @override void dispose(){n.dispose();o.dispose();m.dispose();a.dispose();super.dispose();}
  Future<void> save() async { if(n.text.trim().isEmpty)return; final x={'name':n.text.trim(),'owner':o.text.trim(),'mobile':m.text.trim(),'address':a.text.trim()}; if(widget.index==null) await db.addShop(x); else await db.editShop(widget.index!,x); widget.onSaved?.call(); if(mounted)Navigator.pop(context); }
  @override Widget build(BuildContext c)=>PageShell(widget.index==null?'Register Shop':'Edit Shop', Column(children:[Field('Shop / Company Name',n),Field('Owner Name',o),Field('Mobile Number',m,num:true),Field('Shop Address',a,lines:3),Button(widget.index==null?'Save Shop':'Update Shop',save)]));
}

class ShopsPage extends StatelessWidget { const ShopsPage({super.key}); @override Widget build(BuildContext c)=>PageShell('Shop / Company', Column(children:[for(int i=0;i<db.shops.length;i++) Card(elevation:0,child:ListTile(leading:const Icon(Icons.store,color:green),title:Text('${db.shops[i]['name']??''}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${db.shops[i]['address']??''}'),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await page(c,ShopForm(index:i));if(v=='delete')await db.deleteShop(i);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit Shop')),PopupMenuItem(value:'delete',child:Text('Delete Shop'))]))),Button('Add New Shop',()=>page(c,const ShopForm()),icon:Icons.add_business_rounded)])); }

class ItemsPage extends StatelessWidget { const ItemsPage({super.key}); @override Widget build(BuildContext c){final r=db.list('items');return PageShell('Inventory / Item Master',Column(children:[if(r.isEmpty)const Empty('No items added yet'),for(int i=0;i<r.length;i++) _row(r[i],()=>page(c,ItemForm(index:i)),()=>db.remove('items',i)),Button('Add Another Item',()=>page(c,const ItemForm()),icon:Icons.add_rounded)]);}}
class ItemForm extends StatefulWidget { final int? index; const ItemForm({super.key,this.index}); @override State<ItemForm> createState()=>_ItemFormState(); }
class _ItemFormState extends State<ItemForm>{late TextEditingController code,name,unit,qty;@override void initState(){super.initState();final r=widget.index==null?<String,dynamic>{}:db.list('items')[widget.index!];code=TextEditingController(text:'${r['code']??''}');name=TextEditingController(text:'${r['name']??''}');unit=TextEditingController(text:'${r['unit']??'pcs'}');qty=TextEditingController(text:'${r['quantity']??0}');}@override void dispose(){code.dispose();name.dispose();unit.dispose();qty.dispose();super.dispose();}Future<void> save()async{if(name.text.trim().isEmpty)return;final old=widget.index==null?null:db.list('items')[widget.index!];final x={'id':old?['id']??id(),'code':code.text.trim(),'name':name.text.trim(),'unit':unit.text.trim().isEmpty?'pcs':unit.text.trim(),'quantity':int.tryParse(qty.text)??0};if(widget.index==null)await db.add('items',x);else await db.replace('items',widget.index!,x);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>PageShell(widget.index==null?'New Item':'Edit Item',Column(children:[Field('Item Code',code),Field('Item Name / Description',name),Row(children:[Expanded(child:Field('Unit',unit)),const SizedBox(width:8),Expanded(child:Field('Quantity',qty,num:true))]),Button('Save Item',save)]));}

class CustomersPage extends StatelessWidget{const CustomersPage({super.key});@override Widget build(BuildContext c){final r=db.list('customers');return PageShell('Customer / Party Master',Column(children:[if(r.isEmpty)const Empty('No customers added yet'),for(int i=0;i<r.length;i++)_row(r[i],()=>page(c,CustomerForm(index:i)),()=>db.remove('customers',i)),Button('Add Customer',()=>page(c,const CustomerForm()),icon:Icons.person_add_alt_1_rounded)]);}}
class CustomerForm extends StatefulWidget{final int? index;const CustomerForm({super.key,this.index});@override State<CustomerForm> createState()=>_CustomerFormState();}
class _CustomerFormState extends State<CustomerForm>{late TextEditingController n,m,a;@override void initState(){super.initState();final r=widget.index==null?<String,dynamic>{}:db.list('customers')[widget.index!];n=TextEditingController(text:'${r['name']??''}');m=TextEditingController(text:'${r['mobile']??''}');a=TextEditingController(text:'${r['address']??''}');}@override void dispose(){n.dispose();m.dispose();a.dispose();super.dispose();}Future<void> save()async{if(n.text.trim().isEmpty)return;final old=widget.index==null?null:db.list('customers')[widget.index!];final x={'id':old?['id']??id(),'name':n.text.trim(),'mobile':m.text.trim(),'address':a.text.trim()};if(widget.index==null)await db.add('customers',x);else await db.replace('customers',widget.index!,x);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>PageShell(widget.index==null?'New Customer':'Edit Customer',Column(children:[Field('Customer Name',n),Field('Mobile Number',m,num:true),Field('Address',a,lines:3),Button('Save Customer',save)]));}

class IssuePage extends StatefulWidget{const IssuePage({super.key});@override State<IssuePage> createState()=>_IssuePageState();}
class _IssuePageState extends State<IssuePage>{String? customer;late TextEditingController invoice,date;List<Map<String,dynamic>> rows=[];@override void initState(){super.initState();invoice=TextEditingController(text:'INV-${DateTime.now().millisecondsSinceEpoch}');date=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10));}@override void dispose(){invoice.dispose();date.dispose();super.dispose();}Future<void> save()async{if(customer==null||rows.isEmpty)return;await db.add('issues',{'id':id(),'invoice':invoice.text,'date':date.text,'customer':customer,'items':rows});if(mounted){await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Issued Entry Saved'),content:Text('Invoice ${invoice.text} saved with ${rows.length} item(s).'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('OK'))]));Navigator.pop(context);}}@override Widget build(BuildContext c){final cs=db.list('customers');final items=db.list('items');return PageShell('Issued',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Section('INVOICE'),Field('Invoice Number',invoice),Field('Date',date),DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer'),items:cs.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v),),const SizedBox(height:12),if(cs.isEmpty)Button('Add Customer',()=>page(c,const CustomerForm()),icon:Icons.add_rounded),Section('INVENTORY ITEMS'),for(int i=0;i<rows.length;i++)Card(elevation:0,child:ListTile(title:Text('${rows[i]['name']}'),subtitle:Text('Quantity: ${rows[i]['qty']}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>rows.removeAt(i)))),),Button('Add More Inventory',(){if(items.isEmpty)return;setState(()=>rows.add({'id':items.first['id'],'name':items.first['name'],'qty':1}));},icon:Icons.add_rounded),const SizedBox(height:10),Button('Save & Preview',save,icon:Icons.preview_rounded)]));}}

class ReturnPage extends StatefulWidget{const ReturnPage({super.key});@override State<ReturnPage> createState()=>_ReturnPageState();}
class _ReturnPageState extends State<ReturnPage>{String? customer;final amount=TextEditingController();@override void dispose(){amount.dispose();super.dispose();}@override Widget build(BuildContext c){final cs=db.list('customers');final issues=db.list('issues');return PageShell('Return',Column(children:[DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer'),items:cs.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v)),const SizedBox(height:12),if(customer!=null) ...[const Section('ISSUED ITEMS'),for(final issue in issues.where((x)=>x['customer']==customer)) Card(elevation:0,child:ListTile(title:Text('Invoice ${issue['invoice']}'),subtitle:Text('${(issue['items'] as List).length} item(s) issued'))),Field('Manual Return Amount',amount,num:true),Button('Save Return',()async{await db.add('returns',{'id':id(),'date':DateTime.now().toIso8601String().substring(0,10),'customer':customer,'amount':amount.text});if(mounted)Navigator.pop(context);})] else const Empty('Select a customer to see issued entries')]));}}

class InventoryPage extends StatelessWidget{const InventoryPage({super.key});@override Widget build(BuildContext c){final r=db.list('items');return PageShell('Inventory Register',Column(children:[for(final x in r)Card(elevation:0,child:ListTile(title:Text('${x['name']}'),subtitle:Text('Code: ${x['code']}'),trailing:Text('${x['quantity']} ${x['unit']}')))]));}}
class TransactionPage extends StatelessWidget{const TransactionPage({super.key});@override Widget build(BuildContext c){final i=db.list('issues'),r=db.list('returns');return PageShell('Issue / Return Register',Column(children:[const Section('ISSUED'),for(final x in i)Card(elevation:0,child:ListTile(title:Text('Invoice ${x['invoice']}'),subtitle:Text('Date: ${x['date']}'))),const Section('RETURNS'),for(final x in r)Card(elevation:0,child:ListTile(title:Text('Return • ${x['date']}'),subtitle:Text('Amount: ${x['amount']}')))]));}}
class SettingsPage extends StatelessWidget{const SettingsPage({super.key});@override Widget build(BuildContext c)=>PageShell('Settings',Column(children:[_box(Icons.system_update_alt_rounded,'Check Update','Check for the latest RentFlow version',(){showDialog(context:c,builder:(_)=>const AlertDialog(title:Text('Check Update'),content:Text('You are using the current installed version.'),));}),_box(Icons.info_outline_rounded,'About','RentFlow by PaliaAPK HUB',(){showAboutDialog(context:c,applicationName:'RentFlow',applicationVersion:'1.0.0',children:[const Text('By PaliaAPK HUB\nDeveloper by shanpalia')]);})]));}

class Field extends StatelessWidget{final String label;final TextEditingController controller;final bool num;final int lines;const Field(this.label,this.controller,{super.key,this.num=false,this.lines=1});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:controller,maxLines:lines,keyboardType:num?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:label)));}
class Button extends StatelessWidget{final String text;final VoidCallback on;final IconData icon;const Button(this.text,this.on,{super.key,this.icon=Icons.save_rounded});@override Widget build(BuildContext c)=>SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:on,icon:Icon(icon),label:Text(text)));}
class Section extends StatelessWidget{final String text;const Section(this.text,{super.key});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(bottom:7,top:7),child:Text(text,style:const TextStyle(fontSize:11,letterSpacing:1.4,fontWeight:FontWeight.w900,color:dark)));}
class Empty extends StatelessWidget{final String text;const Empty(this.text,{super.key});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(24),margin:const EdgeInsets.only(bottom:12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:line)),child:Column(children:[const Icon(Icons.inbox_outlined,size:40,color:green),const SizedBox(height:8),Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))]));}
Widget _row(Map<String,dynamic> x, VoidCallback edit, VoidCallback del)=>Card(elevation:0,child:ListTile(leading:const CircleAvatar(backgroundColor:soft,child:Icon(Icons.circle,color:dark,size:14)),title:Text('${x['name']??''}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${x['mobile']??x['code']??''}'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit();if(v=='delete')del();},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))])));
