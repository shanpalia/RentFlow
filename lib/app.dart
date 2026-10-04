import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF5FAF8);
const soft = Color(0xFFE7F7F2);
const line = Color(0xFFDDEBE6);
const website = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const version = '1.0.3';

int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String today() => DateTime.now().toIso8601String().substring(0, 10);
String newId() => DateTime.now().microsecondsSinceEpoch.toString();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentFlowApp());
}

class Store extends ChangeNotifier {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> shops = [];
  int active = 0;

  bool get registered => shops.isNotEmpty;
  Map<String, dynamic> get shop => shops.isEmpty ? <String, dynamic>{} : shops[active];
  List<Map<String, dynamic>> list(String key) => (shop[key] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  List<Map<String, dynamic>> get items => list('items');
  List<Map<String, dynamic>> get customers => list('customers');
  List<Map<String, dynamic>> get issued => list('issued');
  List<Map<String, dynamic>> get returns => list('returns');

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('shops_v2');
      if (raw != null) {
        shops = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    active = prefs.getInt('active_shop') ?? 0;
    if (shops.isEmpty) {
      final oldName = prefs.getString('shop') ?? '';
      if (oldName.isNotEmpty) {
        shops = [_shop(oldName, prefs.getString('owner') ?? '', prefs.getString('phone') ?? '', prefs.getString('address') ?? '')];
        shops[0]['items'] = _oldList('items');
        shops[0]['customers'] = _oldList('customers');
        shops[0]['issued'] = _oldList('rentals');
        await save();
      }
    }
    if (shops.isNotEmpty) {
      if (active < 0) active = 0;
      if (active >= shops.length) active = shops.length - 1;
    }
  }

  List<Map<String, dynamic>> _oldList(String key) {
    try {
      return (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _shop(String name, String owner, String phone, String address) => {
        'id': newId(),
        'name': name,
        'owner': owner,
        'phone': phone,
        'address': address,
        'items': <Map<String, dynamic>>[],
        'customers': <Map<String, dynamic>>[],
        'issued': <Map<String, dynamic>>[],
        'returns': <Map<String, dynamic>>[],
      };

  Future<void> addShop({required String name, required String owner, required String phone, required String address}) async {
    shops.add(_shop(name, owner, phone, address));
    active = shops.length - 1;
    await save();
    notifyListeners();
  }

  Future<void> updateShop(Map<String, String> data) async {
    shop.addAll(data);
    await save();
    notifyListeners();
  }

  Future<void> deleteShop(int index) async {
    shops.removeAt(index);
    if (shops.isEmpty) {
      active = 0;
    } else if (active >= shops.length) {
      active = shops.length - 1;
    }
    await save();
    notifyListeners();
  }

  Future<void> selectShop(int index) async {
    active = index;
    await save();
    notifyListeners();
  }

  Future<void> save() async {
    await prefs.setString('shops_v2', jsonEncode(shops));
    await prefs.setInt('active_shop', active);
  }

  Future<void> changed() async {
    await save();
    notifyListeners();
  }
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
          colorScheme: ColorScheme.fromSeed(seedColor: primary),
          appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: dark, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 1.5)),
          ),
        ),
        home: const SplashPage(),
      );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({this.size = 54, super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .05),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .25), border: Border.all(color: line)),
        child: SvgPicture.asset('assets/rentflow_logo.svg'),
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
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Logo(size: 112),
            SizedBox(height: 18),
            Text('RentFlow', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: dark)),
            SizedBox(height: 5),
            Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Developer by shanpalia', style: TextStyle(color: Colors.black45)),
          ],),
        ),
      );
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

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (mounted) setState(() => loading = false);
    });
  }

  Future<bool> gate(BuildContext context) async {
    if (store.registered) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Register your shop first', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('You can explore RentFlow, but an entry requires a registered shop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Skip')),
          FilledButton.icon(onPressed: () => Navigator.pop(d, true), icon: const Icon(Icons.storefront_rounded), label: const Text('Register Shop')),
        ],
      ),
    );
    if (result == true && context.mounted) await shopForm(context, store);
    return store.registered;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [
      HomePage(store: store, gate: gate),
      ItemsPage(store: store, gate: gate),
      CustomersPage(store: store, gate: gate),
      IssuedPage(store: store, gate: gate),
      SettingsPage(store: store),
    ];
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => Scaffold(
        body: pages[tab],
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: soft,
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
            NavigationDestination(icon: Icon(Icons.people_outline_rounded), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Issued'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Store store;
  final Future<bool> Function(BuildContext) gate;
  const HomePage({required this.store, required this.gate, super.key});

  @override
  Widget build(BuildContext context) {
    final s = store.shop;
    final issuedQty = store.issued.where((e) => e['closed'] != true).fold<int>(0, (n, e) => n + (e['items'] as List? ?? []).fold<int>(0, (a, x) => a + asInt(x['qty'])));
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
        Row(children: [
          const Logo(size: 54),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RentFlow', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: dark)),
            Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
          ])),
          if (store.registered)
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManagerPage(store: store))),
              borderRadius: BorderRadius.circular(18),
              child: Container(width: 155, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)), child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_rounded, color: primary)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SHOP', style: TextStyle(fontSize: 9, color: primary, fontWeight: FontWeight.w900)), Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), Text('${s['owner']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54))]))
              ])),
            )
          else
            IconButton.filledTonal(onPressed: () => shopForm(context, store), icon: const Icon(Icons.storefront_rounded)),
        ]),
        const SizedBox(height: 18),
        if (!store.registered)
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(24)), child: Row(children: [
            const Icon(Icons.storefront_rounded, color: Colors.white), const SizedBox(width: 12),
            const Expanded(child: Text('Register your shop to start entries.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => shopForm(context, store), child: const Text('Register', style: TextStyle(color: Colors.white))),
          ])),
        const SizedBox(height: 22),
        Row(children: [StatCard('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), StatCard('Customers', '${store.customers.length}', Icons.people_outline_rounded)]),
        const SizedBox(height: 10),
        Row(children: [StatCard('Open Issues', '${store.issued.where((e) => e['closed'] != true).length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Issued Qty', '$issuedQty', Icons.local_shipping_outlined)]),
        const SizedBox(height: 26),
        const Text('Quick actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          QuickAction('Add Item', Icons.add_box_outlined, () async { if (await gate(context) && context.mounted) itemForm(context, store); }),
          QuickAction('Customer', Icons.person_add_alt_1_outlined, () async { if (await gate(context) && context.mounted) customerForm(context, store); }),
          QuickAction('Issued', Icons.assignment_outlined, () async { if (await gate(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueFormPage(store: store))); }),
          QuickAction('Return', Icons.keyboard_return_rounded, () async { if (await gate(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnPage(store: store))); }),
          QuickAction('Reports', Icons.analytics_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(store: store)))),
        ]),
        const SizedBox(height: 26),
        const Text('Recent issued', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)),
        const SizedBox(height: 12),
        if (store.issued.isEmpty) const EmptyCard(title: 'No issued entries yet', subtitle: 'Saved issue records will appear here.') else ...store.issued.reversed.take(4).map((e) => IssueCard(e, onTap: () => showIssuePreview(context, store, e))),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const StatCard(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)), child: Row(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: primary)),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)), Text(label, style: const TextStyle(color: Colors.black54))])
  ]));
}

class QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const QuickAction(this.label, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(width: MediaQuery.sizeOf(context).width / 2 - 25, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(height: 102, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 46, height: 46, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: primary)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: dark))
  ]))));
}

class EmptyCard extends StatelessWidget {
  final String title, subtitle;
  const EmptyCard({required this.title, required this.subtitle, super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: line)), child: Column(children: [
    const Icon(Icons.receipt_long_outlined, color: primary, size: 48), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: dark)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))
  ]));
}

class IssueCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  const IssueCard(this.entry, {required this.onTap, super.key});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.receipt_long, color: primary)), title: Text('${entry['customerName']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Text('${entry['invoice']}  •  ${(entry['items'] as List? ?? []).length} item(s)  •  ${entry['date']}'), trailing: Icon(entry['closed'] == true ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: entry['closed'] == true ? primary : null));
}

class ItemsPage extends StatelessWidget {
  final Store store;
  final Future<bool> Function(BuildContext) gate;
  const ItemsPage({required this.store, required this.gate, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) itemForm(context, store); }, icon: const Icon(Icons.add_rounded))]), body: store.items.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: EmptyCard(title: 'Inventory is empty', subtitle: 'Add rental items with rent days.')) : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.items.length, itemBuilder: (c, i) { final x = store.items[i]; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Text('Code: ${x['code']}  •  Rent days: ${x['rentDays']}'), trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => itemForm(context, store, existing: x))); }));
}

class CustomersPage extends StatelessWidget {
  final Store store;
  final Future<bool> Function(BuildContext) gate;
  const CustomersPage({required this.store, required this.gate, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) customerForm(context, store); }, icon: const Icon(Icons.person_add_alt_1_rounded))]), body: store.customers.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: EmptyCard(title: 'No customers', subtitle: 'Customer details will be saved here.')) : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.customers.length, itemBuilder: (c, i) { final x = store.customers[i]; return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.person_outline_rounded, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Text('${x['mobile']}\n${x['address']}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => customerForm(context, store, existing: x))); }));
}

class IssuedPage extends StatelessWidget {
  final Store store;
  final Future<bool> Function(BuildContext) gate;
  const IssuedPage({required this.store, required this.gate, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Issued', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => IssueFormPage(store: store))); }, icon: const Icon(Icons.add_rounded))]), body: store.issued.isEmpty ? const Padding(padding: EdgeInsets.all(18), child: EmptyCard(title: 'No issued records', subtitle: 'Use the + button to create an issue entry.')) : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.issued.length, itemBuilder: (c, i) { final e = store.issued[store.issued.length - 1 - i]; return IssueCard(e, onTap: () => showIssuePreview(context, store, e)); }));
}

class IssueFormPage extends StatefulWidget {
  final Store store;
  const IssueFormPage({required this.store, super.key});
  @override
  State<IssueFormPage> createState() => _IssueFormPageState();
}

class _IssueFormPageState extends State<IssueFormPage> {
  final invoice = TextEditingController();
  final date = TextEditingController(text: today());
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final party = TextEditingController();
  final List<Map<String, dynamic>> rows = [];

  @override
  void dispose() { invoice.dispose(); date.dispose(); name.dispose(); mobile.dispose(); address.dispose(); party.dispose(); super.dispose(); }

  Future<void> pickItem() async {
    if (widget.store.items.isEmpty) { if (mounted) itemForm(context, widget.store); return; }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: ListView(padding: const EdgeInsets.all(14), children: [const Text('Select inventory item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark)), const SizedBox(height: 10), ...widget.store.items.map((x) => ListTile(leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Code ${x['code']} • ${x['rentDays']} rent days'), trailing: const Icon(Icons.add_circle_outline_rounded, color: primary), onTap: () => Navigator.pop(c, x)))])));
    if (selected == null) return;
    final qty = TextEditingController(text: '1');
    final q = await showDialog<int>(context: context, builder: (d) => AlertDialog(title: Text('${selected['name']}'), content: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Issued quantity')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, asInt(qty.text)), child: const Text('Add'))]));
    qty.dispose();
    if (q != null && q > 0) setState(() => rows.add({'itemId': selected['id'], 'item': selected['name'], 'code': selected['code'], 'qty': q, 'rentDays': selected['rentDays']}));
  }

  Future<void> saveIssue() async {
    if (name.text.trim().isEmpty || invoice.text.trim().isEmpty || rows.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice, customer name and at least one item are required.'))); return; }
    final customer = {'id': newId(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()};
    final existing = widget.store.customers.indexWhere((x) => '${x['mobile']}' == customer['mobile'] && customer['mobile'].isNotEmpty);
    if (existing >= 0) widget.store.customers[existing] = customer; else widget.store.customers.add(customer);
    final entry = {'id': newId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'customerName': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'party': party.text.trim(), 'items': rows.map((e) => Map<String, dynamic>.from(e)).toList(), 'closed': false};
    widget.store.issued.add(entry);
    await widget.store.changed();
    if (mounted) await showIssuePreview(context, widget.store, entry);
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Issued Entry', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: saveIssue, icon: const Icon(Icons.check_rounded))]), body: ListView(padding: const EdgeInsets.all(18), children: [
    SectionTitle('Issue details'),
    Row(children: [Expanded(child: TextField(controller: invoice, decoration: const InputDecoration(labelText: 'Invoice No.'))), const SizedBox(width: 10), Expanded(child: TextField(controller: date, readOnly: true, decoration: const InputDecoration(labelText: 'Date'), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: DateTime.tryParse(date.text) ?? DateTime.now()); if (d != null) setState(() => date.text = d.toIso8601String().substring(0, 10)); }))]),
    const SizedBox(height: 10), TextField(controller: name, decoration: const InputDecoration(labelText: 'Party / Customer name')), const SizedBox(height: 10), TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile')), const SizedBox(height: 10), TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')), const SizedBox(height: 10), TextField(controller: party, decoration: const InputDecoration(labelText: 'Party reference (optional)')),
    const SizedBox(height: 22),
    Row(children: [const Expanded(child: SectionTitle('Inventory')), FilledButton.icon(onPressed: pickItem, icon: const Icon(Icons.add), label: const Text('Add item'))]),
    const SizedBox(height: 8),
    if (rows.isEmpty) const EmptyCard(title: 'No items added', subtitle: 'Tap Add item. You can add multiple inventory lines.'),
    ...rows.asMap().entries.map((entry) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)), child: ListTile(leading: CircleAvatar(backgroundColor: soft, child: Text('${entry.key + 1}', style: const TextStyle(color: primary, fontWeight: FontWeight.w900))), title: Text('${entry.value['item']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Code ${entry.value['code']} • Qty ${entry.value['qty']} • ${entry.value['rentDays']} days'), trailing: IconButton(onPressed: () => setState(() => rows.removeAt(entry.key)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)))),
    const SizedBox(height: 18), FilledButton.icon(onPressed: saveIssue, icon: const Icon(Icons.preview_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Save & Preview')),
    const SizedBox(height: 25), const FooterBrand(),
  ]));
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark));
}

class ReturnPage extends StatefulWidget {
  final Store store;
  const ReturnPage({required this.store, super.key});
  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  Map<String, dynamic>? selected;
  final amount = TextEditingController();
  @override
  void dispose() { amount.dispose(); super.dispose(); }
  Future<void> saveReturn() async {
    final e = selected;
    if (e == null) return;
    e['closed'] = true;
    e['returnedDate'] = today();
    e['returnAmount'] = asDouble(amount.text);
    widget.store.returns.add({'id': newId(), 'invoice': e['invoice'], 'customerName': e['customerName'], 'date': today(), 'amount': asDouble(amount.text), 'items': e['items']});
    await widget.store.changed();
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return saved successfully.'))); Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) { final open = widget.store.issued.where((e) => e['closed'] != true).toList(); return Scaffold(appBar: AppBar(title: const Text('Return', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [const SectionTitle('Select issued invoice'), const SizedBox(height: 10), if (open.isEmpty) const EmptyCard(title: 'Nothing to return', subtitle: 'All issued entries are already closed.') else ...open.map((e) => RadioListTile<Map<String, dynamic>>(value: e, groupValue: selected, onChanged: (v) => setState(() => selected = v), title: Text('${e['invoice']} • ${e['customerName']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e['date']} • ${(e['items'] as List).length} item(s)'))), if (selected != null) ...[const SizedBox(height: 15), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Return amount (manual)', prefixText: '₹ ')), const SizedBox(height: 15), FilledButton.icon(onPressed: saveReturn, icon: const Icon(Icons.keyboard_return_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Save Return'))], const SizedBox(height: 25), const FooterBrand()]); }
}

class ShopManagerPage extends StatelessWidget {
  final Store store;
  const ShopManagerPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Manage Shops', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () => shopForm(context, store), icon: const Icon(Icons.add_business_rounded))]), body: ListView(padding: const EdgeInsets.all(18), children: [
    ...store.shops.asMap().entries.map((e) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(onTap: () async { await store.selectShop(e.key); if (context.mounted) Navigator.pop(context); }, leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.storefront_rounded, color: primary)), title: Text('${e.value['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Text('${e.value['address']}\n${e.value['phone']}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await shopForm(context, store, existing: e.value); if (v == 'delete') { final ok = await confirmDelete(context, 'Delete this shop?'); if (ok) await store.deleteShop(e.key); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit shop')), PopupMenuItem(value: 'delete', child: Text('Delete shop'))])))),
    const SizedBox(height: 12), FilledButton.icon(onPressed: () => shopForm(context, store), icon: const Icon(Icons.add_business_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Add New Shop')),
    const SizedBox(height: 25), const FooterBrand(),
  ]);
}

class SettingsPage extends StatelessWidget {
  final Store store;
  const SettingsPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [
    if (store.registered) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)), child: Row(children: [const Logo(size: 52), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${store.shop['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark)), Text('${store.shop['address']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54))])), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManagerPage(store: store))), icon: const Icon(Icons.edit_outlined))])),
    const SizedBox(height: 14),
    SettingTile(Icons.storefront_outlined, 'Shop management', 'Edit, delete or add another shop', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopManagerPage(store: store)))),
    SettingTile(Icons.system_update_alt_rounded, 'Check for App Update', 'Current version $version', () async { final uri = Uri.parse(website); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
    SettingTile(Icons.info_outline_rounded, 'About RentFlow', 'RentFlow • PaliaAPK HUB • Developer by shanpalia', () => showAbout(context)),
    const SizedBox(height: 35), const FooterBrand(),
  ]);
}

class SettingTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const SettingTile(this.icon, this.title, this.subtitle, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: soft, child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: dark)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded));
}

class FooterBrand extends StatelessWidget {
  const FooterBrand({super.key});
  @override
  Widget build(BuildContext context) => const Column(children: [Text('RentFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark)), SizedBox(height: 2), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Developer by shanpalia', style: TextStyle(color: Colors.black45))]);
}

Future<void> shopForm(BuildContext context, Store store, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final owner = TextEditingController(text: '${existing?['owner'] ?? ''}');
  final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
  final address = TextEditingController(text: '${existing?['address'] ?? ''}');
  final key = GlobalKey<FormState>();
  await showDialog<void>(context: context, builder: (d) => AlertDialog(title: Text(existing == null ? 'Register Shop' : 'Edit Shop', style: const TextStyle(fontWeight: FontWeight.w900)), content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Shop name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null), const SizedBox(height: 10), TextFormField(controller: owner, decoration: const InputDecoration(labelText: 'Owner name')), const SizedBox(height: 10), TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile')), const SizedBox(height: 10), TextFormField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Shop address'))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; if (existing == null) { await store.addShop(name: name.text.trim(), owner: owner.text.trim(), phone: phone.text.trim(), address: address.text.trim()); } else { await store.updateShop({'name': name.text.trim(), 'owner': owner.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim()}); } if (d.mounted) Navigator.pop(d); }, child: Text(existing == null ? 'Register' : 'Save'))]));
  name.dispose(); owner.dispose(); phone.dispose(); address.dispose();
}

Future<void> itemForm(BuildContext context, Store store, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final code = TextEditingController(text: '${existing?['code'] ?? ''}');
  final days = TextEditingController(text: '${existing?['rentDays'] ?? 1}');
  await showDialog<void>(context: context, builder: (d) => AlertDialog(title: Text(existing == null ? 'Add Inventory Item' : 'Edit Inventory Item', style: const TextStyle(fontWeight: FontWeight.w900)), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), const SizedBox(height: 10), TextField(controller: code, decoration: const InputDecoration(labelText: 'Item / SKU code')), const SizedBox(height: 10), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent days'))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; final data = {'id': existing?['id'] ?? newId(), 'name': name.text.trim(), 'code': code.text.trim().isEmpty ? 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}' : code.text.trim(), 'rentDays': asInt(days.text)}; final list = store.items; if (existing == null) list.add(data); else { final i = list.indexWhere((x) => '${x['id']}' == '${existing['id']}'); if (i >= 0) list[i] = data; } store.shop['items'] = list; await store.changed(); if (d.mounted) Navigator.pop(d); }, child: const Text('Save'))]));
  name.dispose(); code.dispose(); days.dispose();
}

Future<void> customerForm(BuildContext context, Store store, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final mobile = TextEditingController(text: '${existing?['mobile'] ?? ''}');
  final address = TextEditingController(text: '${existing?['address'] ?? ''}');
  await showDialog<void>(context: context, builder: (d) => AlertDialog(title: Text(existing == null ? 'Add Customer' : 'Edit Customer', style: const TextStyle(fontWeight: FontWeight.w900)), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')), const SizedBox(height: 10), TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile')), const SizedBox(height: 10), TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address'))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; final list = store.customers; final data = {'id': existing?['id'] ?? newId(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}; final i = existing == null ? -1 : list.indexWhere((x) => '${x['id']}' == '${existing['id']}'); if (i >= 0) list[i] = data; else list.add(data); store.shop['customers'] = list; await store.changed(); if (d.mounted) Navigator.pop(d); }, child: const Text('Save'))]));
  name.dispose(); mobile.dispose(); address.dispose();
}

Future<void> showIssuePreview(BuildContext context, Store store, Map<String, dynamic> e) async {
  await showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Logo(size: 50), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RentFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800))])), IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close))]),
    const Divider(),
    Text('Invoice ${e['invoice']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark)), Text('${e['date']} • ${e['customerName']} • ${e['mobile']}'), if ('${e['address']}'.isNotEmpty) Text('${e['address']}'), const SizedBox(height: 15),
    ...((e['items'] as List?) ?? []).map((x) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: soft, child: Text('${x['qty']}')), title: Text('${x['item']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Code ${x['code']} • ${x['rentDays']} days'))),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => printIssue(e, store), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Save / Print PDF'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.check), label: const Text('Done')))]),
    const SizedBox(height: 18), const FooterBrand(),
  ]))));
}

Future<void> printIssue(Map<String, dynamic> e, Store store) async {
  final doc = pw.Document();
  final items = (e['items'] as List? ?? []);
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text('RentFlow', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
    pw.Text('By PaliaAPK HUB'), pw.SizedBox(height: 15),
    pw.Text('Invoice: ${e['invoice']}'), pw.Text('Date: ${e['date']}'), pw.Text('Customer: ${e['customerName']}'), pw.Text('Mobile: ${e['mobile']}'), pw.Text('Address: ${e['address']}'), pw.SizedBox(height: 18),
    pw.TableHelper.fromTextArray(headers: const ['Sr.', 'Item', 'Code', 'Qty', 'Rent Days'], data: List.generate(items.length, (i) { final x = items[i]; return ['${i + 1}', '${x['item']}', '${x['code']}', '${x['qty']}', '${x['rentDays']}']; })),
    pw.Spacer(), pw.Text('Developer by shanpalia'),
  ]));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

class ReportsPage extends StatelessWidget {
  final Store store;
  const ReportsPage({required this.store, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [
    Row(children: [StatCard('Issues', '${store.issued.length}', Icons.assignment_outlined), const SizedBox(width: 10), StatCard('Returns', '${store.returns.length}', Icons.keyboard_return_rounded)]), const SizedBox(height: 15),
    ...store.issued.reversed.map((e) => IssueCard(e, onTap: () => showIssuePreview(context, store, e))), const SizedBox(height: 25), const FooterBrand(),
  ]);
}

Future<void> showAbout(BuildContext context) async => showAboutDialog(context: context, applicationName: 'RentFlow', applicationVersion: version, applicationIcon: const Logo(size: 54), children: const [Text('Professional rental and inventory management by PaliaAPK HUB.'), SizedBox(height: 10), Text('Developer by shanpalia')]);

Future<bool> confirmDelete(BuildContext context, String text) async => await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w900)), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))])) ?? false;
