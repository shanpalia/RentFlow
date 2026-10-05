import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE6F5F1);
const pageBg = Color(0xFFF5F8F7);
const border = Color(0xFFD8E5E1);
const textDark = Color(0xFF172521);

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
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBg,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
      ),
    ),
    home: const SplashPage(),
  );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(child: SizedBox(width: 360, child: SvgPicture.asset('assets/rentflow_splash.svg'))),
  );
}

class StoreDB extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String,dynamic>> shops = [];
  int activeShop = 0;
  bool get ready => prefs != null;
  Map<String,dynamic> get shop => shops.isEmpty ? {} : shops[activeShop];
  List<Map<String,dynamic>> records(String key) {
    final v = shop[key];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
  }
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_data') ?? '[]');
      if (raw is List) shops = raw.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
    } catch (_) { shops = []; }
    activeShop = prefs!.getInt('rentflow_active') ?? 0;
    if (activeShop >= shops.length) activeShop = shops.isEmpty ? 0 : shops.length - 1;
    notifyListeners();
  }
  Future<void> save() async {
    await prefs?.setString('rentflow_data', jsonEncode(shops));
    await prefs?.setInt('rentflow_active', activeShop);
    notifyListeners();
  }
  Future<void> addShop(Map<String,dynamic> data) async {
    shops.add({...data, 'items': [], 'customers': [], 'issues': [], 'returns': []});
    activeShop = shops.length - 1;
    await save();
  }
  Future<void> addRecord(String key, Map<String,dynamic> data) async { (shop[key] as List).add(data); await save(); }
  Future<void> editRecord(String key, int index, Map<String,dynamic> data) async { (shop[key] as List)[index] = data; await save(); }
  Future<void> deleteRecord(String key, int index) async { (shop[key] as List).removeAt(index); await save(); }
  Future<void> updateShop(Map<String,dynamic> data) async { shop.addAll(data); await save(); }
}
final store = StoreDB();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
Future<void> openPage(BuildContext c, Widget page) => Navigator.push(c, MaterialPageRoute(builder: (_) => page));

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const AppHeader({super.key, this.back = false});
  @override Size get preferredSize => const Size.fromHeight(62);
  @override Widget build(BuildContext c) => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: back ? IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.arrow_back_rounded)) : Padding(padding: const EdgeInsets.all(12), child: SvgPicture.asset('assets/rentflow_logo.svg')),
    title: const Text('RentFlow by PaliaAPK HUB', style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w900)),
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: border)),
  );
}

class PageFrame extends StatelessWidget {
  final String title; final Widget child;
  const PageFrame({super.key, required this.title, required this.child});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: const AppHeader(back: true),
    body: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,30), children: [Text(title, style: const TextStyle(fontSize: 26,fontWeight: FontWeight.w900,color:textDark)), const SizedBox(height:16), child]),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  @override void initState(){super.initState();store.load();}
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:store,builder:(_,__) {
    if(!store.ready) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final hasShop=store.shops.isNotEmpty;
    return Scaffold(appBar:const AppHeader(),body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Main Menu',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:textDark)),
      Text(hasShop?'${store.shop['name']??'Shop'} • Emerald workspace':'Set up your rental business',style:const TextStyle(color:Colors.black54)),
      const SizedBox(height:18),
      if(!hasShop) MenuTile(icon:Icons.store_rounded,title:'Register Shop',subtitle:'Create your first shop/company',onTap:()=>openPage(c,const ShopFormPage())) else ...[
        MenuTile(icon:Icons.inventory_2_outlined,title:'Inventory',subtitle:'Item master • multiple entries • stock',onTap:()=>openPage(c,const ItemsPage())),
        MenuTile(icon:Icons.people_alt_outlined,title:'Customers',subtitle:'Customer / party master',onTap:()=>openPage(c,const CustomersPage())),
        MenuTile(icon:Icons.outbox_rounded,title:'Issued',subtitle:'Invoice + customer + multiple item rows',onTap:()=>openPage(c,const IssuePage())),
        MenuTile(icon:Icons.assignment_return_rounded,title:'Return',subtitle:'Customer dropdown + issued items + manual entry',onTap:()=>openPage(c,const ReturnPage())),
        MenuTile(icon:Icons.table_rows_rounded,title:'Inventory Register',subtitle:'Tally / Busy style stock register',onTap:()=>openPage(c,const InventoryRegisterPage())),
        MenuTile(icon:Icons.receipt_long_rounded,title:'Transactions',subtitle:'All issue and return entries',onTap:()=>openPage(c,const TransactionsPage())),
        MenuTile(icon:Icons.store_outlined,title:'Shop / Company',subtitle:'Manage company details',onTap:()=>openPage(c,const ShopsPage())),
        MenuTile(icon:Icons.settings_outlined,title:'Settings',subtitle:'Check Update and app information',onTap:()=>openPage(c,const SettingsPage())),
      ],
      const SizedBox(height:24),
      const Center(child:Text('By PaliaAPK HUB • Developer by shanpalia',style:TextStyle(color:Colors.black45,fontWeight:FontWeight.w700))),
    ]));
  });
}

class MenuTile extends StatelessWidget { final IconData icon; final String title,subtitle; final VoidCallback onTap; const MenuTile({super.key,required this.icon,required this.title,required this.subtitle,required this.onTap}); @override Widget build(BuildContext c)=>Card(elevation:0,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17),side:const BorderSide(color:border)),child:ListTile(onTap:onTap,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:6),leading:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:emeraldSoft,borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:emeraldDark)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900,color:textDark)),subtitle:Text(subtitle,style:const TextStyle(fontSize:12)),trailing:const Icon(Icons.chevron_right_rounded,color:emerald))); }

class ShopFormPage extends StatefulWidget { final bool edit; const ShopFormPage({super.key,this.edit=false}); @override State<ShopFormPage> createState()=>_ShopFormPageState(); }
class _ShopFormPageState extends State<ShopFormPage> { late TextEditingController name,owner,mobile,address; @override void initState(){super.initState();final x=store.shop;name=TextEditingController(text:widget.edit?'${x['name']??''}':'');owner=TextEditingController(text:widget.edit?'${x['owner']??''}':'');mobile=TextEditingController(text:widget.edit?'${x['mobile']??''}':'');address=TextEditingController(text:widget.edit?'${x['address']??''}':'');} @override void dispose(){name.dispose();owner.dispose();mobile.dispose();address.dispose();super.dispose();} Future<void> save()async{if(name.text.trim().isEmpty)return;final d={'name':name.text.trim(),'owner':owner.text.trim(),'mobile':mobile.text.trim(),'address':address.text.trim()};if(widget.edit)await store.updateShop(d);else await store.addShop(d);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>PageFrame(title:widget.edit?'Edit Shop':'Register Shop',child:Column(children:[FieldBox('Shop / Company Name',name),FieldBox('Owner Name',owner),FieldBox('Mobile Number',mobile,keyboard:TextInputType.phone),FieldBox('Address',address,maxLines:3),PrimaryButton(label:widget.edit?'Update Shop':'Save Shop',onPressed:save)])); }

class ShopsPage extends StatelessWidget { const ShopsPage({super.key}); @override Widget build(BuildContext c)=>PageFrame(title:'Shop / Company',child:Column(children:[Card(elevation:0,child:ListTile(leading:const Icon(Icons.store_rounded,color:emerald),title:Text('${store.shop['name']??''}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${store.shop['address']??''}'),trailing:IconButton(icon:const Icon(Icons.edit,color:emerald),onPressed:()=>openPage(c,const ShopFormPage(edit:true)))),),const SizedBox(height:12),PrimaryButton(label:'Add New Shop',icon:Icons.add_business_rounded,onPressed:()=>openPage(c,const ShopFormPage()))])); }

class ItemsPage extends StatelessWidget { const ItemsPage({super.key}); @override Widget build(BuildContext c){final r=store.records('items');return PageFrame(title:'Inventory / Item Master',child:Column(children:[if(r.isEmpty)const EmptyState('No items added yet'),...List.generate(r.length,(i)=>DataRowCard(title:'${r[i]['name']}',subtitle:'Code: ${r[i]['code']} • Unit: ${r[i]['unit']} • Qty: ${r[i]['quantity']}',onEdit:()=>openPage(c,ItemFormPage(index:i)),onDelete:()=>store.deleteRecord('items',i))),PrimaryButton(label:'Add Another Item',icon:Icons.add_rounded,onPressed:()=>openPage(c,const ItemFormPage()))]));} }
class ItemFormPage extends StatefulWidget { final int? index; const ItemFormPage({super.key,this.index}); @override State<ItemFormPage> createState()=>_ItemFormState(); }
class _ItemFormState extends State<ItemFormPage>{late TextEditingController code,name,unit,qty;@override void initState(){super.initState();final x=widget.index==null?<String,dynamic>{}:store.records('items')[widget.index!];code=TextEditingController(text:'${x['code']??''}');name=TextEditingController(text:'${x['name']??''}');unit=TextEditingController(text:'${x['unit']??'pcs'}');qty=TextEditingController(text:'${x['quantity']??0}');}@override void dispose(){code.dispose();name.dispose();unit.dispose();qty.dispose();super.dispose();}Future<void> save()async{if(name.text.trim().isEmpty)return;final old=widget.index==null?null:store.records('items')[widget.index!];final d={'id':old?['id']??newId(),'code':code.text.trim(),'name':name.text.trim(),'unit':unit.text.trim().isEmpty?'pcs':unit.text.trim(),'quantity':int.tryParse(qty.text)??0};if(widget.index==null)await store.addRecord('items',d);else await store.editRecord('items',widget.index!,d);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>PageFrame(title:widget.index==null?'New Item':'Edit Item',child:Column(children:[FieldBox('Item Code',code),FieldBox('Item Name / Description',name),Row(children:[Expanded(child:FieldBox('Unit',unit)),const SizedBox(width:10),Expanded(child:FieldBox('Quantity',qty,keyboard:TextInputType.number))]),PrimaryButton(label:'Save Item',onPressed:save)]));}}

class CustomersPage extends StatelessWidget { const CustomersPage({super.key}); @override Widget build(BuildContext c){final r=store.records('customers');return PageFrame(title:'Customer / Party Master',child:Column(children:[if(r.isEmpty)const EmptyState('No customers added yet'),...List.generate(r.length,(i)=>DataRowCard(title:'${r[i]['name']}',subtitle:'${r[i]['mobile']} • ${r[i]['address']}',onEdit:()=>openPage(c,CustomerFormPage(index:i)),onDelete:()=>store.deleteRecord('customers',i))),PrimaryButton(label:'Add Customer',icon:Icons.person_add_alt_1_rounded,onPressed:()=>openPage(c,const CustomerFormPage()))]));} }
class CustomerFormPage extends StatefulWidget { final int? index; const CustomerFormPage({super.key,this.index}); @override State<CustomerFormPage> createState()=>_CustomerFormState(); }
class _CustomerFormState extends State<CustomerFormPage>{late TextEditingController name,mobile,address;@override void initState(){super.initState();final x=widget.index==null?<String,dynamic>{}:store.records('customers')[widget.index!];name=TextEditingController(text:'${x['name']??''}');mobile=TextEditingController(text:'${x['mobile']??''}');address=TextEditingController(text:'${x['address']??''}');}@override void dispose(){name.dispose();mobile.dispose();address.dispose();super.dispose();}Future<void> save()async{if(name.text.trim().isEmpty)return;final old=widget.index==null?null:store.records('customers')[widget.index!];final d={'id':old?['id']??newId(),'name':name.text.trim(),'mobile':mobile.text.trim(),'address':address.text.trim()};if(widget.index==null)await store.addRecord('customers',d);else await store.editRecord('customers',widget.index!,d);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>PageFrame(title:widget.index==null?'New Customer':'Edit Customer',child:Column(children:[FieldBox('Customer Name',name),FieldBox('Mobile Number',mobile,keyboard:TextInputType.phone),FieldBox('Address',address,maxLines:3),PrimaryButton(label:'Save Customer',onPressed:save)]));}}

class IssuePage extends StatefulWidget{const IssuePage({super.key});@override State<IssuePage> createState()=>_IssueState();}
class _IssueState extends State<IssuePage>{String? customer;final invoice=TextEditingController();final lines=<Map<String,dynamic>>[];@override void initState(){super.initState();invoice.text='INV-${DateTime.now().millisecondsSinceEpoch}';} @override void dispose(){invoice.dispose();super.dispose();} void addLine(){final items=store.records('items');if(items.isEmpty)return;setState(()=>lines.add({'itemId':items.first['id'],'name':items.first['name'],'qty':1}));}Future<void> save()async{if(customer==null||lines.isEmpty)return;await store.addRecord('issues',{'id':newId(),'invoice':invoice.text,'customerId':customer,'date':DateTime.now().toIso8601String().substring(0,10),'items':lines});if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c){final customers=store.records('customers');final items=store.records('items');return PageFrame(title:'Issued / Rental Invoice',child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer'),items:customers.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v))),IconButton(tooltip:'Add Customer',onPressed:()=>openPage(c,const CustomerFormPage()),icon:const Icon(Icons.add_circle,color:emerald,size:30))]),const SizedBox(height:12),FieldBox('Invoice Number',invoice),const SizedBox(height:8),const Text('Items',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),...List.generate(lines.length,(i)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(value:'${lines[i]['itemId']}',decoration:const InputDecoration(labelText:'Item'),items:items.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v){final x=items.firstWhere((e)=>'${e['id']}'==v);setState((){lines[i]['itemId']=v;lines[i]['name']=x['name'];});}})),const SizedBox(width:8),SizedBox(width:75,child:TextFormField(initialValue:'${lines[i]['qty']}',keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Qty'),onChanged:(v)=>lines[i]['qty']=int.tryParse(v)??1)),IconButton(onPressed:()=>setState(()=>lines.removeAt(i)),icon:const Icon(Icons.delete_outline,color:Colors.red))]))),PrimaryButton(label:'Add Another Item',icon:Icons.add_rounded,onPressed:addLine),const SizedBox(height:10),PrimaryButton(label:'Save Issued Invoice',onPressed:save)]));}}

class ReturnPage extends StatefulWidget{const ReturnPage({super.key});@override State<ReturnPage> createState()=>_ReturnState();}
class _ReturnState extends State<ReturnPage>{String? customer;String? issue;final amount=TextEditingController();Future<void> save()async{await store.addRecord('returns',{'id':newId(),'customerId':customer,'issueId':issue,'amount':double.tryParse(amount.text)??0,'date':DateTime.now().toIso8601String().substring(0,10)});if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c){final customers=store.records('customers');final issues=store.records('issues');return PageFrame(title:'Return',child:Column(children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer'),items:customers.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v))),IconButton(onPressed:()=>openPage(c,const CustomerFormPage()),icon:const Icon(Icons.add_circle,color:emerald,size:30))]),const SizedBox(height:12),DropdownButtonFormField<String>(value:issue,decoration:const InputDecoration(labelText:'Issued Invoice'),items:issues.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['invoice']}'))).toList(),onChanged:(v)=>setState(()=>issue=v)),const SizedBox(height:12),FieldBox('Manual Return Amount',amount,keyboard:TextInputType.number),const SizedBox(height:8),PrimaryButton(label:'Save Return',onPressed:save)]));}}

class InventoryRegisterPage extends StatelessWidget{const InventoryRegisterPage({super.key});@override Widget build(BuildContext c){final r=store.records('items');return PageFrame(title:'Inventory Register',child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const[DataColumn(label:Text('Code')),DataColumn(label:Text('Item')),DataColumn(label:Text('Unit')),DataColumn(label:Text('Qty'))],rows:r.map((x)=>DataRow(cells:[DataCell(Text('${x['code']}')),DataCell(Text('${x['name']}')),DataCell(Text('${x['unit']}')),DataCell(Text('${x['quantity']}'))])).toList())));}}
class TransactionsPage extends StatelessWidget{const TransactionsPage({super.key});@override Widget build(BuildContext c){final a=store.records('issues');final b=store.records('returns');return PageFrame(title:'Transactions',child:Column(children:[...a.map((x)=>ListTile(leading:const Icon(Icons.outbox,color:emerald),title:Text('Issued • ${x['invoice']}'),subtitle:Text('${x['date']}'))),...b.map((x)=>ListTile(leading:const Icon(Icons.assignment_return,color:emerald),title:const Text('Return'),subtitle:Text('${x['date']} • Amount ${x['amount']}')))]));}}
class SettingsPage extends StatelessWidget{const SettingsPage({super.key});@override Widget build(BuildContext c)=>PageFrame(title:'Settings',child:Column(children:[Card(elevation:0,child:ListTile(leading:const Icon(Icons.system_update_alt_rounded,color:emerald),title:const Text('Check Update',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Check the latest RentFlow version'),trailing:const Icon(Icons.chevron_right),onTap:()=>showDialog<void>(context:c,builder:(d)=>AlertDialog(title:const Text('Check Update'),content:const Text('You are using the current installed version.'),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('OK'))])))),const SizedBox(height:8),Card(elevation:0,child:ListTile(leading:const Icon(Icons.info_outline,color:emerald),title:const Text('RentFlow',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Rental Management • By PaliaAPK HUB • Developer by shanpalia')))]));}

class FieldBox extends StatelessWidget{final String label;final TextEditingController controller;final TextInputType? keyboard;final int maxLines;const FieldBox(this.label,this.controller,{super.key,this.keyboard,this.maxLines=1});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:controller,keyboardType:keyboard,maxLines:maxLines,decoration:InputDecoration(labelText:label)));}
class PrimaryButton extends StatelessWidget{final String label;final IconData? icon;final VoidCallback onPressed;const PrimaryButton({super.key,required this.label,required this.onPressed,this.icon});@override Widget build(BuildContext c)=>SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onPressed,icon:Icon(icon??Icons.check_rounded),label:Padding(padding:const EdgeInsets.symmetric(vertical:13),child:Text(label,style:const TextStyle(fontWeight:FontWeight.w800)))));}
class DataRowCard extends StatelessWidget{final String title,subtitle;final VoidCallback onEdit,onDelete;const DataRowCard({super.key,required this.title,required this.subtitle,required this.onEdit,required this.onDelete});@override Widget build(BuildContext c)=>Card(elevation:0,margin:const EdgeInsets.only(bottom:10),child:ListTile(title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(subtitle),trailing:Wrap(children:[IconButton(onPressed:onEdit,icon:const Icon(Icons.edit_outlined,color:emerald)),IconButton(onPressed:onDelete,icon:const Icon(Icons.delete_outline,color:Colors.red))])));}
class EmptyState extends StatelessWidget{final String text;const EmptyState(this.text,{super.key});@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.all(30),child:Center(child:Text(text,style:const TextStyle(color:Colors.black54))));}
