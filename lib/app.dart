import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF6FAF8);
const soft = Color(0xFFE8F7F2);
const version = '1.0.3';
const website = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';

int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String money(dynamic v) => '₹${asDouble(v).toStringAsFixed(0)}';

Future<void> main() async {
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
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: dark, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Color(0xFFE3ECE9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.5)),
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
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    });
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 92, height: 92, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x2200A889), blurRadius: 24, offset: Offset(0, 10))]), child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 54)),
      const SizedBox(height: 20),
      const Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: dark)),
      const SizedBox(height: 4),
      const Text('Rental Management', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 22),
      const Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
      const Text('Developer by ShanPalia', style: TextStyle(color: Colors.black45)),
    ])),
  );
}

class Store {
  late SharedPreferences prefs;
  String shop = '';
  String owner = '';
  String phone = '';
  String address = '';
  bool skippedRegistration = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];

  bool get registered => shop.trim().isNotEmpty && owner.trim().isNotEmpty;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    shop = prefs.getString('shop') ?? '';
    owner = prefs.getString('owner') ?? '';
    phone = prefs.getString('phone') ?? '';
    address = prefs.getString('address') ?? '';
    skippedRegistration = prefs.getBool('registration_skipped') ?? false;
    items = readList('items');
    customers = readList('customers');
    rentals = readList('rentals');
  }
  List<Map<String, dynamic>> readList(String key) {
    try {
      final v = jsonDecode(prefs.getString(key) ?? '[]');
      if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return [];
  }
  Future<void> save() async {
    await prefs.setString('shop', shop);
    await prefs.setString('owner', owner);
    await prefs.setString('phone', phone);
    await prefs.setString('address', address);
    await prefs.setBool('registration_skipped', skippedRegistration);
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
  void refresh() { if (mounted) setState(() {}); }
  Future<bool> requireRegistration(BuildContext context) async {
    if (store.registered) return true;
    final register = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Register your shop first'),
        content: const Text('Please register your shop before adding items, customers or rentals. You can continue browsing without registration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.storefront), label: const Text('Register Shop')),
        ],
      ),
    );
    if (register == true && context.mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopRegistrationPage(store: store)));
      refresh();
    }
    return store.registered;
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [
      HomePage(store: store, onRegister: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopRegistrationPage(store: store))); refresh(); }, onEntry: requireRegistration),
      ItemsPage(store: store, onEntry: requireRegistration, refresh: refresh),
      CustomersPage(store: store, onEntry: requireRegistration, refresh: refresh),
      RentalsPage(store: store, onEntry: requireRegistration, refresh: refresh),
      SettingsPage(store: store, onRegister: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopRegistrationPage(store: store))); refresh(); }),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && index != 0) setState(() => index = 0); },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: soft,
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Rentals'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class ShopRegistrationPage extends StatefulWidget {
  final Store store;
  const ShopRegistrationPage({required this.store, super.key});
  @override State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}
class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  late final TextEditingController shop, owner, phone, address;
  @override void initState() { super.initState(); shop = TextEditingController(text: widget.store.shop); owner = TextEditingController(text: widget.store.owner); phone = TextEditingController(text: widget.store.phone); address = TextEditingController(text: widget.store.address); }
  @override void dispose() { shop.dispose(); owner.dispose(); phone.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async {
    if (shop.text.trim().isEmpty || owner.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop name and owner name are required.'))); return; }
    widget.store.shop = shop.text.trim(); widget.store.owner = owner.text.trim(); widget.store.phone = phone.text.trim(); widget.store.address = address.text.trim(); widget.store.skippedRegistration = false;
    await widget.store.save();
    if (mounted) Navigator.pop(context);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register Your Shop', style: TextStyle(fontWeight: FontWeight.w800))),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.storefront_rounded, color: primary, size: 38), SizedBox(height: 12), Text('Set up your shop', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: dark)), SizedBox(height: 5), Text('Register once to start adding items, customers and rental entries.', style: TextStyle(color: Colors.black54))])),
      const SizedBox(height: 22),
      TextField(controller: shop, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Shop name *', prefixIcon: Icon(Icons.store_outlined))),
      const SizedBox(height: 12),
      TextField(controller: owner, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Owner name *', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined))),
      const SizedBox(height: 12),
      TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Shop address', prefixIcon: Icon(Icons.location_on_outlined))),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: save, icon: const Icon(Icons.check_circle_outline), label: const Text('Save & Continue'), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    ])),
  );
}

class HomePage extends StatelessWidget {
  final Store store; final VoidCallback onRegister; final Future<bool> Function(BuildContext) onEntry;
  const HomePage({required this.store, required this.onRegister, required this.onEntry, super.key});
  @override Widget build(BuildContext context) {
    final issuedQty = store.rentals.fold<int>(0, (n, r) => n + (asInt(r['qty']) - asInt(r['received'])));
    final active = store.rentals.where((r) => asInt(r['received']) < asInt(r['qty'])).length;
    final totalRent = store.rentals.fold<double>(0, (n, r) => n + asDouble(r['amount']));
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 24), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.registered ? store.shop : 'Welcome to RentFlow', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: dark)), Text(store.registered ? 'Rental dashboard' : 'Manage your rentals simply', style: const TextStyle(color: Colors.black54))])),
        if (!store.registered) IconButton.filledTonal(onPressed: onRegister, icon: const Icon(Icons.storefront)),
        if (store.registered) CircleAvatar(backgroundColor: soft, child: const Icon(Icons.store, color: primary)),
      ]),
      const SizedBox(height: 20),
      if (!store.registered) _registerBanner(onRegister),
      if (!store.registered) const SizedBox(height: 16),
      Row(children: [
        statCard('Items', '${store.items.length}', Icons.inventory_2_outlined),
        const SizedBox(width: 10), statCard('Customers', '${store.customers.length}', Icons.people_outline),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        statCard('Active', '$active', Icons.assignment_outlined),
        const SizedBox(width: 10), statCard('Issued Qty', '$issuedQty', Icons.local_shipping_outlined),
      ]),
      const SizedBox(height: 18),
      const Text('Quick actions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark)),
      const SizedBox(height: 10),
      Row(children: [
        quickAction(context, 'Add Item', Icons.add_box_outlined, () async { if (await onEntry(context) && context.mounted) await itemDialog(context, store, () {}); }),
        const SizedBox(width: 10), quickAction(context, 'Customer', Icons.person_add_alt_1_outlined, () async { if (await onEntry(context) && context.mounted) await customerDialog(context, store); }),
        const SizedBox(width: 10), quickAction(context, 'New Rental', Icons.add_business_outlined, () async { if (await onEntry(context) && context.mounted) await rentalDialog(context, store, () {}); }),
      ]),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent rentals', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark)), Text(money(totalRent), style: const TextStyle(fontWeight: FontWeight.w900, color: primary))]),
      const SizedBox(height: 8),
      if (store.rentals.isEmpty) emptyCard(Icons.receipt_long_outlined, 'No rentals yet', 'Your latest rental entries will appear here.')
      else ...store.rentals.reversed.take(6).map((r) => rentalCard(r)),
    ]));
  }
}

Widget _registerBanner(VoidCallback onRegister) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Register your shop', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Unlock item, customer and rental entry.', style: TextStyle(color: Colors.white70))])), TextButton(onPressed: onRegister, child: const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))]));
Widget statCard(String label, String value, IconData icon) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5))]), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: primary)), const SizedBox(width: 11), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)), Text(label, style: const TextStyle(color: Colors.black54))])])));
Widget quickAction(BuildContext context, String text, IconData icon, VoidCallback onTap) => Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 94, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3ECE9))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: primary, size: 28), const SizedBox(height: 7), Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark))]))));
Widget emptyCard(IconData icon, String title, String sub) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [Icon(icon, color: primary, size: 38), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: dark)), Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
Widget rentalCard(Map<String, dynamic> r) { final complete = asInt(r['received']) >= asInt(r['qty']); return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Row(children: [CircleAvatar(backgroundColor: complete ? const Color(0xFFE7F7EA) : soft, child: Icon(complete ? Icons.check : Icons.schedule, color: complete ? Colors.green : primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['customer']}', style: const TextStyle(fontWeight: FontWeight.w800, color: dark)), Text('${r['item']} • Qty ${r['qty']} • ${r['date']}', style: const TextStyle(color: Colors.black54, fontSize: 12))])), Text(money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: primary))])); }

class ItemsPage extends StatelessWidget {
  final Store store; final Future<bool> Function(BuildContext) onEntry; final VoidCallback refresh;
  const ItemsPage({required this.store, required this.onEntry, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Items', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await onEntry(context) && context.mounted) await itemDialog(context, store, refresh); }, icon: const Icon(Icons.add))]), body: store.items.isEmpty ? emptyCard(Icons.inventory_2_outlined, 'No items added', 'Add your rental inventory here.') : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.items.length, itemBuilder: (_, i) { final x = store.items[i]; final rented = store.rentals.where((r) => '${r['item']}' == '${x['name']}' && asInt(r['received']) < asInt(r['qty'])).fold<int>(0, (n, r) => n + asInt(r['qty']) - asInt(r['received'])); return itemTile(context, store, x, rented, refresh); }));
}
Widget itemTile(BuildContext context, Store store, Map<String, dynamic> x, int rented, VoidCallback refresh) => Dismissible(key: ValueKey('${x['name']}_${x.hashCode}'), background: Container(margin: const EdgeInsets.only(bottom: 10), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete_outline, color: Colors.red)), confirmDismiss: (_) async => await confirmDelete(context, 'Delete item?', 'This item will be removed from inventory.'), onDismissed: (_) async { store.items.remove(x); await store.save(); refresh(); }, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.inventory_2, color: primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), Text('Total ${asInt(x['qty'])} • Available ${asInt(x['qty']) - rented}', style: const TextStyle(color: Colors.black54)), Text('Rent ${money(x['rent'])}', style: const TextStyle(color: primary, fontWeight: FontWeight.w700))])), IconButton(onPressed: () async { await itemDialog(context, store, refresh, existing: x); }, icon: const Icon(Icons.edit_outlined))])));

class CustomersPage extends StatelessWidget {
  final Store store; final Future<bool> Function(BuildContext) onEntry; final VoidCallback refresh;
  const CustomersPage({required this.store, required this.onEntry, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await onEntry(context) && context.mounted) await customerDialog(context, store, refresh: refresh); }, icon: const Icon(Icons.person_add_alt_1))]), body: store.customers.isEmpty ? emptyCard(Icons.people_outline, 'No customers yet', 'Customer records will appear here.') : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.customers.length, itemBuilder: (_, i) { final x = store.customers[i]; final count = store.rentals.where((r) => '${r['customer']}' == '${x['name']}').length; return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: CircleAvatar(backgroundColor: soft, child: Text('${x['name']}'.trim().isEmpty ? '?' : '${x['name']}'.trim()[0].toUpperCase(), style: const TextStyle(color: primary, fontWeight: FontWeight.w900))), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: dark)), subtitle: Text('${x['phone'] ?? ''} • $count rentals'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await customerDialog(context, store, existing: x, refresh: refresh); if (v == 'delete' && await confirmDelete(context, 'Delete customer?', 'Customer record will be removed.')) { store.customers.remove(x); await store.save(); refresh(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]))); }));
}

class RentalsPage extends StatelessWidget {
  final Store store; final Future<bool> Function(BuildContext) onEntry; final VoidCallback refresh;
  const RentalsPage({required this.store, required this.onEntry, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Rentals', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await onEntry(context) && context.mounted) await rentalDialog(context, store, refresh); }, icon: const Icon(Icons.add_business_outlined))]), body: store.rentals.isEmpty ? emptyCard(Icons.assignment_outlined, 'No rental entries', 'Create a rental after adding an item and customer.') : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.rentals.length, itemBuilder: (_, i) => rentalActionTile(context, store, store.rentals[store.rentals.length - 1 - i], refresh)));
}
Widget rentalActionTile(BuildContext context, Store store, Map<String, dynamic> r, VoidCallback refresh) { final done = asInt(r['received']) >= asInt(r['qty']); final pending = asInt(r['qty']) - asInt(r['received']); return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [Row(children: [CircleAvatar(backgroundColor: done ? const Color(0xFFE7F7EA) : soft, child: Icon(done ? Icons.check : Icons.schedule, color: done ? Colors.green : primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['item']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), Text('${r['customer']} • ${r['date']}', style: const TextStyle(color: Colors.black54))])), Text(money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: primary))]), const SizedBox(height: 12), Row(children: [statusChip(done ? 'Returned' : '$pending pending', done), const Spacer(), if (!done) OutlinedButton.icon(onPressed: () async { await returnRental(context, store, r, refresh); }, icon: const Icon(Icons.assignment_return_outlined, size: 18), label: const Text('Return'))]) ])); }
Widget statusChip(String text, bool done) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: done ? const Color(0xFFE7F7EA) : const Color(0xFFFFF4D8), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: done ? Colors.green.shade700 : Colors.orange.shade800)));

class SettingsPage extends StatelessWidget {
  final Store store; final VoidCallback onRegister;
  const SettingsPage({required this.store, required this.onRegister, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(22)), child: Row(children: [CircleAvatar(radius: 27, backgroundColor: soft, child: const Icon(Icons.store, color: primary)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.registered ? store.shop : 'Shop not registered', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text(store.registered ? '${store.owner}\n${store.phone}' : 'Register to start entering data', style: const TextStyle(color: Colors.white70))])), IconButton(onPressed: onRegister, icon: Icon(store.registered ? Icons.edit_outlined : Icons.add_business, color: Colors.white))])),
    const SizedBox(height: 14),
    settingsSection('App', [
      ListTile(leading: const Icon(Icons.system_update_outlined, color: primary), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check the latest RentFlow version'), onTap: () => checkUpdate(context)),
      ListTile(leading: const Icon(Icons.language_outlined, color: primary), title: const Text('PaliaAPK HUB Website'), onTap: () => launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication)),
    ]),
    const SizedBox(height: 12),
    settingsSection('About', [const ListTile(leading: Icon(Icons.info_outline, color: primary), title: Text('RentFlow'), subtitle: Text('By PaliaAPK HUB • Developer by ShanPalia'))]),
  ]));
}
Widget settingsSection(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 4, bottom: 7), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54))), Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: children))]);

Future<void> itemDialog(BuildContext context, Store store, VoidCallback refresh, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final qty = TextEditingController(text: existing == null ? '1' : '${asInt(existing['qty'])}');
  final rent = TextEditingController(text: existing == null ? '' : '${asDouble(existing['rent'])}');
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(existing == null ? 'Add Rental Item' : 'Edit Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total quantity')), const SizedBox(height: 10), TextField(controller: rent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent price'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))]));
  if (ok != true || name.text.trim().isEmpty) return;
  final data = {'name': name.text.trim(), 'qty': asInt(qty.text), 'rent': asDouble(rent.text)};
  if (existing == null) store.items.add(data); else { existing..clear()..addAll(data); }
  await store.save(); refresh();
}

Future<void> customerDialog(BuildContext context, Store store, {Map<String, dynamic>? existing, VoidCallback? refresh}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}'); final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(existing == null ? 'New Customer' : 'Edit Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))]));
  if (ok != true || name.text.trim().isEmpty) return;
  final data = {'name': name.text.trim(), 'phone': phone.text.trim()};
  if (existing == null) store.customers.add(data); else { existing..clear()..addAll(data); }
  await store.save(); refresh?.call();
}

Future<void> rentalDialog(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item and customer first.'))); return; }
  String customer = '${store.customers.first['name']}'; String item = '${store.items.first['name']}';
  final qty = TextEditingController(text: '1'); final due = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('New Rental'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: customer, decoration: const InputDecoration(labelText: 'Customer'), items: store.customers.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => customer = v ?? customer)), const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: item, decoration: const InputDecoration(labelText: 'Item'), items: store.items.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => item = v ?? item)), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), const SizedBox(height: 10), TextField(controller: due, decoration: const InputDecoration(labelText: 'Due date (optional)', prefixIcon: Icon(Icons.event_outlined))) ])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create Rental'))])));
  if (ok != true) return;
  final q = asInt(qty.text); final inv = store.items.firstWhere((x) => '${x['name']}' == item); final available = asInt(inv['qty']) - store.rentals.where((r) => '${r['item']}' == item && asInt(r['received']) < asInt(r['qty'])).fold<int>(0, (n, r) => n + asInt(r['qty']) - asInt(r['received']));
  if (q <= 0 || q > available) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $available quantity is available.'))); return; }
  final amount = q * asDouble(inv['rent']);
  store.rentals.add({'customer': customer, 'item': item, 'qty': q, 'received': 0, 'amount': amount, 'date': DateTime.now().toString().substring(0, 10), 'due': due.text.trim()});
  await store.save(); refresh();
}

Future<void> returnRental(BuildContext context, Store store, Map<String, dynamic> r, VoidCallback refresh) async {
  final pending = asInt(r['qty']) - asInt(r['received']);
  final controller = TextEditingController(text: '$pending');
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Return Item'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity returned (max $pending)')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm Return'))]));
  if (ok != true) return;
  final n = asInt(controller.text);
  if (n <= 0 || n > pending) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid return quantity.'))); return; }
  r['received'] = asInt(r['received']) + n; await store.save(); refresh();
}

Future<bool> confirmDelete(BuildContext context, String title, String message) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))])) ?? false;

Future<void> checkUpdate(BuildContext context) async {
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Checking...')])));
  try {
    final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 8));
    if (!context.mounted) return;
    Navigator.pop(context);
    if (response.statusCode != 200) throw Exception();
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = '${data['version'] ?? version}';
    showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(latest == version ? 'You are up to date' : 'Update available'), content: Text(latest == version ? 'RentFlow $version is the latest version.' : 'Version $latest is available.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')), if (latest != version) FilledButton(onPressed: () => launchUrl(Uri.parse('${data['url'] ?? website}'), mode: LaunchMode.externalApplication), child: const Text('Update'))]));
  } catch (_) { if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check for updates.'))); } }
}

Future<void> customerReport(BuildContext context, Store store, String customer) async {
  final rows = store.rentals.where((r) => '${r['customer']}' == customer).toList();
  await showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(customer), content: SizedBox(width: 360, child: rows.isEmpty ? const Text('No rental history.') : ListView(shrinkWrap: true, children: rows.map((r) => ListTile(title: Text('${r['item']} • Qty ${r['qty']}'), subtitle: Text('${r['date']} • ${r['received']}/${r['qty']} returned'), trailing: Text(money(r['amount'])))).toList())), actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
}
