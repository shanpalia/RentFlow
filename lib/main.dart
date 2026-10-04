import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const primaryDark = Color(0xFF007C69);
const ink = Color(0xFF10241F);
const muted = Color(0xFF687873);
const pageBg = Color(0xFFF5FAF8);
const mint = Color(0xFFE5F8F2);
const red = Color(0xFFE5484D);
const websiteUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';
const appVersion = '1.0.1';
const appBuild = 3;

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
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        fontFamily: 'sans',
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
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
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
            RentFlowLogo(size: 155),
            SizedBox(height: 18),
            Text('RentFlow', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: ink)),
            SizedBox(height: 5),
            Text('By PaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
            SizedBox(height: 5),
            Text('Developer by ShanPalia', style: TextStyle(fontSize: 15, color: muted)),
          ],
        ),
      ),
    );
  }
}

class RentFlowLogo extends StatelessWidget {
  final double size;
  const RentFlowLogo({required this.size, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: primary, width: size * .065),
        boxShadow: const [BoxShadow(color: Color(0x3300A889), blurRadius: 22, offset: Offset(0, 7))],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final roof = Paint()
      ..color = primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrow = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roofPath = Path()
      ..moveTo(s * .21, s * .45)
      ..lineTo(s * .50, s * .20)
      ..lineTo(s * .79, s * .45);
    canvas.drawPath(roofPath, roof);
    canvas.drawLine(Offset(s * .31, s * .42), Offset(s * .31, s * .68), roof);
    canvas.drawLine(Offset(s * .69, s * .42), Offset(s * .69, s * .68), roof);

    final forward = Path()
      ..moveTo(s * .20, s * .73)
      ..lineTo(s * .59, s * .73)
      ..moveTo(s * .50, s * .64)
      ..lineTo(s * .59, s * .73)
      ..lineTo(s * .50, s * .82);
    canvas.drawPath(forward, arrow);

    final back = Path()
      ..moveTo(s * .80, s * .55)
      ..lineTo(s * .41, s * .55)
      ..moveTo(s * .50, s * .46)
      ..lineTo(s * .41, s * .55)
      ..lineTo(s * .50, s * .64);
    canvas.drawPath(back, arrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

int number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double amount(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String rupees(dynamic value) => '₹${amount(value).toStringAsFixed(0)}';
String today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Store store = Store();
  int selected = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (!mounted) return;
    setState(() => loading = false);
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));

    final pages = [
      HomePage(store: store, refresh: refresh),
      ItemsPage(store: store, refresh: refresh),
      CustomersPage(store: store, refresh: refresh),
      ReportsPage(store: store),
      SettingsPage(onCheckUpdates: () => checkForUpdates(context)),
    ];

    return Scaffold(
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        backgroundColor: Colors.white,
        indicatorColor: mint,
        height: 76,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: primary), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded, color: primary), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded, color: primary), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded, color: primary), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded, color: primary), label: 'Settings'),
        ],
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
    final total = store.items.fold<int>(0, (sum, item) => sum + number(item['qty']));
    final available = store.items.fold<int>(0, (sum, item) => sum + number(item['available'] ?? item['qty']));
    final issued = (total - available).clamp(0, 999999);
    final due = store.rentals.fold<int>(0, (sum, rental) => sum + (number(rental['qty']) - number(rental['received'])).clamp(0, 999999));
    final recent = store.rentals.reversed.take(4).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HomeHeader()),
          SliverToBoxAdapter(child: _HeroBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(children: [
                StatCard(label: 'Total Items', value: '$total', icon: Icons.inventory_2_rounded),
                StatCard(label: 'Available', value: '$available', icon: Icons.check_circle_rounded),
                StatCard(label: 'Issued', value: '$issued', icon: Icons.north_east_rounded),
                StatCard(label: 'Items Due', value: '$due', icon: Icons.schedule_rounded),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: FilledButton.icon(
                onPressed: () => rentalForm(context, store, refresh),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.add_circle_rounded, size: 30),
                label: const Text('New Rental', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(children: [
                QuickAction(title: 'Add Item', icon: Icons.inventory_2_rounded, onTap: () => itemForm(context, store, refresh)),
                QuickAction(title: 'New Customer', icon: Icons.person_add_alt_1_rounded, onTap: () => customerForm(context, store, refresh)),
                QuickAction(title: 'Invoice', icon: Icons.receipt_long_rounded, onTap: () => invoiceDialog(context, store)),
                QuickAction(title: 'Receive', icon: Icons.undo_rounded, onTap: () => receiveForm(context, store, refresh)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
              child: Row(children: const [
                Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink))),
              ]),
            ),
          ),
          if (recent.isEmpty)
            const SliverToBoxAdapter(child: EmptyCard(message: 'No rentals yet. Create your first rental.'))
          else
            SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (context, index) => RentalTile(data: recent[index]),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: DueCard(store: store),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(children: [
        const RentFlowWordmark(),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, size: 30)),
        Container(
          decoration: const BoxDecoration(color: Color(0xFFEAF0F0), shape: BoxShape.circle),
          child: IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
        ),
      ]),
    );
  }
}

class RentFlowWordmark extends StatelessWidget {
  const RentFlowWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primary, width: 3)),
        child: const Icon(Icons.swap_horiz_rounded, color: primaryDark, size: 31),
      ),
      const SizedBox(width: 8),
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'Rent', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
        TextSpan(text: 'Flow', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: primary)),
      ])),
    ]);
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFDFF8F1), Color(0xFFF3FFFB)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Good Morning,', style: TextStyle(fontSize: 17, color: muted)),
          SizedBox(height: 3),
          Text('Shop Owner', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)),
          SizedBox(height: 4),
          Text('Manage your rental business easily', style: TextStyle(fontSize: 14, color: ink)),
        ])),
        Container(
          width: 100,
          height: 76,
          decoration: BoxDecoration(color: Colors.white.withOpacity(.65), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.storefront_rounded, color: primary, size: 52),
        ),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const StatCard({required this.label, required this.value, required this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.all(10),
        height: 112,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3ECE9))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: primary, size: 25),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: muted)),
        ]),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const QuickAction({required this.title, required this.icon, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3ECE9))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: primary, size: 30),
              const SizedBox(height: 7),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

class RentalTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const RentalTile({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    final returned = number(data['received']) >= number(data['qty']);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5ECEA))),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_rounded, color: primary, size: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['customer'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
          Text('${data['item'] ?? 'Item'} • Qty: ${number(data['qty'])}', style: const TextStyle(color: muted, fontSize: 13)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(rupees(data['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 4),
          Text(returned ? 'Returned' : 'Issued', style: TextStyle(color: returned ? muted : primary, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class DueCard extends StatelessWidget {
  final Store store;
  const DueCard({required this.store, super.key});

  @override
  Widget build(BuildContext context) {
    final active = store.rentals.where((r) => number(r['received']) < number(r['qty'])).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD5D5))),
      child: Row(children: [
        const CircleAvatar(backgroundColor: red, child: Icon(Icons.schedule_rounded, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today's Due", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink)),
          Text('${active.length} active rental(s)', style: const TextStyle(color: muted)),
        ])),
        Text('${active.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: red)),
      ]),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String message;
  const EmptyCard({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Center(child: Text(message, style: const TextStyle(color: muted))));
  }
}

class ItemsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      const _PageHeader(title: 'Items', subtitle: 'Manage your rental inventory'),
      Expanded(child: store.items.isEmpty ? const EmptyCard(message: 'No items added yet.') : ListView.builder(itemCount: store.items.length, itemBuilder: (_, i) {
        final item = store.items[i];
        return ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)), title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Qty ${number(item['qty'])} • Available ${number(item['available'] ?? item['qty'])}'), trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => itemForm(context, store, refresh)));
      })),
      Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: () => itemForm(context, store, refresh), icon: const Icon(Icons.add), label: const Text('Add Item'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: primary))),
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
      const _PageHeader(title: 'Customers', subtitle: 'Customer records and contacts'),
      Expanded(child: store.customers.isEmpty ? const EmptyCard(message: 'No customers added yet.') : ListView.builder(itemCount: store.customers.length, itemBuilder: (_, i) {
        final c = store.customers[i];
        return ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person_rounded, color: primary)), title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${c['phone'] ?? 'No phone'}'));
      })),
      Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: () => customerForm(context, store, refresh), icon: const Icon(Icons.person_add_alt_1), label: const Text('New Customer'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: primary))),
    ]));
  }
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});

  @override
  Widget build(BuildContext context) {
    final revenue = store.rentals.fold<double>(0, (sum, rental) => sum + amount(rental['amount']));
    return SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      const _PageHeader(title: 'Reports', subtitle: 'Rental business overview'),
      Row(children: [
        Expanded(child: _ReportCard(title: 'Rentals', value: '${store.rentals.length}', icon: Icons.swap_horiz_rounded)),
        Expanded(child: _ReportCard(title: 'Revenue', value: rupees(revenue), icon: Icons.payments_rounded)),
      ]),
      Container(margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Rental History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 10),
        if (store.rentals.isEmpty) const Text('No rental records yet.', style: TextStyle(color: muted)) else ...store.rentals.reversed.map((r) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${r['customer']} • ${r['item']}'), trailing: Text(rupees(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900)))),
      ])),
    ]));
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _ReportCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(18, 4, 5, 4), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: primary, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: muted)), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink))]))]));
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onCheckUpdates;
  const SettingsPage({required this.onCheckUpdates, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 30), children: [
      const Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ink)),
      const Text('App, updates and branding', style: TextStyle(fontSize: 17, color: muted)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE0EBE7))), child: Row(children: [
        const RentFlowLogo(size: 82),
        const SizedBox(width: 16),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RentFlow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
          SizedBox(height: 4),
          Text('By PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primary)),
          SizedBox(height: 3),
          Text('Developer by ShanPalia', style: TextStyle(fontSize: 14, color: muted)),
        ])),
      ])),
      const SizedBox(height: 16),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE0EBE7))), child: Column(children: [
        ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.system_update_alt_rounded, color: primary)), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Check the latest RentFlow version'), trailing: const Icon(Icons.chevron_right_rounded), onTap: onCheckUpdates),
        const Divider(height: 1),
        ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.language_rounded, color: primary)), title: const Text('PaliaAPK HUB Website', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Open website'), trailing: const Icon(Icons.open_in_new_rounded), onTap: () async { final uri = Uri.parse(websiteUrl); await launchUrl(uri, mode: LaunchMode.externalApplication); }),
      ])),
      const SizedBox(height: 28),
      Center(child: Column(children: const [Text('RentFlow 1.0.1', style: TextStyle(fontSize: 17, color: muted)), SizedBox(height: 7), Text('Rental management made simple', style: TextStyle(color: muted))])),
    ]));
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 12), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink)), Text(subtitle, style: const TextStyle(color: muted))]))]));
}

Future<void> itemForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Add Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
  if (ok != true || name.text.trim().isEmpty) return;
  final q = number(qty.text);
  store.items.add({'name': name.text.trim(), 'qty': q, 'available': q});
  await store.save();
  refresh();
}

Future<void> customerForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
  if (ok != true || name.text.trim().isEmpty) return;
  store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()});
  await store.save();
  refresh();
}

Future<void> rentalForm(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.items.isEmpty || store.customers.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item and customer first.')));
    return;
  }
  final amountController = TextEditingController(text: '0');
  final qtyController = TextEditingController(text: '1');
  String item = '${store.items.first['name']}';
  String customer = '${store.customers.first['name']}';
  final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('New Rental'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: item, items: store.items.map((e) => DropdownMenuItem(value: '${e['name']}', child: Text('${e['name']}'))).toList(), onChanged: (v) => setDialog(() => item = v ?? item), decoration: const InputDecoration(labelText: 'Item')), DropdownButtonFormField<String>(initialValue: customer, items: store.customers.map((e) => DropdownMenuItem(value: '${e['name']}', child: Text('${e['name']}'))).toList(), onChanged: (v) => setDialog(() => customer = v ?? customer), decoration: const InputDecoration(labelText: 'Customer')), TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))])));
  if (ok != true) return;
  final q = number(qtyController.text);
  final found = store.items.firstWhere((e) => '${e['name']}' == item);
  found['available'] = (number(found['available'] ?? found['qty']) - q).clamp(0, 999999);
  store.rentals.add({'item': item, 'customer': customer, 'qty': q, 'received': 0, 'amount': amount(amountController.text), 'date': today()});
  await store.save();
  refresh();
}

Future<void> receiveForm(BuildContext context, Store store, VoidCallback refresh) async {
  final active = store.rentals.where((r) => number(r['received']) < number(r['qty'])).toList();
  if (active.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active rental found.')));
    return;
  }
  final rental = active.last;
  final found = store.items.where((e) => '${e['name']}' == '${rental['item']}').toList();
  rental['received'] = number(rental['qty']);
  if (found.isNotEmpty) found.first['available'] = number(found.first['available']) + number(rental['qty']);
  await store.save();
  refresh();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental marked as returned.')));
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  if (store.rentals.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No rental available for invoice.')));
    return;
  }
  final r = store.rentals.last;
  await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Rental Invoice'), content: Text('Customer: ${r['customer']}\nItem: ${r['item']}\nQuantity: ${r['qty']}\nDate: ${r['date']}\nAmount: ${rupees(r['amount'])}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
}

Future<void> checkForUpdates(BuildContext context) async {
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(color: primary), SizedBox(width: 16), Text('Checking for updates...')])));
  Map<String, dynamic>? info;
  try {
    final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) info = Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  if (!context.mounted) return;
  Navigator.of(context).pop();
  if (info == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check updates. Please try again.')));
    return;
  }
  final latestBuild = number(info['latest_version_code'] ?? info['build']);
  final latestVersion = '${info['latest_version'] ?? info['version'] ?? appVersion}';
  if (latestBuild <= appBuild) {
    await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('You are up to date'), content: Text('RentFlow $appVersion is the latest version.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    return;
  }
  final notes = '${info['release_notes'] ?? info['releaseNotes'] ?? 'New RentFlow update available.'}';
  final link = '${info['apk_url'] ?? info['downloadUrl'] ?? websiteUrl}';
  await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Update available'), content: Text('RentFlow $latestVersion is available.\n\n$notes'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')), FilledButton(onPressed: () async { final uri = Uri.tryParse(link); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); if (context.mounted) Navigator.pop(context); }, child: const Text('Update Now'))]));
}
