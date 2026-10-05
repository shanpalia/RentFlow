import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE7F6F1);
const pageBg = Color(0xFFF5F8F7);
const ink = Color(0xFF172521);
const line = Color(0xFFD8E5E1);

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
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        home: const HomePage(),
      );
}

class RentDb extends ChangeNotifier {
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

  Future<void> stock(String id, int delta) async {
    final list = shop['items'] as List? ?? [];
    for (var i = 0; i < list.length; i++) {
      final item = Map<String, dynamic>.from(list[i] as Map);
      if ('${item['id']}' == id) {
        final q = (int.tryParse('${item['quantity'] ?? 0}') ?? 0) + delta;
        item['quantity'] = q < 0 ? 0 : q;
        list[i] = item;
        break;
      }
    }
    await save();
  }
}

final db = RentDb();
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(dynamic value) => '₹${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';
List<Map<String, dynamic>> maps(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
int rentDays(String issue, String returned) {
  final a = DateTime.tryParse(issue) ?? DateTime.now();
  final b = DateTime.tryParse(returned) ?? DateTime.now();
  final d = b.difference(a).inDays;
  return d < 1 ? 1 : d;
}
void openPage(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

class Header extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const Header({super.key, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => AppBar(
        leading: back
            ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded))
            : Builder(builder: (c) => IconButton(onPressed: () => Scaffold.of(c).openDrawer(), icon: const Icon(Icons.menu_rounded, size: 30))),
        title: Row(children: [
          SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34),
          const SizedBox(width: 10),
          const Text('RentFlow by PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: line)),
      );
}

class MenuEntry {
  final String title;
  final IconData icon;
  final Widget page;
  const MenuEntry(this.title, this.icon, this.page);
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  void go(BuildContext context, Widget page) {
    Navigator.pop(context);
    openPage(context, page);
  }
  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                SvgPicture.asset('assets/rentflow_logo.svg', width: 48, height: 48),
                const SizedBox(width: 12),
                const Text('RentFlow\nPaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  MenuEntry('Dashboard', Icons.dashboard_rounded, const HomePage()),
                  MenuEntry('Inventory', Icons.inventory_2_rounded, const ItemsPage()),
                  MenuEntry('Customers / Parties', Icons.people_alt_rounded, const CustomersPage()),
                  MenuEntry('Issued / New Invoice', Icons.outbox_rounded, const IssuePage()),
                  MenuEntry('Returns', Icons.assignment_return_rounded, const ReturnPage()),
                  MenuEntry('Inventory Register', Icons.table_rows_rounded, const InventoryPage()),
                  MenuEntry('Reports / Bills', Icons.receipt_long_rounded, const BillsPage()),
                  MenuEntry('Shop / Company', Icons.store_rounded, const ShopPage()),
                  MenuEntry('Settings / About', Icons.settings_rounded, const SettingsPage()),
                ].map((e) => ListTile(
                      leading: Icon(e.icon, color: emerald),
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => go(context, e.page),
                    )).toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );

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
    db.load();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: db,
        builder: (_, __) {
          if (!db.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
          return Scaffold(
            appBar: const Header(),
            drawer: const AppDrawer(),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                shopCard(context),
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
                    action('New Invoice', Icons.receipt_long_rounded, () => openPage(context, const IssuePage())),
                    action('Return', Icons.assignment_return_rounded, () => openPage(context, const ReturnPage())),
                    action('Add Item', Icons.add_box_rounded, () => openPage(context, const ItemForm())),
                    action('Add Customer', Icons.person_add_rounded, () => openPage(context, const CustomerForm())),
                    action('Inventory', Icons.inventory_2_rounded, () => openPage(context, const ItemsPage())),
                    action('Reports / Bills', Icons.picture_as_pdf_rounded, () => openPage(context, const BillsPage())),
                  ],
                ),
                const SizedBox(height: 18),
                Row(children: [stat('Items', db.records('items').length, Icons.inventory_2), stat('Parties', db.records('customers').length, Icons.people), stat('Issued', db.records('issues').length, Icons.outbox)]),
                const SizedBox(height: 24),
                const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) {
                setState(() => tab = v);
                if (v == 1) openPage(context, const ItemsPage());
                if (v == 2) openPage(context, const IssuePage());
                if (v == 3) openPage(context, const ReturnPage());
                if (v == 4) openPage(context, const SettingsPage());
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.outbox_outlined), label: 'Issued'),
                NavigationDestination(icon: Icon(Icons.assignment_return_outlined), label: 'Returns'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'About'),
              ],
            ),
          );
        },
      );

  Widget shopCard(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 66,
              height: 66,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(16)),
              child: '${db.shop['image'] ?? ''}'.isNotEmpty
                  ? Image.file(File('${db.shop['image']}'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 34))
                  : const Icon(Icons.store_rounded, color: emerald, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${db.shop['name'] ?? 'Register your shop'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text('${db.shop['owner'] ?? ''}  ${db.shop['mobile'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                Text('${db.shop['address'] ?? 'Add your shop information'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            IconButton(onPressed: () => openPage(context, const ShopPage()), icon: const Icon(Icons.edit_outlined, color: emerald)),
          ]),
        ),
      );

  Widget action(String title, IconData icon, VoidCallback onTap) => ActionCard(title, icon, onTap);
  Widget stat(String title, int count, IconData icon) => Expanded(child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(icon, color: emerald), Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: Colors.black54))]))));
}

class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ActionCard(this.title, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: emerald, size: 30), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))])),
      );
}

class Frame extends StatelessWidget {
  final String title;
  final Widget child;
  const Frame(this.title, this.child, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const Header(back: true),
        body: ListView(padding: const EdgeInsets.all(16), children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)), Container(height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(5))), child]),
      );
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboard;
  const Field(this.label, this.controller, {super.key, this.maxLines = 1, this.keyboard});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label)));
}

class SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  const SaveButton(this.label, this.onPressed, {super.key, this.icon = Icons.save_rounded});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Padding(padding: const EdgeInsets.all(12), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))));
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(28), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)));
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopState();
}
class _ShopState extends State<ShopPage> {
  late TextEditingController name, owner, mobile, address;
  String image = '';
  @override
  void initState() {
    super.initState();
    final x = db.shop;
    name = TextEditingController(text: '${x['name'] ?? ''}');
    owner = TextEditingController(text: '${x['owner'] ?? ''}');
    mobile = TextEditingController(text: '${x['mobile'] ?? ''}');
    address = TextEditingController(text: '${x['address'] ?? ''}');
    image = '${x['image'] ?? ''}';
  }
  @override
  void dispose() { name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => image = x.path);
  }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final data = {'name': name.text.trim(), 'owner': owner.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'image': image};
    if (db.shops.isEmpty) { await db.addShop(data); } else { await db.updateShop(data); }
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => Frame('Shop / Company', Column(children: [
        GestureDetector(onTap: pickImage, child: Container(width: 100, height: 100, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(22)), child: image.isNotEmpty ? Image.file(File(image), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.add_a_photo, color: emerald, size: 34)) : const Icon(Icons.add_a_photo, color: emerald, size: 34))),
        const SizedBox(height: 8), const Text('Tap to add shop image', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18),
        Field('Shop Name', name), Field('Owner Name', owner), Field('Mobile Number', mobile, keyboard: TextInputType.phone), Field('Address', address, maxLines: 3), SaveButton('Save Shop', save),
      ]));
}

class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = db.records('items');
    return Frame('Inventory', Column(children: [
      Row(children: [const Expanded(child: Text('Items / Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(tooltip: 'Add Item', onPressed: () => openPage(context, const ItemForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 34))]),
      if (items.isEmpty) const EmptyState('No items yet. Tap + to add item.'),
      ...items.asMap().entries.map((e) => Card(elevation: 0, child: ListTile(leading: const CircleAvatar(backgroundColor: emeraldSoft, child: Icon(Icons.inventory_2, color: emerald)), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Code ${e.value['code'] ?? ''} • Rent ₹${e.value['rentPrice'] ?? 15}/100'), trailing: Text('${e.value['quantity'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), onTap: () => openPage(context, ItemForm(index: e.key))))),
    ]));
  }
}

class ItemForm extends StatefulWidget {
  final int? index;
  const ItemForm({super.key, this.index});
  @override
  State<ItemForm> createState() => _ItemFormState();
}
class _ItemFormState extends State<ItemForm> {
  late TextEditingController code, name, unit, quantity, rent;
  @override
  void initState() {
    super.initState();
    final x = widget.index == null ? <String, dynamic>{} : db.records('items')[widget.index!];
    code = TextEditingController(text: '${x['code'] ?? ''}'); name = TextEditingController(text: '${x['name'] ?? ''}'); unit = TextEditingController(text: '${x['unit'] ?? 'pcs'}'); quantity = TextEditingController(text: '${x['quantity'] ?? 0}'); rent = TextEditingController(text: '${x['rentPrice'] ?? 15}');
  }
  @override
  void dispose() { code.dispose(); name.dispose(); unit.dispose(); quantity.dispose(); rent.dispose(); super.dispose(); }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final old = widget.index == null ? null : db.records('items')[widget.index!];
    final data = {'id': old?['id'] ?? uid(), 'code': code.text.trim(), 'name': name.text.trim(), 'unit': unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(), 'quantity': int.tryParse(quantity.text) ?? 0, 'rentPrice': double.tryParse(rent.text) ?? 15};
    if (widget.index == null) await db.addRecord('items', data); else await db.editRecord('items', widget.index!, data);
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => Frame(widget.index == null ? 'Add Item' : 'Edit Item', Column(children: [Field('Item Code', code), Field('Item Name', name), Field('Unit', unit), Field('Quantity', quantity, keyboard: TextInputType.number), Field('Rent Price per 100', rent, keyboard: const TextInputType.numberWithOptions(decimal: true)), SaveButton('Save Item', save)]));
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final customers = db.records('customers');
    return Frame('Customers / Parties', Column(children: [
      Row(children: [const Expanded(child: Text('Party Master', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(context, const CustomerForm()), icon: const Icon(Icons.person_add_rounded, color: emerald, size: 32))]),
      if (customers.isEmpty) const EmptyState('No parties. Tap + to add.'),
      ...customers.asMap().entries.map((e) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.person, color: emerald), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e.value['mobile'] ?? ''}\n${e.value['address'] ?? ''}'), onTap: () => openPage(context, CustomerForm(index: e.key))))),
    ]));
  }
}

class CustomerForm extends StatefulWidget {
  final int? index;
  const CustomerForm({super.key, this.index});
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}
class _CustomerFormState extends State<CustomerForm> {
  late TextEditingController name, mobile, address;
  @override
  void initState() { super.initState(); final x = widget.index == null ? <String, dynamic>{} : db.records('customers')[widget.index!]; name = TextEditingController(text: '${x['name'] ?? ''}'); mobile = TextEditingController(text: '${x['mobile'] ?? ''}'); address = TextEditingController(text: '${x['address'] ?? ''}'); }
  @override
  void dispose() { name.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; final old = widget.index == null ? null : db.records('customers')[widget.index!]; final d = {'id': old?['id'] ?? uid(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}; if (widget.index == null) await db.addRecord('customers', d); else await db.editRecord('customers', widget.index!, d); if (mounted) Navigator.pop(context); }
  @override
  Widget build(BuildContext context) => Frame(widget.index == null ? 'Add Customer / Party' : 'Edit Customer', Column(children: [Field('Party Name', name), Field('Mobile Number', mobile, keyboard: TextInputType.phone), Field('Address', address, maxLines: 3), SaveButton('Save Customer', save)]));
}

class IssuePage extends StatefulWidget {
  const IssuePage({super.key});
  @override
  State<IssuePage> createState() => _IssueState();
}
class _IssueState extends State<IssuePage> {
  String? customer;
  final invoice = TextEditingController();
  final rows = <Map<String, dynamic>>[];
  @override
  void initState() { super.initState(); invoice.text = 'INV-${DateTime.now().millisecondsSinceEpoch}'; }
  @override
  void dispose() { invoice.dispose(); super.dispose(); }
  void addRow() {
    final items = db.records('items');
    if (items.isEmpty) return;
    final x = items.first;
    setState(() => rows.add({'itemId': x['id'], 'name': x['name'], 'qty': 1, 'rentPrice': x['rentPrice'] ?? 15}));
  }
  Future<void> save() async {
    if (customer == null || rows.isEmpty) return;
    await db.addRecord('issues', {'id': uid(), 'invoice': invoice.text.trim(), 'customerId': customer, 'issueDate': today(), 'items': rows.map((e) => Map<String, dynamic>.from(e)).toList()});
    for (final x in rows) await db.stock('${x['itemId']}', -(int.tryParse('${x['qty']}') ?? 0));
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    final customers = db.records('customers');
    final items = db.records('items');
    return Frame('Issued / New Invoice', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: DropdownButtonFormField<String>(value: customer, decoration: const InputDecoration(labelText: 'Customer / Party'), items: customers.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => customer = v))), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(context, const CustomerForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 32))]),
      const SizedBox(height: 12), Field('Invoice Number', invoice),
      ...rows.asMap().entries.map((e) {
        final i = e.key; final x = e.value;
        return Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: DropdownButtonFormField<String>(value: '${x['itemId']}', decoration: const InputDecoration(labelText: 'Item'), items: items.map((z) => DropdownMenuItem(value: '${z['id']}', child: Text('${z['name']}'))).toList(), onChanged: (v) { final z = items.firstWhere((q) => '${q['id']}' == v); setState(() { x['itemId'] = v; x['name'] = z['name']; x['rentPrice'] = z['rentPrice'] ?? 15; }); })), const SizedBox(width: 8), SizedBox(width: 72, child: TextFormField(initialValue: '${x['qty']}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'), onChanged: (v) => x['qty'] = int.tryParse(v) ?? 1)), IconButton(onPressed: () => setState(() => rows.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.red))])));
      }),
      TextButton.icon(onPressed: addRow, icon: const Icon(Icons.add_circle, color: emerald), label: const Text('Add Another Item')),
      const SizedBox(height: 10),
      const Text('Issue date is saved automatically. Rent days are calculated only when the item is returned.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 10), SaveButton('Save Issued Invoice', save),
    ]));
  }
}

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});
  @override
  State<ReturnPage> createState() => _ReturnState();
}
class _ReturnState extends State<ReturnPage> {
  String? customer;
  Map<String, dynamic>? issue;
  final selected = <String, int>{};
  final manualAmount = TextEditingController();
  final notes = TextEditingController();
  @override
  void dispose() { manualAmount.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (issue == null) return;
    final returnDate = today();
    final days = rentDays('${issue!['issueDate']}', returnDate);
    final out = <Map<String, dynamic>>[];
    double total = 0;
    for (final x in maps(issue!['items'])) {
      final q = selected['${x['itemId']}'] ?? 0;
      if (q <= 0) continue;
      final rate = double.tryParse('${x['rentPrice'] ?? 15}') ?? 15;
      final amount = rate * q * days / 100;
      total += amount;
      out.add({'itemId': x['itemId'], 'name': x['name'], 'issuedQty': x['qty'], 'returnQty': q, 'rentPrice': rate, 'rentDays': days, 'amount': amount});
      await db.stock('${x['itemId']}', q);
    }
    if (out.isEmpty) return;
    final manual = double.tryParse(manualAmount.text.trim());
    if (manual != null) total = manual;
    await db.addRecord('returns', {'id': uid(), 'returnInvoice': 'RET-${DateTime.now().millisecondsSinceEpoch}', 'customerId': customer, 'issueInvoice': issue!['invoice'], 'issueDate': issue!['issueDate'], 'returnDate': returnDate, 'rentDays': days, 'amount': total, 'notes': notes.text.trim(), 'items': out});
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    final customers = db.records('customers');
    final issues = db.records('issues');
    final items = issue == null ? <Map<String, dynamic>>[] : maps(issue!['items']);
    return Frame('Return / Receive', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: DropdownButtonFormField<String>(value: customer, decoration: const InputDecoration(labelText: 'Customer / Party'), items: customers.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() { customer = v; issue = null; selected.clear(); }))), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(context, const CustomerForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 32))]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: issue?['id']?.toString(), decoration: const InputDecoration(labelText: 'Issued Invoice'), items: issues.where((x) => customer == null || '${x['customerId']}' == customer).map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['invoice']} • ${x['issueDate']}'))).toList(), onChanged: (v) { if (v == null) return; final x = issues.firstWhere((q) => '${q['id']}' == v); setState(() { issue = x; selected.clear(); }); }),
      if (issue != null) ...[
        const SizedBox(height: 12),
        Text('Issued Date: ${issue!['issueDate']}   •   Return Date: ${today()}', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Rent Days: ${rentDays('${issue!['issueDate']}', today())}', style: const TextStyle(fontWeight: FontWeight.w800, color: emeraldDark)),
        const SizedBox(height: 8),
        ...items.map((x) => ReturnItemCard(item: x, selectedQty: selected['${x['itemId']}'] ?? 0, onChanged: (q) => setState(() => selected['${x['itemId']}'] = q))),
        Field('Manual Return Amount (optional)', manualAmount, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        Field('Notes', notes, maxLines: 3),
        SaveButton('Save Return & Receipt', save),
      ],
    ]));
  }
}

class ReturnItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int selectedQty;
  final ValueChanged<int> onChanged;
  const ReturnItemCard({super.key, required this.item, required this.selectedQty, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final max = int.tryParse('${item['qty'] ?? 0}') ?? 0;
    final rate = double.tryParse('${item['rentPrice'] ?? 15}') ?? 15;
    final days = rentDays('${item['issueDate'] ?? today()}', today());
    return Card(elevation: 0, color: selectedQty > 0 ? emeraldSoft : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(selectedQty > 0 ? Icons.check_circle : Icons.inventory_2_outlined, color: emerald), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('Issued Qty $max • Rent ₹$rate/100 • Rent Days $days'), Text('Return Amount: ${money(rate * selectedQty * days / 100)}', style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.w800))])), SizedBox(width: 82, child: TextFormField(initialValue: selectedQty == 0 ? '' : '$selectedQty', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Return', hintText: '0-$max'), onChanged: (v) => onChanged((int.tryParse(v) ?? 0).clamp(0, max))))])));
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = db.records('items');
    return Frame('Inventory Register', Column(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('Current Stock / Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      const SizedBox(height: 8),
      if (items.isEmpty) const EmptyState('No inventory records.'),
      ...items.map((x) => Card(elevation: 0, child: ListTile(title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Code ${x['code'] ?? ''} • Rent ₹${x['rentPrice'] ?? 15}/100'), trailing: Text('${x['quantity'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: emerald)))),
    ]));
  }
}

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});
  String party(String? id) { for (final x in db.records('customers')) { if ('${x['id']}' == id) return '${x['name']}'; } return 'Party'; }
  @override
  Widget build(BuildContext context) {
    final issues = db.records('issues');
    final returns = db.records('returns');
    return Frame('Reports / Bills', Column(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('ISSUED BILLS', style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark))),
      ...issues.map((x) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.receipt_long, color: emerald), title: Text('${x['invoice']} • ${party('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Issued ${x['issueDate']} • ${maps(x['items']).length} item(s)'), trailing: IconButton(tooltip: 'Preview / Print PDF', onPressed: () => showBillPreview(context, x), icon: const Icon(Icons.picture_as_pdf, color: emerald))))),
      const SizedBox(height: 14),
      const Align(alignment: Alignment.centerLeft, child: Text('RETURN RECEIPTS', style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark))),
      ...returns.map((x) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.assignment_return, color: emerald), title: Text('${x['returnInvoice']} • ${party('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Issued ${x['issueDate']} • Return ${x['returnDate']} • Rent Days ${x['rentDays']} • ${money(x['amount'])}'), trailing: IconButton(tooltip: 'Preview / Print PDF', onPressed: () => showBillPreview(context, x, isReturn: true), icon: const Icon(Icons.picture_as_pdf, color: emerald))))),
      if (issues.isEmpty && returns.isEmpty) const EmptyState('No bills yet.'),
    ]));
  }
}

Future<void> showBillPreview(BuildContext context, Map<String, dynamic> data, {bool isReturn = false}) async {
  final doc = buildBillPdf(data, isReturn: isReturn);
  await showDialog<void>(context: context, builder: (_) => Dialog(child: SizedBox(width: 760, height: 720, child: PdfPreview(build: (_) => doc.save(), allowPrinting: true, allowSharing: true, canChangePageFormat: false, canChangeOrientation: false))));
}

pw.Document buildBillPdf(Map<String, dynamic> data, {bool isReturn = false}) {
  final doc = pw.Document();
  final items = maps(data['items']);
  final shopName = '${db.shop['name'] ?? 'RentFlow'}';
  doc.addPage(pw.MultiPage(pageFormat: pw.PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (context) => [
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)), pw.Text('${db.shop['address'] ?? ''}'), pw.Text('${db.shop['mobile'] ?? ''}')]), pw.Text(isReturn ? 'RETURN RECEIPT' : 'RENT ISSUE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))]),
    pw.SizedBox(height: 18),
    pw.Divider(),
    pw.Text('${isReturn ? 'Receipt No.' : 'Invoice No.'}: ${isReturn ? data['returnInvoice'] : data['invoice']}'),
    pw.Text('Customer: ${customerName('${data['customerId']}')}'),
    pw.Text('Issued Date: ${data['issueDate'] ?? '-'}'),
    if (isReturn) pw.Text('Return Date: ${data['returnDate'] ?? '-'}'),
    if (isReturn) pw.Text('Rent Days: ${data['rentDays'] ?? 0}'),
    pw.SizedBox(height: 14),
    pw.Table.fromTextArray(headers: isReturn ? ['Item', 'Issued Qty', 'Return Qty', 'Rent / 100', 'Rent Days', 'Amount'] : ['Item', 'Qty', 'Rent / 100'], data: items.map((x) => isReturn ? ['${x['name']}', '${x['issuedQty']}', '${x['returnQty']}', '₹${x['rentPrice']}', '${x['rentDays']}', money(x['amount'])] : ['${x['name']}', '${x['qty']}', '₹${x['rentPrice']}']).toList()),
    pw.SizedBox(height: 16),
    if (isReturn) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Total Amount: ${money(data['amount'])}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
    if ('${data['notes'] ?? ''}'.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 12), child: pw.Text('Notes: ${data['notes']}')),
    pw.SizedBox(height: 35),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Customer Signature'), pw.Text('Authorized Signature')]),
    pw.SizedBox(height: 35),
    pw.Center(child: pw.Text('RentFlow by PaliaAPK HUB • Developer by shanpalia', style: const pw.TextStyle(fontSize: 9))),
  ]);
  return doc;
}

String customerName(String? id) { for (final x in db.records('customers')) { if ('${x['id']}' == id) return '${x['name']}'; } return 'Party'; }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Frame('Settings / About', Column(children: [
    Card(elevation: 0, child: ListTile(leading: const Icon(Icons.store, color: emerald), title: const Text('Shop / Company'), subtitle: const Text('Edit shop information and shop image'), onTap: () => openPage(context, const ShopPage()))),
    Card(elevation: 0, child: const ListTile(leading: Icon(Icons.info_outline, color: emerald), title: Text('RentFlow by PaliaAPK HUB'), subtitle: Text('Developer by shanpalia'))),
  ]));
}
