import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF5FAF8);
const version = '1.0.2';
const website = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';

int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String rupee(dynamic v) => '₹${asDouble(v).toStringAsFixed(0)}';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentFlowApp());
}

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentFlow',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary), scaffoldBackgroundColor: bg),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    });
  }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 48, backgroundColor: primary, child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 58)), SizedBox(height: 18), Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: dark)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)), Text('Developer by ShanPalia', style: TextStyle(color: Colors.grey))])));
}

class Store {
  late SharedPreferences prefs;
  String shop = '';
  String owner = '';
  String phone = '';
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    shop = prefs.getString('shop') ?? '';
    owner = prefs.getString('owner') ?? '';
    phone = prefs.getString('phone') ?? '';
    items = readList('items');
    customers = readList('customers');
    rentals = readList('rentals');
  }
  List<Map<String, dynamic>> readList(String key) {
    try {
      final value = jsonDecode(prefs.getString(key) ?? '[]');
      if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return [];
  }
  Future<void> save() async {
    await prefs.setString('shop', shop);
    await prefs.setString('owner', owner);
    await prefs.setString('phone', phone);
    await prefs.setString('items', jsonEncode(items));
    await prefs.setString('customers', jsonEncode(customers));
    await prefs.setString('rentals', jsonEncode(rentals));
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  final store = Store();
  int index = 0;
  bool loading = true;
  @override void initState() { super.initState(); store.load().then((_) { if (mounted) setState(() => loading = false); }); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [HomePage(store: store, refresh: refresh), ItemsPage(store: store, refresh: refresh), CustomersPage(store: store), ReportsPage(store: store), SettingsPage(store: store)];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && index != 0) setState(() => index = 0); },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ]),
      ),
    );
  }
  void refresh() { if (mounted) setState(() {}); }
}

class HomePage extends StatelessWidget {
  final Store store; final VoidCallback refresh;
  const HomePage({required this.store, required this.refresh, super.key});
  @override Widget build(BuildContext context) {
    final issued = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).length;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      Text(store.shop.isEmpty ? 'RentFlow' : store.shop, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: dark)),
      const Text('Rental Management', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 18),
      Row(children: [metric('Items', store.items.length), metric('Customers', store.customers.length), metric('Issued', issued)]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => rentalDialog(context, store, refresh), icon: const Icon(Icons.add), label: const Text('New Rental'), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(54))),
      const SizedBox(height: 16),
      const Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ...store.rentals.reversed.take(8).map((r) => Card(child: ListTile(title: Text('${r['customer']}'), subtitle: Text('${r['item']} • Qty ${r['qty']} • ${r['date']}'), trailing: Text(rupee(r['amount']))))),
    ]));
  }
}
Widget metric(String label, int value) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.grey))]))));

class ItemsPage extends StatelessWidget {
  final Store store; final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});
  @override Widget build(BuildContext context) => SafeArea(child: Column(children: [pageHeader('Items', 'Rental inventory'), Expanded(child: store.items.isEmpty ? const Center(child: Text('No items added yet')) : ListView.builder(itemCount: store.items.length, itemBuilder: (_, i) { final x = store.items[i]; return ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE4F8F2), child: Icon(Icons.inventory_2, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Qty ${asInt(x['qty'])} • Rent ${rupee(x['rent'])}')); })), actionButton('Add Item', () => itemDialog(context, store, refresh))]));
}
class CustomersPage extends StatelessWidget {
  final Store store;
  const CustomersPage({required this.store, super.key});
  @override Widget build(BuildContext context) => SafeArea(child: Column(children: [pageHeader('Customers', 'Customer records'), Expanded(child: store.customers.isEmpty ? const Center(child: Text('No customers added yet')) : ListView.builder(itemCount: store.customers.length, itemBuilder: (_, i) { final x = store.customers[i]; return ListTile(onTap: () => customerReport(context, store, '${x['name']}'), leading: const CircleAvatar(backgroundColor: Color(0xFFE4F8F2), child: Icon(Icons.person, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${x['phone'] ?? ''}'), trailing: const Icon(Icons.chevron_right)); })), actionButton('New Customer', () => customerDialog(context, store))]));
}
class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [pageHeader('Reports', 'Date, day and amount'), ...store.rentals.reversed.map((r) => Card(child: ListTile(title: Text('${r['customer']} • ${r['item']}'), subtitle: Text('${r['date']} • Qty ${r['qty']} • Received ${r['received']}/${r['qty']}'), trailing: Text(rupee(r['amount']))))) ]));
}
Widget pageHeader(String title, String sub) => Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: dark)), Text(sub, style: const TextStyle(color: Colors.grey))]));
Widget actionButton(String text, VoidCallback onTap) => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.add), label: Text(text), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(52))));

class SettingsPage extends StatelessWidget {
  final Store store;
  const SettingsPage({required this.store, super.key});
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Settings', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: dark)), const SizedBox(height: 16),
    Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE4F8F2), child: Icon(Icons.store, color: primary)), title: Text(store.shop.isEmpty ? 'Your Shop' : store.shop, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${store.owner}\n${store.phone}'))),
    const SizedBox(height: 12),
    Card(child: Column(children: [
      ListTile(leading: const Icon(Icons.system_update, color: primary), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check the latest RentFlow version'), onTap: () => checkUpdate(context)),
      ListTile(leading: const Icon(Icons.language, color: primary), title: const Text('PaliaAPK HUB Website'), onTap: () => launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication)),
      const ListTile(leading: Icon(Icons.info_outline, color: primary), title: Text('RentFlow'), subtitle: Text('By PaliaAPK HUB • Developer by ShanPalia')),
    ])),
  ]));
}

Future<void> checkUpdate(BuildContext context) async {
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Checking...')])));
  try {
    final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 8));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (response.statusCode != 200) throw Exception();
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = '${data['version'] ?? version}';
    if (latest == version) {
      showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Up to date'), content: Text('RentFlow $version is the latest version.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
    } else {
      showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Update available'), content: Text('Version $latest is available.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')), FilledButton(onPressed: () => launchUrl(Uri.parse('${data['url'] ?? website}'), mode: LaunchMode.externalApplication), child: const Text('Update'))]));
    }
  } catch (_) {
    if (context.mounted) { Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check for updates.'))); }
  }
}

Future<void> itemDialog(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController(); final qty = TextEditingController(text: '1'); final rent = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Add Rental Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent price'))]), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save'))]));
  if (ok == true && name.text.trim().isNotEmpty) { store.items.add({'name': name.text.trim(), 'qty': asInt(qty.text), 'rent': asDouble(rent.text)}); await store.save(); refresh(); }
}

Future<void> customerDialog(BuildContext context, Store store) async {
  final name = TextEditingController(); final phone = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))]), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save'))]));
  if (ok == true && name.text.trim().isNotEmpty) { store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()}); await store.save(); }
}

Future<void> rentalDialog(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item and customer first.'))); return; }
  String customer = '${store.customers.first['name']}'; String item = '${store.items.first['name']}'; final qty = TextEditingController(text: '1');
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('New Rental'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: customer, items: store.customers.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => customer = v ?? customer)), DropdownButtonFormField<String>(initialValue: item, items: store.items.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => item = v ?? item)), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))]), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Issue'))])));
  if (ok == true) { final selected = store.items.firstWhere((x) => '${x['name']}' == item); final count = asInt(qty.text); store.rentals.add({'customer': customer, 'item': item, 'qty': count, 'received': 0, 'amount': asDouble(selected['rent']) * count, 'date': DateTime.now().toIso8601String().substring(0, 10)}); await store.save(); refresh(); }
}

Future<void> receiveDialog(BuildContext context, Store store) async {
  final open = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).toList();
  if (open.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No issued rental found.'))); return; }
  open.first['received'] = open.first['qty']; await store.save();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item received successfully.')));
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  final r = store.rentals.isEmpty ? null : store.rentals.last;
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Invoice'), content: Text(r == null ? 'No rental yet.' : 'Customer: ${r['customer']}\nItem: ${r['item']}\nDate: ${r['date']}\nQty: ${r['qty']}\nAmount: ${rupee(r['amount'])}'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))]));
}

Future<void> customerReport(BuildContext context, Store store, String customer) async {
  final rows = store.rentals.where((r) => '${r['customer']}' == customer).toList();
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text('$customer Report'), content: SizedBox(width: 360, child: rows.isEmpty ? const Text('No rental history.') : ListView(shrinkWrap: true, children: rows.map((r) => ListTile(title: Text('${r['item']} • Qty ${r['qty']}'), subtitle: Text('${r['date']} • ${r['received']}/${r['qty']} received'), trailing: Text(rupee(r['amount'])))).toList())), actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))]));
}
