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

int asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String money(dynamic value) => '₹${asDouble(value).toStringAsFixed(0)}';

void main() => runApp(const RentFlowApp());

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentFlow',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
      ),
      home: const SplashPage(),
    );
  }
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
      final registered = (prefs.getString('shop_name') ?? '').trim().isNotEmpty;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => registered ? const AppShell() : const ShopPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 18),
            const Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: dark)),
            const Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
            const Text('Developer by ShanPalia', style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

class Store {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];
  String shopName = '';
  String owner = '';
  String phone = '';

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    shopName = prefs.getString('shop_name') ?? '';
    owner = prefs.getString('owner') ?? '';
    phone = prefs.getString('phone') ?? '';
    items = readList('items');
    customers = readList('customers');
    rentals = readList('rentals');
  }

  List<Map<String, dynamic>> readList(String key) {
    try {
      final decoded = jsonDecode(prefs.getString(key) ?? '[]');
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveData() async {
    await prefs.setString('items', jsonEncode(items));
    await prefs.setString('customers', jsonEncode(customers));
    await prefs.setString('rentals', jsonEncode(rentals));
  }

  Future<void> saveShop(String name, String ownerName, String mobile) async {
    shopName = name.trim();
    owner = ownerName.trim();
    phone = mobile.trim();
    await prefs.setString('shop_name', shopName);
    await prefs.setString('owner', owner);
    await prefs.setString('phone', phone);
  }
}

class ShopPage extends StatefulWidget {
  final Store? existing;
  const ShopPage({this.existing, super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final owner = TextEditingController();
  final phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = widget.existing;
    if (store != null) {
      name.text = store.shopName;
      owner.text = store.owner;
      phone.text = store.phone;
    }
  }

  @override
  void dispose() {
    name.dispose();
    owner.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final store = widget.existing ?? Store();
    if (widget.existing == null) await store.load();
    await store.saveShop(name.text, owner.text, phone.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 28),
              const Icon(Icons.storefront_rounded, color: primary, size: 62),
              const SizedBox(height: 10),
              const Text('Register Your Shop', textAlign: TextAlign.center, style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: dark)),
              const SizedBox(height: 26),
              formField(name, 'Shop name', Icons.store),
              formField(owner, 'Owner name', Icons.person),
              formField(phone, 'Phone', Icons.phone),
              const SizedBox(height: 8),
              FilledButton(onPressed: save, style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(54)), child: const Text('Continue')),
              const SizedBox(height: 18),
              const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by ShanPalia', style: TextStyle(color: muted, fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }
}

Widget formField(TextEditingController controller, String label, IconData icon) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controller, validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: primary), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))));

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final store = Store();
  int index = 0;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    store.load().then((_) { if (mounted) setState(() => ready = true); });
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = <Widget>[
      HomePage(store: store, refresh: refresh),
      ItemsPage(store: store, refresh: refresh),
      CustomersPage(store: store, refresh: refresh),
      ReportsPage(store: store),
      SettingsPage(store: store, refresh: refresh),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && index != 0) setState(() => index = 0); },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const HomePage({required this.store, required this.refresh, super.key});

  @override
  Widget build(BuildContext context) {
    final issued = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).length;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      Text(store.shopName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: dark)),
      const Text('Rental Management', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      Row(children: [statCard('Items', '${store.items.length}'), statCard('Customers', '${store.customers.length}'), statCard('Issued', '$issued')]),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () => rentalDialog(context, store, refresh), icon: const Icon(Icons.add_circle), label: const Text('New Rental'), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(55))),
      const SizedBox(height: 12),
      Row(children: [quickButton('Item', Icons.inventory_2, () => itemDialog(context, store, refresh)), quickButton('Customer', Icons.person_add, () => customerDialog(context, store, refresh)), quickButton('Invoice', Icons.receipt_long, () => invoiceDialog(context, store)), quickButton('Receive', Icons.assignment_return, () => receiveDialog(context, store, refresh))]),
      const SizedBox(height: 22),
      const Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark)),
      ...store.rentals.reversed.take(8).map((r) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2, color: primary)), title: Text('${r['customer']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${r['item']} • Qty ${r['qty']}'), trailing: Text(money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900))))),
    ]));
  }
}

Widget statCard(String label, String value) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: muted, fontSize: 12))]))));
Widget quickButton(String label, IconData icon, VoidCallback action) => Expanded(child: InkWell(onTap: action, child: Container(margin: const EdgeInsets.only(right: 5), padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(children: [Icon(icon, color: primary), const SizedBox(height: 5), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]))));

class ItemsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [pageHeader('Items', 'Rental inventory'), Expanded(child: store.items.isEmpty ? const Center(child: Text('No items added yet', style: TextStyle(color: muted))) : ListView.builder(itemCount: store.items.length, itemBuilder: (_, i) { final item = store.items[i]; return ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2, color: primary)), title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Qty ${asInt(item['qty'])} • Rent ${money(item['rent'])}')); })), actionButton('Add Item', () => itemDialog(context, store, refresh))]));
}

class CustomersPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const CustomersPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [pageHeader('Customers', 'Customer records'), Expanded(child: store.customers.isEmpty ? const Center(child: Text('No customers added yet', style: TextStyle(color: muted))) : ListView.builder(itemCount: store.customers.length, itemBuilder: (_, i) { final customer = store.customers[i]; return ListTile(onTap: () => customerReport(context, store, '${customer['name']}'), leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person, color: primary)), title: Text('${customer['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${customer['phone'] ?? ''}'), trailing: const Icon(Icons.chevron_right)); })), actionButton('New Customer', () => customerDialog(context, store, refresh))]));
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    final issued = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).length;
    final returned = store.rentals.where((r) => asInt(r['received']) >= asInt(r['qty'])).length;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [pageHeader('Reports', 'Rental business overview'), Row(children: [statCard('Issued', '$issued'), statCard('Returned', '$returned')]), const SizedBox(height: 15), const Text('Rental History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), ...store.rentals.reversed.map((r) => Card(child: ListTile(title: Text('${r['customer']} • ${r['item']}'), subtitle: Text('${r['date']} • Qty ${r['qty']}'), trailing: Text(money(r['amount'])))))]));
  }
}

Widget pageHeader(String title, String subtitle) => Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: dark)), Text(subtitle, style: const TextStyle(color: muted))]));
Widget actionButton(String text, VoidCallback action) => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: action, icon: const Icon(Icons.add), label: Text(text), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(52))));

class SettingsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const SettingsPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [const Text('Settings', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: dark)), const SizedBox(height: 14), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('RentFlow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)), const Text('Developer by ShanPalia', style: TextStyle(color: muted)), const SizedBox(height: 8), Text(store.shopName, style: const TextStyle(fontWeight: FontWeight.w800))]))), settingsTile('Shop Profile', '${store.shopName} • ${store.owner}', Icons.store, () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(existing: store))); await store.load(); refresh(); }), settingsTile('Check for App Update', 'Check the latest RentFlow version', Icons.system_update_alt, () => checkUpdate(context)), settingsTile('PaliaAPK HUB Website', 'Open website', Icons.language, () => launchUrl(Uri.parse(websiteUrl), mode: LaunchMode.externalApplication)), const SizedBox(height: 14), const Center(child: Text('RentFlow $appVersion', style: TextStyle(color: muted))) ]));
}

Widget settingsTile(String title, String subtitle, IconData icon, VoidCallback action) => Card(child: ListTile(onTap: action, leading: CircleAvatar(backgroundColor: mint, child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right)));

Future<void> itemDialog(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rent = TextEditingController(text: '0');
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Add Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent price'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
  if (ok == true && name.text.trim().isNotEmpty) { final quantity = asInt(qty.text); store.items.add({'name': name.text.trim(), 'qty': quantity, 'available': quantity, 'rent': asDouble(rent.text)}); await store.saveData(); refresh(); }
}

Future<void> customerDialog(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
  if (ok == true && name.text.trim().isNotEmpty) { store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()}); await store.saveData(); refresh(); }
}

Future<void> rentalDialog(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item and customer first.'))); return; }
  String customer = '${store.customers.first['name']}';
  String item = '${store.items.first['name']}';
  final qty = TextEditingController(text: '1');
  final days = TextEditingController(text: '1');
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(title: const Text('New Rental'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: customer, items: store.customers.map((c) => DropdownMenuItem(value: '${c['name']}', child: Text('${c['name']}'))).toList(), onChanged: (v) => setDialogState(() => customer = v ?? customer), decoration: const InputDecoration(labelText: 'Customer')), DropdownButtonFormField<String>(initialValue: item, items: store.items.map((i) => DropdownMenuItem(value: '${i['name']}', child: Text('${i['name']}'))).toList(), onChanged: (v) => setDialogState(() => item = v ?? item), decoration: const InputDecoration(labelText: 'Item')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Issue'))])));
  if (ok == true) { final quantity = asInt(qty.text); final duration = asInt(days.text); final selected = store.items.firstWhere((i) => '${i['name']}' == item); final available = asInt(selected['available']); if (quantity <= 0 || quantity > available) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity not available.'))); return; } final amount = asDouble(selected['rent']) * quantity * duration; selected['available'] = available - quantity; store.rentals.add({'customer': customer, 'item': item, 'qty': quantity, 'received': 0, 'days': duration, 'amount': amount, 'date': DateTime.now().toIso8601String().split('T').first}); await store.saveData(); refresh(); }
}

Future<void> receiveDialog(BuildContext context, Store store, VoidCallback refresh) async {
  final active = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).toList();
  if (active.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No issued rental found.'))); return; }
  Map<String, dynamic> selected = active.first;
  final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(title: const Text('Receive Item'), content: DropdownButtonFormField<Map<String, dynamic>>(initialValue: selected, items: active.map((r) => DropdownMenuItem(value: r, child: Text('${r['customer']} • ${r['item']}'))).toList(), onChanged: (v) { if (v != null) setDialogState(() => selected = v); }), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Received'))])));
  if (ok == true) { final qty = asInt(selected['qty']); selected['received'] = qty; final item = store.items.firstWhere((i) => '${i['name']}' == '${selected['item']}'); item['available'] = asInt(item['available']) + qty; await store.saveData(); refresh(); }
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  if (store.rentals.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No rental available for invoice.'))); return; }
  final rental = store.rentals.last;
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Invoice'), content: Text('RentFlow\n\nCustomer: ${rental['customer']}\nItem: ${rental['item']}\nQuantity: ${rental['qty']}\nDate: ${rental['date']}\nAmount: ${money(rental['amount'])}'), actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))]));
}

Future<void> customerReport(BuildContext context, Store store, String customer) async {
  final rows = store.rentals.where((r) => '${r['customer']}' == customer).toList();
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(customer), content: SizedBox(width: 360, child: rows.isEmpty ? const Text('No rental history.') : ListView(shrinkWrap: true, children: rows.map((r) => ListTile(title: Text('${r['item']} • Qty ${r['qty']}'), subtitle: Text('${r['date']} • ${r['received']}/${r['qty']} received'), trailing: Text(money(r['amount'])))).toList())), actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))]));
}

Future<void> checkUpdate(BuildContext context) async {
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 18), Text('Checking for updates...')]));
  try {
    final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 8));
    if (!context.mounted) return;
    Navigator.pop(context);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = '${data['version'] ?? appVersion}';
    if (latest != appVersion) {
      final url = '${data['url'] ?? websiteUrl}';
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Update available'), content: Text('RentFlow $latest is available.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')), FilledButton(onPressed: () { Navigator.pop(dialogContext); launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }, child: const Text('Update'))]));
    } else {
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('You are up to date'), content: const Text('You already have the latest RentFlow version.'), actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))]));
    }
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check for updates. Please try again later.')));
  }
}
