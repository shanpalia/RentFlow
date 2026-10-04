import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF5FAF8);
const line = Color(0xFFDDEBE6);

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
    'issued': <Map<String, dynamic>>[], 'returns': <Map<String, dynamic>>[]
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
  Future<void> selectShop(int index) async { if (index >= 0 && index < shops.length) { active = index; await save(); } }
  Future<void> changed() => save();
}

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'RentFlow',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: primary)),
    home: const Splash(),
  );
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState() { super.initState(); Future.delayed(const Duration(milliseconds: 1100), () { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell())); }); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SizedBox(width: 330, child: SvgPicture.asset('assets/rentflow_splash.svg'))));
}
class Logo extends StatelessWidget { final double size; const Logo({this.size = 44, super.key}); @override Widget build(BuildContext context) => SvgPicture.asset('assets/rentflow_logo.svg', width: size, height: size); }
class Header extends StatelessWidget implements PreferredSizeWidget {
  final String title; final List<Widget>? actions; const Header(this.title, {this.actions, super.key});
  @override Size get preferredSize => const Size.fromHeight(78);
  @override Widget build(BuildContext context) => AppBar(
    backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, toolbarHeight: 78, leadingWidth: 64,
    leading: const Padding(padding: EdgeInsets.only(left: 14), child: Logo(size: 44)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900)), const Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800))]),
    actions: actions,
  );
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  final store = Store(); int tab = 0; bool loading = true;
  @override void initState() { super.initState(); store.load().then((_) { if (mounted) setState(() => loading = false); }); }
  Future<bool> gate() async {
    if (store.registered) return true;
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Register your shop', style: TextStyle(fontWeight: FontWeight.w900)),
      content: const Text('Register a shop before adding customers, inventory or issued entries.'),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Register'))],
    ));
    if (ok == true && mounted) await shopForm(context, store);
    return store.registered;
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [Home(store: store, gate: gate), InventoryPage(store: store, gate: gate), CustomersPage(store: store, gate: gate), IssuedPage(store: store, gate: gate), SettingsPage(store: store)];
    return AnimatedBuilder(animation: store, builder: (_, __) => Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Issued'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
      ]),
    ));
  }
}

class StatCard extends StatelessWidget {
  final String label, value; final IconData icon; const StatCard(this.label, this.value, this.icon, {super.key});
  @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFE7F7F2), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: primary, size: 27)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.black54))])]));
}
class ActionBox extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap; const ActionBox({required this.label, required this.icon, required this.onTap, super.key});
  @override Widget build(BuildContext context) => SizedBox(width: (MediaQuery.sizeOf(context).width - 56) / 2, height: 100, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE7F7F2), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: primary, size: 28)), const SizedBox(height: 7), Text(label, style: const TextStyle(color: dark, fontWeight: FontWeight.w900))]))));
}
class Empty extends StatelessWidget {
  final String title, subtitle; const Empty(this.title, this.subtitle, {super.key});
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)), child: Column(children: [const Icon(Icons.inbox_outlined, color: primary, size: 46), const SizedBox(height: 8), Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
}

class Home extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const Home({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) {
    final sh = store.shop;
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
      Row(children: [const Logo(size: 58), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(color: dark, fontSize: 30, fontWeight: FontWeight.w900)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 15, fontWeight: FontWeight.w900))])),
        if (store.registered) InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManager(store: store))), child: Container(width: 155, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: line)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE7F7F2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront, color: primary)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SHOP', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900)), Text('${sh['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: dark, fontWeight: FontWeight.w900))]))]))) else IconButton.filledTonal(onPressed: () => shopForm(context, store), icon: const Icon(Icons.storefront)),
      ]),
      const SizedBox(height: 18), if (store.registered) _shopBanner(context, sh) else _registerBanner(context), const SizedBox(height: 16),
      Row(children: [StatCard('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), StatCard('Customers', '${store.customers.length}', Icons.people_outline)]), const SizedBox(height: 10),
      Row(children: [StatCard('Issued', '${store.issued.length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Returns', '${store.returns.length}', Icons.keyboard_return)]), const SizedBox(height: 24),
      const Text('Quick actions', style: TextStyle(color: dark, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 11),
      Wrap(spacing: 10, runSpacing: 10, children: [
        ActionBox(label: 'Add Item', icon: Icons.add_box_outlined, onTap: () async { if (await gate() && context.mounted) await itemForm(context, store); }),
        ActionBox(label: 'Customer', icon: Icons.person_add_alt_1, onTap: () async { if (await gate() && context.mounted) await customerForm(context, store); }),
        ActionBox(label: 'Issued', icon: Icons.assignment_outlined, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueForm(store: store))); }),
        ActionBox(label: 'Return', icon: Icons.keyboard_return, onTap: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnPage(store: store))); }),
        ActionBox(label: 'Reports', icon: Icons.analytics_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(store: store)))),
      ]), const SizedBox(height: 24), const Text('Recent issued', style: TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
      if (store.issued.isEmpty) const Empty('No issued entries', 'Your saved invoices will appear here.') else ...store.issued.reversed.take(5).map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))), const SizedBox(height: 24), const Footer(),
    ]));
  }
  Widget _registerBanner(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)), child: Row(children: [const Icon(Icons.storefront, color: Colors.white, size: 32), const SizedBox(width: 12), const Expanded(child: Text('Register your shop to unlock entries.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))), FilledButton(onPressed: () => shopForm(context, store), child: const Text('Register'))]));
  Widget _shopBanner(BuildContext context, Map<String, dynamic> x) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)), child: Row(children: [const Icon(Icons.storefront, color: primary, size: 34), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text('${x['owner']}  •  ${x['mobile']}', style: const TextStyle(color: Colors.white70)), Text('${x['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))])), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManager(store: store))), icon: const Icon(Icons.edit_outlined, color: Colors.white))]));
}

class EntryTile extends StatelessWidget {
  final Map<String, dynamic> data; final VoidCallback onTap; const EntryTile({required this.data, required this.onTap, super.key});
  @override Widget build(BuildContext context) { final rows = data['items'] is List ? (data['items'] as List).length : 0; return Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)), child: ListTile(onTap: onTap, leading: const Logo(size: 38), title: Text('${data['partyName'] ?? data['customerName'] ?? 'Party'}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${data['invoice']}  •  ${data['date']}  •  $rows item(s)'), trailing: const Icon(Icons.chevron_right))); }
}

class InventoryPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const InventoryPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: Header('Inventory', actions: [IconButton(onPressed: () async { if (await gate() && context.mounted) await itemForm(context, store); }, icon: const Icon(Icons.add_circle_outline))]), body: store.items.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Empty('Inventory is empty', 'Add an item to start your tally.')) : ListView(padding: const EdgeInsets.all(18), children: store.items.asMap().entries.map((entry) { final i = entry.key; final x = entry.value; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: line)), child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE7F7F2), child: Text('${i + 1}', style: const TextStyle(color: primary, fontWeight: FontWeight.w900))), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}  •  Rent ${x['rentDays']} day(s)'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => itemForm(context, store, old: x), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () async { x['qty'] = toInt(x['qty']) + 1; await store.changed(); }, icon: const Icon(Icons.add_circle, color: primary))]))); }).toList()));
}

class CustomersPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const CustomersPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: Header('Customers', actions: [IconButton(onPressed: () async { if (await gate() && context.mounted) await customerForm(context, store); }, icon: const Icon(Icons.person_add_alt_1))]), body: store.customers.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Empty('No customers', 'Customer details will appear here.')) : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.customers.length, itemBuilder: (_, i) { final x = store.customers[i]; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE7F7F2), child: Icon(Icons.person_outline, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${x['mobile']}\n${x['address']}'), isThreeLine: true, trailing: IconButton(onPressed: () => customerForm(context, store, old: x), icon: const Icon(Icons.edit_outlined)))); }));
}

class IssuedPage extends StatelessWidget {
  final Store store; final Future<bool> Function() gate; const IssuedPage({required this.store, required this.gate, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: Header('Issued', actions: [IconButton(onPressed: () async { if (await gate() && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueForm(store: store))); }, icon: const Icon(Icons.add_circle_outline))]), body: store.issued.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: Empty('No issued records', 'Create an issued invoice with multiple inventory lines.')) : ListView(padding: const EdgeInsets.all(18), children: store.issued.reversed.map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))).toList()));
}

class IssueForm extends StatefulWidget { final Store store; const IssueForm({required this.store, super.key}); @override State<IssueForm> createState() => _IssueFormState(); }
class _IssueFormState extends State<IssueForm> {
  final date = TextEditingController(text: today()), invoice = TextEditingController(), party = TextEditingController(), mobile = TextEditingController(), address = TextEditingController();
  final lines = <Map<String, dynamic>>[];
  @override void initState() { super.initState(); invoice.text = 'RF-${DateTime.now().millisecondsSinceEpoch}'; }
  @override void dispose() { date.dispose(); invoice.dispose(); party.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> addLine() async {
    if (widget.store.items.isEmpty) { await itemForm(context, widget.store); if (widget.store.items.isEmpty) return; }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(context: context, showDragHandle: true, builder: (c) => ListView(padding: const EdgeInsets.all(18), children: [const Text('Select inventory item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark)), const SizedBox(height: 8), ...widget.store.items.map((x) => ListTile(leading: const Icon(Icons.inventory_2_outlined, color: primary), title: Text('${x['name']}'), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}'), trailing: const Icon(Icons.add_circle_outline), onTap: () => Navigator.pop(c, x)))]));
    if (selected == null || !mounted) return;
    final max = toInt(selected['qty']); final q = TextEditingController(text: '1');
    final result = await showDialog<int>(context: context, builder: (d) => AlertDialog(title: Text('${selected['name']}'), content: TextField(controller: q, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Issued quantity (max $max)')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () { final value = toInt(q.text); if (value > 0 && value <= max) Navigator.pop(d, value); }, child: const Text('Add'))])); q.dispose();
    if (result == null || !mounted) return;
    final existing = lines.indexWhere((e) => e['itemId'] == selected['id']); if (existing >= 0) lines[existing]['qty'] = toInt(lines[existing]['qty']) + result; else lines.add({'itemId': selected['id'], 'name': selected['name'], 'srl': selected['srl'], 'qty': result, 'rentDays': selected['rentDays']}); setState(() {});
  }
  Future<void> save() async {
    if (party.text.trim().isEmpty || lines.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter party name and add at least one inventory item.'))); return; }
    final entry = {'invoice': invoice.text.trim(), 'date': date.text.trim(), 'partyName': party.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'items': lines.map((e) => Map<String, dynamic>.from(e)).toList()};
    for (final line in lines) { final index = widget.store.items.indexWhere((x) => x['id'] == line['itemId']); if (index >= 0) widget.store.items[index]['qty'] = toInt(widget.store.items[index]['qty']) - toInt(line['qty']); }
    widget.store.shop['issued'] = [...widget.store.issued, entry]; await widget.store.changed(); if (mounted) await previewInvoice(context, widget.store, entry);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header('New Issued Entry'), body: ListView(padding: const EdgeInsets.all(18), children: [
    _field(invoice, 'Invoice No', readOnly: true), _field(date, 'Issued Date'), _field(party, 'Party Name'), _field(mobile, 'Mobile'), _field(address, 'Address', maxLines: 2),
    Row(children: [const Expanded(child: Text('Inventory', style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900))), FilledButton.icon(onPressed: addLine, icon: const Icon(Icons.add), label: const Text('Add Item'))]), const SizedBox(height: 8),
    if (lines.isEmpty) const Empty('No items added', 'Tap Add Item to build the invoice line by line.') else ...lines.asMap().entries.map((entry) { final i = entry.key; final x = entry.value; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE7F7F2), child: Text('${i + 1}')), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('SRL ${x['srl']}  •  Qty ${x['qty']}  •  Rent ${x['rentDays']} day(s)'), trailing: IconButton(onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)))); }),
    const SizedBox(height: 14), SizedBox(height: 52, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.preview_outlined), label: const Text('Save & Preview', style: TextStyle(fontWeight: FontWeight.w900)))), const SizedBox(height: 25), const Footer(),
  ]));
}

Widget _field(TextEditingController controller, String label, {bool readOnly = false, int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 11), child: TextField(controller: controller, readOnly: readOnly, maxLines: maxLines, decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: line)))));

class ReturnPage extends StatefulWidget { final Store store; const ReturnPage({required this.store, super.key}); @override State<ReturnPage> createState() => _ReturnPageState(); }
class _ReturnPageState extends State<ReturnPage> {
  Map<String, dynamic>? selected; final qty = TextEditingController(text: '1'); final amount = TextEditingController(text: '0');
  @override void dispose() { qty.dispose(); amount.dispose(); super.dispose(); }
  Future<void> choose() async { final x = await showModalBottomSheet<Map<String, dynamic>>(context: context, showDragHandle: true, builder: (c) => ListView(padding: const EdgeInsets.all(18), children: [const Text('Issued entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), ...widget.store.issued.reversed.map((e) => ListTile(title: Text('${e['partyName']}'), subtitle: Text('${e['invoice']}  •  ${e['date']}'), onTap: () => Navigator.pop(c, e)))])); if (x != null) setState(() => selected = x); }
  Future<void> save() async { if (selected == null) return; final q = toInt(qty.text); if (q <= 0) return; final entry = {'id': uid(), 'date': today(), 'invoice': selected!['invoice'], 'partyName': selected!['partyName'], 'qty': q, 'amount': toInt(amount.text)}; widget.store.shop['returns'] = [...widget.store.returns, entry]; await widget.store.changed(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return saved successfully'))); }
  @override Widget build(BuildContext context) => Scaffold(appBar: const Header('Return'), body: ListView(padding: const EdgeInsets.all(18), children: [const Text('Return issued material', style: TextStyle(color: dark, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 6), const Text('Select an issued invoice, then enter returned quantity and manual amount.'), const SizedBox(height: 18), FilledButton.icon(onPressed: choose, icon: const Icon(Icons.receipt_long), label: Text(selected == null ? 'Select Issued Entry' : '${selected!['partyName']}  •  ${selected!['invoice']}')), const SizedBox(height: 14), _field(qty, 'Returned Quantity'), _field(amount, 'Manual Return Amount'), const SizedBox(height: 8), SizedBox(height: 52, child: FilledButton.icon(onPressed: selected == null ? null : save, icon: const Icon(Icons.save_outlined), label: const Text('Save Return'))), const SizedBox(height: 25), const Footer()]));
}

class ReportsPage extends StatelessWidget { final Store store; const ReportsPage({required this.store, super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: const Header('Reports'), body: ListView(padding: const EdgeInsets.all(18), children: [Row(children: [StatCard('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), StatCard('Customers', '${store.customers.length}', Icons.people_outline)]), const SizedBox(height: 10), Row(children: [StatCard('Issued', '${store.issued.length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Returns', '${store.returns.length}', Icons.keyboard_return)]), const SizedBox(height: 22), const Text('Issued report', style: TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (store.issued.isEmpty) const Empty('No report data', 'Issue records will be listed here.') else ...store.issued.reversed.map((e) => EntryTile(data: e, onTap: () => previewInvoice(context, store, e))), const SizedBox(height: 20), const Footer()])); }

class ShopManager extends StatelessWidget { final Store store; const ShopManager({required this.store, super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: const Header('Shop Management'), body: ListView(padding: const EdgeInsets.all(18), children: [const Text('Your shops', style: TextStyle(color: dark, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...store.shops.asMap().entries.map((e) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: () async { await store.selectShop(e.key); if (context.mounted) Navigator.pop(context); }, leading: const Logo(size: 42), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e.value['owner']}  •  ${e.value['mobile']}\n${e.value['address']}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await shopForm(context, store, index: e.key); if (v == 'delete') { final ok = await confirmDialog(context, 'Delete shop?', 'This will delete this shop and its local records.'); if (ok) await store.deleteShop(e.key); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit shop')), PopupMenuItem(value: 'delete', child: Text('Delete shop'))])))), const SizedBox(height: 10), SizedBox(height: 50, child: OutlinedButton.icon(onPressed: () => shopForm(context, store), icon: const Icon(Icons.add_business), label: const Text('Add New Shop'))), const SizedBox(height: 24), const Footer()])); }

class SettingsPage extends StatelessWidget { final Store store; const SettingsPage({required this.store, super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: const Header('Settings'), body: ListView(padding: const EdgeInsets.all(18), children: [SizedBox(height: 50, child: FilledButton.icon(onPressed: () => shopForm(context, store), icon: const Icon(Icons.storefront), label: const Text('Register / Add New Shop'))), const SizedBox(height: 22), const Text('Shop', style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (store.registered) Card(color: Colors.white, child: ListTile(leading: const Icon(Icons.store, color: primary), title: Text('${store.shop['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${store.shop['owner']}\n${store.shop['address']}'), isThreeLine: true, trailing: IconButton(onPressed: () => shopForm(context, store), icon: const Icon(Icons.edit_outlined)))) else const Empty('No shop registered', 'Register your shop to enable rental entries.'), const SizedBox(height: 22), const Text('App', style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.w900)), Card(color: Colors.white, child: Column(children: [ListTile(leading: const Icon(Icons.system_update_alt, color: primary), title: const Text('Check for App Update'), subtitle: const Text('Check the latest RentFlow version')), ListTile(leading: const Icon(Icons.language, color: primary), title: const Text('PaliaAPK HUB Website'))])), const SizedBox(height: 20), Card(color: Colors.white, child: const ListTile(leading: Icon(Icons.info_outline, color: primary), title: Text('RentFlow', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('By PaliaAPK HUB  •  Developer by ShanPalia'))), const SizedBox(height: 28), const Footer()])); }
class Footer extends StatelessWidget { const Footer({super.key}); @override Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('RentFlow  •  By PaliaAPK HUB  •  Developer by ShanPalia', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)))); }

Future<bool> confirmDialog(BuildContext context, String title, String message) async => await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirm'))])) ?? false;

Future<void> shopForm(BuildContext context, Store store, {int? index}) async {
  final x = index == null ? null : store.shops[index]; final name = TextEditingController(text: '${x?['name'] ?? ''}'); final owner = TextEditingController(text: '${x?['owner'] ?? ''}'); final mobile = TextEditingController(text: '${x?['mobile'] ?? ''}'); final address = TextEditingController(text: '${x?['address'] ?? ''}');
  await showDialog(context: context, builder: (d) => AlertDialog(title: Text(index == null ? 'Register Shop' : 'Edit Shop'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Shop Name'), _field(owner, 'Owner Name'), _field(mobile, 'Mobile'), _field(address, 'Shop Address', maxLines: 3)])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; if (index == null) await store.addShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); else { await store.selectShop(index); await store.updateShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); } if (d.mounted) Navigator.pop(d); }, child: const Text('Save'))])); name.dispose(); owner.dispose(); mobile.dispose(); address.dispose();
}

Future<void> itemForm(BuildContext context, Store store, {Map<String, dynamic>? old}) async {
  final name = TextEditingController(text: '${old?['name'] ?? ''}'); final srl = TextEditingController(text: '${old?['srl'] ?? ''}'); final qty = TextEditingController(text: '${old?['qty'] ?? '1'}'); final days = TextEditingController(text: '${old?['rentDays'] ?? '1'}');
  await showDialog(context: context, builder: (d) => AlertDialog(title: Text(old == null ? 'Add Inventory Item' : 'Edit Inventory Item'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Item Name'), _field(srl, 'SRL'), _field(qty, 'Quantity'), _field(days, 'Rent Days')])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; if (old == null) store.items.add({'id': uid(), 'name': name.text.trim(), 'srl': srl.text.trim().isEmpty ? '${store.items.length + 1}' : srl.text.trim(), 'qty': toInt(qty.text), 'rentDays': toInt(days.text)}); else { old['name'] = name.text.trim(); old['srl'] = srl.text.trim(); old['qty'] = toInt(qty.text); old['rentDays'] = toInt(days.text); } await store.changed(); if (d.mounted) Navigator.pop(d); }, child: const Text('Save'))])); name.dispose(); srl.dispose(); qty.dispose(); days.dispose();
}

Future<void> customerForm(BuildContext context, Store store, {Map<String, dynamic>? old}) async {
  final name = TextEditingController(text: '${old?['name'] ?? ''}'); final mobile = TextEditingController(text: '${old?['mobile'] ?? ''}'); final address = TextEditingController(text: '${old?['address'] ?? ''}');
  await showDialog(context: context, builder: (d) => AlertDialog(title: Text(old == null ? 'Add Customer' : 'Edit Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Customer Name'), _field(mobile, 'Mobile'), _field(address, 'Address', maxLines: 2)]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; if (old == null) store.customers.add({'id': uid(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}); else { old['name'] = name.text.trim(); old['mobile'] = mobile.text.trim(); old['address'] = address.text.trim(); } await store.changed(); if (d.mounted) Navigator.pop(d); }, child: const Text('Save'))])); name.dispose(); mobile.dispose(); address.dispose();
}

Future<void> previewInvoice(BuildContext context, Store store, Map<String, dynamic> data) async {
  await showDialog(context: context, builder: (d) => AlertDialog(title: const Text('Invoice Preview', style: TextStyle(fontWeight: FontWeight.w300, fontSize: 26)), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${store.shop['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)), const Text('RentFlow  •  By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w900)), const Divider(), Text('Invoice: ${data['invoice']}'), Text('Issued Date: ${data['date']}'), const SizedBox(height: 8), Text('Party: ${data['partyName'] ?? ''}'), Text('Mobile: ${data['mobile'] ?? ''}'), Text('Address: ${data['address'] ?? ''}'), const SizedBox(height: 12), ...((data['items'] as List? ?? const []).asMap().entries.map((e) { final x = e.value as Map; return Padding(padding: const EdgeInsets.only(bottom: 7), child: Text('${e.key + 1}. SRL ${x['srl']} / ${x['name']}   Qty: ${x['qty']}   Rent Days: ${x['rentDays']}')); })), const SizedBox(height: 10), const Text('TOTAL — Manual amount is not required on issue', style: TextStyle(color: primary, fontWeight: FontWeight.w900)), const SizedBox(height: 10), const Text('RentFlow  •  By PaliaAPK HUB  •  Developer by ShanPalia', style: TextStyle(color: Colors.black45))]))), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close')), FilledButton.icon(onPressed: () => savePdf(context, store, data), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Save PDF'))]));
}

Future<void> savePdf(BuildContext context, Store store, Map<String, dynamic> data) async {
  final doc = pw.Document(); final rows = (data['items'] as List? ?? const []).map((x) => ['${x['srl']}', '${x['name']}', '${x['qty']}', '${x['rentDays']}']).toList();
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('${store.shop['name']}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)), pw.Text('RentFlow  •  By PaliaAPK HUB'), pw.SizedBox(height: 12), pw.Divider(), pw.Text('Invoice: ${data['invoice']}'), pw.Text('Issued Date: ${data['date']}'), pw.SizedBox(height: 8), pw.Text('Party: ${data['partyName'] ?? ''}'), pw.Text('Mobile: ${data['mobile'] ?? ''}'), pw.Text('Address: ${data['address'] ?? ''}'), pw.SizedBox(height: 14), pw.Table.fromTextArray(headers: const ['SRL', 'Inventory', 'Qty', 'Rent Days'], data: rows), pw.SizedBox(height: 20), pw.Text('RentFlow  •  By PaliaAPK HUB  •  Developer by ShanPalia')]));
  final bytes = await doc.save(); await Printing.sharePdf(bytes: bytes, filename: '${data['invoice']}.pdf');
}
