import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE7F6F1);
const pageBg = Color(0xFFF5F8F7);
const ink = Color(0xFF172521);
const line = Color(0xFFD8E5E1);

void startRentFlow() {
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
          scaffoldBackgroundColor: pageBg,
          colorScheme: ColorScheme.fromSeed(seedColor: emerald),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        home: const HomePage(),
      );
}

class RentDb extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String, dynamic>> shops = [];
  int active = 0;
  bool get ready => prefs != null;
  Map<String, dynamic> get shop => shops.isEmpty ? <String, dynamic>{} : shops[active];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_data') ?? '[]');
      if (raw is List) shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      shops = [];
    }
    active = prefs!.getInt('rentflow_active') ?? 0;
    if (active < 0 || active >= shops.length) active = 0;
    notifyListeners();
  }

  Future<void> save() async {
    await prefs?.setString('rentflow_data', jsonEncode(shops));
    await prefs?.setInt('rentflow_active', active);
    notifyListeners();
  }

  List<Map<String, dynamic>> records(String key) {
    final value = shop[key];
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addShop(Map<String, dynamic> data) async {
    shops.add({...data, 'items': [], 'customers': [], 'issues': [], 'returns': []});
    active = shops.length - 1;
    await save();
  }

  Future<void> updateShop(Map<String, dynamic> data) async {
    shop.addAll(data);
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> data) async {
    if (shop[key] is! List) shop[key] = [];
    (shop[key] as List).add(data);
    await save();
  }

  Future<void> editRecord(String key, int index, Map<String, dynamic> data) async {
    (shop[key] as List)[index] = data;
    await save();
  }

  Future<void> stock(String id, int delta) async {
    final list = shop['items'] as List? ?? [];
    for (var i = 0; i < list.length; i++) {
      final item = Map<String, dynamic>.from(list[i] as Map);
      if ('${item['id']}' == id) {
        final q = (int.tryParse('${item['quantity'] ?? 0}') ?? 0) + delta;
        item['quantity'] = q < 0 ? 0 : q;
        list[i] = item;
        break;
      }
    }
    await save();
  }
}

final db = RentDb();
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(dynamic value) => '₹${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';
List<Map<String, dynamic>> maps(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
int rentDays(String issue, String returned) {
  final a = DateTime.tryParse(issue) ?? DateTime.now();
  final b = DateTime.tryParse(returned) ?? DateTime.now();
  final d = b.difference(a).inDays;
  return d < 1 ? 1 : d;
}
void openPage(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

class Header extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const Header({super.key, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => AppBar(
        leading: back ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)) : Builder(builder: (c) => IconButton(onPressed: () => Scaffold.of(c).openDrawer(), icon: const Icon(Icons.menu_rounded, size: 30))),
        title: Row(children: [SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34), const SizedBox(width: 10), const Text('RentFlow by PaliaAPK HUB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: line)),
      );
}

class MenuEntry {
  final String title;
  final IconData icon;
  final Widget page;
  const MenuEntry(this.title, this.icon, this.page);
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  void go(BuildContext context, Widget page) {
    Navigator.pop(context);
    openPage(context, page);
  }
  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                SvgPicture.asset('assets/rentflow_logo.svg', width: 48, height: 48),
                const SizedBox(width: 12),
                const Text('RentFlow\nPaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  MenuEntry('Dashboard', Icons.dashboard_rounded, const HomePage()),
                  MenuEntry('Inventory', Icons.inventory_2_rounded, const ItemsPage()),
                  MenuEntry('Customers / Parties', Icons.people_alt_rounded, const CustomersPage()),
                  MenuEntry('Issued / New Invoice', Icons.outbox_rounded, const IssuePage()),
                  MenuEntry('Returns', Icons.assignment_return_rounded, const ReturnPage()),
                  MenuEntry('Inventory Register', Icons.table_rows_rounded, const InventoryPage()),
                  MenuEntry('Reports / Bills', Icons.receipt_long_rounded, const BillsPage()),
                  MenuEntry('Shop / Company', Icons.store_rounded, const ShopPage()),
                  MenuEntry('Settings / About', Icons.settings_rounded, const SettingsPage()),
                ].map((e) => ListTile(
                      leading: Icon(e.icon, color: emerald),
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => go(context, e.page),
                    )).toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    db.load();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: db,
        builder: (_, __) {
          if (!db.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
          return Scaffold(
            appBar: const Header(),
            drawer: const AppDrawer(),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                shopCard(context),
                const SizedBox(height: 18),
                const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    action('New Invoice', Icons.receipt_long_rounded, () => openPage(context, const IssuePage())),
                    action('Return', Icons.assignment_return_rounded, () => openPage(context, const ReturnPage())),
                    action('Add Item', Icons.add_box_rounded, () => openPage(context, const ItemForm())),
                    action('Add Customer', Icons.person_add_rounded, () => openPage(context, const CustomerForm())),
                    action('Inventory', Icons.inventory_2_rounded, () => openPage(context, const ItemsPage())),
                    action('Reports / Bills', Icons.picture_as_pdf_rounded, () => openPage(context, const BillsPage())),
                  ],
                ),
                const SizedBox(height: 18),
                Row(children: [stat('Items', db.records('items').length, Icons.inventory_2), stat('Parties', db.records('customers').length, Icons.people), stat('Issued', db.records('issues').length, Icons.outbox)]),
                const SizedBox(height: 24),
                const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) {
                setState(() => tab = v);
                if (v == 1) openPage(context, const ItemsPage());
                if (v == 2) openPage(context, const IssuePage());
                if (v == 3) openPage(context, const ReturnPage());
                if (v == 4) openPage(context, const SettingsPage());
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.outbox_outlined), label: 'Issued'),
                NavigationDestination(icon: Icon(Icons.assignment_return_outlined), label: 'Returns'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'About'),
              ],
            ),
          );
        },
      );

  Widget shopCard(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 66,
              height: 66,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(16)),
              child: '${db.shop['image'] ?? ''}'.isNotEmpty ? Image.file(File('${db.shop['image']}'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 34)) : const Icon(Icons.store_rounded, color: emerald, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${db.shop['name'] ?? 'Register your shop'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('${db.shop['owner'] ?? ''}  ${db.shop['mobile'] ?? ''}', style: const TextStyle(color: Colors.black54)), Text('${db.shop['address'] ?? 'Add your shop information'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54))])),
            IconButton(onPressed: () => openPage(context, const ShopPage()), icon: const Icon(Icons.edit_outlined, color: emerald)),
          ]),
        ),
      );

  Widget action(String title, IconData icon, VoidCallback onTap) => ActionCard(title, icon, onTap);
  Widget stat(String title, int count, IconData icon) => Expanded(child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Icon(icon, color: emerald), Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: Colors.black54))]))));
}

class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ActionCard(this.title, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: emerald, size: 30), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))])));
}

class Frame extends StatelessWidget {
  final String title;
  final Widget child;
  const Frame(this.title, this.child, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: const Header(back: true), body: ListView(padding: const EdgeInsets.all(16), children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)), Container(height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(5))), child]));
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboard;
  const Field(this.label, this.controller, {super.key, this.maxLines = 1, this.keyboard});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label)));
}

class SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  const SaveButton(this.label, this.onPressed, {super.key, this.icon = Icons.save_rounded});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Padding(padding: const EdgeInsets.all(12), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))));
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(28), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)));
}
