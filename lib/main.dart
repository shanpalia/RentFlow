import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoMark(size: 118),
            SizedBox(height: 18),
            Text('RentFlow', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: dark)),
            SizedBox(height: 4),
            Text('By PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary)),
            SizedBox(height: 4),
            Text('Developer by ShanPalia', style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({required this.size, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(size * .24),
        boxShadow: const [BoxShadow(color: Color(0x3300A889), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: size * .58),
    );
  }
}

class Store {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    items = read('rf_items');
    customers = read('rf_customers');
    rentals = read('rf_rentals');
  }

  List<Map<String, dynamic>> read(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return [];
      return value.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
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

int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String money(dynamic value) => asDouble(value).toStringAsFixed(2);
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
  final store = Store();
  int tab = 0;
  bool loading = true;
  DateTime? lastBack;

  @override
  void initState() {
    super.initState();
    loadStore();
  }

  Future<void> loadStore() async {
    await store.load();
    if (!mounted) return;
    setState(() => loading = false);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) checkForUpdate(silent: true);
    });
  }

  void refresh() => setState(() {});

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit')),
      );
    }
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (!silent) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(color: primary),
            SizedBox(width: 16),
            Text('Checking for updates...'),
          ]),
        ),
      );
    }

    Map<String, dynamic>? info;
    try {
      final response = await http.get(Uri.parse(updateUrl));
      if (response.statusCode == 200) {
        final value = jsonDecode(response.body);
        if (value is Map) info = Map<String, dynamic>.from(value);
      }
    } catch (_) {}

    if (!mounted) return;
    if (!silent && Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (info == null) {
      if (!silent) showMessage('Unable to check updates right now.');
      return;
    }

    final latestBuild = asInt(info['latest_version_code'] ?? info['build'] ?? 0);
    final latestVersion = '${info['latest_version'] ?? info['version'] ?? currentVersion}';

    if (latestBuild <= currentBuild) {
      if (!silent) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('You are up to date'),
            content: Text('RentFlow $currentVersion is the latest version.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    final notes = '${info['release_notes'] ?? info['releaseNotes'] ?? 'New version available.'}';
    final link = '${info['apk_url'] ?? info['downloadUrl'] ?? websiteUrl}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: Text('RentFlow $latestVersion is available.\n\n$notes'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
          FilledButton(
            onPressed: () async {
              final uri = Uri.tryParse(link);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = <Widget>[
      HomePage(store: store, refresh: refresh, goReports: () => setState(() => tab = 3)),
      ItemsPage(store: store, refresh: refresh),
      CustomersPage(store: store, refresh: refresh),
      ReportsPage(store: store),
      SettingsPage(onCheck: checkForUpdate),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          indicatorColor: mint,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const PageHeader({required this.title, required this.subtitle, this.action, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      child: Row(children: [
        const LogoMark(size: 48),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: dark)),
          Text(subtitle, style: const TextStyle(color: muted)),
        ])),
        if (action != null) action!,
      ]),
    );
  }
}

class HomePage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  final VoidCallback goReports;
  const HomePage({required this.store, required this.refresh, required this.goReports, super.key});
  @override
  Widget build(BuildContext context) {
    final total = store.items.fold<int>(0, (s, e) => s + asInt(e['qty']));
    final available = store.items.fold<int>(0, (s, e) => s + asInt(e['available'] ?? e['qty']));
    final issued = total - available;
    final due = store.rentals.fold<int>(0, (s, e) => s + asInt(e['qty']) - asInt(e['received']));
    final recent = store.rentals.reversed.take(4).toList();

    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: PageHeader(title: 'RentFlow', subtitle: 'Rental management made simple')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE8F8F3), Color(0xFFD7F3EA)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Good Morning', style: TextStyle(color: muted)),
                  SizedBox(height: 4),
                  Text('Shop Owner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dark)),
                  SizedBox(height: 5),
                  Text('Manage your rental business easily', style: TextStyle(color: dark)),
                ])),
                Icon(Icons.storefront_rounded, color: primary, size: 62),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Metric('Items', '$total', Icons.inventory_2_rounded),
              Metric('Available', '$available', Icons.check_circle_rounded),
              Metric('Issued', '$issued', Icons.north_east_rounded),
              Metric('Due', '$due', Icons.schedule_rounded),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => rentalForm(context, store, refresh),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('New Rental', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              QuickAction('Add Item', Icons.inventory_2_rounded, () => itemForm(context, store, refresh)),
              QuickAction('Customer', Icons.person_add_alt_1_rounded, () => customerForm(context, store, refresh)),
              QuickAction('Invoice', Icons.receipt_long_rounded, () => invoiceDialog(context, store)),
              QuickAction('Receive', Icons.undo_rounded, () => receiveForm(context, store, refresh)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              const Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              TextButton(onPressed: goReports, child: const Text('View All')),
            ]),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final r = recent[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.swap_horiz_rounded, color: primary)),
                    title: Text('${r['customer']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${r['item']} • Qty ${r['qty']} • ${r['date']}'),
                    trailing: Text('₹${money(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              );
            },
            childCount: recent.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ]),
    );
  }
}

class Metric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const Metric(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2ECE8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: primary, size: 22),
          const Spacer(),
          Text(title, style: const TextStyle(color: muted, fontSize: 10)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)),
        ]),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const QuickAction(this.title, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9E5))),
          child: Column(children: [
            Icon(icon, color: primary, size: 26),
            const SizedBox(height: 7),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class ItemsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      PageHeader(title: 'Items', subtitle: 'Rental items and daily rates', action: IconButton(onPressed: () => itemForm(context, store, refresh), icon: const Icon(Icons.add_circle_rounded, color: primary))),
      Expanded(
        child: store.items.isEmpty
            ? const EmptyState(icon: Icons.inventory_2_outlined, text: 'No items added yet')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                itemCount: store.items.length,
                itemBuilder: (context, index) {
                  final item = store.items[index];
                  return Card(child: ListTile(
                    leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)),
                    title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('Qty ${item['qty']} • Available ${item['available']} • ₹${money(item['rate'])}/day'),
                    trailing: IconButton(onPressed: () async { store.items.removeAt(index); await store.save(); refresh(); }, icon: const Icon(Icons.delete_outline)),
                  ));
                },
              ),
      ),
    ]));
  }
}

class CustomersPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const CustomersPage({required this.store, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      PageHeader(title: 'Customers', subtitle: 'Your rental customers', action: IconButton(onPressed: () => customerForm(context, store, refresh), icon: const Icon(Icons.person_add_rounded, color: primary))),
      Expanded(
        child: store.customers.isEmpty
            ? const EmptyState(icon: Icons.people_outline, text: 'No customers added yet')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                itemCount: store.customers.length,
                itemBuilder: (context, index) {
                  final customer = store.customers[index];
                  return Card(child: ListTile(
                    leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person_rounded, color: primary)),
                    title: Text('${customer['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${customer['phone']}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => customerReport(context, store, '${customer['name']}'),
                  ));
                },
              ),
      ),
    ]));
  }
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      const PageHeader(title: 'Reports', subtitle: 'Rental history and amounts'),
      Expanded(
        child: store.rentals.isEmpty
            ? const EmptyState(icon: Icons.bar_chart_rounded, text: 'No rental report yet')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                itemCount: store.rentals.length,
                itemBuilder: (context, index) {
                  final r = store.rentals[store.rentals.length - 1 - index];
                  final due = asInt(r['qty']) - asInt(r['received']);
                  return Card(child: ListTile(
                    title: Text('${r['customer']} • ${r['item']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('Date ${r['date']} • Issued ${r['qty']} • Received ${r['received']} • Days ${r['days']} • Rate ₹${money(r['rate'])}'),
                    trailing: Text('₹${money(r['amount'])}\n${due > 0 ? 'Due $due' : 'Returned'}', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w900, color: due > 0 ? Colors.red : primary)),
                  ));
                },
              ),
      ),
    ]));
  }
}

class SettingsPage extends StatelessWidget {
  final Future<void> Function({bool silent}) onCheck;
  const SettingsPage({required this.onCheck, super.key});
  Future<void> openWebsite() => launchUrl(Uri.parse(websiteUrl), mode: LaunchMode.externalApplication);
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      const PageHeader(title: 'Settings', subtitle: 'App, updates and branding'),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        const LogoMark(size: 72),
        const SizedBox(width: 16),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RentFlow', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: dark)),
          SizedBox(height: 4),
          Text('By PaliaAPK HUB', style: TextStyle(fontWeight: FontWeight.w800, color: primary)),
          SizedBox(height: 3),
          Text('Developer by ShanPalia', style: TextStyle(color: muted)),
        ])),
      ]))),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.system_update_alt_rounded, color: primary), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check the latest RentFlow version'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => onCheck(silent: false)),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.language_rounded, color: primary), title: const Text('PaliaAPK HUB Website', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Open website'), trailing: const Icon(Icons.open_in_new_rounded), onTap: openWebsite),
      ])),
      const SizedBox(height: 28),
      Center(child: Text('RentFlow $currentVersion', style: const TextStyle(color: muted))),
      const SizedBox(height: 4),
      const Center(child: Text('Rental management made simple', style: TextStyle(color: muted))),
    ]));
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({required this.icon, required this.text, super.key});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: primary), const SizedBox(height: 12), Text(text, style: const TextStyle(color: muted, fontSize: 16))]));
}

Future<void> itemForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(
    title: const Text('Add Item'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
      TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
      TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent per day')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
      FilledButton(onPressed: () async {
        if (name.text.trim().isEmpty) return;
        final q = asInt(qty.text);
        if (q <= 0) return;
        store.items.add({'name': name.text.trim(), 'qty': q, 'available': q, 'rate': asDouble(rate.text)});
        await store.save();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        refresh();
      }, child: const Text('Save')),
    ],
  ));
}

Future<void> customerForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(
    title: const Text('New Customer'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
      FilledButton(onPressed: () async {
        if (name.text.trim().isEmpty) return;
        store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()});
        await store.save();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        refresh();
      }, child: const Text('Save')),
    ],
  ));
}

Future<void> rentalForm(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) {
    await showDialog(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add item and customer first'),
      content: const Text('Create at least one item and one customer before issuing a rental.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
    ));
    return;
  }

  String customer = '${store.customers.first['name']}';
  String item = '${store.items.first['name']}';
  final qty = TextEditingController(text: '1');
  final days = TextEditingController(text: '1');
  final rate = TextEditingController(text: '${store.items.first['rate']}');

  await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
    title: const Text('New Rental'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: customer,
        decoration: const InputDecoration(labelText: 'Customer'),
        items: store.customers.map((c) => DropdownMenuItem(value: '${c['name']}', child: Text('${c['name']}'))).toList(),
        onChanged: (v) { if (v != null) setLocal(() => customer = v); },
      ),
      DropdownButtonFormField<String>(
        initialValue: item,
        decoration: const InputDecoration(labelText: 'Item'),
        items: store.items.map((i) => DropdownMenuItem(value: '${i['name']}', child: Text('${i['name']}'))).toList(),
        onChanged: (v) {
          if (v == null) return;
          final found = store.items.firstWhere((e) => '${e['name']}' == v);
          setLocal(() { item = v; rate.text = '${found['rate']}'; });
        },
      ),
      TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity issued')),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days')),
      TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate per day')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
      FilledButton(onPressed: () async {
        final q = asInt(qty.text);
        final d = asInt(days.text);
        final r = asDouble(rate.text);
        final found = store.items.firstWhere((e) => '${e['name']}' == item);
        final available = asInt(found['available']);
        if (q <= 0 || q > available || d <= 0) return;
        found['available'] = available - q;
        store.rentals.add({'customer': customer, 'item': item, 'date': today(), 'qty': q, 'received': 0, 'days': d, 'rate': r, 'amount': q * d * r});
        await store.save();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        refresh();
      }, child: const Text('Issue Rental')),
    ],
  )));
}

Future<void> receiveForm(BuildContext context, Store store, VoidCallback refresh) async {
  final active = store.rentals.where((r) => asInt(r['qty']) > asInt(r['received'])).toList();
  if (active.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No issued items to receive')));
    return;
  }
  Map<String, dynamic> selected = active.first;
  final received = TextEditingController(text: '${asInt(selected['qty']) - asInt(selected['received'])}');

  await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
    title: const Text('Receive Item'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: '${selected['customer']}|${selected['item']}',
        items: active.map((r) => DropdownMenuItem(value: '${r['customer']}|${r['item']}', child: Text('${r['customer']} • ${r['item']}'))).toList(),
        onChanged: (v) {
          if (v == null) return;
          final found = active.firstWhere((r) => '${r['customer']}|${r['item']}' == v);
          setLocal(() { selected = found; received.text = '${asInt(found['qty']) - asInt(found['received'])}'; });
        },
      ),
      TextField(controller: received, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity received')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
      FilledButton(onPressed: () async {
        final n = asInt(received.text);
        final remaining = asInt(selected['qty']) - asInt(selected['received']);
        if (n <= 0 || n > remaining) return;
        selected['received'] = asInt(selected['received']) + n;
        final item = store.items.firstWhere((e) => '${e['name']}' == '${selected['item']}');
        item['available'] = asInt(item['available']) + n;
        await store.save();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        refresh();
      }, child: const Text('Receive')),
    ],
  )));
}

Future<void> customerReport(BuildContext context, Store store, String customer) async {
  final rows = store.rentals.where((r) => '${r['customer']}' == customer).toList();
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(
    title: Text('$customer Report'),
    content: SizedBox(
      width: double.maxFinite,
      child: rows.isEmpty
          ? const Text('No rentals found.')
          : ListView(shrinkWrap: true, children: rows.map((r) => ListTile(
              title: Text('${r['item']}'),
              subtitle: Text('Date ${r['date']} • Issued ${r['qty']} • Received ${r['received']} • Days ${r['days']}'),
              trailing: Text('₹${money(r['amount'])}'),
            )).toList()),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
  ));
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  if (store.rentals.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No rental available for invoice')));
    return;
  }
  final r = store.rentals.last;
  await showDialog(context: context, builder: (dialogContext) => AlertDialog(
    title: const Text('Invoice'),
    content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('RentFlow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const Text('By PaliaAPK HUB'),
      const Divider(),
      Text('Customer: ${r['customer']}'),
      Text('Item: ${r['item']}'),
      Text('Date: ${r['date']}'),
      Text('Issued: ${r['qty']}'),
      Text('Received: ${r['received']}'),
      Text('Days: ${r['days']}'),
      Text('Rate: ₹${money(r['rate'])}'),
      const SizedBox(height: 10),
      Text('Amount: ₹${money(r['amount'])}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
  ));
}
