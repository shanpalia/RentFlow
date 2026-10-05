import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const primaryDark = Color(0xFF087864);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF5FAF8);
const line = Color(0xFFDDEBE6);
const soft = Color(0xFFE7F7F2);

int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class Store extends ChangeNotifier {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> shops = [];
  int active = 0;
  bool get registered => shops.isNotEmpty;
  Map<String, dynamic> get shop => registered ? shops[active] : <String, dynamic>{};
  List<Map<String, dynamic>> list(String key) {
    final value = shop[key];
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  List<Map<String, dynamic>> get items => list('items');
  List<Map<String, dynamic>> get customers => list('customers');
  List<Map<String, dynamic>> get issued => list('issued');
  List<Map<String, dynamic>> get returns => list('returns');
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final decoded = jsonDecode(prefs.getString('shops') ?? '[]');
      if (decoded is List) shops = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { shops = []; }
    active = prefs.getInt('active') ?? 0;
    if (active >= shops.length) active = shops.isEmpty ? 0 : shops.length - 1;
  }
  Map<String, dynamic> makeShop(String name, String owner, String mobile, String address) => {
    'id': uid(), 'name': name, 'owner': owner, 'mobile': mobile, 'address': address,
    'items': <Map<String, dynamic>>[], 'customers': <Map<String, dynamic>>[],
    'issued': <Map<String, dynamic>>[], 'returns': <Map<String, dynamic>>[],
  };
  Future<void> save() async {
    await prefs.setString('shops', jsonEncode(shops));
    await prefs.setInt('active', active);
    notifyListeners();
  }
  Future<void> addShop(String name, String owner, String mobile, String address) async {
    shops.add(makeShop(name, owner, mobile, address)); active = shops.length - 1; await save();
  }
  Future<void> updateShop(String name, String owner, String mobile, String address) async {
    if (!registered) return;
    shop['name'] = name; shop['owner'] = owner; shop['mobile'] = mobile; shop['address'] = address; await save();
  }
  Future<void> deleteShop(int index) async {
    if (index < 0 || index >= shops.length) return;
    shops.removeAt(index); active = shops.isEmpty ? 0 : active.clamp(0, shops.length - 1).toInt(); await save();
  }
  Future<void> selectShop(int index) async {
    if (index < 0 || index >= shops.length) return;
    active = index; await save();
  }
  Future<void> changed() => save();
}

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'RentFlow',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: primary),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, labelStyle: const TextStyle(color: Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: primary, width: 1.8)))),
    home: const Splash(),
  );
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState() { super.initState(); Future.delayed(const Duration(milliseconds: 1200), () { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell())); }); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SizedBox(width: 330, child: SvgPicture.asset('assets/rentflow_splash.svg'))));
}
class Logo extends StatelessWidget {
  final double size; const Logo({this.size = 46, super.key});
  @override Widget build(BuildContext context) => SvgPicture.asset('assets/rentflow_logo.svg', width: size, height: size);
}
class Header extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions; const Header({this.actions, super.key});
  @override Size get preferredSize => const Size.fromHeight(74);
  @override Widget build(BuildContext context) => AppBar(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, toolbarHeight: 74, leadingWidth: 66,
    leading: const Padding(padding: EdgeInsets.only(left: 14), child: Logo(size: 46)),
    title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800))]),
    actions: actions,
  );
}
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override Widget build(BuildContext context) => Row(children: [const Logo(size: 58), const SizedBox(width: 12), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(color: dark, fontSize: 30, fontWeight: FontWeight.w900)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 15, fontWeight: FontWeight.w900))])]);
}
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  final store = Store(); int tab = 0; bool loading = true;
  @override void initState() { super.initState(); store.load().then((_) { if (mounted) setState(() => loading = false); }); }
  Future<bool> gate() async {
    if (store.registered) return true;
    if (!mounted) return false;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopFormPage(store: store)));
    return store.registered;
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [Home(store: store, gate: gate), InventoryPage(store: store, gate: gate), CustomersPage(store: store, gate: gate), IssuedPage(store: store, gate: gate), SettingsPage(store: store)];
    return AnimatedBuilder(animation: store, builder: (_, __) => Scaffold(body: pages[tab], bottomNavigationBar: NavigationBar(height: 76, backgroundColor: const Color(0xFFEAF2EF), indicatorColor: const Color(0xFFCDEEE4), selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Items'),
      NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'),
      NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Issued'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
    ]));
  }
}
class PageFrame extends StatelessWidget {
  final String title; final Widget child; final List<Widget>? actions;
  const PageFrame({required this.title, required this.child, this.actions, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: Header(actions: actions), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [Text(title, style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 16), child]));
}
class StatCard extends StatelessWidget {
  final String label, value; final IconData icon; const StatCard(this.label, this.value, this.icon, {super.key});
  @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: primary, size: 26)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.black54))]))]));
}
class ActionBox extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const ActionBox({required this.label, required this.icon, required this.onTap, super.key});
  @override Widget build(BuildContext context) => SizedBox(width: (MediaQuery.sizeOf(context).width - 56) / 2, height: 112, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: primary, size: 28)), const SizedBox(height: 7), Text(label, style: const TextStyle(color: dark, fontWeight: FontWeight.w900))]))));
}
class Empty extends StatelessWidget {
  final String title, subtitle; const Empty(this.title, this.subtitle, {super.key});
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)), child: Column(children: [const Icon(Icons.inbox_outlined, color: primary, size: 46), const SizedBox(height: 8), Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
}
class Footer extends StatelessWidget {
  const Footer({super.key});
  @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(top: 18), child: Column(children: [Text('RentFlow', style: TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 16)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 12)), SizedBox(height: 3), Text('Developer by ShanPalia', style: TextStyle(color: Colors.black45, fontSize: 11))]));
}
class Home extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const Home({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [const BrandHeader(), const SizedBox(height: 12), if (store.registered) _ShopCard(store: store) else _RegisterCard(store: store), const SizedBox(height: 16), Row(children: [StatCard('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), StatCard('Customers', '${store.customers.length}', Icons.people_outline)]), const SizedBox(height: 10), Row(children: [StatCard('Issued', '${store.issued.length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Returns', '${store.returns.length}', Icons.keyboard_return)]), const SizedBox(height: 24), const Text('Quick actions', style: TextStyle(color: dark, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 11), Wrap(spacing: 10, runSpacing: 10, children: [
    ActionBox(label: 'Add Item', icon: Icons.add_box_outlined, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ItemFormPage(store: store))); }),
    ActionBox(label: 'Customer', icon: Icons.person_add_alt_1_outlined, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormPage(store: store))); }),
    ActionBox(label: 'Issued', icon: Icons.assignment_outlined, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueForm(store: store))); }),
    ActionBox(label: 'Return', icon: Icons.keyboard_return_rounded, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnPage(store: store))); }),
    ActionBox(label: 'Reports', icon: Icons.analytics_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(store: store)))),
  ]), const SizedBox(height: 24), const Text('Recent issued', style: TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (store.issued.isEmpty) const Empty('No issued entries', 'Saved invoices will appear here.') else ...store.issued.reversed.take(5).map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))), const Footer()]));
}
class _ShopCard extends StatelessWidget {
  final Store store; const _ShopCard({required this.store});
  @override Widget build(BuildContext context) { final sh = store.shop; return InkWell(borderRadius: BorderRadius.circular(24), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManager(store: store))), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)), child: Row(children: [const Icon(Icons.storefront_outlined, color: primary, size: 35), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${sh['name']}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), Text('${sh['owner']}  •  ${sh['mobile']}', style: const TextStyle(color: Colors.white70)), Text('${sh['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))])), const Icon(Icons.chevron_right, color: Colors.white70)]))); }
}
class _RegisterCard extends StatelessWidget {
  final Store store; const _RegisterCard({required this.store});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)), child: Row(children: [const Icon(Icons.storefront_outlined, color: primary, size: 34), const SizedBox(width: 12), const Expanded(child: Text('Register your shop to start managing rentals.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))), FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopFormPage(store: store))), child: const Text('Register'))]));
}
class EntryTile extends StatelessWidget {
  final Map<String, dynamic> data; final VoidCallback onTap; const EntryTile({required this.data, required this.onTap, super.key});
  @override Widget build(BuildContext context) { final rows = data['items'] is List ? (data['items'] as List).length : 0; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(onTap: onTap, leading: const Logo(size: 38), title: Text('${data['partyName'] ?? 'Party'}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${data['invoice']}  •  ${data['date']}  •  $rows item(s)'), trailing: const Icon(Icons.chevron_right))); }
}
class InventoryPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const InventoryPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Inventory', actions: [IconButton(tooltip: 'Add item', onPressed: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ItemFormPage(store: store))); }, icon: const Icon(Icons.add_circle_outline))], child: store.items.isEmpty ? const Empty('Inventory is empty', 'Add an item to start your inventory.') : Column(children: store.items.asMap().entries.map((entry) { final i = entry.key; final x = entry.value; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: Text('${i + 1}', style: const TextStyle(color: primary, fontWeight: FontWeight.w900))), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}  •  Rent ${x['rentDays']} day(s)'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemFormPage(store: store, old: x)))); }).toList()));
}
class CustomersPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const CustomersPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Customers', actions: [IconButton(onPressed: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormPage(store: store))); }, icon: const Icon(Icons.person_add_alt_1_outlined))], child: store.customers.isEmpty ? const Empty('No customers', 'Add a customer to use the customer dropdown.') : Column(children: store.customers.map((x) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.person_outline, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${x['mobile']}\n${x['address']}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormPage(store: store, old: x))))).toList()));
}
class IssuedPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const IssuedPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Issued', actions: [IconButton(onPressed: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueForm(store: store))); }, icon: const Icon(Icons.add_circle_outline))], child: store.issued.isEmpty ? const Empty('No issued records', 'Create an issued entry with inventory lines.') : Column(children: store.issued.reversed.map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))).toList()));
}
class IssueForm extends StatefulWidget {
  final Store store; const IssueForm({required this.store, super.key}); @override State<IssueForm> createState() => _IssueFormState();
}
class _IssueFormState extends State<IssueForm> {
  final date = TextEditingController(text: today()); final invoice = TextEditingController(); String? customerId; Map<String, dynamic>? selectedCustomer; final lines = <Map<String, dynamic>>[];
  @override void initState() { super.initState(); invoice.text = 'RF-${DateTime.now().millisecondsSinceEpoch}'; }
  @override void dispose() { date.dispose(); invoice.dispose(); super.dispose(); }
  Future<void> addLine() async {
    if (widget.store.items.isEmpty) { await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemFormPage(store: widget.store))); if (widget.store.items.isEmpty || !mounted) return; }
    final selected = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => InventoryPickerPage(store: widget.store)));
    if (selected == null || !mounted) return;
    final max = toInt(selected['qty']); final q = TextEditingController(text: '1');
    final qty = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => QuantityPage(itemName: '${selected['name']}', max: max, controller: q))); q.dispose();
    if (qty == null || !mounted) return;
    final existing = lines.indexWhere((e) => e['itemId'] == selected['id']);
    setState(() { if (existing >= 0) { lines[existing]['qty'] = toInt(lines[existing]['qty']) + qty; } else { lines.add({'itemId': selected['id'], 'name': selected['name'], 'srl': selected['srl'], 'qty': qty, 'rentDays': selected['rentDays']}); } });
  }
  Future<void> save() async {
    if (invoice.text.trim().isEmpty || selectedCustomer == null || lines.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter invoice number, select customer and add item.'))); return; }
    final entry = {'invoice': invoice.text.trim(), 'date': date.text.trim(), 'customerId': selectedCustomer!['id'], 'partyName': selectedCustomer!['name'], 'mobile': selectedCustomer!['mobile'], 'address': selectedCustomer!['address'], 'items': lines.map((e) => Map<String, dynamic>.from(e)).toList()};
    for (final line in lines) { final index = widget.store.items.indexWhere((x) => x['id'] == line['itemId']); if (index >= 0) widget.store.items[index]['qty'] = toInt(widget.store.items[index]['qty']) - toInt(line['qty']); }
    widget.store.shop['issued'] = [...widget.store.issued, entry]; await widget.store.changed(); if (mounted) await previewInvoice(context, widget.store, entry);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [const Text('New Issued Entry', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 16), _field(invoice, 'Invoice No'), _field(date, 'Issued Date'), DropdownButtonFormField<String>(value: customerId, decoration: const InputDecoration(labelText: 'Customer'), items: widget.store.customers.map((x) => DropdownMenuItem<String>(value: '${x['id']}', child: Text('${x['name']}'))).toList(), onChanged: (value) { final found = widget.store.customers.firstWhere((x) => '${x['id']}' == value, orElse: () => <String, dynamic>{}); setState(() { customerId = value; selectedCustomer = found.isEmpty ? null : found; }); }), if (widget.store.customers.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton.icon(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormPage(store: widget.store))); if (mounted) setState(() {}); }, icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Add Customer'))), if (selectedCustomer != null) ...[const SizedBox(height: 10), _InfoCard(icon: Icons.person_outline, title: '${selectedCustomer!['name']}', subtitle: '${selectedCustomer!['mobile']}  •  ${selectedCustomer!['address']}')], const SizedBox(height: 20), Row(children: [const Expanded(child: Text('Inventory', style: TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900))), FilledButton.icon(onPressed: addLine, icon: const Icon(Icons.add), label: const Text('Add Item'))]), const SizedBox(height: 10), if (lines.isEmpty) const Empty('No items added', 'Tap Add Item to open the inventory selection page.') else ...lines.asMap().entries.map((entry) { final i = entry.key; final x = entry.value; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: Text('${i + 1}')), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}  •  Rent ${x['rentDays']} day(s)'), trailing: IconButton(onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)))); }), const SizedBox(height: 14), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.preview_outlined), label: const Text('Save & Preview', style: TextStyle(fontWeight: FontWeight.w900)))), const Footer()]));
}
class InventoryPickerPage extends StatelessWidget {
  final Store store; const InventoryPickerPage({required this.store, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Select Inventory', child: store.items.isEmpty ? const Empty('Inventory is empty', 'Add an item first.') : Column(children: store.items.map((x) { final qty = toInt(x['qty']); return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Available $qty'), trailing: const Icon(Icons.arrow_forward_ios, size: 17), onTap: qty <= 0 ? null : () => Navigator.pop(context, x))); }).toList()));
}
class QuantityPage extends StatelessWidget {
  final String itemName; final int max; final TextEditingController controller;
  const QuantityPage({required this.itemName, required this.max, required this.controller, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [const Text('Issued Quantity', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), _InfoCard(icon: Icons.inventory_2_outlined, title: itemName, subtitle: 'Available quantity: $max'), const SizedBox(height: 18), _field(controller, 'Quantity (max $max)', keyboard: TextInputType.number), const SizedBox(height: 12), SizedBox(height: 52, child: FilledButton(onPressed: () { final value = toInt(controller.text); if (value <= 0 || value > max) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity.'))); return; } Navigator.pop(context, value); }, child: const Text('Add to Issued Entry')))]));
}
class ReturnPage extends StatefulWidget {
  final Store store; const ReturnPage({required this.store, super.key}); @override State<ReturnPage> createState() => _ReturnPageState();
}
class _ReturnPageState extends State<ReturnPage> {
  Map<String, dynamic>? selected; final qty = TextEditingController(text: '1'); final amount = TextEditingController();
  @override void dispose() { qty.dispose(); amount.dispose(); super.dispose(); }
  Future<void> choose() async { final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => IssuedPickerPage(store: widget.store))); if (x != null && mounted) setState(() => selected = x); }
  Future<void> save() async { if (selected == null) return; final q = toInt(qty.text); if (q <= 0 || amount.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter returned quantity and manual amount.'))); return; } final entry = {'id': uid(), 'date': today(), 'invoice': selected!['invoice'], 'partyName': selected!['partyName'], 'qty': q, 'amount': amount.text.trim()}; widget.store.shop['returns'] = [...widget.store.returns, entry]; await widget.store.changed(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return saved successfully'))); Navigator.pop(context); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [const Text('Return', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Select an issued invoice, then enter returned quantity and manual amount.'), const SizedBox(height: 18), OutlinedButton.icon(onPressed: choose, icon: const Icon(Icons.receipt_long_outlined), label: Text(selected == null ? 'Select Issued Entry' : '${selected!['partyName']}  •  ${selected!['invoice']}')), const SizedBox(height: 14), if (selected != null) _InfoCard(icon: Icons.receipt_long_outlined, title: '${selected!['partyName']}', subtitle: 'Invoice ${selected!['invoice']}'), if (selected != null) ...[const SizedBox(height: 14), _field(qty, 'Returned Quantity', keyboard: TextInputType.number), _field(amount, 'Manual Return Amount', keyboard: TextInputType.number), const SizedBox(height: 8), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Return'))], const Footer()]));
}
class IssuedPickerPage extends StatelessWidget {
  final Store store; const IssuedPickerPage({required this.store, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Select Issued Entry', child: store.issued.isEmpty ? const Empty('No issued entries', 'Create an issued entry first.') : Column(children: store.issued.reversed.map((e) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), child: ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.receipt_long_outlined, color: primary)), title: Text('${e['partyName']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e['invoice']}  •  ${e['date']}'), trailing: const Icon(Icons.arrow_forward_ios, size: 17), onTap: () => Navigator.pop(context, e)))).toList()));
}
class ReportsPage extends StatelessWidget {
  final Store store; const ReportsPage({required this.store, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Reports', child: Column(children: [Row(children: [StatCard('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), StatCard('Customers', '${store.customers.length}', Icons.people_outline)]), const SizedBox(height: 10), Row(children: [StatCard('Issued', '${store.issued.length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Returns', '${store.returns.length}', Icons.keyboard_return)]), const SizedBox(height: 22), const Align(alignment: Alignment.centerLeft, child: Text('Issued report', style: TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900))), const SizedBox(height: 8), if (store.issued.isEmpty) const Empty('No report data', 'Issue records will be listed here.') else ...store.issued.reversed.map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))), const Footer()]));
}
class ShopManager extends StatelessWidget {
  final Store store; const ShopManager({required this.store, super.key});
  @override Widget build(BuildContext context) => PageFrame(title: 'Shop Management', actions: [IconButton(tooltip: 'Add new shop', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopFormPage(store: store))), icon: const Icon(Icons.add_business_outlined))], child: Column(children: store.shops.asMap().entries.map((entry) { final i = entry.key; final x = entry.value; final active = i == store.active; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: active ? primary : line, width: active ? 1.5 : 1)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [ListTile(onTap: () async { await store.selectShop(i); if (context.mounted) Navigator.pop(context); }, leading: const Logo(size: 42), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${x['owner']}  •  ${x['mobile']}\n${x['address']}'), isThreeLine: true, trailing: active ? const Chip(label: Text('Active'), avatar: Icon(Icons.check_circle, color: primary, size: 17)) : const Icon(Icons.radio_button_unchecked)), const Divider(height: 1, color: line), Row(children: [Expanded(child: TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopFormPage(store: store, index: i))), icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))), Expanded(child: TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeleteShopPage(store: store, index: i))), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: const Text('Delete', style: TextStyle(color: Colors.redAccent))))])])); }).toList()));
}
class ShopFormPage extends StatefulWidget {
  final Store store; final int? index; const ShopFormPage({required this.store, this.index, super.key}); @override State<ShopFormPage> createState() => _ShopFormPageState();
}
class _ShopFormPageState extends State<ShopFormPage> {
  late final TextEditingController name, owner, mobile, address;
  @override void initState() { super.initState(); final x = widget.index == null ? null : widget.store.shops[widget.index!]; name = TextEditingController(text: '${x?['name'] ?? ''}'); owner = TextEditingController(text: '${x?['owner'] ?? ''}'); mobile = TextEditingController(text: '${x?['mobile'] ?? ''}'); address = TextEditingController(text: '${x?['address'] ?? ''}'); }
  @override void dispose() { name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; if (widget.index == null) await widget.store.addShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); else { await widget.store.selectShop(widget.index!); await widget.store.updateShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); } if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [Text(widget.index == null ? 'Register Shop' : 'Edit Shop', style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), _field(name, 'Shop Name'), _field(owner, 'Owner Name'), _field(mobile, 'Mobile', keyboard: TextInputType.phone), _field(address, 'Shop Address', maxLines: 3), const SizedBox(height: 8), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Shop'))), const Footer()]));
}
class DeleteShopPage extends StatelessWidget {
  final Store store; final int index; const DeleteShopPage({required this.store, required this.index, super.key});
  @override Widget build(BuildContext context) { final x = store.shops[index]; return Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [const Text('Delete Shop', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), _InfoCard(icon: Icons.delete_outline, title: '${x['name']}', subtitle: 'This removes the shop and its local inventory, customers, issued entries and returns.'), const SizedBox(height: 18), SizedBox(height: 52, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () async { await store.deleteShop(index); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.delete_outline), label: const Text('Delete Shop Permanently'))])); }
}
class ItemFormPage extends StatefulWidget {
  final Store store; final Map<String, dynamic>? old; const ItemFormPage({required this.store, this.old, super.key}); @override State<ItemFormPage> createState() => _ItemFormPageState();
}
class _ItemFormPageState extends State<ItemFormPage> {
  late final TextEditingController name, srl, qty, days;
  @override void initState() { super.initState(); final x = widget.old; name = TextEditingController(text: '${x?['name'] ?? ''}'); srl = TextEditingController(text: '${x?['srl'] ?? ''}'); qty = TextEditingController(text: '${x?['qty'] ?? '1'}'); days = TextEditingController(text: '${x?['rentDays'] ?? '1'}'); }
  @override void dispose() { name.dispose(); srl.dispose(); qty.dispose(); days.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; if (widget.old == null) widget.store.items.add({'id': uid(), 'name': name.text.trim(), 'srl': srl.text.trim().isEmpty ? '${widget.store.items.length + 1}' : srl.text.trim(), 'qty': toInt(qty.text), 'rentDays': toInt(days.text)}); else { widget.old!['name'] = name.text.trim(); widget.old!['srl'] = srl.text.trim(); widget.old!['qty'] = toInt(qty.text); widget.old!['rentDays'] = toInt(days.text); } await widget.store.changed(); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [Text(widget.old == null ? 'Add Item' : 'Edit Item', style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), _field(name, 'Item Name'), _field(srl, 'SRL'), _field(qty, 'Quantity', keyboard: TextInputType.number), _field(days, 'Rent Days', keyboard: TextInputType.number), const SizedBox(height: 8), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Item'))), const Footer()]));
}
class CustomerFormPage extends StatefulWidget {
  final Store store; final Map<String, dynamic>? old; const CustomerFormPage({required this.store, this.old, super.key}); @override State<CustomerFormPage> createState() => _CustomerFormPageState();
}
class _CustomerFormPageState extends State<CustomerFormPage> {
  late final TextEditingController name, mobile, address;
  @override void initState() { super.initState(); final x = widget.old; name = TextEditingController(text: '${x?['name'] ?? ''}'); mobile = TextEditingController(text: '${x?['mobile'] ?? ''}'); address = TextEditingController(text: '${x?['address'] ?? ''}'); }
  @override void dispose() { name.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; if (widget.old == null) widget.store.customers.add({'id': uid(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}); else { widget.old!['name'] = name.text.trim(); widget.old!['mobile'] = mobile.text.trim(); widget.old!['address'] = address.text.trim(); } await widget.store.changed(); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [Text(widget.old == null ? 'Add Customer' : 'Edit Customer', style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), _field(name, 'Customer Name'), _field(mobile, 'Mobile', keyboard: TextInputType.phone), _field(address, 'Address', maxLines: 3), const SizedBox(height: 8), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Customer'))), const Footer()]));
}
class SettingsPage extends StatefulWidget {
  final Store store; const SettingsPage({required this.store, super.key}); @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  bool checking = false;
  Future<void> checkUpdate() async {
    setState(() => checking = true);
    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/shanpalia/RentFlow/releases/latest'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); final latest = '${data['tag_name'] ?? ''}'.replaceFirst('v', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(latest.isNotEmpty && latest != '1.0.2+4' && latest != '1.0.2' ? 'New RentFlow version available: $latest' : 'RentFlow is up to date.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No published update was found right now.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check for updates.')));
    } finally { if (mounted) setState(() => checking = false); }
  }
  @override Widget build(BuildContext context) => PageFrame(title: 'Settings', child: Column(children: [
    if (widget.store.registered) _InfoCard(icon: Icons.storefront_outlined, title: '${widget.store.shop['name']}', subtitle: '${widget.store.shop['owner']}  •  ${widget.store.shop['mobile']}\n${widget.store.shop['address']}'),
    const SizedBox(height: 12),
    _SettingsTile(icon: Icons.store_mall_directory_outlined, title: 'Shop Management', subtitle: 'Edit, delete or add another shop', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManager(store: widget.store)))),
    _SettingsTile(icon: Icons.system_update_alt_rounded, title: 'Check for Update', subtitle: checking ? 'Checking latest RentFlow release...' : 'Check the latest published version', trailing: checking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null, onTap: checking ? null : checkUpdate),
    _SettingsTile(icon: Icons.language_outlined, title: 'PaliaAPK HUB Website', subtitle: 'Open the project website', onTap: () async { final uri = Uri.parse('https://shanpalia.github.io/WebsitePaliaAPK_V.2/'); await launchUrl(uri, mode: LaunchMode.externalApplication); }),
    const SizedBox(height: 12), _InfoCard(icon: Icons.info_outline, title: 'RentFlow', subtitle: 'By PaliaAPK HUB\nDeveloper by ShanPalia'), const Footer(),
  ]));
}
class _SettingsTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Widget? trailing; final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  @override Widget build(BuildContext context) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: trailing ?? const Icon(Icons.chevron_right)));
}
class _InfoCard extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: line)), child: Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: primary, size: 26)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.black54))]))]));
}
Widget _field(TextEditingController controller, String label, {bool readOnly = false, int maxLines = 1, TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 11), child: TextField(controller: controller, readOnly: readOnly, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label)));
Future<void> previewInvoice(BuildContext context, Store store, Map<String, dynamic> data) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicePreviewPage(store: store, data: data))); }
class InvoicePreviewPage extends StatelessWidget {
  final Store store; final Map<String, dynamic> data; const InvoicePreviewPage({required this.store, required this.data, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header(), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [const Text('Invoice Preview', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 16), _InfoCard(icon: Icons.receipt_long_outlined, title: '${store.shop['name']}', subtitle: 'Invoice ${data['invoice']}  •  ${data['date']}'), const SizedBox(height: 14), _InfoCard(icon: Icons.person_outline, title: '${data['partyName']}', subtitle: '${data['mobile']}  •  ${data['address']}'), const SizedBox(height: 14), ...((data['items'] as List? ?? const []).asMap().entries.map((e) { final x = e.value as Map; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: Text('${e.key + 1}')), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}  •  Rent ${x['rentDays']} day(s)'))); })), const SizedBox(height: 10), SizedBox(height: 52, child: FilledButton.icon(onPressed: () => savePdf(context, store, data), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Save PDF'))), const Footer()]));
}
Future<void> savePdf(BuildContext context, Store store, Map<String, dynamic> data) async {
  final doc = pw.Document(); final rows = (data['items'] as List? ?? const []).map((x) => ['${x['srl']}', '${x['name']}', '${x['qty']}', '${x['rentDays']}']).toList();
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('${store.shop['name']}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)), pw.Text('RentFlow  •  By PaliaAPK HUB'), pw.SizedBox(height: 12), pw.Divider(), pw.Text('Invoice: ${data['invoice']}'), pw.Text('Issued Date: ${data['date']}'), pw.SizedBox(height: 8), pw.Text('Party: ${data['partyName'] ?? ''}'), pw.Text('Mobile: ${data['mobile'] ?? ''}'), pw.Text('Address: ${data['address'] ?? ''}'), pw.SizedBox(height: 14), pw.TableHelper.fromTextArray(headers: const ['SRL', 'Inventory', 'Qty', 'Rent Days'], data: rows), pw.SizedBox(height: 20), pw.Text('RentFlow  •  By PaliaAPK HUB  •  Developer by ShanPalia')]));
  final bytes = await doc.save(); await Printing.sharePdf(bytes: bytes, filename: '${data['invoice']}.pdf');
}
