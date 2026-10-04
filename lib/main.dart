import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const muted = Color(0xFF71807B);
const bg = Color(0xFFF5F9F7);
const mint = Color(0xFFE8F8F3);
const websiteUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';
const currentVersion = '1.0.1';
const currentBuild = 3;

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
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LogoMark(size: 126),
            SizedBox(height: 20),
            Text('RentFlow', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: dark)),
            SizedBox(height: 5),
            Text('By PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary)),
            SizedBox(height: 5),
            Text('Developer by ShanPalia', style: TextStyle(fontSize: 14, color: muted)),
          ]),
        ),
      );
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({required this.size, super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(size * .23), boxShadow: const [BoxShadow(color: Color(0x3300A889), blurRadius: 18, offset: Offset(0, 7))]),
        child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: size * .58),
      );
}

class Store {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    items = _read('rf_items');
    customers = _read('rf_customers');
    rentals = _read('rf_rentals');
  }

  List<Map<String, dynamic>> _read(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save() async {
    await prefs.setString('rf_items', jsonEncode(items));
    await prefs.setString('rf_customers', jsonEncode(customers));
    await prefs.setString('rf_rentals', jsonEncode(rentals));
  }
}

int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String money(dynamic v) {
  final n = asDouble(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}
String today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Store store = Store();
  int tab = 0;
  bool loading = true;
  DateTime? lastBack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (!mounted) return;
    setState(() => loading = false);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) checkForUpdate(silent: true);
    });
  }

  void go(int index) => setState(() => tab = index);

  Future<void> handleBack() async {
    if (tab != 0) {
      setState(() => tab = 0);
      return;
    }
    final now = DateTime.now();
    if (lastBack != null && now.difference(lastBack!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    lastBack = now;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)));
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (!silent) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(color: primary), SizedBox(width: 16), Text('Checking for updates...')])));
    }
    Map<String, dynamic>? info;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(updateUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final decoded = jsonDecode(await response.transform(utf8.decoder).join());
        if (decoded is Map) info = Map<String, dynamic>.from(decoded);
      }
      client.close();
    } catch (_) {}
    if (!mounted) return;
    if (!silent && Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (info == null) {
      if (!silent) _message('Unable to check updates right now.');
      return;
    }
    final latestBuild = asInt(info['latest_version_code'] ?? info['build']);
    final latestVersion = '${info['latest_version'] ?? info['version'] ?? currentVersion}';
    if (latestBuild <= currentBuild) {
      if (!silent) {
        showDialog(context: context, builder: (_) => AlertDialog(title: const Text('You are up to date'), content: Text('RentFlow $currentVersion is the latest version.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      }
      return;
    }
    final notes = '${info['release_notes'] ?? info['releaseNotes'] ?? 'New version available.'}';
    final link = '${info['apk_url'] ?? info['downloadUrl'] ?? websiteUrl}';
    if (!mounted) return;
    showDialog(context: context, builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text('RentFlow $latestVersion is available.\n\n$notes'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
            FilledButton(onPressed: () async {
              final uri = Uri.tryParse(link);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Update Now')),
          ],
        ));
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = <Widget>[
      HomePage(store: store, onRefresh: () => setState(() {}), onReports: () => go(3), onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(onCheck: checkForUpdate))), onUpdate: checkForUpdate),
      ItemsPage(store: store, refresh: () => setState(() {})),
      CustomersPage(store: store),
      ReportsPage(store: store),
    ];
    return PopScope(canPop: false, onPopInvokedWithResult: (didPop, result) { if (!didPop) handleBack(); }, child: Scaffold(body: IndexedStack(index: tab, children: pages), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: go, indicatorColor: mint, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'), NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Items'), NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'), NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Reports')]));
  }
}

class HomePage extends StatelessWidget {
  final Store store;
  final VoidCallback onRefresh;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onUpdate;
  const HomePage({required this.store, required this.onRefresh, required this.onReports, required this.onSettings, required this.onUpdate, super.key});

  @override
  Widget build(BuildContext context) {
    final total = store.items.fold<int>(0, (sum, e) => sum + asInt(e['qty']));
    final available = store.items.fold<int>(0, (sum, e) => sum + asInt(e['available'] ?? e['qty']));
    final issued = total - available;
    final due = store.rentals.fold<int>(0, (sum, e) => sum + (asInt(e['qty']) - asInt(e['received'])));
    final recent = store.rentals.reversed.take(4).toList();
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 0), child: Row(children: [const LogoMark(size: 52), const SizedBox(width: 12), const Expanded(child: Text('RentFlow', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: dark))), IconButton(onPressed: onUpdate, icon: const Icon(Icons.notifications_none_rounded)), IconButton(onPressed: onSettings, icon: const Icon(Icons.settings_rounded))]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE5FAF4), Color(0xFFD7F3EA)]), borderRadius: BorderRadius.circular(24)), child: Row(children: const [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good Morning,', style: TextStyle(color: muted, fontSize: 15)), SizedBox(height: 3), Text('Shop Owner', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: dark)), SizedBox(height: 4), Text('Manage your rental business easily', style: TextStyle(color: dark))])), Icon(Icons.storefront_rounded, size: 68, color: primary)]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Row(children: [Metric('Total Items', '$total', Icons.inventory_2_rounded), const SizedBox(width: 8), Metric('Available', '$available', Icons.check_circle_rounded), const SizedBox(width: 8), Metric('Issued', '$issued', Icons.north_east_rounded), const SizedBox(width: 8), Metric('Items Due', '$due', Icons.schedule_rounded)]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () => rentalForm(context, store, onRefresh), icon: const Icon(Icons.add_circle_outline_rounded, size: 28), label: const Text('New Rental', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Row(children: [ActionTile('Add Item', Icons.inventory_2_rounded, () => itemForm(context, store, onRefresh)), ActionTile('New Customer', Icons.person_add_alt_1_rounded, () => customerForm(context, store, onRefresh)), ActionTile('Invoice', Icons.receipt_long_rounded, () => invoiceDialog(context, store)), ActionTile('Receive Item', Icons.undo_rounded, () => receiveForm(context, store, onRefresh))]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Row(children: [const Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), TextButton(onPressed: onReports, child: const Text('View All'))]))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) { final r = recent[index]; return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.swap_horiz_rounded, color: primary)), title: Text('${r['customer']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${r['item']} • Qty ${r['qty']} • ${r['date']}'), trailing: Text('₹${money(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.w900))); }, childCount: recent.length))),
    ]));
  }
}

class Metric extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const Metric(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(height: 106, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: primary, size: 23), const Spacer(), Text(title, style: const TextStyle(color: muted, fontSize: 11)), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: dark))])));
}

class ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ActionTile(this.title, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9E5))), child: Column(children: [Icon(icon, color: primary, size: 27), const SizedBox(height: 7), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))]))));
}

class AppPage extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  final List<Widget> children;
  const AppPage({required this.title, required this.subtitle, required this.children, this.action, super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(20, 16, 14, 14), child: Row(children: [const LogoMark(size: 48), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: dark)), Text(subtitle, style: const TextStyle(color: muted))])), if (action != null) action!])), Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: children)]));
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty({required this.icon, required this.text, super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 80), child: Column(children: [Icon(icon, size: 70, color: primary), const SizedBox(height: 14), Text(text, style: const TextStyle(color: muted, fontSize: 16))]));
}

class ItemsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[if (store.items.isEmpty) const Empty(icon: Icons.inventory_2_outlined, text: 'No items added yet')];
    for (final item in store.items) {
      children.add(Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)), title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Qty ${item['qty']} • Available ${item['available']} • Rent ₹${money(item['rate'])}'), trailing: IconButton(onPressed: () async { store.items.remove(item); await store.save(); refresh(); }, icon: const Icon(Icons.delete_outline))));
    }
    return AppPage(title: 'Items', subtitle: 'Manage rental items', action: IconButton(onPressed: () => itemForm(context, store, refresh), icon: const Icon(Icons.add_circle_rounded, color: primary)), children: children);
  }
}

class CustomersPage extends StatelessWidget {
  final Store store;
  const CustomersPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[if (store.customers.isEmpty) const Empty(icon: Icons.people_outline, text: 'No customers added yet')];
    for (final customer in store.customers) {
      children.add(Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person, color: primary)), title: Text('${customer['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${customer['phone']}'), onTap: () => customerReport(context, store, '${customer['name']}'))));
    }
    return AppPage(title: 'Customers', subtitle: 'Tap a customer for their report', action: IconButton(onPressed: () => customerForm(context, store, () {}), icon: const Icon(Icons.person_add_rounded, color: primary)), children: children);
  }
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (store.rentals.isEmpty) children.add(const Empty(icon: Icons.bar_chart_rounded, text: 'No rental report yet'));
    for (final r in store.rentals.reversed) {
      final due = asInt(r['qty']) - asInt(r['received']);
      children.add(Card(child: ListTile(title: Text('${r['customer']} • ${r['item']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Date ${r['date']}  •  Issued ${r['qty']}  •  Received ${r['received']}  •  Days ${r['days']}  •  Rate ₹${money(r['rate'])}'), trailing: Text('₹${money(r['amount'])}\n${due > 0 ? 'Due $due' : 'Returned'}', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w900, color: due > 0 ? Colors.red : primary))));
    }
    return AppPage(title: 'Reports', subtitle: 'Date, issued, received, days, rate and amount', children: children);
  }
}

Future<void> itemForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final qty = TextEditingController();
  final rate = TextEditingController();
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Add Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), const SizedBox(height: 10), TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent price per day'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; final q = asInt(qty.text); store.items.add({'name': name.text.trim(), 'qty': q, 'available': q, 'rate': asDouble(rate.text)}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Save'))]));
}

Future<void> customerForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Save'))]));
}

Future<void> rentalForm(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add item and customer first'), content: const Text('Create at least one item and one customer before issuing a rental.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    return;
  }
  String customer = '${store.customers.first['name']}';
  String item = '${store.items.first['name']}';
  final qty = TextEditingController(text: '1');
  final days = TextEditingController(text: '1');
  final rate = TextEditingController(text: '${store.items.first['rate']}');
  await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: const Text('New Rental'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: customer, decoration: const InputDecoration(labelText: 'Customer'), items: store.customers.map((c) => DropdownMenuItem(value: '${c['name']}', child: Text('${c['name']}'))).toList(), onChanged: (v) { if (v != null) setLocal(() => customer = v); }), const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: item, decoration: const InputDecoration(labelText: 'Item'), items: store.items.map((i) => DropdownMenuItem(value: '${i['name']}', child: Text('${i['name']}'))).toList(), onChanged: (v) { if (v != null) { final found = store.items.firstWhere((e) => '${e['name']}' == v); setLocal(() { item = v; rate.text = '${found['rate']}'; }); } }), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity issued')), const SizedBox(height: 10), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days')), const SizedBox(height: 10), TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent rate (manual edit allowed)'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { final selected = store.items.firstWhere((e) => '${e['name']}' == item); final q = asInt(qty.text); final d = asInt(days.text); final r = asDouble(rate.text); if (q <= 0 || d <= 0 || q > asInt(selected['available'])) return; selected['available'] = asInt(selected['available']) - q; store.rentals.add({'customer': customer, 'item': item, 'qty': q, 'received': 0, 'days': d, 'rate': r, 'amount': q * d * r, 'date': today()}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Issue Rental'))]));
}

Future<void> receiveForm(BuildContext context, Store store, VoidCallback refresh) async {
  final active = store.rentals.where((r) => asInt(r['qty']) > asInt(r['received'])).toList();
  if (active.isEmpty) { showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Nothing to receive'), content: const Text('There are no issued items waiting for return.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])); return; }
  Map<String, dynamic> selected = active.first;
  final qty = TextEditingController(text: '1');
  await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: const Text('Receive Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<Map<String, dynamic>>(initialValue: selected, decoration: const InputDecoration(labelText: 'Rental'), items: active.map((r) => DropdownMenuItem(value: r, child: Text('${r['customer']} • ${r['item']}'))).toList(), onChanged: (v) { if (v != null) setLocal(() => selected = v); }), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity received'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { final n = asInt(qty.text); final remaining = asInt(selected['qty']) - asInt(selected['received']); final received = n > remaining ? remaining : n; selected['received'] = asInt(selected['received']) + received; final item = store.items.firstWhere((i) => '${i['name']}' == '${selected['item']}', orElse: () => {}); if (item.isNotEmpty) item['available'] = asInt(item['available']) + received; await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Receive'))]));
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  if (store.rentals.isEmpty) { showDialog(context: context, builder: (_) => AlertDialog(title: const Text('No invoice data'), content: const Text('Create a rental first.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))])); return; }
  final r = store.rentals.last;
  await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Invoice'), content: Text('Customer: ${r['customer']}\nItem: ${r['item']}\nDate: ${r['date']}\nQuantity: ${r['qty']}\nDays: ${r['days']}\nRate: ₹${money(r['rate'])}\nAmount: ₹${money(r['amount'])}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')), FilledButton.icon(onPressed: () => createPdf(r), icon: const Icon(Icons.picture_as_pdf), label: const Text('Create PDF'))]));
}

Future<void> createPdf(Map<String, dynamic> r) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('RentFlow', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 12), pw.Text('By PaliaAPK HUB'), pw.Divider(), pw.Text('Customer: ${r['customer']}'), pw.Text('Item: ${r['item']}'), pw.Text('Date: ${r['date']}'), pw.Text('Issued: ${r['qty']}'), pw.Text('Received: ${r['received']}'), pw.Text('Days: ${r['days']}'), pw.Text('Rate: ₹${money(r['rate'])}'), pw.SizedBox(height: 12), pw.Text('Amount: ₹${money(r['amount'])}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))])));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

Future<void> customerReport(BuildContext context, Store store, String customer) async {
  final rows = store.rentals.where((r) => '${r['customer']}' == customer).toList();
  await showDialog(context: context, builder: (_) => AlertDialog(title: Text('$customer Report'), content: SizedBox(width: double.maxFinite, child: rows.isEmpty ? const Text('No rentals found.') : ListView(shrinkWrap: true, children: rows.map((r) => ListTile(title: Text('${r['item']}'), subtitle: Text('Date ${r['date']} • Issued ${r['qty']} • Received ${r['received']} • Days ${r['days']} • Rate ₹${money(r['rate'])}'), trailing: Text('₹${money(r['amount'])}'))).toList())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
}

class SettingsPage extends StatelessWidget {
  final Future<void> Function({bool silent}) onCheck;
  const SettingsPage({required this.onCheck, super.key});
  Future<void> openWebsite() async { final uri = Uri.parse(websiteUrl); await launchUrl(uri, mode: LaunchMode.externalApplication); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(20), children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(24)), child: Row(children: const [LogoMark(size: 82), SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dark)), SizedBox(height: 4), Text('By PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary)), SizedBox(height: 3), Text('Developer by ShanPalia', style: TextStyle(color: muted))]))])), const SizedBox(height: 18), Card(child: Column(children: [ListTile(leading: const Icon(Icons.system_update_alt_rounded, color: primary), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check PaliaAPK HUB for the latest RentFlow APK'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => onCheck(silent: false)), const Divider(height: 1), ListTile(leading: const Icon(Icons.language_rounded, color: primary), title: const Text('PaliaAPK HUB Website', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Open website'), trailing: const Icon(Icons.open_in_new_rounded), onTap: openWebsite)])), const SizedBox(height: 30), Center(child: Text('RentFlow $currentVersion', style: const TextStyle(color: muted, fontSize: 16))), const SizedBox(height: 5), const Center(child: Text('Rental management made simple', style: TextStyle(color: muted))) ]));
}
