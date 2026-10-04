import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const primary = Color(0xFF00A889);
const mint = Color(0xFFE8F8F3);
const bg = Color(0xFFF5F9F7);
const ink = Color(0xFF14211D);
const muted = Color(0xFF71807B);
const websiteUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2EBE7))),
        ),
      ),
      home: const SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      }
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
            Brand(size: 108),
            SizedBox(height: 22),
            Text('RentFlow', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: ink)),
            SizedBox(height: 7),
            Text('By PaliaAPK HUB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primary)),
            SizedBox(height: 5),
            Text('Developer by ShanPalia', style: TextStyle(fontSize: 14, color: muted)),
          ],
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  final double size;
  const Brand({required this.size, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(size * .25),
        boxShadow: const [BoxShadow(color: Color(0x2600A889), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: size * .58),
    );
  }
}

class DB {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    items = _read('items');
    customers = _read('customers');
    rentals = _read('rentals');
  }

  List<Map<String, dynamic>> _read(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save() async {
    await prefs.setString('items', jsonEncode(items));
    await prefs.setString('customers', jsonEncode(customers));
    await prefs.setString('rentals', jsonEncode(rentals));
  }
}

int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String money(dynamic value) {
  final n = asDouble(value);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}
String today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final db = DB();
  int tab = 0;
  bool loading = true;
  DateTime? lastBack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await db.load();
    if (mounted) setState(() => loading = false);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = <Widget>[
      Home(db: db, refresh: refresh, selectTab: (i) => setState(() => tab = i)),
      ItemsPage(db: db, refresh: refresh),
      CustomersPage(db: db, refresh: refresh),
      ReportsPage(db: db),
    ];
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          indicatorColor: mint,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}

class Home extends StatelessWidget {
  final DB db;
  final VoidCallback refresh;
  final ValueChanged<int> selectTab;
  const Home({required this.db, required this.refresh, required this.selectTab, super.key});

  @override
  Widget build(BuildContext context) {
    final total = db.items.fold<int>(0, (sum, item) => sum + asInt(item['qty']));
    final available = db.items.fold<int>(0, (sum, item) => sum + asInt(item['available']));
    final issued = total - available;
    final due = db.rentals.fold<int>(0, (sum, rental) => sum + asInt(rental['qty']) - asInt(rental['received']));
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                const Brand(size: 52),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), Text('Rental management', style: TextStyle(color: muted))])),
                IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings_outlined)),
                IconButton(onPressed: () => showAbout(context), icon: const Icon(Icons.info_outline_rounded)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE9FAF5), Color(0xFFDDF5ED)]), borderRadius: BorderRadius.circular(26)),
                child: const Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RENTAL MANAGEMENT', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1)), SizedBox(height: 8), Text('Run your rental\nbusiness smarter.', style: TextStyle(fontSize: 27, height: 1.08, fontWeight: FontWeight.w900, color: ink)), SizedBox(height: 9), Text('Items, customers, rentals and invoices in one place.', style: TextStyle(color: muted, height: 1.35))])),
                  SizedBox(width: 16),
                  Icon(Icons.swap_horizontal_circle_rounded, color: primary, size: 58),
                ]),
              ),
            ),
          ),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), sliver: SliverToBoxAdapter(child: Row(children: [Expanded(child: StatCard('Total Items', '$total', Icons.inventory_2_rounded)), const SizedBox(width: 10), Expanded(child: StatCard('Available', '$available', Icons.check_circle_rounded))]))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), sliver: SliverToBoxAdapter(child: Row(children: [Expanded(child: StatCard('Issued', '$issued', Icons.north_east_rounded)), const SizedBox(width: 10), Expanded(child: StatCard('Items Due', '$due', Icons.schedule_rounded))]))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), sliver: SliverToBoxAdapter(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), onPressed: () => rentalForm(context, db, refresh), icon: const Icon(Icons.add_rounded), label: const Text('New Rental', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), sliver: SliverToBoxAdapter(child: Row(children: [QuickAction('Add Item', Icons.inventory_2_outlined, () => itemForm(context, db, refresh)), QuickAction('Customer', Icons.person_add_alt_1_rounded, () => customerForm(context, db, refresh)), QuickAction('Invoice', Icons.receipt_long_outlined, () => invoiceList(context, db)), QuickAction('Receive', Icons.undo_rounded, () => receiveForm(context, db, refresh))]))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 10), sliver: SliverToBoxAdapter(child: Row(children: [const Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), TextButton(onPressed: () => selectTab(3), child: const Text('View all'))]))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            sliver: SliverList.builder(
              itemCount: db.rentals.length > 6 ? 6 : db.rentals.length,
              itemBuilder: (context, index) {
                final rental = db.rentals[db.rentals.length - 1 - index];
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.swap_horiz_rounded, color: primary)), title: Text('${rental['customer']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${rental['item']} • ${rental['date']} • ${rental['days']} day(s)'), trailing: Text('₹${money(rental['amount'])}', style: const TextStyle(fontWeight: FontWeight.w900))));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const StatCard(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4ECE8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: primary),
        const Spacer(),
        Text(title, style: const TextStyle(color: muted, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink)),
      ]),
    );
  }
}

class QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const QuickAction(this.label, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9E5))), child: Column(children: [Icon(icon, color: primary), const SizedBox(height: 7), Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))]))));
  }
}

class PageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final List<Widget> children;
  const PageFrame({required this.title, required this.subtitle, required this.children, this.action, super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 14, 14), child: Row(children: [const Brand(size: 46), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: muted))])), if (action != null) action!])),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: children)),
    ]));
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({required this.icon, required this.text, super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Column(children: [Icon(icon, size: 56, color: primary), const SizedBox(height: 12), Text(text, style: const TextStyle(color: muted, fontWeight: FontWeight.w700))]));
}

class ItemsPage extends StatefulWidget {
  final DB db;
  final VoidCallback refresh;
  const ItemsPage({required this.db, required this.refresh, super.key});
  @override State<ItemsPage> createState() => _ItemsPageState();
}
class _ItemsPageState extends State<ItemsPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.db.items.where((x) => '${x['name']} ${x['category']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return PageFrame(title: 'Items', subtitle: 'Manage your rental inventory', action: IconButton.filled(onPressed: () => itemForm(context, widget.db, widget.refresh), icon: const Icon(Icons.add_rounded)), children: [
      TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search items')),
      const SizedBox(height: 14),
      if (list.isEmpty) const EmptyState(icon: Icons.inventory_2_outlined, text: 'No items added yet'),
      ...list.map((x) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${x['category']} • ${x['type']} • ₹${money(x['rate'])}'), trailing: Text('${asInt(x['available'])}/${asInt(x['qty'])}', style: const TextStyle(fontWeight: FontWeight.w900))))),
    ]);
  }
}

class CustomersPage extends StatefulWidget {
  final DB db;
  final VoidCallback refresh;
  const CustomersPage({required this.db, required this.refresh, super.key});
  @override State<CustomersPage> createState() => _CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.db.customers.where((x) => '${x['name']} ${x['mobile']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return PageFrame(title: 'Customers', subtitle: 'Customer-wise rental history', action: IconButton.filled(onPressed: () => customerForm(context, widget.db, widget.refresh), icon: const Icon(Icons.person_add_alt_1_rounded)), children: [
      TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search customer')),
      const SizedBox(height: 14),
      if (list.isEmpty) const EmptyState(icon: Icons.people_outline, text: 'No customers added yet'),
      ...list.map((x) => Card(child: ListTile(onTap: () => customerReport(context, widget.db, '${x['name']}'), leading: CircleAvatar(backgroundColor: mint, child: Text('${x['name']}'.isEmpty ? '?' : '${x['name']}'.substring(0, 1).toUpperCase(), style: const TextStyle(color: primary, fontWeight: FontWeight.w900))), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${x['mobile']} • Tap for full report'), trailing: const Icon(Icons.chevron_right_rounded)))),
    ]);
  }
}

class ReportsPage extends StatefulWidget {
  final DB db;
  const ReportsPage({required this.db, super.key});
  @override State<ReportsPage> createState() => _ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.db.rentals.where((r) => '${r['customer']} ${r['item']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return PageFrame(title: 'Reports', subtitle: 'Date-wise rental report', action: IconButton(onPressed: () => invoiceList(context, widget.db), icon: const Icon(Icons.receipt_long_outlined)), children: [
      TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search customer or item')),
      const SizedBox(height: 14),
      if (rows.isEmpty) const EmptyState(icon: Icons.analytics_outlined, text: 'No rental transactions yet'),
      if (rows.isNotEmpty)
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [DataColumn(label: Text('Date')), DataColumn(label: Text('Customer')), DataColumn(label: Text('Item')), DataColumn(label: Text('Issued')), DataColumn(label: Text('Received')), DataColumn(label: Text('Days')), DataColumn(label: Text('Rate')), DataColumn(label: Text('Amount')), DataColumn(label: Text('Due'))],
              rows: rows.map((r) => DataRow(cells: [DataCell(Text('${r['date']}')), DataCell(Text('${r['customer']}')), DataCell(Text('${r['item']}')), DataCell(Text('${r['qty']}')), DataCell(Text('${r['received']}')), DataCell(Text('${r['days']}')), DataCell(Text('₹${money(r['rate'])}')), DataCell(Text('₹${money(r['amount'])}')), DataCell(Text('${asInt(r['qty']) - asInt(r['received'])}'))])).toList(),
            ),
          ),
        ),
    ]);
  }
}

Future<void> itemForm(BuildContext context, DB db, VoidCallback refresh) async {
  final name = TextEditingController();
  final category = TextEditingController(text: 'Rental');
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  String type = 'Day';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
            const SizedBox(height: 10),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 10),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 10),
            TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent price')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: type, items: const [DropdownMenuItem(value: 'Day', child: Text('Per Day')), DropdownMenuItem(value: 'Hour', child: Text('Per Hour')), DropdownMenuItem(value: 'Event', child: Text('Per Event'))], onChanged: (v) => setState(() => type = v ?? 'Day'), decoration: const InputDecoration(labelText: 'Rate type')),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
        );
      });
    },
  );
  if (ok != true || name.text.trim().isEmpty) return;
  final count = asInt(qty.text);
  db.items.add({'name': name.text.trim(), 'category': category.text.trim(), 'qty': count, 'available': count, 'rate': asDouble(rate.text), 'type': type});
  await db.save();
  refresh();
}

Future<void> customerForm(BuildContext context, DB db, VoidCallback refresh) async {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Customer'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')),
        const SizedBox(height: 10),
        TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
        const SizedBox(height: 10),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  db.customers.add({'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()});
  await db.save();
  refresh();
}

Future<void> rentalForm(BuildContext context, DB db, VoidCallback refresh) async {
  if (db.items.isEmpty || db.customers.isEmpty) {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Add details first'), content: const Text('Please add at least one item and one customer before creating a rental.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    return;
  }
  String customer = '${db.customers.first['name']}';
  String item = '${db.items.first['name']}';
  final qty = TextEditingController(text: '1');
  final days = TextEditingController(text: '1');
  final rate = TextEditingController(text: money(db.items.first['rate']));
  final amount = TextEditingController();

  void syncAmount() {
    amount.text = money(asInt(qty.text) * asInt(days.text) * asDouble(rate.text));
  }
  syncAmount();

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('New Rental'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: customer,
                items: db.customers.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(),
                onChanged: (v) => setState(() => customer = v ?? customer),
                decoration: const InputDecoration(labelText: 'Customer'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: item,
                items: db.items.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(),
                onChanged: (v) {
                  item = v ?? item;
                  final selected = db.items.firstWhere((x) => '${x['name']}' == item);
                  rate.text = money(selected['rate']);
                  syncAmount();
                  setState(() {});
                },
                decoration: const InputDecoration(labelText: 'Item'),
              ),
              const SizedBox(height: 10),
              TextField(controller: qty, keyboardType: TextInputType.number, onChanged: (_) => setState(syncAmount), decoration: const InputDecoration(labelText: 'Quantity')),
              const SizedBox(height: 10),
              TextField(controller: days, keyboardType: TextInputType.number, onChanged: (_) => setState(syncAmount), decoration: const InputDecoration(labelText: 'Days')),
              const SizedBox(height: 10),
              TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(syncAmount), decoration: const InputDecoration(labelText: 'Rate (editable)')),
              const SizedBox(height: 10),
              TextField(controller: amount, readOnly: true, decoration: const InputDecoration(labelText: 'Amount')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
        );
      });
    },
  );

  if (ok != true) return;
  final selected = db.items.firstWhere((x) => '${x['name']}' == item);
  final q = asInt(qty.text);
  final available = asInt(selected['available']);
  if (q <= 0 || q > available) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity is greater than available stock.')));
    return;
  }
  selected['available'] = available - q;
  db.rentals.add({'date': today(), 'customer': customer, 'item': item, 'qty': q, 'received': 0, 'days': asInt(days.text), 'rate': asDouble(rate.text), 'amount': asDouble(amount.text)});
  await db.save();
  refresh();
}

Future<void> receiveForm(BuildContext context, DB db, VoidCallback refresh) async {
  final active = db.rentals.where((r) => asInt(r['qty']) > asInt(r['received'])).toList();
  if (active.isEmpty) {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Nothing to receive'), content: const Text('There are no outstanding rental items.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    return;
  }
  Map<String, dynamic> rental = active.first;
  final received = TextEditingController(text: '${asInt(rental['qty']) - asInt(rental['received'])}');
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Receive Item'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: rental,
              items: active.map((r) => DropdownMenuItem(value: r, child: Text('${r['customer']} • ${r['item']}'))).toList(),
              onChanged: (v) {
                rental = v ?? rental;
                received.text = '${asInt(rental['qty']) - asInt(rental['received'])}';
                setState(() {});
              },
              decoration: const InputDecoration(labelText: 'Rental'),
            ),
            const SizedBox(height: 12),
            TextField(controller: received, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Received quantity')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Receive'))],
        );
      });
    },
  );
  if (ok != true) return;
  final n = asInt(received.text);
  final remaining = asInt(rental['qty']) - asInt(rental['received']);
  if (n <= 0 || n > remaining) return;
  rental['received'] = asInt(rental['received']) + n;
  final item = db.items.firstWhere((x) => '${x['name']}' == '${rental['item']}', orElse: () => {});
  if (item.isNotEmpty) item['available'] = asInt(item['available']) + n;
  await db.save();
  refresh();
}

Future<void> customerReport(BuildContext context, DB db, String name) async {
  final rows = db.rentals.where((r) => '${r['customer']}' == name).toList();
  final issued = rows.fold<int>(0, (s, r) => s + asInt(r['qty']));
  final received = rows.fold<int>(0, (s, r) => s + asInt(r['received']));
  final amount = rows.fold<double>(0, (s, r) => s + asDouble(r['amount']));
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerReportPage(name: name, rows: rows, issued: issued, received: received, amount: amount)));
}

class CustomerReportPage extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> rows;
  final int issued;
  final int received;
  final double amount;
  const CustomerReportPage({required this.name, required this.rows, required this.issued, required this.received, required this.amount, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [Expanded(child: StatCard('Issued', '$issued', Icons.north_east_rounded)), const SizedBox(width: 10), Expanded(child: StatCard('Received', '$received', Icons.undo_rounded))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: StatCard('Item Due', '${issued - received}', Icons.schedule_rounded)), const SizedBox(width: 10), Expanded(child: StatCard('Amount', '₹${money(amount)}', Icons.receipt_long_rounded))]),
        const SizedBox(height: 20),
        const Text('Rental History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...rows.map((r) => Card(child: ListTile(title: Text('${r['item']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${r['date']} • ${r['days']} day(s) • Issued ${r['qty']} • Received ${r['received']}'), trailing: Text('₹${money(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.w900))))),
      ],),
    );
  }
}

Future<void> invoiceList(BuildContext context, DB db) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicePage(db: db)));
}

class InvoicePage extends StatelessWidget {
  final DB db;
  const InvoicePage({required this.db, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: db.rentals.length,
        itemBuilder: (context, index) {
          final r = db.rentals[db.rentals.length - 1 - index];
          return Card(child: ListTile(title: Text('${r['customer']} • ${r['item']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${r['date']} • ₹${money(r['amount'])}'), trailing: IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: primary), onPressed: () => createInvoicePdf(r))));
        },
      ),
    );
  }
}

Future<void> createInvoicePdf(Map<String, dynamic> r) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(build: (context) {
    return pw.Padding(padding: const pw.EdgeInsets.all(28), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RENTFLOW', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('By PaliaAPK HUB'),
      pw.Text('Developer by ShanPalia'),
      pw.Divider(),
      pw.Text('Date: ${r['date']}'),
      pw.SizedBox(height: 8),
      pw.Text('Customer: ${r['customer']}'),
      pw.SizedBox(height: 18),
      pw.Text('Item: ${r['item']}'),
      pw.Text('Quantity: ${r['qty']}'),
      pw.Text('Days: ${r['days']}'),
      pw.Text('Rate: ₹${money(r['rate'])}'),
      pw.SizedBox(height: 12),
      pw.Text('TOTAL: ₹${money(r['amount'])}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    ]));
  }));
  await Printing.sharePdf(bytes: await doc.save(), filename: 'RentFlow-Invoice.pdf');
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  Future<void> openWebsite(BuildContext context) async {
    final uri = Uri.parse(websiteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open website')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(color: mint, child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Brand(size: 64), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)), Text('Developer by ShanPalia', style: TextStyle(color: muted))]))]))),
        const SizedBox(height: 14),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.system_update_alt_rounded, color: primary), title: const Text('App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check PaliaAPK HUB for the latest APK'), trailing: const Icon(Icons.open_in_new_rounded), onTap: () => openWebsite(context)),
          ListTile(leading: const Icon(Icons.language_rounded, color: primary), title: const Text('PaliaAPK HUB Website', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Open website'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openWebsite(context)),
        ])),
        const SizedBox(height: 18),
        const Center(child: Text('RentFlow 1.0.0', style: TextStyle(color: muted))),
        const SizedBox(height: 4),
        const Center(child: Text('Rental management made simple', style: TextStyle(color: muted))),
      ]),
    );
  }
}

void showAbout(BuildContext context) {
  showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('About RentFlow'),
    content: const Column(mainAxisSize: MainAxisSize.min, children: [Brand(size: 76), SizedBox(height: 14), Text('RentFlow', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Developer by ShanPalia', style: TextStyle(color: muted))]),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ));
}
