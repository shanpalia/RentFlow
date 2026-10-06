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

String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(dynamic v) =>
    '₹${(double.tryParse('$v') ?? 0).toStringAsFixed(2)}';
int numInt(dynamic v) => int.tryParse('$v') ?? 0;
double numDouble(dynamic v) => double.tryParse('$v') ?? 0;
List<Map<String, dynamic>> maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
int rentDays(String issue, String returned) {
  final a = DateTime.tryParse(issue) ?? DateTime.now();
  final b = DateTime.tryParse(returned) ?? DateTime.now();
  final d = b.difference(a).inDays;
  return d < 1 ? 1 : d;
}

class RentDb extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String, dynamic>> shops = <Map<String, dynamic>>[];
  int active = 0;
  bool get ready => prefs != null;
  Map<String, dynamic> get shop =>
      shops.isEmpty ? <String, dynamic>{} : shops[active];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_data') ?? '[]');
      shops = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
    } catch (_) {
      shops = <Map<String, dynamic>>[];
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

  List<Map<String, dynamic>> records(String key) => maps(shop[key]);

  Future<void> addShop(Map<String, dynamic> data) async {
    shops.add({
      ...data,
      'items': [],
      'customers': [],
      'issues': [],
      'returns': [],
    });
    active = shops.length - 1;
    await save();
  }

  Future<void> updateShop(Map<String, dynamic> data) async {
    if (shops.isEmpty) return;
    shop.addAll(data);
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> data) async {
    if (shop[key] is! List) shop[key] = <dynamic>[];
    (shop[key] as List).add(data);
    await save();
  }

  Future<void> updateStock(String id, int delta) async {
    final list = shop['items'] as List? ?? <dynamic>[];
    for (var i = 0; i < list.length; i++) {
      final item = Map<String, dynamic>.from(list[i] as Map);
      if ('${item['id']}' == id) {
        item['quantity'] = (numInt(item['quantity']) + delta).clamp(0, 999999);
        list[i] = item;
        break;
      }
    }
    await save();
  }
}

final db = RentDb();

void openPage(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

void snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

void startRentFlow() {
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: emerald),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: line),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Header extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const Header({super.key, this.back = false});

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: back
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : Builder(
              builder: (c) => IconButton(
                onPressed: () => Scaffold.of(c).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 30),
              ),
            ),
      title: Row(
        children: [
          SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'RentFlow by PaliaAPK HUB',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: line),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void go(BuildContext context, Widget page) {
    Navigator.pop(context);
    openPage(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final entries = <Map<String, dynamic>>[
      {'t': 'Dashboard', 'i': Icons.dashboard_rounded, 'p': const HomePage()},
      {
        't': 'Inventory',
        'i': Icons.inventory_2_rounded,
        'p': const ItemsPage(),
      },
      {
        't': 'Customers / Parties',
        'i': Icons.people_alt_rounded,
        'p': const CustomersPage(),
      },
      {
        't': 'Issued / New Invoice',
        'i': Icons.outbox_rounded,
        'p': const IssuePage(),
      },
      {
        't': 'Returns',
        'i': Icons.assignment_return_rounded,
        'p': const ReturnPage(),
      },
      {
        't': 'Inventory Register',
        'i': Icons.table_rows_rounded,
        'p': const InventoryPage(),
      },
      {
        't': 'Reports / Bills',
        'i': Icons.receipt_long_rounded,
        'p': const BillsPage(),
      },
      {'t': 'Shop / Company', 'i': Icons.store_rounded, 'p': const ShopPage()},
      {
        't': 'Settings / About',
        'i': Icons.settings_rounded,
        'p': const SettingsPage(),
      },
    ];
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/rentflow_logo.svg',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'RentFlow\nPaliaAPK HUB',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: entries
                    .map(
                      (e) => ListTile(
                        leading: Icon(e['i'] as IconData, color: emerald),
                        title: Text(
                          e['t'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => go(context, e['p'] as Widget),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'By PaliaAPK HUB • Developer by shanpalia',
                style: TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

  Widget action(String title, IconData icon, VoidCallback onTap) =>
      ActionCard(title, icon, onTap);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) {
        if (!db.ready) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: emerald)),
          );
        }
        return Scaffold(
          appBar: const Header(),
          drawer: const AppDrawer(),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShopInfoCard(onEdit: () => openPage(context, const ShopPage())),
              const SizedBox(height: 18),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  action(
                    'New Invoice',
                    Icons.receipt_long_rounded,
                    () => openPage(context, const IssuePage()),
                  ),
                  action(
                    'Return',
                    Icons.assignment_return_rounded,
                    () => openPage(context, const ReturnPage()),
                  ),
                  action(
                    'Add Item',
                    Icons.add_box_rounded,
                    () => openPage(context, const ItemForm()),
                  ),
                  action(
                    'Add Customer',
                    Icons.person_add_rounded,
                    () => openPage(context, const CustomerForm()),
                  ),
                  action(
                    'Inventory',
                    Icons.inventory_2_rounded,
                    () => openPage(context, const ItemsPage()),
                  ),
                  action(
                    'Reports / Bills',
                    Icons.picture_as_pdf_rounded,
                    () => openPage(context, const BillsPage()),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  StatCard(
                    'Items',
                    db.records('items').length,
                    Icons.inventory_2_rounded,
                  ),
                  StatCard(
                    'Parties',
                    db.records('customers').length,
                    Icons.people_alt_rounded,
                  ),
                  StatCard(
                    'Issued',
                    db.records('issues').length,
                    Icons.outbox_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'RentFlow • By PaliaAPK HUB • Developer by shanpalia',
                  style: TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(Icons.outbox_outlined),
                label: 'Issued',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_return_outlined),
                label: 'Returns',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                label: 'About',
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShopInfoCard extends StatelessWidget {
  final VoidCallback onEdit;
  const ShopInfoCard({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final image = '${db.shop['image'] ?? ''}';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: emeraldSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: image.isNotEmpty
                  ? Image.file(
                      File(image),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.store_rounded,
                        color: emerald,
                        size: 34,
                      ),
                    )
                  : const Icon(Icons.store_rounded, color: emerald, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${db.shop['name'] ?? 'Register your shop'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${db.shop['owner'] ?? ''}  ${db.shop['mobile'] ?? ''}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    '${db.shop['address'] ?? 'Add your shop information'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: emerald),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  const StatCard(this.title, this.count, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: emerald),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ActionCard(this.title, this.icon, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: emerald, size: 30),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class Frame extends StatelessWidget {
  final String title;
  final Widget child;
  const Frame(this.title, this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(back: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: emerald,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboard;
  const Field(
    this.label,
    this.controller, {
    super.key,
    this.maxLines = 1,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  const SaveButton(
    this.label,
    this.onPressed, {
    super.key,
    this.icon = Icons.save_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopState();
}

class _ShopState extends State<ShopPage> {
  final name = TextEditingController();
  final owner = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  String? image;

  @override
  void initState() {
    super.initState();
    name.text = '${db.shop['name'] ?? ''}';
    owner.text = '${db.shop['owner'] ?? ''}';
    mobile.text = '${db.shop['mobile'] ?? ''}';
    address.text = '${db.shop['address'] ?? ''}';
    image = '${db.shop['image'] ?? ''}'.isEmpty ? null : '${db.shop['image']}';
  }

  @override
  void dispose() {
    name.dispose();
    owner.dispose();
    mobile.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => image = x.path);
  }

  Future<void> save() async {
    final data = {
      'name': name.text.trim(),
      'owner': owner.text.trim(),
      'mobile': mobile.text.trim(),
      'address': address.text.trim(),
      'image': image ?? '',
    };
    if (db.shops.isEmpty) {
      await db.addShop(data);
    } else {
      await db.updateShop(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Frame(
      'Shop / Company',
      Column(
        children: [
          Center(
            child: GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: emeraldSoft,
                backgroundImage: image == null ? null : FileImage(File(image!)),
                child: image == null
                    ? const Icon(
                        Icons.add_a_photo_rounded,
                        color: emerald,
                        size: 32,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Field('Shop / Company Name', name),
          Field('Owner Name', owner),
          Field('Mobile', mobile, keyboard: TextInputType.phone),
          Field('Address', address, maxLines: 3),
          SaveButton('Save Shop Information', save),
        ],
      ),
    );
  }
}

class ItemForm extends StatefulWidget {
  final int? index;
  const ItemForm({super.key, this.index});
  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final name = TextEditingController();
  final code = TextEditingController();
  final qty = TextEditingController(text: '0');
  final rent = TextEditingController(text: '15');

  @override
  void initState() {
    super.initState();
    if (widget.index != null) {
      final x = db.records('items')[widget.index!];
      name.text = '${x['name'] ?? ''}';
      code.text = '${x['code'] ?? ''}';
      qty.text = '${x['quantity'] ?? 0}';
      rent.text = '${x['rentPrice'] ?? 15}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    qty.dispose();
    rent.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final data = {
      'id': widget.index == null
          ? uid()
          : db.records('items')[widget.index!]['id'],
      'name': name.text.trim(),
      'code': code.text.trim(),
      'quantity': numInt(qty.text),
      'rentPrice': numDouble(rent.text),
    };
    final list = db.shop['items'] as List? ?? <dynamic>[];
    if (widget.index == null)
      list.add(data);
    else
      list[widget.index!] = data;
    db.shop['items'] = list;
    await db.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Frame(
    'Add / Edit Item',
    Column(
      children: [
        Field('Item Name', name),
        Field('Item Code', code),
        Field('Stock Quantity', qty, keyboard: TextInputType.number),
        Field(
          'Rent Price / 100',
          rent,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Example: ₹15 per 100 • rent is calculated on returned quantity and numeric rent days.',
            ),
          ),
        ),
        SaveButton('Save Item', save),
      ],
    ),
  );
}

class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = db.records('items');
    return Frame(
      'Inventory',
      Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Items / Stock',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Add Item',
                onPressed: () => openPage(context, const ItemForm()),
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: emerald,
                  size: 34,
                ),
              ),
            ],
          ),
          if (items.isEmpty)
            const EmptyState('No items yet. Tap + to add an item.'),
          ...items.asMap().entries.map(
            (e) => Card(
              elevation: 0,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: emeraldSoft,
                  child: Icon(Icons.inventory_2_rounded, color: emerald),
                ),
                title: Text(
                  '${e.value['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Code ${e.value['code'] ?? ''} • Rent ${money(e.value['rentPrice'])}/100',
                ),
                trailing: Text(
                  '${e.value['quantity'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () => openPage(context, ItemForm(index: e.key)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerForm extends StatefulWidget {
  final int? index;
  const CustomerForm({super.key, this.index});
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.index != null) {
      final x = db.records('customers')[widget.index!];
      name.text = '${x['name'] ?? ''}';
      mobile.text = '${x['mobile'] ?? ''}';
      address.text = '${x['address'] ?? ''}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final list = db.shop['customers'] as List? ?? <dynamic>[];
    final data = {
      'id': widget.index == null
          ? uid()
          : db.records('customers')[widget.index!]['id'],
      'name': name.text.trim(),
      'mobile': mobile.text.trim(),
      'address': address.text.trim(),
    };
    if (widget.index == null)
      list.add(data);
    else
      list[widget.index!] = data;
    db.shop['customers'] = list;
    await db.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Frame(
    'Add / Edit Party',
    Column(
      children: [
        Field('Party / Customer Name', name),
        Field('Mobile', mobile, keyboard: TextInputType.phone),
        Field('Address', address, maxLines: 3),
        SaveButton('Save Customer', save),
      ],
    ),
  );
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final a = db.records('customers');
    return Frame(
      'Customers / Parties',
      Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Party Master',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Add Customer',
                onPressed: () => openPage(context, const CustomerForm()),
                icon: const Icon(
                  Icons.person_add_rounded,
                  color: emerald,
                  size: 32,
                ),
              ),
            ],
          ),
          if (a.isEmpty) const EmptyState('No parties. Tap + to add.'),
          ...a.asMap().entries.map(
            (e) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.person_rounded, color: emerald),
                title: Text(
                  '${e.value['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${e.value['mobile'] ?? ''}\n${e.value['address'] ?? ''}',
                ),
                onTap: () => openPage(context, CustomerForm(index: e.key)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IssuePage extends StatefulWidget {
  const IssuePage({super.key});
  @override
  State<IssuePage> createState() => _IssueState();
}

class _IssueState extends State<IssuePage> {
  String? customer;
  final invoice = TextEditingController();
  final rows = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    invoice.text = 'INV-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    invoice.dispose();
    super.dispose();
  }

  void addRow() {
    final items = db.records('items');
    if (items.isEmpty) return;
    final x = items.first;
    setState(
      () => rows.add({
        'itemId': x['id'],
        'name': x['name'],
        'qty': 1,
        'rentPrice': x['rentPrice'] ?? 15,
      }),
    );
  }

  Future<void> save() async {
    if (customer == null || rows.isEmpty) {
      snack(context, 'Select a party and at least one item.');
      return;
    }
    await db.addRecord('issues', {
      'id': uid(),
      'invoice': invoice.text.trim(),
      'customerId': customer,
      'issueDate': today(),
      'items': rows.map((e) => Map<String, dynamic>.from(e)).toList(),
    });
    for (final x in rows)
      await db.updateStock('${x['itemId']}', -numInt(x['qty']));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customers = db.records('customers');
    final items = db.records('items');
    return Frame(
      'Issued / New Invoice',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: customer,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Party',
                  ),
                  items: customers
                      .map(
                        (x) => DropdownMenuItem(
                          value: '${x['id']}',
                          child: Text('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => customer = v),
                ),
              ),
              IconButton(
                tooltip: 'Add Customer',
                onPressed: () => openPage(context, const CustomerForm()),
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: emerald,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Field('Invoice Number', invoice),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final x = e.value;
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: '${x['itemId']}',
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: items
                            .map(
                              (z) => DropdownMenuItem(
                                value: '${z['id']}',
                                child: Text('${z['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          final z = items.firstWhere((q) => '${q['id']}' == v);
                          setState(() {
                            x['itemId'] = v;
                            x['name'] = z['name'];
                            x['rentPrice'] = z['rentPrice'] ?? 15;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 78,
                      child: TextFormField(
                        initialValue: '${x['qty']}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                        onChanged: (v) => x['qty'] = numInt(v),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => rows.removeAt(i)),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: addRow,
            icon: const Icon(Icons.add_circle, color: emerald),
            label: const Text('Add Another Item'),
          ),
          SaveButton('Save Issued Invoice', save),
        ],
      ),
    );
  }
}

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});
  @override
  State<ReturnPage> createState() => _ReturnState();
}

class _ReturnState extends State<ReturnPage> {
  String? customer;
  Map<String, dynamic>? issue;
  final selected = <String, int>{};
  final manual = TextEditingController();

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (issue == null) {
      snack(context, 'Select an issued invoice.');
      return;
    }
    final returned = today();
    final days = rentDays('${issue!['issueDate']}', returned);
    final out = <Map<String, dynamic>>[];
    double total = 0;
    for (final x in maps(issue!['items'])) {
      final q = selected['${x['itemId']}'] ?? 0;
      if (q <= 0) continue;
      final r = numDouble(x['rentPrice'] ?? 15);
      final amount = r * q * days / 100;
      total += amount;
      out.add({
        'itemId': x['itemId'],
        'name': x['name'],
        'issuedQty': numInt(x['qty']),
        'returnQty': q,
        'rentPrice': r,
        'rentDays': days,
        'amount': amount,
      });
      await db.updateStock('${x['itemId']}', q);
    }
    if (out.isEmpty) {
      snack(context, 'Enter return quantity for at least one item.');
      return;
    }
    final m = double.tryParse(manual.text.trim());
    if (m != null) total = m;
    await db.addRecord('returns', {
      'id': uid(),
      'returnInvoice': 'RET-${DateTime.now().millisecondsSinceEpoch}',
      'customerId': customer,
      'issueInvoice': issue!['invoice'],
      'issueDate': issue!['issueDate'],
      'returnDate': returned,
      'rentDays': days,
      'amount': total,
      'items': out,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customers = db.records('customers');
    final issues = db.records('issues');
    final items = issue == null
        ? <Map<String, dynamic>>[]
        : maps(issue!['items']);
    return Frame(
      'Return / Receive',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: customer,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Party',
                  ),
                  items: customers
                      .map(
                        (x) => DropdownMenuItem(
                          value: '${x['id']}',
                          child: Text('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    customer = v;
                    issue = null;
                    selected.clear();
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Add Customer',
                onPressed: () => openPage(context, const CustomerForm()),
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: emerald,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: issue?['id']?.toString(),
            decoration: const InputDecoration(labelText: 'Issued Invoice'),
            items: issues
                .where(
                  (x) => customer == null || '${x['customerId']}' == customer,
                )
                .map(
                  (x) => DropdownMenuItem(
                    value: '${x['id']}',
                    child: Text('${x['invoice']} • ${x['issueDate']}'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final x = issues.firstWhere((q) => '${q['id']}' == v);
              setState(() {
                issue = x;
                selected.clear();
              });
            },
          ),
          if (issue != null) ...[
            const SizedBox(height: 12),
            Text(
              'Issued date: ${issue!['issueDate']} • Return date: ${today()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (x) => ReturnItemCard(
                item: x,
                selectedQty: selected['${x['itemId']}'] ?? 0,
                issueDate: '${issue!['issueDate']}',
                onChanged: (q) =>
                    setState(() => selected['${x['itemId']}'] = q),
              ),
            ),
            Field(
              'Manual Return Amount (optional)',
              manual,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            SaveButton('Save Return & Receipt', save),
          ],
        ],
      ),
    );
  }
}

class ReturnItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int selectedQty;
  final String issueDate;
  final ValueChanged<int> onChanged;
  const ReturnItemCard({
    super.key,
    required this.item,
    required this.selectedQty,
    required this.issueDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final max = numInt(item['qty']);
    final r = numDouble(item['rentPrice'] ?? 15);
    final days = rentDays(issueDate, today());
    final amount = r * selectedQty * days / 100;
    return Card(
      elevation: 0,
      color: selectedQty > 0 ? emeraldSoft : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              selectedQty > 0 ? Icons.check_circle : Icons.inventory_2_outlined,
              color: emerald,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text('Issued Qty $max • Rent ${money(r)}/100'),
                  Text(
                    'Rent Days $days • Amount ${money(amount)}',
                    style: const TextStyle(
                      color: emeraldDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 78,
              child: TextFormField(
                initialValue: selectedQty == 0 ? '' : '$selectedQty',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Return',
                  hintText: '0-$max',
                ),
                onChanged: (v) => onChanged((numInt(v)).clamp(0, max)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final items = db.records('items');
    final issues = db.records('issues');
    final returned = db.records('returns');
    final issuedByItem = <String, int>{};
    final returnedByItem = <String, int>{};
    for (final i in issues)
      for (final x in maps(i['items'])) {
        issuedByItem['${x['itemId']}'] =
            (issuedByItem['${x['itemId']}'] ?? 0) + numInt(x['qty']);
      }
    for (final r in returned)
      for (final x in maps(r['items'])) {
        returnedByItem['${x['itemId']}'] =
            (returnedByItem['${x['itemId']}'] ?? 0) + numInt(x['returnQty']);
      }
    return Frame(
      'Inventory Register',
      Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Current Stock • Issued • Returned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty) const EmptyState('No inventory records.'),
          ...items.map(
            (x) => Card(
              elevation: 0,
              child: ListTile(
                title: Text(
                  '${x['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Stock ${x['quantity'] ?? 0} • Issued ${issuedByItem['${x['id']}'] ?? 0} • Returned ${returnedByItem['${x['id']}'] ?? 0} • Rent ${money(x['rentPrice'])}/100',
                ),
                trailing: Text(
                  '${x['quantity'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: emerald,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String partyName(String? id) {
  for (final x in db.records('customers'))
    if ('${x['id']}' == id) return '${x['name']}';
  return 'Party';
}

Future<void> showBill(
  BuildContext context,
  Map<String, dynamic> record, {
  bool isReturn = false,
}) async {
  final doc = pw.Document();
  final items = maps(record['items']);
  doc.addPage(
    pw.MultiPage(
      build: (c) => [
        pw.Text(
          db.shop['name']?.toString().isNotEmpty == true
              ? '${db.shop['name']}'
              : 'RentFlow',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('${db.shop['address'] ?? ''}  ${db.shop['mobile'] ?? ''}'),
        pw.Divider(),
        pw.Text(
          isReturn ? 'RETURN RECEIPT' : 'ISSUED INVOICE',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Party: ${partyName('${record['customerId']}')}'),
        pw.Text('Invoice: ${record[isReturn ? 'returnInvoice' : 'invoice']}'),
        if (isReturn)
          pw.Text(
            'Issued Date: ${record['issueDate']}    Return Date: ${record['returnDate']}    Rent Days: ${record['rentDays']}',
          ),
        if (!isReturn) pw.Text('Issued Date: ${record['issueDate']}'),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: isReturn
              ? ['Item', 'Issued', 'Return', 'Rent/100', 'Days', 'Amount']
              : ['Item', 'Qty', 'Rent/100'],
          data: items
              .map(
                (x) => isReturn
                    ? [
                        '${x['name']}',
                        '${x['issuedQty']}',
                        '${x['returnQty']}',
                        money(x['rentPrice']),
                        '${x['rentDays']}',
                        money(x['amount']),
                      ]
                    : ['${x['name']}', '${x['qty']}', money(x['rentPrice'])],
              )
              .toList(),
        ),
        if (isReturn) ...[
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL: ${money(record['amount'])}',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
        pw.SizedBox(height: 28),
        pw.Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia'),
      ],
    ),
  );
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PdfPreviewPage(
        document: doc,
        title: isReturn ? 'Return Receipt' : 'Issued Invoice',
      ),
    ),
  );
}

class PdfPreviewPage extends StatelessWidget {
  final pw.Document document;
  final String title;
  const PdfPreviewPage({
    super.key,
    required this.document,
    required this.title,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PdfPreview(
      build: (format) => document.save(),
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: true,
      allowSharing: true,
    ),
  );
}

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final issues = db.records('issues');
    final returns = db.records('returns');
    return Frame(
      'Reports / Bills',
      Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ISSUED BILLS',
              style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark),
            ),
          ),
          ...issues.map(
            (x) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: emerald),
                title: Text(
                  '${x['invoice']} • ${partyName('${x['customerId']}')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Issued ${x['issueDate']} • ${maps(x['items']).length} item(s)',
                ),
                trailing: IconButton(
                  tooltip: 'Preview / Print PDF',
                  onPressed: () => showBill(context, x),
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: emerald,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'RETURN RECEIPTS',
              style: TextStyle(fontWeight: FontWeight.w900, color: emeraldDark),
            ),
          ),
          ...returns.map(
            (x) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(
                  Icons.assignment_return_rounded,
                  color: emerald,
                ),
                title: Text(
                  '${x['returnInvoice']} • ${partyName('${x['customerId']}')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Issued ${x['issueDate']} • Return ${x['returnDate']} • ${x['rentDays']} days • ${money(x['amount'])}',
                ),
                trailing: IconButton(
                  tooltip: 'Preview / Print PDF',
                  onPressed: () => showBill(context, x, isReturn: true),
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: emerald,
                  ),
                ),
              ),
            ),
          ),
          if (issues.isEmpty && returns.isEmpty)
            const EmptyState('No bills yet. Create an invoice first.'),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Frame(
    'Settings / About',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.store_rounded, color: emerald),
            title: Text(
              '${db.shop['name'] ?? 'RentFlow'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Shop / Company information'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded, color: emerald),
            title: Text(
              'RentFlow',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'Rental management • Bills • Inventory • Returns\nBy PaliaAPK HUB • Developer by shanpalia',
            ),
          ),
        ),
      ],
    ),
  );
}
