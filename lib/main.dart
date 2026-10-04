import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            RentFlowLogo(size: 150),
            SizedBox(height: 18),
            Text('RentFlow', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: ink)),
            SizedBox(height: 4),
            Text('By PaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
            SizedBox(height: 4),
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
        border: Border.all(color: primary, width: size * .075),
        boxShadow: const [BoxShadow(color: Color(0x3300A889), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final roof = Paint()..color = primaryDark..style = PaintingStyle.stroke..strokeWidth = s * .075..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final arrow = Paint()..color = primary..style = PaintingStyle.stroke..strokeWidth = s * .065..strokeCap = StrokeCap.round;
    final p = Path()
      ..moveTo(s * .22, s * .45)
      ..lineTo(s * .50, s * .22)
      ..lineTo(s * .78, s * .45);
    canvas.drawPath(p, roof);
    canvas.drawLine(Offset(s * .31, s * .42), Offset(s * .31, s * .67), roof);
    canvas.drawLine(Offset(s * .69, s * .42), Offset(s * .69, s * .67), roof);
    canvas.drawLine(Offset(s * .38, s * .67), Offset(s * .62, s * .67), roof);
    final a = Path()..moveTo(s * .22, s * .72)..lineTo(s * .55, s * .72)..lineTo(s * .48, s * .65);
    canvas.drawPath(a, arrow);
    final b = Path()..moveTo(s * .78, s * .58)..lineTo(s * .45, s * .58)..lineTo(s * .52, s * .51);
    canvas.drawPath(b, arrow);
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
String dateNow() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';
}

String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Store store = Store();
  int selected = 0;
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
  }

  void refresh() => setState(() {});

  Future<void> back() async {
    if (selected != 0) {
      setState(() => selected = 0);
      return;
    }
    final now = DateTime.now();
    if (lastBack != null && now.difference(lastBack!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    lastBack = now;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Press back again to exit')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));

    final pages = <Widget>[
      HomePage(store: store, refresh: refresh, openReports: () => setState(() => selected = 3)),
      ItemsPage(store: store, refresh: refresh),
      CustomersPage(store: store, refresh: refresh),
      ReportsPage(store: store),
      SettingsPage(onCheckUpdates: () => checkForUpdates(context)),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        body: IndexedStack(index: selected, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) => setState(() => selected = index),
          indicatorColor: mint,
          backgroundColor: Colors.white,
          height: 76,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: primary), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded, color: primary), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded, color: primary), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded, color: primary), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded, color: primary), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

Future<void> checkForUpdates(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [CircularProgressIndicator(color: primary), SizedBox(width: 16), Text('Checking for updates...')]),
    ),
  );

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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('You are up to date'),
        content: Text('RentFlow $appVersion is the latest version.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }

  final notes = '${info['release_notes'] ?? info['releaseNotes'] ?? 'New RentFlow update available.'}';
  final link = '${info['apk_url'] ?? info['downloadUrl'] ?? websiteUrl}';
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Update available'),
      content: Text('RentFlow $latestVersion is available.\n\n$notes'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        FilledButton(
          onPressed: () async {
            final uri = Uri.tryParse(link);
            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Update Now'),
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  final VoidCallback openReports;
  const HomePage({required this.store, required this.refresh, required this.openReports, super.key});

  @override
  Widget build(BuildContext context) {
    final total = store.items.fold<int>(0, (sum, e) => sum + number(e['qty']));
    final available = store.items.fold<int>(0, (sum, e) => sum + number(e['available'] ?? e['qty']));
    final issued = (total - available).clamp(0, 999999);
    final due = store.rentals.fold<int>(0, (sum, e) => sum + (number(e['qty']) - number(e['received'])).clamp(0, 999999));
    final recent = store.rentals.reversed.take(4).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HomeHeader()),
          SliverToBoxAdapter(child: _HeroBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: FilledButton.icon(
                onPressed: () => rentalForm(context, store, refresh),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.add_circle_rounded, size: 30),
                label: const Text('New Rental', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                QuickAction(title: 'Add Item', icon: Icons.inventory_2_rounded, onTap: () => itemForm(context, store, refresh)),
                QuickAction(title: 'New Customer', icon: Icons.person_add_alt_1_rounded, onTap: () => customerForm(context, store, refresh)),
                QuickAction(title: 'Invoice', icon: Icons.receipt_long_rounded, onTap: () => invoiceDialog(context, store)),
                QuickAction(title: 'Receive Item', icon: Icons.undo_rounded, onTap: () => receiveForm(context, store, refresh)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(children: [
                const Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink))),
                TextButton(onPressed: openReports, child: const Text('View All')),
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: const Color(0xFFFFEEF0), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD1D6))),
                child: Row(children: [
                  const CircleAvatar(backgroundColor: red, child: Icon(Icons.schedule_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('$due items pending return', style: const TextStyle(fontWeight: FontWeight.w800, color: ink))),
                  TextButton(onPressed: openReports, child: const Text('View All')),
                ]),
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(children: [
        const RentFlowLogo(size: 58),
        const SizedBox(width: 12),
        const Expanded(child: Text('RentFlow', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink))),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, size: 28)),
        Container(
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
        ),
      ]),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 154,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFDDF8F1), Color(0xFFC7F1E7)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Good Morning,', style: TextStyle(color: muted, fontSize: 16)),
            SizedBox(height: 3),
            Text('Shop Owner', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)),
            SizedBox(height: 5),
            Text('Manage your rental business easily', style: TextStyle(color: ink)),
          ])),
          SizedBox(width: 110, child: _RentalIllustration()),
        ]),
      ),
    );
  }
}

class _RentalIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RentalPainter());
  }
}

class _RentalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final metal = Paint()..color = const Color(0xFF68777A)..style = PaintingStyle.stroke..strokeWidth = 3;
    final green = Paint()..color = primaryDark..style = PaintingStyle.stroke..strokeWidth = 4;
    final roof = Path()..moveTo(8, size.height * .45)..lineTo(size.width * .5, 18)..lineTo(size.width - 8, size.height * .45);
    canvas.drawPath(roof, green);
    canvas.drawLine(18, size.height * .44, 18, size.height * .88, metal);
    canvas.drawLine(size.width - 18, size.height * .44, size.width - 18, size.height * .88, metal);
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(12 + i * 8, size.height * .62, 12 + i * 8, size.height * .88, metal);
    }
    canvas.drawLine(size.width * .58, size.height * .67, size.width * .93, size.height * .67, metal);
    canvas.drawLine(size.width * .58, size.height * .74, size.width * .93, size.height * .74, metal);
    canvas.drawLine(size.width * .58, size.height * .81, size.width * .93, size.height * .81, metal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        padding: const EdgeInsets.fromLTRB(9, 10, 5, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4ECE9))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: primary, size: 22),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: muted)),
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
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 102,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4ECE9))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: primary, size: 30),
              const SizedBox(height: 7),
              Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.event_available_rounded, color: primary)),
          title: Text('${data['customer'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${data['item'] ?? 'Item'} • Qty ${data['qty'] ?? 0} • ${data['date'] ?? ''}'),
          trailing: Text(rupees(data['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String message;
  const EmptyCard({required this.message, super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(message, style: const TextStyle(color: muted))))));
}

class SettingsPage extends StatelessWidget {
  final Future<void> Function() onCheckUpdates;
  const SettingsPage({required this.onCheckUpdates, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 32)),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
                SizedBox(height: 2),
                Text('App, updates and branding', style: TextStyle(color: muted, fontSize: 15)),
              ]),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDCEAE5)),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, 5))],
              ),
              child: Row(children: [
                const RentFlowLogo(size: 96),
                const SizedBox(width: 18),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RentFlow', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: ink)),
                  SizedBox(height: 6),
                  Text('By PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primary)),
                  SizedBox(height: 5),
                  Text('Developer by ShanPalia', style: TextStyle(fontSize: 15, color: muted)),
                ])),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDCEAE5))),
              child: Column(children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.system_update_alt_rounded, color: primary)),
                  title: const Text('Check for Updates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink)),
                  subtitle: const Text('Check the latest RentFlow version', style: TextStyle(color: muted)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 30),
                  onTap: onCheckUpdates,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.language_rounded, color: primary)),
                  title: const Text('PaliaAPK HUB Website', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink)),
                  subtitle: const Text('Open website', style: TextStyle(color: muted)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 27),
                  onTap: () async {
                    final uri = Uri.parse(websiteUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: Column(children: const [
              Text('RentFlow 1.0.1', style: TextStyle(fontSize: 17, color: muted)),
              SizedBox(height: 8),
              Text('Rental management made simple', style: TextStyle(fontSize: 15, color: muted)),
              SizedBox(height: 5),
              Text('By PaliaAPK HUB • Developer by ShanPalia', style: TextStyle(fontSize: 12, color: muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class ItemsPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const ItemsPage({required this.store, required this.refresh, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _SimpleHeader(title: 'Items', subtitle: 'Manage rental stock', action: Icons.add_rounded, onAction: () => itemForm(context, store, refresh))),
        if (store.items.isEmpty)
          const SliverToBoxAdapter(child: EmptyCard(message: 'No items added yet.'))
        else
          SliverList.builder(
            itemCount: store.items.length,
            itemBuilder: (_, i) {
              final item = store.items[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                child: Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)), title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Available ${item['available'] ?? item['qty'] ?? 0}'), trailing: Text('Qty ${item['qty'] ?? 0}'))),
              );
            },
          ),
      ]),
    );
  }
}

class CustomersPage extends StatelessWidget {
  final Store store;
  final VoidCallback refresh;
  const CustomersPage({required this.store, required this.refresh, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _SimpleHeader(title: 'Customers', subtitle: 'Your rental customers', action: Icons.person_add_alt_1_rounded, onAction: () => customerForm(context, store, refresh))),
        if (store.customers.isEmpty)
          const SliverToBoxAdapter(child: EmptyCard(message: 'No customers added yet.'))
        else
          SliverList.builder(
            itemCount: store.customers.length,
            itemBuilder: (_, i) {
              final customer = store.customers[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                child: Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person_rounded, color: primary)), title: Text('${customer['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${customer['phone'] ?? ''}'))),
              );
            },
          ),
      ]),
    );
  }
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});

  @override
  Widget build(BuildContext context) {
    final revenue = store.rentals.fold<double>(0, (sum, e) => sum + amount(e['amount']));
    return SafeArea(
      child: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: _SimpleHeader(title: 'Reports', subtitle: 'Rental business overview')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: _ReportCard(title: 'Rentals', value: '${store.rentals.length}', icon: Icons.swap_horiz_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _ReportCard(title: 'Revenue', value: rupees(revenue), icon: Icons.payments_rounded)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rental History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 14),
              if (store.rentals.isEmpty) const Text('No rental records yet.', style: TextStyle(color: muted)) else ...store.rentals.reversed.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text('${r['customer']} • ${r['item']}', style: const TextStyle(fontWeight: FontWeight.w700))), Text(rupees(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900))]))),
            ]))),
          ),
        ),
      ]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _ReportCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDCEAE5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: primary), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: muted))]);
}

class _SimpleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData action;
  final VoidCallback? onAction;
  const _SimpleHeader({required this.title, required this.subtitle, this.action = Icons.more_horiz_rounded, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 14, 14), child: Row(children: [const RentFlowLogo(size: 52), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)), Text(subtitle, style: const TextStyle(color: muted))])), IconButton(onPressed: onAction, icon: Icon(action))]));
}

Future<void> itemForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add Item'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; final n = number(qty.text); store.items.add({'name': name.text.trim(), 'qty': n, 'available': n}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Save'))],
    ),
  );
}

Future<void> customerForm(BuildContext context, Store store, VoidCallback refresh) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New Customer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim()}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Save'))],
    ),
  );
}

Future<void> rentalForm(BuildContext context, Store store, VoidCallback refresh) async {
  final customer = TextEditingController();
  final item = TextEditingController();
  final qty = TextEditingController(text: '1');
  final total = TextEditingController(text: '0');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New Rental'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer')), TextField(controller: item, decoration: const InputDecoration(labelText: 'Item')), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async { if (customer.text.trim().isEmpty || item.text.trim().isEmpty) return; store.rentals.add({'customer': customer.text.trim(), 'item': item.text.trim(), 'qty': number(qty.text), 'received': 0, 'amount': amount(total.text), 'date': dateNow()}); await store.save(); if (dialogContext.mounted) Navigator.pop(dialogContext); refresh(); }, child: const Text('Save Rental'))],
    ),
  );
}

Future<void> receiveForm(BuildContext context, Store store, VoidCallback refresh) async {
  if (store.rentals.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active rental found.')));
    return;
  }
  final rental = store.rentals.last;
  rental['received'] = number(rental['qty']);
  await store.save();
  refresh();
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Latest rental marked as returned.')));
}

Future<void> invoiceDialog(BuildContext context, Store store) async {
  final total = store.rentals.fold<double>(0, (sum, e) => sum + amount(e['amount']));
  await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Invoice Summary'), content: Text('RentFlow\n\nRentals: ${store.rentals.length}\nTotal: ${rupees(total)}\n\nBy PaliaAPK HUB\nDeveloper by ShanPalia'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
}
