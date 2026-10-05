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
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: border)),
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
      if (raw is List) shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
    final v = shop[key];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<void> updateStock(String id, int delta) async {
    final list = shop['items'] as List? ?? [];
    for (var i = 0; i < list.length; i++) {
      final x = Map<String, dynamic>.from(list[i] as Map);
      if ('${x['id']}' == id) {
        x['quantity'] = (int.tryParse('${x['quantity'] ?? 0}') ?? 0) + delta;
        if ((x['quantity'] as int) < 0) x['quantity'] = 0;
        list[i] = x;
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
List<Map<String, dynamic>> asMaps(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
int rentDays(String issue, String returned) {
  final a = DateTime.tryParse(issue) ?? DateTime.now();
  final b = DateTime.tryParse(returned) ?? DateTime.now();
  final d = b.difference(a).inDays;
  return d < 1 ? 1 : d;
}

void openPage(BuildContext c, Widget page) => Navigator.push(c, MaterialPageRoute(builder: (_) => page));

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const AppHeader({super.key, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => AppBar(
        leading: back
            ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded))
            : Builder(builder: (c) => IconButton(onPressed: () => Scaffold.of(c).openDrawer(), icon: const Icon(Icons.menu_rounded, size: 30))),
        title: Row(children: [SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34), const SizedBox(width: 10), const Text('RentFlow by PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: border)),
      );
}

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});
  void go(BuildContext c, Widget p) { Navigator.pop(c); openPage(c, p); }
  @override
  Widget build(BuildContext c) => Drawer(
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(20), child: Row(children: [SvgPicture.asset('assets/rentflow_logo.svg', width: 48, height: 48), const SizedBox(width: 12), const Text('RentFlow\nPaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
          const Divider(),
          Expanded(child: ListView(children: [
            _item(c, 'Dashboard', Icons.dashboard_rounded, const HomePage()),
            _item(c, 'Inventory', Icons.inventory_2_rounded, const ItemsPage()),
            _item(c, 'Customers / Parties', Icons.people_alt_rounded, const CustomersPage()),
            _item(c, 'Issued / New Invoice', Icons.outbox_rounded, const IssuePage()),
            _item(c, 'Returns', Icons.assignment_return_rounded, const ReturnPage()),
            _item(c, 'Inventory Register', Icons.table_rows_rounded, const InventoryPage()),
            _item(c, 'Reports / Bills', Icons.receipt_long_rounded, const BillsPage()),
            _item(c, 'Shop / Company', Icons.store_rounded, const ShopPage()),
            _item(c, 'Settings / About', Icons.settings_rounded, const SettingsPage()),
          ])),
          const Padding(padding: EdgeInsets.all(16), child: Text('By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
        ])),
      );
  Widget _item(BuildContext c, String title, IconData icon, Widget p) => ListTile(leading: Icon(icon, color: emerald), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), onTap: () => go(c, p));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomeState();
}
class _HomeState extends State<HomePage> {
  int tab = 0;
  @override void initState() { super.initState(); rentDb.load(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: rentDb, builder: (_, __) {
        if (!rentDb.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
        return Scaffold(
          appBar: const AppHeader(), drawer: const SideMenu(),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _shopCard(c),
            const SizedBox(height: 18),
            const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.45, children: [
              _action('New Invoice', Icons.receipt_long_rounded, () => openPage(c, const IssuePage())),
              _action('Return', Icons.assignment_return_rounded, () => openPage(c, const ReturnPage())),
              _action('Add Item', Icons.add_box_rounded, () => openPage(c, const ItemForm())),
              _action('Add Customer', Icons.person_add_rounded, () => openPage(c, const CustomerForm())),
              _action('Inventory', Icons.inventory_2_rounded, () => openPage(c, const ItemsPage())),
              _action('Reports / Bills', Icons.picture_as_pdf_rounded, () => openPage(c, const BillsPage())),
            ]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: _stat('Items', rentDb.records('items').length, Icons.inventory_2)), Expanded(child: _stat('Parties', rentDb.records('customers').length, Icons.people)), Expanded(child: _stat('Issued', rentDb.records('issues').length, Icons.outbox))]),
            const SizedBox(height: 24),
            const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
          ]),
          bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) { setState(() => tab = v); if (v == 1) openPage(c, const ItemsPage()); if (v == 2) openPage(c, const IssuePage()); if (v == 3) openPage(c, const ReturnPage()); if (v == 4) openPage(c, const SettingsPage()); }, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'), NavigationDestination(icon: Icon(Icons.outbox_outlined), label: 'Issued'), NavigationDestination(icon: Icon(Icons.assignment_return_outlined), label: 'Returns'), NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'About')]),
        );
      });
  Widget _shopCard(BuildContext c) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: border)), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 66, height: 66, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(16)), child: rentDb.shop['image'] != null && '${rentDb.shop['image']}'.isNotEmpty ? Image.file(File('${rentDb.shop['image']}'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 34)) : const Icon(Icons.store_rounded, color: emerald, size: 34)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${rentDb.shop['name'] ?? 'Register your shop'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('${rentDb.shop['owner'] ?? ''}  ${rentDb.shop['mobile'] ?? ''}', style: const TextStyle(color: Colors.black54)), Text('${rentDb.shop['address'] ?? 'Add your shop information'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54))])), IconButton(onPressed: () => openPage(c, const ShopPage()), icon: const Icon(Icons.edit_outlined, color: emerald))])));
  Widget _action(String t, IconData i, VoidCallback f) => ActionCard(t, i, f);
  Widget _stat(String t, int n, IconData i) => Card(elevation: 0, margin: const EdgeInsets.only(right: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(i, color: emerald), Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(t, style: const TextStyle(color: Colors.black54))])));
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
  @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label)));
}
class SaveButton extends StatelessWidget {
  final String label; final VoidCallback onPressed; final IconData icon;
  const SaveButton(this.label, this.onPressed, {super.key, this.icon = Icons.check_rounded});
  @override Widget build(BuildContext c) => SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Padding(padding: const EdgeInsets.all(12), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))));
}

class ShopPage extends StatefulWidget { const ShopPage({super.key}); @override State<ShopPage> createState() => _ShopState(); }
class _ShopState extends State<ShopPage> {
  late TextEditingController name, owner, mobile, address; String? image;
  @override void initState() { super.initState(); final x = rentDb.shop; name = TextEditingController(text: '${x['name'] ?? ''}'); owner = TextEditingController(text: '${x['owner'] ?? ''}'); mobile = TextEditingController(text: '${x['mobile'] ?? ''}'); address = TextEditingController(text: '${x['address'] ?? ''}'); image = x['image']?.toString(); }
  @override void dispose() { name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> pick() async { final x = await ImagePicker().pickImage(source: ImageSource.gallery); if (x != null) setState(() => image = x.path); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; final d = {'name': name.text.trim(), 'owner': owner.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'image': image ?? ''}; if (rentDb.shops.isEmpty) await rentDb.addShop(d); else await rentDb.updateShop(d); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext c) => PageFrame('Shop / Company', Column(children: [GestureDetector(onTap: pick, child: Container(width: 100, height: 100, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(22)), child: image != null && image!.isNotEmpty ? Image.file(File(image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.add_a_photo, color: emerald, size: 34)) : const Icon(Icons.add_a_photo, color: emerald, size: 34))), const SizedBox(height: 8), const Text('Tap to add shop image', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18), FieldBox('Shop Name', name), FieldBox('Owner Name', owner), FieldBox('Mobile Number', mobile, keyboard: TextInputType.phone), FieldBox('Address', address, maxLines: 3), SaveButton('Save Shop', save, icon: Icons.save_rounded)]));
}

class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});
  @override Widget build(BuildContext c) { final a = rentDb.records('items'); return PageFrame('Inventory', Column(children: [Row(children: [const Expanded(child: Text('Items / Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(tooltip: 'Add Item', onPressed: () => openPage(c, const ItemForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 34))]), if (a.isEmpty) const Padding(padding: EdgeInsets.all(25), child: Text('No items yet. Tap + to add item.')), ...a.asMap().entries.map((e) => Card(elevation: 0, child: ListTile(leading: const CircleAvatar(backgroundColor: emeraldSoft, child: Icon(Icons.inventory_2, color: emerald)), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Code ${e.value['code'] ?? ''} • Rent ${e.value['rentPrice'] ?? 15}/100'), trailing: Text('${e.value['quantity'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), onTap: () => openPage(c, ItemForm(index: e.key))))])); }
}
class ItemForm extends StatefulWidget { final int? index; const ItemForm({super.key, this.index}); @override State<ItemForm> createState() => _ItemFormState(); }
class _ItemFormState extends State<ItemForm> {
  late TextEditingController code, name, unit, qty, rent;
  @override void initState() { super.initState(); final x = widget.index == null ? <String, dynamic>{} : rentDb.records('items')[widget.index!]; code = TextEditingController(text: '${x['code'] ?? ''}'); name = TextEditingController(text: '${x['name'] ?? ''}'); unit = TextEditingController(text: '${x['unit'] ?? 'pcs'}'); qty = TextEditingController(text: '${x['quantity'] ?? 0}'); rent = TextEditingController(text: '${x['rentPrice'] ?? 15}'); }
  @override void dispose() { code.dispose(); name.dispose(); unit.dispose(); qty.dispose(); rent.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; final old = widget.index == null ? null : rentDb.records('items')[widget.index!]; final d = {'id': old?['id'] ?? uid(), 'code': code.text.trim(), 'name': name.text.trim(), 'unit': unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(), 'quantity': int.tryParse(qty.text) ?? 0, 'rentPrice': double.tryParse(rent.text) ?? 15}; if (widget.index == null) await rentDb.addRecord('items', d); else await rentDb.editRecord('items', widget.index!, d); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext c) => PageFrame(widget.index == null ? 'Add Item' : 'Edit Item', Column(children: [FieldBox('Item Code', code), FieldBox('Item Name / Description', name), Row(children: [Expanded(child: FieldBox('Unit', unit)), const SizedBox(width: 10), Expanded(child: FieldBox('Quantity', qty, keyboard: TextInputType.number))]), FieldBox('Rent Price / 100', rent, keyboard: const TextInputType.numberWithOptions(decimal: true)), SaveButton('Save Item', save, icon: Icons.save_rounded)]));
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override Widget build(BuildContext c) { final a = rentDb.records('customers'); return PageFrame('Customers / Parties', Column(children: [Row(children: [const Expanded(child: Text('Party Master', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(c, const CustomerForm()), icon: const Icon(Icons.person_add_rounded, color: emerald, size: 32))]), if (a.isEmpty) const Padding(padding: EdgeInsets.all(25), child: Text('No parties. Tap + to add.')), ...a.asMap().entries.map((e) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.person, color: emerald), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e.value['mobile'] ?? ''}\n${e.value['address'] ?? ''}'), onTap: () => openPage(c, CustomerForm(index: e.key))))])); }
}
class CustomerForm extends StatefulWidget { final int? index; const CustomerForm({super.key, this.index}); @override State<CustomerForm> createState() => _CustomerFormState(); }
class _CustomerFormState extends State<CustomerForm> {
  late TextEditingController name, mobile, address;
  @override void initState() { super.initState(); final x = widget.index == null ? <String, dynamic>{} : rentDb.records('customers')[widget.index!]; name = TextEditingController(text: '${x['name'] ?? ''}'); mobile = TextEditingController(text: '${x['mobile'] ?? ''}'); address = TextEditingController(text: '${x['address'] ?? ''}'); }
  @override void dispose() { name.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; final old = widget.index == null ? null : rentDb.records('customers')[widget.index!]; final d = {'id': old?['id'] ?? uid(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}; if (widget.index == null) await rentDb.addRecord('customers', d); else await rentDb.editRecord('customers', widget.index!, d); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext c) => PageFrame(widget.index == null ? 'Add Customer / Party' : 'Edit Customer', Column(children: [FieldBox('Customer Name', name), FieldBox('Mobile Number', mobile, keyboard: TextInputType.phone), FieldBox('Address', address, maxLines: 3), SaveButton('Save Customer', save, icon: Icons.save_rounded)]));
}

class IssuePage extends StatefulWidget { const IssuePage({super.key}); @override State<IssuePage> createState() => _IssueState(); }
class _IssueState extends State<IssuePage> {
  String? customer; final invoice = TextEditingController(); final rows = <Map<String, dynamic>>[];
  @override void initState() { super.initState(); invoice.text = 'INV-${DateTime.now().millisecondsSinceEpoch}'; }
  @override void dispose() { invoice.dispose(); super.dispose(); }
  void addRow() { final a = rentDb.records('items'); if (a.isNotEmpty) setState(() => rows.add({'itemId': a.first['id'], 'name': a.first['name'], 'qty': 1, 'rentPrice': a.first['rentPrice'] ?? 15})); }
  Future<void> save() async { if (customer == null || rows.isEmpty) return; final issueDate = today(); await rentDb.addRecord('issues', {'id': uid(), 'invoice': invoice.text.trim(), 'customerId': customer, 'issueDate': issueDate, 'items': rows.map((e) => Map<String, dynamic>.from(e)).toList()}); for (final x in rows) await rentDb.updateStock('${x['itemId']}', -(int.tryParse('${x['qty']}') ?? 0)); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext c) { final customers = rentDb.records('customers'); final items = rentDb.records('items'); return PageFrame('Issued / New Invoice', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: DropdownButtonFormField<String>(value: customer, decoration: const InputDecoration(labelText: 'Customer / Party'), items: customers.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => customer = v))), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(c, const CustomerForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 32))]), const SizedBox(height: 10), FieldBox('Invoice Number', invoice), if (items.isEmpty) const EmptyState('Add inventory item first.'), ...rows.asMap().entries.map((e) { final x = e.value; final i = e.key; return Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: DropdownButtonFormField<String>(value: '${x['itemId']}', decoration: const InputDecoration(labelText: 'Item'), items: items.map((z) => DropdownMenuItem(value: '${z['id']}', child: Text('${z['name']}'))).toList(), onChanged: (v) { final z = items.firstWhere((q) => '${q['id']}' == v); setState(() { x['itemId'] = v; x['name'] = z['name']; x['rentPrice'] = z['rentPrice'] ?? 15; }); })), const SizedBox(width: 8), SizedBox(width: 75, child: TextFormField(initialValue: '${x['qty']}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'), onChanged: (v) => x['qty'] = int.tryParse(v) ?? 1)), IconButton(onPressed: () => setState(() => rows.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.red))]))); }), TextButton.icon(onPressed: addRow, icon: const Icon(Icons.add_circle, color: emerald), label: const Text('Add Another Item')), const SizedBox(height: 10), SaveButton('Save Issued Invoice', save, icon: Icons.save_rounded)])); }
}

class ReturnPage extends StatefulWidget { const ReturnPage({super.key}); @override State<ReturnPage> createState() => _ReturnState(); }
class _ReturnState extends State<ReturnPage> {
  String? customer; Map<String, dynamic>? issue; final selected = <String, int>{}; final amount = TextEditingController(); final notes = TextEditingController();
  @override void dispose() { amount.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async { if (issue == null) return; final returned = today(); final items = asMaps(issue!['items']); final out = <Map<String, dynamic>>[]; double total = 0; int maxDays = 1; for (final x in items) { final q = selected['${x['itemId']}'] ?? 0; if (q <= 0) continue; final d = rentDays('${issue!['issueDate']}', returned); final r = double.tryParse('${x['rentPrice'] ?? 15}') ?? 15; final line = r * q * d / 100; total += line; maxDays = d; out.add({'itemId': x['itemId'], 'name': x['name'], 'issuedQty': x['qty'], 'returnQty': q, 'rentPrice': r, 'rentDays': d, 'amount': line}); await rentDb.updateStock('${x['itemId']}', q); } if (out.isEmpty) return; final manual = double.tryParse(amount.text); if (manual != null) total = manual; await rentDb.addRecord('returns', {'id': uid(), 'returnInvoice': 'RET-${DateTime.now().millisecondsSinceEpoch}', 'customerId': customer, 'issueInvoice': issue!['invoice'], 'issueDate': issue!['issueDate'], 'returnDate': returned, 'rentDays': maxDays, 'amount': total, 'notes': notes.text.trim(), 'items': out}); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext c) { final customers = rentDb.records('customers'); final issues = rentDb.records('issues'); final items = issue == null ? <Map<String, dynamic>>[] : asMaps(issue!['items']); return PageFrame('Return / Receive', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: DropdownButtonFormField<String>(value: customer, decoration: const InputDecoration(labelText: 'Customer / Party'), items: customers.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() { customer = v; issue = null; selected.clear(); }))), const SizedBox(width: 8), IconButton(tooltip: 'Add Customer', onPressed: () => openPage(c, const CustomerForm()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 32))]), const SizedBox(height: 10), DropdownButtonFormField<String>(value: issue?['id']?.toString(), decoration: const InputDecoration(labelText: 'Issued Invoice'), items: issues.where((x) => customer == null || '${x['customerId']}' == customer).map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['invoice']} • ${x['issueDate']}'))).toList(), onChanged: (v) { final x = issues.firstWhere((q) => '${q['id']}' == v); setState(() { issue = x; selected.clear(); }); }), const SizedBox(height: 12), if (issue != null) ...[Text('Issued date: ${issue!['issueDate']}  •  Return date: ${today()}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), ...items.map((x) => ReturnItemCard(item: x, selectedQty: selected['${x['itemId']}'] ?? 0, onChanged: (q) => setState(() => selected['${x['itemId']}'] = q))), FieldBox('Manual Return Amount (optional)', amount, keyboard: const TextInputType.numberWithOptions(decimal: true)), FieldBox('Notes', notes, maxLines: 3), SaveButton('Save Return & Receipt', save, icon: Icons.save_rounded)])); }
}
class ReturnItemCard extends StatelessWidget {
  final Map<String, dynamic> item; final int selectedQty; final ValueChanged<int> onChanged;
  const ReturnItemCard({super.key, required this.item, required this.selectedQty, required this.onChanged});
  @override Widget build(BuildContext c) { final max = int.tryParse('${item['qty'] ?? 0}') ?? 0; final r = double.tryParse('${item['rentPrice'] ?? 15}') ?? 15; final days = rentDays('${item['issueDate'] ?? DateTime.now().toIso8601String()}', today()); return Card(elevation: 0, color: selectedQty > 0 ? emeraldSoft : Colors.white, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(selectedQty > 0 ? Icons.check_circle : Icons.inventory_2_outlined, color: emerald), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('Issued Qty $max • Rent $r/100 • Rent Days $days'), Text('Selected amount ${money(r * selectedQty * days / 100)}', style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.w800))])), SizedBox(width: 78, child: TextFormField(initialValue: selectedQty == 0 ? '' : '$selectedQty', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Return', hintText: '0-$max'), onChanged: (v) => onChanged((int.tryParse(v) ?? 0).clamp(0, max)))]))); }
}

class InventoryPage extends StatelessWidget { const InventoryPage({super.key}); @override Widget build(BuildContext c) { final a = rentDb.records('items'); return PageFrame('Inventory Register', Column(children: [const Row(children: [Expanded(child: Text('Current Stock / Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]), const SizedBox(height: 8), if (a.isEmpty) const EmptyState('No inventory records.'), ...a.map((x) => Card(elevation: 0, child: ListTile(title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Code ${x['code'] ?? ''} • Rent ${x['rentPrice'] ?? 15}/100'), trailing: Text('${x['quantity'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: emerald))))])); } }

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});
  String party(String? id) { for (final x in rentDb.records('customers')) { if ('${x['id']}' == id) return '${x['name']}'; } return 'Party'; }
  @override Widget build(BuildContext c) { final issues = rentDb.records('issues'); final returns = rentDb.records('returns'); return PageFrame('Reports / Bills', Column(children: [const Align(alignment: Alignment.centerLeft, child: Text('ISSUED BILLS', style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark))), if (issues.isEmpty) const EmptyState('No issued bills yet.'), ...issues.map((x) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.receipt_long, color: emerald), title: Text('${x['invoice']} • ${party('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Issued ${x['issueDate']} • ${asMaps(x['items']).length} item(s)'), trailing: IconButton(tooltip: 'Preview / Print PDF', onPressed: () => showPdf(c, x), icon: const Icon(Icons.picture_as_pdf, color: emerald))))), const SizedBox(height: 12), const Align(alignment: Alignment.centerLeft, child: Text('RETURN RECEIPTS', style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark))), if (returns.isEmpty) const EmptyState('No return receipts yet.'), ...returns.map((x) => Card(elevation: 0, child: ListTile(leading: const Icon(Icons.assignment_return, color: emerald), title: Text('${x['returnInvoice'] ?? 'Return'} • ${party('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Issued ${x['issueDate']} • Return ${x['returnDate']} • Rent Days ${x['rentDays']} • ${money(x['amount'])}'), trailing: IconButton(tooltip: 'Preview / Print PDF', onPressed: () => showPdf(c, x, isReturn: true), icon: const Icon(Icons.picture_as_pdf, color: emerald)))))])); }
}

Future<void> showPdf(BuildContext context, Map<String, dynamic> data, {bool isReturn = false}) async {
  final doc = pw.Document();
  final items = asMaps(data['items']);
  final customer = (() { for (final x in rentDb.records('customers')) { if ('${x['id']}' == '${data['customerId']}') return '${x['name']}'; } return 'Party'; })();
  doc.addPage(pw.MultiPage(pageFormat: pw.PdfPageFormat.a4, build: (_) => [
    pw.Text('${rentDb.shop['name'] ?? 'RentFlow'}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
    pw.Text('${rentDb.shop['address'] ?? ''}  ${rentDb.shop['mobile'] ?? ''}'),
    pw.SizedBox(height: 12),
    pw.Text(isReturn ? 'RETURN RECEIPT' : 'RENTAL ISSUE INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 6),
    pw.Text('Party: $customer'),
    pw.Text('Invoice: ${data['returnInvoice'] ?? data['invoice'] ?? ''}'),
    pw.Text('Issued Date: ${data['issueDate'] ?? ''}'),
    if (isReturn) pw.Text('Return Date: ${data['returnDate'] ?? ''}'),
    pw.SizedBox(height: 14),
    pw.TableHelper.fromTextArray(headers: isReturn ? ['Item', 'Issued Qty', 'Return Qty', 'Rent / 100', 'Rent Days', 'Amount'] : ['Item', 'Qty', 'Rent / 100'], data: items.map((x) => isReturn ? ['${x['name']}', '${x['issuedQty']}', '${x['returnQty']}', '${x['rentPrice']}', '${x['rentDays']}', money(x['amount'])] : ['${x['name']}', '${x['qty']}', '${x['rentPrice']}']).toList()),
    if (isReturn) pw.Padding(padding: const pw.EdgeInsets.only(top: 12), child: pw.Text('Total: ${money(data['amount'])}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
    pw.SizedBox(height: 30), pw.Text('By PaliaAPK HUB • Developer by shanpalia'),
  ]));
  if (!context.mounted) return;
  await showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.preview, color: emerald), title: const Text('Preview / Print PDF'), onTap: () { Navigator.pop(context); Printing.layoutPdf(onLayout: (_) async => doc.save()); }), ListTile(leading: const Icon(Icons.share, color: emerald), title: const Text('Save / Share PDF'), onTap: () { Navigator.pop(context); Printing.sharePdf(bytes: await doc.save(), filename: '${data['returnInvoice'] ?? data['invoice'] ?? 'rentflow'}.pdf'); })])));
}

class EmptyState extends StatelessWidget { final String text; const EmptyState(this.text, {super.key}); @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)))); }
class SettingsPage extends StatelessWidget { const SettingsPage({super.key}); @override Widget build(BuildContext c) => PageFrame('Settings / About', Column(children: [Card(elevation: 0, child: ListTile(leading: const Icon(Icons.info_outline, color: emerald), title: const Text('RentFlow', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Rental Management • By PaliaAPK HUB • Developer by shanpalia'))), Card(elevation: 0, child: ListTile(leading: const Icon(Icons.store_rounded, color: emerald), title: const Text('Shop / Company'), onTap: () => openPage(c, const ShopPage())))])); }
