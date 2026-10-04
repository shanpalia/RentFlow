import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const muted = Color(0xFF687873);
const bg = Color(0xFFF5FAF8);
const mint = Color(0xFFE4F8F2);
const appVersion = '1.0.2';
const websiteUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';

int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String money(dynamic value) => '₹${asDouble(value).toStringAsFixed(0)}';

void main() => runApp(const RentFlowApp());

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RentFlow',
        theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: primary)),
        home: const SplashPage(),
      );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => (prefs.getString('shop_name') ?? '').isEmpty ? const ShopPage() : const AppShell()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 96, height: 96, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 60)),
          const SizedBox(height: 18),
          const Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: dark)),
          const Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
          const Text('Developer by ShanPalia', style: TextStyle(color: muted)),
        ])),
      );
}

class Store {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];
  String shopName = '', owner = '', phone = '';
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    shopName = prefs.getString('shop_name') ?? '';
    owner = prefs.getString('owner') ?? '';
    phone = prefs.getString('phone') ?? '';
    items = readList('items'); customers = readList('customers'); rentals = readList('rentals');
  }
  List<Map<String, dynamic>> readList(String key) {
    try {
      final raw = jsonDecode(prefs.getString(key) ?? '[]');
      if (raw is! List) return [];
      return raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { return []; }
  }
  Future<void> saveData() async {
    await prefs.setString('items', jsonEncode(items)); await prefs.setString('customers', jsonEncode(customers)); await prefs.setString('rentals', jsonEncode(rentals));
  }
  Future<void> saveShop(String name, String ownerName, String mobile) async {
    shopName=name.trim(); owner=ownerName.trim(); phone=mobile.trim();
    await prefs.setString('shop_name', shopName); await prefs.setString('owner', owner); await prefs.setString('phone', phone);
  }
}

class ShopPage extends StatefulWidget {
  final Store? existing;
  const ShopPage({this.existing, super.key});
  @override State<ShopPage> createState() => _ShopPageState();
}
class _ShopPageState extends State<ShopPage> {
  final form = GlobalKey<FormState>();
  final name=TextEditingController(), owner=TextEditingController(), phone=TextEditingController();
  @override void initState(){super.initState();final s=widget.existing;if(s!=null){name.text=s.shopName;owner.text=s.owner;phone.text=s.phone;}}
  @override void dispose(){name.dispose();owner.dispose();phone.dispose();super.dispose();}
  Future<void> save() async { if(!(form.currentState?.validate()??false))return; final s=widget.existing??Store();if(widget.existing==null)await s.load();await s.saveShop(name.text,owner.text,phone.text);if(!mounted)return;Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AppShell())); }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Form(key:form,child:ListView(padding:const EdgeInsets.all(22),children:[
    const SizedBox(height:28),const Icon(Icons.storefront_rounded,color:primary,size:62),const SizedBox(height:10),const Text('Register Your Shop',textAlign:TextAlign.center,style:TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:dark)),const SizedBox(height:26),
    field(name,'Shop name',Icons.store),field(owner,'Owner name',Icons.person),field(phone,'Phone',Icons.phone),const SizedBox(height:8),
    FilledButton(onPressed:save,style:FilledButton.styleFrom(backgroundColor:primary,minimumSize:const Size.fromHeight(54)),child:const Text('Continue')),
    const SizedBox(height:18),const Center(child:Text('RentFlow • By PaliaAPK HUB • Developer by ShanPalia',style:TextStyle(color:muted,fontSize:12)))
  ]))));
}
Widget field(TextEditingController c,String label,IconData icon)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,validator:(v)=>v==null||v.trim().isEmpty?'Required':null,decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon,color:primary),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none))));

class AppShell extends StatefulWidget{const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{final store=Store();int index=0;bool ready=false;@override void initState(){super.initState();store.load().then((_){if(mounted)setState(()=>ready=true);});}void refresh()=>setState((){});
@override Widget build(BuildContext context){if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator(color:primary)));final pages=[HomePage(store:store,refresh:refresh),ItemsPage(store:store,refresh:refresh),CustomersPage(store:store,refresh:refresh),ReportsPage(store:store),SettingsPage(store:store,refresh:refresh)];return PopScope(canPop:index==0,onPopInvokedWithResult:(didPop,result){if(!didPop&&index!=0)setState(()=>index=0);},child:Scaffold(body:pages[index],bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'Items'),NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Customers'),NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart),label:'Reports'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Settings')])));}}

class HomePage extends StatelessWidget{final Store store;final VoidCallback refresh;const HomePage({required this.store,required this.refresh,super.key});@override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[Text(store.shopName,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:dark)),const Text('Rental Management',style:TextStyle(color:muted)),const SizedBox(height:18),Row(children:[statCard('Items','${store.items.length}'),statCard('Customers','${store.customers.length}'),statCard('Issued','${store.rentals.where((r)=>asInt(r['received'])<asInt(r['qty'])).length}')]),const SizedBox(height:14),FilledButton.icon(onPressed:()=>rentalDialog(context,store,refresh),icon:const Icon(Icons.add_circle),label:const Text('New Rental'),style:FilledButton.styleFrom(backgroundColor:primary,minimumSize:const Size.fromHeight(55))),const SizedBox(height:12),Row(children:[quick('Item',Icons.inventory_2,()=>itemDialog(context,store,refresh)),quick('Customer',Icons.person_add,()=>customerDialog(context,store,refresh)),quick('Invoice',Icons.receipt_long,()=>invoiceDialog(context,store)),quick('Receive',Icons.assignment_return,()=>receiveDialog(context,store,refresh))]),const SizedBox(height:22),const Text('Recent Rentals',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:dark)),...store.rentals.reversed.take(8).map((r)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:mint,child:Icon(Icons.inventory_2,color:primary)),title:Text('${r['customer']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${r['item']} • Qty ${r['qty']}'),trailing:Text(money(r['amount']),style:const TextStyle(fontWeight:FontWeight.w900)))))]));}
Widget statCard(String label,String value)=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:muted,fontSize:12))]))));
Widget quick(String label,IconData icon,VoidCallback action)=>Expanded(child:InkWell(onTap:action,child:Container(margin:const EdgeInsets.only(right:5),padding:const EdgeInsets.symmetric(vertical:13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Column(children:[Icon(icon,color:primary),const SizedBox(height:5),Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]))));}

class ItemsPage extends StatelessWidget{final Store store;final VoidCallback refresh;const ItemsPage({required this.store,required this.refresh,super.key});@override Widget build(BuildContext c)=>SafeArea(child:Column(children:[pageHeader('Items','Rental inventory'),Expanded(child:store.items.isEmpty?const Center(child:Text('No items added yet',style:TextStyle(color:muted))):ListView.builder(itemCount:store.items.length,itemBuilder:(_,i){final x=store.items[i];return ListTile(leading:const CircleAvatar(backgroundColor:mint,child:Icon(Icons.inventory_2,color:primary)),title:Text('${x['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Qty ${asInt(x['qty'])} • Rent ${money(x['rent'])}'));})),actionButton('Add Item',()=>itemDialog(c,store,refresh))]));}
class CustomersPage extends StatelessWidget{final Store store;final VoidCallback refresh;const CustomersPage({required this.store,required this.refresh,super.key});@override Widget build(BuildContext c)=>SafeArea(child:Column(children:[pageHeader('Customers','Customer records'),Expanded(child:store.customers.isEmpty?const Center(child:Text('No customers added yet',style:TextStyle(color:muted))):ListView.builder(itemCount:store.customers.length,itemBuilder:(_,i){final x=store.customers[i];return ListTile(onTap:()=>customerReport(c,store,'${x['name']}'),leading:const CircleAvatar(backgroundColor:mint,child:Icon(Icons.person,color:primary)),title:Text('${x['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${x['phone']??''}'),trailing:const Icon(Icons.chevron_right));})),actionButton('New Customer',()=>customerDialog(c,store,refresh))]));}
class ReportsPage extends StatelessWidget{final Store store;const ReportsPage({required this.store,super.key});@override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[pageHeader('Reports','Rental business overview'),Row(children:[statCard('Issued','${store.rentals.where((r)=>asInt(r['received'])<asInt(r['qty'])).length}'),statCard('Returned','${store.rentals.where((r)=>asInt(r['received'])>=asInt(r['qty'])).length}')]),const SizedBox(height:15),const Text('Rental History',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),...store.rentals.reversed.map((r)=>Card(child:ListTile(title:Text('${r['customer']} • ${r['item']}'),subtitle:Text('${r['date']} • Qty ${r['qty']}'),trailing:Text(money(r['amount'])))))]));}}
Widget pageHeader(String title,String subtitle)=>Padding(padding:const EdgeInsets.fromLTRB(18,18,18,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:dark)),Text(subtitle,style:const TextStyle(color:muted))]));
Widget actionButton(String text,VoidCallback action)=>Padding(padding:const EdgeInsets.fromLTRB(18,8,18,14),child:FilledButton.icon(onPressed:action,icon:const Icon(Icons.add),label:Text(text),style:FilledButton.styleFrom(backgroundColor:primary,minimumSize:const Size.fromHeight(52))));

class SettingsPage extends StatelessWidget{final Store store;final VoidCallback refresh;const SettingsPage({required this.store,required this.refresh,super.key});@override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[const Text('Settings',style:TextStyle(fontSize:31,fontWeight:FontWeight.w900,color:dark)),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('RentFlow',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const Text('By PaliaAPK HUB',style:TextStyle(color:primary,fontWeight:FontWeight.w800)),const Text('Developer by ShanPalia',style:TextStyle(color:muted)),const SizedBox(height:8),Text(store.shopName,style:const TextStyle(fontWeight:FontWeight.w800))]))),settingsTile('Shop Profile','${store.shopName} • ${store.owner}',Icons.store,()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ShopPage(existing:store))).then((_){store.load().then((_){refresh();});})),settingsTile('Check for App Update','Check the latest RentFlow version',Icons.system_update_alt,()=>checkUpdate(c)),settingsTile('PaliaAPK HUB Website','Open website',Icons.language,()=>launchUrl(Uri.parse(websiteUrl),mode:LaunchMode.externalApplication)),const SizedBox(height:14),Center(child:Text('RentFlow $appVersion',style:const TextStyle(color:muted))) ]));}}
Widget settingsTile(String title,String subtitle,IconData icon,VoidCallback action)=>Card(child:ListTile(onTap:action,leading:CircleAvatar(backgroundColor:mint,child:Icon(icon,color:primary)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right)));

Future<void> itemDialog(BuildContext c,Store s,VoidCallback refresh)async{final n=TextEditingController(),q=TextEditingController(text:'1'),r=TextEditingController(text:'0');final ok=await showDialog<bool>(context:c,builder:(d)=>AlertDialog(title:const Text('Add Item'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Item name')),TextField(controller:q,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity')),TextField(controller:r,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Rent price'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))]));if(ok==true&&n.text.trim().isNotEmpty){final qty=asInt(q.text);s.items.add({'name':n.text.trim(),'qty':qty,'available':qty,'rent':asDouble(r.text)});await s.saveData();refresh();}}
Future<void> customerDialog(BuildContext c,Store s,VoidCallback refresh)async{final n=TextEditingController(),p=TextEditingController();final ok=await showDialog<bool>(context:c,builder:(d)=>AlertDialog(title:const Text('New Customer'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Name')),TextField(controller:p,decoration:const InputDecoration(labelText:'Phone'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))]));if(ok==true&&n.text.trim().isNotEmpty){s.customers.add({'name':n.text.trim(),'phone':p.text.trim()});await s.saveData();refresh();}}
Future<void> rentalDialog(BuildContext c,Store s,VoidCallback refresh)async{if(s.items.isEmpty||s.customers.isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Add an item and customer first.')));return;}String item='${s.items.first['name']}',customer='${s.customers.first['name']}';final q=TextEditingController(text:'1'),a=TextEditingController(text:'0');final ok=await showDialog<bool>(context:c,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('New Rental'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:item,items:s.items.map((e)=>DropdownMenuItem(value:'${e['name']}',child:Text('${e['name']}'))).toList(),onChanged:(v)=>setD(()=>item=v??item),decoration:const InputDecoration(labelText:'Item')),DropdownButtonFormField<String>(initialValue:customer,items:s.customers.map((e)=>DropdownMenuItem(value:'${e['name']}',child:Text('${e['name']}'))).toList(),onChanged:(v)=>setD(()=>customer=v??customer),decoration:const InputDecoration(labelText:'Customer')),TextField(controller:q,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity')),TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Issue'))])));if(ok==true){final qty=asInt(q.text);final itemMap=s.items.firstWhere((x)=>'${x['name']}'==item);if(qty>0&&qty<=asInt(itemMap['available'])){itemMap['available']=asInt(itemMap['available'])-qty;s.rentals.add({'item':item,'customer':customer,'qty':qty,'received':0,'amount':asDouble(a.text),'date':DateTime.now().toString().split(' ').first});await s.saveData();refresh();}}}
Future<void> receiveDialog(BuildContext c,Store s,VoidCallback refresh)async{final active=s.rentals.where((r)=>asInt(r['received'])<asInt(r['qty'])).toList();if(active.isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('No issued rental found.')));return;}Map<String,dynamic> selected=active.first;final ok=await showDialog<bool>(context:c,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Receive Item'),content:DropdownButtonFormField<Map<String,dynamic>>(initialValue:selected,items:active.map((r)=>DropdownMenuItem(value:r,child:Text('${r['customer']} • ${r['item']}'))).toList(),onChanged:(v)=>setD(()=>selected=v??selected)),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Receive'))])));if(ok==true){final qty=asInt(selected['qty']);selected['received']=qty;final it=s.items.firstWhere((x)=>'${x['name']}'=='${selected['item']}',orElse:()=>{});if(it.isNotEmpty)it['available']=asInt(it['available'])+qty;await s.saveData();refresh();}}
Future<void> invoiceDialog(BuildContext c,Store s)async{if(s.rentals.isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('No rental invoice available.')));return;}final r=s.rentals.last;showDialog(context:c,builder:(d)=>AlertDialog(title:const Text('Rental Invoice'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('RentFlow',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const Text('By PaliaAPK HUB'),const SizedBox(height:14),Text('Customer: ${r['customer']}'),Text('Item: ${r['item']}'),Text('Date: ${r['date']}'),Text('Qty: ${r['qty']}'),const SizedBox(height:10),Text('Amount: ${money(r['amount'])}',style:const TextStyle(fontWeight:FontWeight.w900))]),actions:[FilledButton(onPressed:()=>Navigator.pop(d),child:const Text('Close'))]));}
Future<void> customerReport(BuildContext c,Store s,String name)async{final rows=s.rentals.where((r)=>'${r['customer']}'==name).toList();showDialog(context:c,builder:(d)=>AlertDialog(title:Text('$name Report'),content:SizedBox(width:360,child:rows.isEmpty?const Text('No rental records.'):ListView(shrinkWrap:true,children:rows.map((r)=>ListTile(title:Text('${r['item']} • Qty ${r['qty']}'),subtitle:Text('${r['date']} • ${asInt(r['received'])>=asInt(r['qty'])?'Received':'Issued'}'),trailing:Text(money(r['amount'])))).toList())),actions:[FilledButton(onPressed:()=>Navigator.pop(d),child:const Text('Close'))]));}
Future<void> checkUpdate(BuildContext c)async{showDialog(context:c,builder:(_)=>const AlertDialog(content:Row(children:[CircularProgressIndicator(color:primary),SizedBox(width:16),Text('Checking for updates...')])));try{final response=await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds:8));if(!c.mounted)return;Navigator.pop(c);if(response.statusCode!=200){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Could not check for updates.')));return;}final data=jsonDecode(response.body);final latest='${data['version']??appVersion}';if(latest!=appVersion){showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Update Available'),content:Text('RentFlow $latest is available.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Later')),FilledButton(onPressed:()=>launchUrl(Uri.parse('${data['url']??websiteUrl}'),mode:LaunchMode.externalApplication),child:const Text('Update'))]));}else{ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('RentFlow is up to date.')));}}catch(_){if(c.mounted){Navigator.pop(c);ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Could not check for updates.')));}}}
