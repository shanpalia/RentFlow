import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE7F6F1);
const pageBg = Color(0xFFF5F8F7);
const ink = Color(0xFF172521);
const border = Color(0xFFD8E5E1);

void startRentFlowFixed() {
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
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: ink,
            elevation: 0,
          ),
        ),
        home: const HomePage(),
      );
}

class RentDB extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String, dynamic>> shops = [];
  int active = 0;
  bool get ready => prefs != null;
  Map<String, dynamic> get shop => shops.isEmpty ? <String, dynamic>{} : shops[active];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_data') ?? '[]');
      if (raw is List) {
        shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      shops = [];
    }
    active = prefs!.getInt('rentflow_active') ?? 0;
    if (active < 0 || active >= shops.length) active = 0;
    notifyListeners();
  }

  Future<void> save() async {
    await prefs?.setString('rentflow_data', jsonEncode(shops));
    await prefs?.setInt('rentflow_active', active);
    notifyListeners();
  }

  List<Map<String, dynamic>> records(String key) {
    final value = shop[key];
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addShop(Map<String, dynamic> data) async {
    shops.add({...data, 'items': [], 'customers': [], 'issues': [], 'returns': []});
    active = shops.length - 1;
    await save();
  }

  Future<void> updateShop(Map<String, dynamic> data) async {
    shop.addAll(data);
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> data) async {
    if (shop[key] is! List) shop[key] = [];
    (shop[key] as List).add(data);
    await save();
  }

  Future<void> editRecord(String key, int index, Map<String, dynamic> data) async {
    (shop[key] as List)[index] = data;
    await save();
  }

  Future<void> updateStock(String itemId, int delta) async {
    final items = shop['items'] as List? ?? [];
    for (var i = 0; i < items.length; i++) {
      final item = Map<String, dynamic>.from(items[i] as Map);
      if ('${item['id']}' == itemId) {
        item['quantity'] = (int.tryParse('${item['quantity'] ?? 0}') ?? 0) + delta;
        items[i] = item;
        break;
      }
    }
    await save();
  }
}

final rentDb = RentDB();
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(dynamic v) => '₹${(double.tryParse('$v') ?? 0).toStringAsFixed(2)}';
List<Map<String, dynamic>> mapList(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
int calcDays(String issue, String returned) {
  final a = DateTime.tryParse(issue) ?? DateTime.now();
  final b = DateTime.tryParse(returned) ?? DateTime.now();
  final d = b.difference(a).inDays;
  return d < 1 ? 1 : d;
}
void openPage(BuildContext context, Widget page) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const AppHeader({super.key, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => AppBar(
        leading: back
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : Builder(
                builder: (c) => IconButton(
                  onPressed: () => Scaffold.of(c).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, size: 30),
                ),
              ),
        title: Row(
          children: [
            SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34),
            const SizedBox(width: 10),
            const Text('RentFlow by PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      );
}

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});
  void go(BuildContext c, Widget page) {
    Navigator.pop(c);
    openPage(c, page);
  }
  @override
  Widget build(BuildContext c) => Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SvgPicture.asset('assets/rentflow_logo.svg', width: 48, height: 48),
                    const SizedBox(width: 12),
                    const Text('RentFlow\nPaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    item(c, 'Dashboard', Icons.dashboard_rounded, const HomePage()),
                    item(c, 'Inventory', Icons.inventory_2_rounded, const ItemsPage()),
                    item(c, 'Customers / Parties', Icons.people_alt_rounded, const CustomersPage()),
                    item(c, 'Issued / New Invoice', Icons.outbox_rounded, const IssuePage()),
                    item(c, 'Returns', Icons.assignment_return_rounded, const ReturnPage()),
                    item(c, 'Inventory Register', Icons.table_rows_rounded, const InventoryPage()),
                    item(c, 'Reports / Bills', Icons.receipt_long_rounded, const BillsPage()),
                    item(c, 'Shop / Company', Icons.store_rounded, const ShopPage()),
                    item(c, 'Settings / About', Icons.settings_rounded, const SettingsPage()),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
  Widget item(BuildContext c, String title, IconData icon, Widget page) => ListTile(
        leading: Icon(icon, color: emerald),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        onTap: () => go(c, page),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}
class _HomeState extends State<HomePage> {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    rentDb.load();
  }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
        animation: rentDb,
        builder: (_, __) {
          if (!rentDb.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
          return Scaffold(
            appBar: const AppHeader(),
            drawer: const SideMenu(),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                shopCard(c),
                const SizedBox(height: 18),
                const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    action('New Invoice', Icons.receipt_long_rounded, () => openPage(c, const IssuePage())),
                    action('Return', Icons.assignment_return_rounded, () => openPage(c, const ReturnPage())),
                    action('Add Item', Icons.add_box_rounded, () => openPage(c, const ItemForm())),
                    action('Add Customer', Icons.person_add_rounded, () => openPage(c, const CustomerForm())),
                    action('Inventory', Icons.inventory_2_rounded, () => openPage(c, const ItemsPage())),
                    action('Reports / Bills', Icons.picture_as_pdf_rounded, () => openPage(c, const BillsPage())),
                  ],
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: stat('Items', rentDb.records('items').length, Icons.inventory_2)),
                  Expanded(child: stat('Parties', rentDb.records('customers').length, Icons.people)),
                  Expanded(child: stat('Issued', rentDb.records('issues').length, Icons.outbox)),
                ]),
                const SizedBox(height: 24),
                const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) {
                setState(() => tab = v);
                if (v == 1) openPage(c, const ItemsPage());
                if (v == 2) openPage(c, const IssuePage());
                if (v == 3) openPage(c, const ReturnPage());
                if (v == 4) openPage(c, const SettingsPage());
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.outbox_outlined), label: 'Issued'),
                NavigationDestination(icon: Icon(Icons.assignment_return_outlined), label: 'Returns'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
            ),
          );
        },
      );
  Widget shopCard(BuildContext c) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: border)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(16)),
                child: rentDb.shop['image'] != null && '${rentDb.shop['image']}'.isNotEmpty
                    ? Image.file(File('${rentDb.shop['image']}'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 34))
                    : const Icon(Icons.store_rounded, color: emerald, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rentDb.shop['name'] ?? 'Register your shop'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text('${rentDb.shop['owner'] ?? ''}  ${rentDb.shop['mobile'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                Text('${rentDb.shop['address'] ?? 'Shop information'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
              ])),
              IconButton(onPressed: () => openPage(c, const ShopPage()), icon: const Icon(Icons.edit_outlined, color: emerald)),
            ],
          ),
        ),
      );
  Widget action(String title, IconData icon, VoidCallback onTap) => ActionCard(title, icon, onTap);
  Widget stat(String title, int value, IconData icon) => Card(elevation: 0, margin: const EdgeInsets.only(right: 8), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Icon(icon, color: emerald), const SizedBox(height: 4), Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: Colors.black54))])));
}

class ActionCard extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback onTap;
  const ActionCard(this.title, this.icon, this.onTap, {super.key});
  @override Widget build(BuildContext c) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: border)), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: emerald, size: 30), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))])));
}

class PageFrame extends StatelessWidget {
  final String title; final Widget child;
  const PageFrame(this.title, this.child, {super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: const AppHeader(back: true), body: ListView(padding: const EdgeInsets.all(16), children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)), Container(height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(5))), child]));
}
class FieldBox extends StatelessWidget {
  final String label; final TextEditingController controller; final int maxLines; final TextInputType? keyboard;
  const FieldBox(this.label, this.controller, {super.key, this.maxLines = 1, this.keyboard});
  @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))));
}
class SaveButton extends StatelessWidget { final String label; final VoidCallback onPressed; final IconData icon; const SaveButton(this.label, this.onPressed, {super.key, this.icon = Icons.check_rounded}); @override Widget build(BuildContext c) => SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Padding(padding: const EdgeInsets.all(12), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))); }

class ShopPage extends StatefulWidget { const ShopPage({super.key}); @override State<ShopPage> createState() => _ShopState(); }
class _ShopState extends State<ShopPage> {
  late TextEditingController name, owner, mobile, address; String? image;
  @override void initState(){super.initState();final x=rentDb.shop;name=TextEditingController(text:'${x['name']??''}');owner=TextEditingController(text:'${x['owner']??''}');mobile=TextEditingController(text:'${x['mobile']??''}');address=TextEditingController(text:'${x['address']??''}');image=x['image'];}
  @override void dispose(){name.dispose();owner.dispose();mobile.dispose();address.dispose();super.dispose();}
  Future<void> pickImage() async { final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80); if(x!=null)setState(()=>image=x.path); }
  Future<void> save() async { if(name.text.trim().isEmpty)return; final x={'name':name.text.trim(),'owner':owner.text.trim(),'mobile':mobile.text.trim(),'address':address.text.trim(),'image':image}; if(rentDb.shops.isEmpty)await rentDb.addShop(x);else await rentDb.updateShop(x);if(mounted)Navigator.pop(context); }
  @override Widget build(BuildContext c)=>PageFrame(rentDb.shops.isEmpty?'Register Shop':'Shop / Company',Column(children:[GestureDetector(onTap:pickImage,child:Container(width:120,height:120,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:emeraldSoft,borderRadius:BorderRadius.circular(22)),child:image!=null?Image.file(File(image!),fit:BoxFit.cover):const Icon(Icons.add_a_photo_rounded,color:emerald,size:40))),const SizedBox(height:8),const Text('Tap to add shop image'),const SizedBox(height:16),FieldBox('Shop / Company Name',name),FieldBox('Owner Name',owner),FieldBox('Mobile Number',mobile,keyboard:TextInputType.phone),FieldBox('Address',address,maxLines:3),SaveButton(rentDb.shops.isEmpty?'Save Shop':'Update Shop',save)]));
}

class ItemsPage extends StatelessWidget { const ItemsPage({super.key}); @override Widget build(BuildContext c){final a=rentDb.records('items');return PageFrame('Inventory',Column(children:[Row(children:[const Expanded(child:Text('Items / Stock',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),IconButton(tooltip:'Add Item',onPressed:()=>openPage(c,const ItemForm()),icon:const Icon(Icons.add_circle_rounded,color:emerald,size:34))]),if(a.isEmpty)const Padding(padding:EdgeInsets.all(25),child:Text('No items yet. Tap + to add item.')),...a.asMap().entries.map((e)=>Card(elevation:0,child:ListTile(leading:const CircleAvatar(backgroundColor:emeraldSoft,child:Icon(Icons.inventory_2,color:emerald)),title:Text('${e.value['name']}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('Code ${e.value['code']??''} • Rent ${e.value['rentPrice']??15}/100'),trailing:Text('${e.value['quantity']??0}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),onTap:()=>openPage(c,ItemForm(index:e.key))))]));}}
class ItemForm extends StatefulWidget { final int? index; const ItemForm({super.key,this.index}); @override State<ItemForm> createState()=>_ItemState(); }
class _ItemState extends State<ItemForm>{late TextEditingController code,name,unit,qty,rent;@override void initState(){super.initState();final x=widget.index==null?<String,dynamic>{}:rentDb.records('items')[widget.index!];code=TextEditingController(text:'${x['code']??''}');name=TextEditingController(text:'${x['name']??''}');unit=TextEditingController(text:'${x['unit']??'pcs'}');qty=TextEditingController(text:'${x['quantity']??0}');rent=TextEditingController(text:'${x['rentPrice']??15}');}@override void dispose(){code.dispose();name.dispose();unit.dispose();qty.dispose();rent.dispose();super.dispose();}Future<void> save()async{if(name.text.trim().isEmpty)return;final old=widget.index==null?null:rentDb.records('items')[widget.index!];final x={'id':old?['id']??uid(),'code':code.text.trim(),'name':name.text.trim(),'unit':unit.text.trim().isEmpty?'pcs':unit.text.trim(),'quantity':int.tryParse(qty.text)??0,'rentPrice':double.tryParse(rent.text)??15};if(widget.index==null)await rentDb.addRecord('items',x);else await rentDb.editRecord('items',widget.index!,x);if(mounted)Navigator.pop(context);}@override Widget build(BuildContext c)=>PageFrame(widget.index==null?'Add Item':'Edit Item',Column(children:[FieldBox('Item Code',code),FieldBox('Item Name / Description',name),Row(children:[Expanded(child:FieldBox('Unit',unit)),const SizedBox(width:8),Expanded(child:FieldBox('Opening Qty',qty,keyboard:TextInputType.number))]),FieldBox('Rent Price / 100',rent,keyboard:TextInputType.number),const Align(alignment:Alignment.centerLeft,child:Text('Patra default: ₹15 per 100 pcs',style:TextStyle(color:emeraldDark,fontWeight:FontWeight.w700))),const SizedBox(height:14),SaveButton('Save Item',save)]));}

class CustomersPage extends StatelessWidget{const CustomersPage({super.key});@override Widget build(BuildContext c){final a=rentDb.records('customers');return PageFrame('Customers / Parties',Column(children:[Row(children:[const Expanded(child:Text('Party Master',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),IconButton(tooltip:'Add Customer',onPressed:()=>openPage(c,const CustomerForm()),icon:const Icon(Icons.person_add_rounded,color:emerald,size:32))]),...a.asMap().entries.map((e)=>Card(elevation:0,child:ListTile(leading:const Icon(Icons.person,color:emerald),title:Text('${e.value['name']}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${e.value['mobile']??''}\n${e.value['address']??''}'),onTap:()=>openPage(c,CustomerForm(index:e.key)))),if(a.isEmpty)const Padding(padding:EdgeInsets.all(25),child:Text('No parties. Tap + to add.'))]));}}
class CustomerForm extends StatefulWidget{final int? index;const CustomerForm({super.key,this.index});@override State<CustomerForm> createState()=>_CustomerState();}
class _CustomerState extends State<CustomerForm>{late TextEditingController name,mobile,address;@override void initState(){super.initState();final x=widget.index==null?<String,dynamic>{}:rentDb.records('customers')[widget.index!];name=TextEditingController(text:'${x['name']??''}');mobile=TextEditingController(text:'${x['mobile']??''}');address=TextEditingController(text:'${x['address']??''}');}@override void dispose(){name.dispose();mobile.dispose();address.dispose();super.dispose();}Future<void> save()async{if(name.text.trim().isEmpty)return;final old=widget.index==null?null:rentDb.records('customers')[widget.index!];final x={'id':old?['id']??uid(),'name':name.text.trim(),'mobile':mobile.text.trim(),'address':address.text.trim()};if(widget.index==null)await rentDb.addRecord('customers',x);else await rentDb.editRecord('customers',widget.index!,x);if(mounted)Navigator.pop(context);}@override Widget build(BuildContext c)=>PageFrame(widget.index==null?'Add Customer':'Edit Customer',Column(children:[FieldBox('Customer / Party Name',name),FieldBox('Mobile Number',mobile,keyboard:TextInputType.phone),FieldBox('Address',address,maxLines:3),SaveButton('Save Customer',save)]));}

class IssuePage extends StatefulWidget{const IssuePage({super.key});@override State<IssuePage> createState()=>_IssueState();}
class _IssueState extends State<IssuePage>{String? customer;final invoice=TextEditingController();final rows=<Map<String,dynamic>>[];@override void initState(){super.initState();invoice.text='INV-${DateTime.now().millisecondsSinceEpoch}';}@override void dispose(){invoice.dispose();super.dispose();}void addRow(){final a=rentDb.records('items');if(a.isNotEmpty)setState(()=>rows.add({'itemId':a.first['id'],'name':a.first['name'],'qty':1,'rentPrice':a.first['rentPrice']??15}));}Future<void> save()async{if(customer==null||rows.isEmpty)return;await rentDb.addRecord('issues',{'id':uid(),'invoice':invoice.text,'customerId':customer,'issueDate':today(),'items':rows.map((e)=>Map<String,dynamic>.from(e)).toList()});for(final x in rows)await rentDb.updateStock('${x['itemId']}',-(int.tryParse('${x['qty']}')??0));if(mounted)Navigator.pop(context);}@override Widget build(BuildContext c){final customers=rentDb.records('customers'),items=rentDb.records('items');return PageFrame('Issued / New Invoice',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer / Party'),items:customers.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v))),IconButton(tooltip:'Add Customer',onPressed:()=>openPage(c,const CustomerForm()),icon:const Icon(Icons.add_circle_rounded,color:emerald,size:32))]),const SizedBox(height:10),FieldBox('Invoice Number',invoice),...rows.asMap().entries.map((e){final x=e.value,i=e.key;return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(value:'${x['itemId']}',decoration:const InputDecoration(labelText:'Item'),items:items.map((z)=>DropdownMenuItem(value:'${z['id']}',child:Text('${z['name']}'))).toList(),onChanged:(v){final z=items.firstWhere((q)=>'${q['id']}'==v);setState((){x['itemId']=v;x['name']=z['name'];x['rentPrice']=z['rentPrice']??15;});}})),SizedBox(width:75,child:TextFormField(initialValue:'${x['qty']}',keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Qty'),onChanged:(v)=>x['qty']=int.tryParse(v)??1)),IconButton(onPressed:()=>setState(()=>rows.removeAt(i)),icon:const Icon(Icons.delete_outline,color:Colors.red))]));}),TextButton.icon(onPressed:addRow,icon:const Icon(Icons.add_circle,color:emerald),label:const Text('Add Another Item')),const SizedBox(height:10),SaveButton('Save Issued Invoice',save,icon:Icons.save_rounded)]));}}

class ReturnPage extends StatefulWidget{const ReturnPage({super.key});@override State<ReturnPage> createState()=>_ReturnState();}
class _ReturnState extends State<ReturnPage>{String? customer,issueId;final amount=TextEditingController(),notes=TextEditingController();DateTime returnDate=DateTime.now();final selected=<String,int>{};@override void dispose(){amount.dispose();notes.dispose();super.dispose();}
Future<void> save()async{final issues=rentDb.records('issues');final issue=issues.firstWhere((x)=>'${x['id']}'==issueId,orElse:()=>{});if(issue.isEmpty||customer==null)return;final rd=returnDate.toIso8601String().substring(0,10),days=calcDays('${issue['issueDate']}',rd),items=mapList(issue['items']).map((x){final q=selected['${x['itemId']}']??0;final r=double.tryParse('${x['rentPrice']??15}')??15;return {...x,'returnQty':q,'rentDays':days,'amount':r*q*days};}).where((x)=>(x['returnQty'] as int)>0).toList();if(items.isEmpty)return;final total=items.fold<double>(0,(s,x)=>s+(double.tryParse('${x['amount']}')??0));await rentDb.addRecord('returns',{'id':uid(),'returnInvoice':'RET-${DateTime.now().millisecondsSinceEpoch}','customerId':customer,'issueId':issueId,'issueDate':issue['issueDate'],'returnDate':rd,'rentDays':days,'amount':double.tryParse(amount.text)??total,'notes':notes.text,'items':items});for(final x in items)await rentDb.updateStock('${x['itemId']}',x['returnQty'] as int);if(mounted)Navigator.pop(context);}
@override Widget build(BuildContext c){final customers=rentDb.records('customers'),issues=rentDb.records('issues');final issue=issues.firstWhere((x)=>'${x['id']}'==issueId,orElse:()=>{});final items=mapList(issue['items']);return PageFrame('Return / Receive',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(value:customer,decoration:const InputDecoration(labelText:'Customer / Party'),items:customers.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setState(()=>customer=v))),IconButton(tooltip:'Add Customer',onPressed:()=>openPage(c,const CustomerForm()),icon:const Icon(Icons.add_circle_rounded,color:emerald,size:32))]),const SizedBox(height:10),DropdownButtonFormField<String>(value:issueId,decoration:const InputDecoration(labelText:'Issued Invoice'),items:issues.map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['invoice']} • ${x['issueDate']}'))).toList(),onChanged:(v){final x=issues.firstWhere((z)=>'${z['id']}'==v);setState((){issueId=v;customer='${x['customerId']}';});}),if(issue.isNotEmpty)...[const SizedBox(height:12),Text('Issue Date: ${issue['issueDate']}',style:const TextStyle(fontWeight:FontWeight.w800)),...items.map((x){final max=int.tryParse('${x['qty']}')??0,key='${x['itemId']}';return Card(elevation:0,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x['name']}',style:const TextStyle(fontWeight:FontWeight.w900)),Text('Issued Qty $max • Rent ${x['rentPrice']??15}/100')])) ,SizedBox(width:82,child:TextFormField(initialValue:'${selected[key]??0}',keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Return Qty'),onChanged:(v)=>selected[key]=(int.tryParse(v)??0).clamp(0,max)))]));}),const SizedBox(height:8),ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),side:const BorderSide(color:border)),leading:const Icon(Icons.calendar_month,color:emerald),title:const Text('Return Date'),subtitle:Text(returnDate.toIso8601String().substring(0,10)),onTap:()async{final d=await showDatePicker(context:c,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:returnDate);if(d!=null)setState(()=>returnDate=d);}),Text('Rent Days: ${calcDays('${issue['issueDate']}',returnDate.toIso8601String().substring(0,10))}',style:const TextStyle(fontWeight:FontWeight.w900,color:emeraldDark)),FieldBox('Manual Amount (optional)',amount,keyboard:TextInputType.number),FieldBox('Notes',notes,maxLines:2),SaveButton('Save Return',save,icon:Icons.save_rounded)]));}}

class InventoryPage extends StatelessWidget{const InventoryPage({super.key});@override Widget build(BuildContext c){final a=rentDb.records('items');return PageFrame('Inventory Register',Column(children:[...a.map((x)=>Card(elevation:0,child:ListTile(leading:const Icon(Icons.inventory_2,color:emerald),title:Text('${x['name']}',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('Rent ${x['rentPrice']??15}/100 • ${x['unit']??'pcs'}'),trailing:Text('${x['quantity']??0}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))))]));}}

class BillsPage extends StatelessWidget{const BillsPage({super.key});String party(String id){for(final x in rentDb.records('customers')){if('${x['id']}'==id)return '${x['name']}';}return 'Party';}
Future<void> showPdf(Map<String,dynamic> bill,{bool isReturn=false})async{final doc=pw.Document();final items=mapList(bill['items']);doc.addPage(pw.MultiPage(build:(_)=>[pw.Text('${rentDb.shop['name']??'RentFlow'}',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),pw.Text('RentFlow by PaliaAPK HUB'),pw.SizedBox(height:10),pw.Text(isReturn?'RETURN RECEIPT':'RENT / ISSUE INVOICE'),pw.Text('Party: ${party('${bill['customerId']}')}'),pw.Text('Issue Date: ${bill['issueDate']??'-'}'),if(isReturn)pw.Text('Return Date: ${bill['returnDate']??'-'}   Rent Days: ${bill['rentDays']??0}'),pw.SizedBox(height:10),pw.Table.fromTextArray(headers:isReturn?['Item','Issued','Return','Rent','Days','Amount']:['Item','Qty','Rent/100'],data:items.map((x)=>isReturn?['${x['name']}','${x['qty']}','${x['returnQty']}','${x['rentPrice']}','${x['rentDays']}','${x['amount']}']:['${x['name']}','${x['qty']}','${x['rentPrice']}']).toList()),if(isReturn)pw.Padding(padding:const pw.EdgeInsets.only(top:12),child:pw.Text('Total: ${money(bill['amount'])}',style:pw.TextStyle(fontWeight:pw.FontWeight.bold))),pw.SizedBox(height:20),pw.Text('By PaliaAPK HUB • Developer by shanpalia')]));await Printing.layoutPdf(onLayout:(_)=>doc.save(),name:'${isReturn?'return':'invoice'}_${bill['id']}.pdf');}
@override Widget build(BuildContext c){final issues=rentDb.records('issues'),returns=rentDb.records('returns');return PageFrame('Reports / Bills',Column(children:[const Align(alignment:Alignment.centerLeft,child:Text('ISSUED BILLS',style:TextStyle(fontWeight:FontWeight.w900,color:emeraldDark))),...issues.map((x)=>Card(elevation:0,child:ListTile(leading:const Icon(Icons.receipt_long,color:emerald),title:Text('${x['invoice']} • ${party('${x['customerId']}')}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Issued ${x['issueDate']} • ${mapList(x['items']).length} item(s)'),trailing:IconButton(tooltip:'Print / Preview PDF',onPressed:()=>showPdf(x),icon:const Icon(Icons.picture_as_pdf,color:emerald)))),const SizedBox(height:12),const Align(alignment:Alignment.centerLeft,child:Text('RETURN RECEIPTS',style:TextStyle(fontWeight:FontWeight.w900,color:emeraldDark))),...returns.map((x)=>Card(elevation:0,child:ListTile(leading:const Icon(Icons.assignment_return,color:emerald),title:Text('${x['returnInvoice']} • ${party('${x['customerId']}')}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Issued ${x['issueDate']} • Return ${x['returnDate']} • ${x['rentDays']} days • ${money(x['amount'])}'),trailing:IconButton(tooltip:'Print / Preview PDF',onPressed:()=>showPdf(x,isReturn:true),icon:const Icon(Icons.picture_as_pdf,color:emerald)))),if(issues.isEmpty&&returns.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Text('No bills yet.'))]));}}

class SettingsPage extends StatelessWidget{const SettingsPage({super.key});@override Widget build(BuildContext c)=>PageFrame('Settings / About',Column(children:[Card(elevation:0,child:ListTile(leading:const Icon(Icons.info_outline,color:emerald),title:const Text('RentFlow by PaliaAPK HUB',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:const Text('Professional rental and inventory management.'))),Card(elevation:0,child:ListTile(leading:const Icon(Icons.store,color:emerald),title:const Text('Shop / Company'),subtitle:Text('${rentDb.shop['name']??'Not registered'}'),onTap:()=>openPage(c,const ShopPage()))),const SizedBox(height:12),const Text('Developer by shanpalia',style:TextStyle(color:Colors.black54,fontWeight:FontWeight.w700))]));}
