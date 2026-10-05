import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color primary = Color(0xFF009E83);
const Color dark = Color(0xFF10241F);
const Color bg = Color(0xFFF4F8F6);
const Color border = Color(0xFFD8E4E0);
const Color soft = Color(0xFFE4F5F0);

Future<void> startRentFlow() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentFlowApp());
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);

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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
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
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SvgPicture.asset('assets/rentflow_splash.svg', width: 360),
        ),
      ),
    );
  }
}

class RentStore extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String, dynamic>> shops = [];
  int activeShop = 0;

  bool get hasShop => shops.isNotEmpty;
  Map<String, dynamic> get shop => hasShop ? shops[activeShop] : <String, dynamic>{};

  List<Map<String, dynamic>> list(String key) {
    if (!hasShop) return <Map<String, dynamic>>[];
    final value = shop[key];
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get items => list('items');
  List<Map<String, dynamic>> get customers => list('customers');
  List<Map<String, dynamic>> get issued => list('issued');
  List<Map<String, dynamic>> get returns => list('returns');

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_shops') ?? '[]');
      if (raw is List) {
        shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      shops = [];
    }
    activeShop = prefs!.getInt('rentflow_active_shop') ?? 0;
    if (shops.isEmpty) activeShop = 0;
    if (shops.isNotEmpty && activeShop >= shops.length) activeShop = shops.length - 1;
    notifyListeners();
  }

  Future<void> save() async {
    if (prefs == null) return;
    await prefs!.setString('rentflow_shops', jsonEncode(shops));
    await prefs!.setInt('rentflow_active_shop', activeShop);
    notifyListeners();
  }

  Map<String, dynamic> shopData(String name, String owner, String mobile, String address) {
    return {
      'id': newId(),
      'name': name,
      'owner': owner,
      'mobile': mobile,
      'address': address,
      'items': <Map<String, dynamic>>[],
      'customers': <Map<String, dynamic>>[],
      'issued': <Map<String, dynamic>>[],
      'returns': <Map<String, dynamic>>[],
    };
  }

  Future<void> addShop(String name, String owner, String mobile, String address) async {
    shops.add(shopData(name, owner, mobile, address));
    activeShop = shops.length - 1;
    await save();
  }

  Future<void> updateShop(String name, String owner, String mobile, String address) async {
    if (!hasShop) return;
    shop['name'] = name;
    shop['owner'] = owner;
    shop['mobile'] = mobile;
    shop['address'] = address;
    await save();
  }

  Future<void> deleteShop(int index) async {
    if (index < 0 || index >= shops.length) return;
    shops.removeAt(index);
    if (shops.isEmpty) {
      activeShop = 0;
    } else if (activeShop >= shops.length) {
      activeShop = shops.length - 1;
    }
    await save();
  }

  Future<void> selectShop(int index) async {
    if (index < 0 || index >= shops.length) return;
    activeShop = index;
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> value) async {
    if (!hasShop) return;
    final valueList = shop[key];
    if (valueList is List) {
      valueList.add(value);
      await save();
    }
  }

  Future<void> updateRecord(String key, int index, Map<String, dynamic> value) async {
    if (!hasShop) return;
    final valueList = shop[key];
    if (valueList is List && index >= 0 && index < valueList.length) {
      valueList[index] = value;
      await save();
    }
  }

  Future<void> deleteRecord(String key, int index) async {
    if (!hasShop) return;
    final valueList = shop[key];
    if (valueList is List && index >= 0 && index < valueList.length) {
      valueList.removeAt(index);
      await save();
    }
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final RentStore store = RentStore();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => HomePage(store: store),
    );
  }
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const AppHeader({super.key, this.back = true});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: back,
      backgroundColor: bg,
      surfaceTintColor: bg,
      elevation: 0,
      titleSpacing: back ? 0 : 18,
      title: Row(
        children: [
          SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34),
          const SizedBox(width: 10),
          const Text(
            'RentFlow',
            style: TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(width: 7),
          const Text(
            'by PaliaAPK HUB',
            style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ErpPage extends StatelessWidget {
  final String title;
  final Widget child;
  const ErpPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text(title, style: const TextStyle(color: dark, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Container(height: 3, width: 48, alignment: Alignment.centerLeft, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

void openPage(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class HomePage extends StatelessWidget {
  final RentStore store;
  const HomePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final modules = <_MenuItem>[
      _MenuItem('Issue Entry', 'Issue rental / delivery', Icons.outbox_outlined, () => openPage(context, IssuePage(store: store))),
      _MenuItem('Return Entry', 'Return issued items', Icons.assignment_return_outlined, () => openPage(context, ReturnPage(store: store))),
      _MenuItem('Item Master', 'Inventory and rental items', Icons.inventory_2_outlined, () => openPage(context, ItemsPage(store: store))),
      _MenuItem('Customer / Party', 'Customer master', Icons.people_alt_outlined, () => openPage(context, CustomersPage(store: store))),
      _MenuItem('Reports', 'Issue and return reports', Icons.assessment_outlined, () => openPage(context, ReportsPage(store: store))),
      _MenuItem('Shop / Company', 'Add, edit or delete shop', Icons.store_outlined, () => openPage(context, ShopsPage(store: store))),
      _MenuItem('Settings', 'Update and about', Icons.settings_outlined, () => openPage(context, SettingsPage(store: store))),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Row(
              children: [
                SvgPicture.asset('assets/rentflow_logo.svg', width: 46, height: 46),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RentFlow', style: TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)),
                      Text('by PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => openPage(context, SettingsPage(store: store)), icon: const Icon(Icons.settings_outlined, color: dark)),
              ],
            ),
            const SizedBox(height: 20),
            _ShopBanner(store: store),
            const SizedBox(height: 20),
            const Text('MAIN MENU', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            for (final item in modules) _MenuCard(item: item),
            const SizedBox(height: 14),
            const Center(child: Text('Developer by ShanPalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _ShopBanner extends StatelessWidget {
  final RentStore store;
  const _ShopBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    if (!store.hasShop) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: border)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const CircleAvatar(radius: 25, backgroundColor: soft, child: Icon(Icons.store_outlined, color: primary)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No shop registered', style: TextStyle(color: dark, fontSize: 17, fontWeight: FontWeight.w900)), Text('Register your shop to start entries.', style: TextStyle(color: Colors.black54))])),
            FilledButton(onPressed: () => openPage(context, ShopFormPage(store: store)), child: const Text('Register')),
          ]),
        ),
      );
    }
    return Card(
      elevation: 0,
      color: dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const CircleAvatar(radius: 25, backgroundColor: soft, child: Icon(Icons.store_outlined, color: primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${store.shop['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text('${store.shop['address'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))])),
          IconButton(onPressed: () => openPage(context, ShopsPage(store: store)), icon: const Icon(Icons.chevron_right, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _MenuItem(this.title, this.subtitle, this.icon, this.onTap);
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(15)), child: Icon(item.icon, color: primary, size: 25)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 3), Text(item.subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12))])),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}

class ShopFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ShopFormPage({super.key, required this.store, this.index});

  @override
  State<ShopFormPage> createState() => _ShopFormPageState();
}

class _ShopFormPageState extends State<ShopFormPage> {
  late TextEditingController name;
  late TextEditingController owner;
  late TextEditingController mobile;
  late TextEditingController address;

  @override
  void initState() {
    super.initState();
    final x = widget.index == null ? <String, dynamic>{} : widget.store.shops[widget.index!];
    name = TextEditingController(text: '${x['name'] ?? ''}');
    owner = TextEditingController(text: '${x['owner'] ?? ''}');
    mobile = TextEditingController(text: '${x['mobile'] ?? ''}');
    address = TextEditingController(text: '${x['address'] ?? ''}');
  }

  @override
  void dispose() {
    name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    if (widget.index == null) {
      await widget.store.addShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim());
    } else if (widget.index == widget.store.activeShop) {
      await widget.store.updateShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim());
    } else {
      final x = widget.store.shops[widget.index!];
      x['name'] = name.text.trim(); x['owner'] = owner.text.trim(); x['mobile'] = mobile.text.trim(); x['address'] = address.text.trim();
      await widget.store.save();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(
      title: widget.index == null ? 'Register Shop / Company' : 'Edit Shop / Company',
      child: Column(children: [
        _Field(label: 'Shop / Company Name', controller: name),
        _Field(label: 'Owner Name', controller: owner),
        _Field(label: 'Mobile Number', controller: mobile, number: true),
        _Field(label: 'Shop Address', controller: address, maxLines: 3),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: Text(widget.index == null ? 'Register Shop' : 'Update Shop'))),
      ]),
    );
  }
}

class ShopsPage extends StatelessWidget {
  final RentStore store;
  const ShopsPage({super.key, required this.store});

  Future<void> delete(BuildContext context, int index) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete shop?'), content: const Text('This removes the shop and its local records.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok == true) await store.deleteShop(index);
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(
      title: 'Shop / Company Master',
      child: Column(children: [
        for (int i = 0; i < store.shops.length; i++)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: i == store.activeShop ? primary : border, width: i == store.activeShop ? 1.5 : 1)),
            child: ListTile(
              onTap: () => store.selectShop(i),
              leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.store_outlined, color: primary)),
              title: Text('${store.shops[i]['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)),
              subtitle: Text('${store.shops[i]['owner'] ?? ''} • ${store.shops[i]['mobile'] ?? ''}\n${store.shops[i]['address'] ?? ''}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') openPage(context, ShopFormPage(store: store, index: i)); if (value == 'delete') delete(context, i); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
            ),
          ),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, ShopFormPage(store: store)), icon: const Icon(Icons.add_business), label: const Text('Add New Shop'))),
      ]),
    );
  }
}

class ItemsPage extends StatelessWidget {
  final RentStore store;
  const ItemsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(
      title: 'Item Master / Inventory',
      child: Column(children: [
        if (store.items.isEmpty) const _Empty(text: 'No inventory items. Add your first item.')
        else for (int i = 0; i < store.items.length; i++) _Record(title: '${store.items[i]['name']}', subtitle: 'Code ${store.items[i]['code'] ?? '-'} • ${store.items[i]['unit'] ?? 'pcs'} • Qty ${store.items[i]['quantity'] ?? 0}', onEdit: () => openPage(context, ItemFormPage(store: store, index: i)), onDelete: () => store.deleteRecord('items', i)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, ItemFormPage(store: store)), icon: const Icon(Icons.add), label: const Text('Add Another Item'))),
      ]),
    );
  }
}

class ItemFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ItemFormPage({super.key, required this.store, this.index});

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  late TextEditingController code, name, unit, quantity;

  @override
  void initState() {
    super.initState();
    final x = widget.index == null ? <String, dynamic>{} : widget.store.items[widget.index!];
    code = TextEditingController(text: '${x['code'] ?? ''}');
    name = TextEditingController(text: '${x['name'] ?? ''}');
    unit = TextEditingController(text: '${x['unit'] ?? 'pcs'}');
    quantity = TextEditingController(text: '${x['quantity'] ?? 0}');
  }

  @override
  void dispose() { code.dispose(); name.dispose(); unit.dispose(); quantity.dispose(); super.dispose(); }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final old = widget.index == null ? null : widget.store.items[widget.index!];
    final value = {'id': old?['id'] ?? newId(), 'code': code.text.trim(), 'name': name.text.trim(), 'unit': unit.text.trim(), 'quantity': int.tryParse(quantity.text) ?? 0};
    if (widget.index == null) await widget.store.addRecord('items', value); else await widget.store.updateRecord('items', widget.index!, value);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: widget.index == null ? 'New Inventory Item' : 'Edit Inventory Item', child: Column(children: [
      _Field(label: 'Item Code', controller: code),
      _Field(label: 'Item Name / Description', controller: name),
      Row(children: [Expanded(child: _Field(label: 'Unit', controller: unit)), const SizedBox(width: 10), Expanded(child: _Field(label: 'Opening Quantity', controller: quantity, number: true))]),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Item'))),
    ]));
  }
}

class CustomersPage extends StatelessWidget {
  final RentStore store;
  const CustomersPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Customer / Party Master', child: Column(children: [
      if (store.customers.isEmpty) const _Empty(text: 'No customers. Add as many parties as required.')
      else for (int i = 0; i < store.customers.length; i++) _Record(title: '${store.customers[i]['name']}', subtitle: '${store.customers[i]['mobile'] ?? ''} • ${store.customers[i]['address'] ?? ''}', onEdit: () => openPage(context, CustomerFormPage(store: store, index: i)), onDelete: () => store.deleteRecord('customers', i)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, CustomerFormPage(store: store)), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add Another Customer'))),
    ]));
  }
}

class CustomerFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const CustomerFormPage({super.key, required this.store, this.index});

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  late TextEditingController name, mobile, address;

  @override
  void initState() {
    super.initState();
    final x = widget.index == null ? <String, dynamic>{} : widget.store.customers[widget.index!];
    name = TextEditingController(text: '${x['name'] ?? ''}');
    mobile = TextEditingController(text: '${x['mobile'] ?? ''}');
    address = TextEditingController(text: '${x['address'] ?? ''}');
  }

  @override
  void dispose() { name.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final old = widget.index == null ? null : widget.store.customers[widget.index!];
    final value = {'id': old?['id'] ?? newId(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()};
    if (widget.index == null) await widget.store.addRecord('customers', value); else await widget.store.updateRecord('customers', widget.index!, value);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ErpPage(title: widget.index == null ? 'New Customer / Party' : 'Edit Customer / Party', child: Column(children: [_Field(label: 'Customer / Party Name', controller: name), _Field(label: 'Mobile Number', controller: mobile, number: true), _Field(label: 'Address', controller: address, maxLines: 3), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Customer')))]));
}

class IssuePage extends StatefulWidget {
  final RentStore store;
  const IssuePage({super.key, required this.store});

  @override
  State<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends State<IssuePage> {
  late TextEditingController invoice, date, address;
  String? customerId;
  final List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    invoice = TextEditingController(text: 'RF-${DateTime.now().millisecondsSinceEpoch}');
    date = TextEditingController(text: today());
    address = TextEditingController();
  }

  @override
  void dispose() { invoice.dispose(); date.dispose(); address.dispose(); super.dispose(); }

  String customerName() {
    for (final customer in widget.store.customers) {
      if ('${customer['id']}' == customerId) return '${customer['name']}';
    }
    return 'Select Customer / Party';
  }

  Future<void> pickCustomer() async {
    final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => CustomerPickerPage(store: widget.store)));
    if (x != null) setState(() { customerId = '${x['id']}'; address.text = '${x['address'] ?? ''}'; });
  }

  Future<void> addItem() async {
    final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ItemPickerPage(store: widget.store)));
    if (x != null) setState(() => entries.add({'itemId': x['id'], 'name': x['name'], 'unit': x['unit'] ?? 'pcs', 'quantity': 1, 'rentDays': 1}));
  }

  Future<void> save() async {
    if (customerId == null || entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select customer and add at least one item.')));
      return;
    }
    await widget.store.addRecord('issued', {'id': newId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'customerId': customerId, 'customer': customerName(), 'address': address.text.trim(), 'lines': entries.map((e) => Map<String, dynamic>.from(e)).toList()});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Issue Entry', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: _Field(label: 'Invoice / Issue No.', controller: invoice)), const SizedBox(width: 10), Expanded(child: _Field(label: 'Date', controller: date))]),
      InkWell(onTap: pickCustomer, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(labelText: 'Customer / Party'), child: Row(children: [Expanded(child: Text(customerName(), style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), const Icon(Icons.arrow_drop_down)]))),
      const SizedBox(height: 12),
      _Field(label: 'Party / Site Address', controller: address, maxLines: 2),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('INVENTORY ENTRIES', style: TextStyle(color: primary, fontWeight: FontWeight.w900, letterSpacing: 1)), FilledButton.icon(onPressed: addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'))]),
      const SizedBox(height: 8),
      if (entries.isEmpty) const _Empty(text: 'Add multiple inventory lines. You can keep adding items.'),
      for (int i = 0; i < entries.length; i++) IssueLineCard(entry: entries[i], onDelete: () => setState(() => entries.removeAt(i)), onChanged: (v) => setState(() => entries[i] = v)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Issue Entry'))),
    ]));
  }
}

class IssueLineCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const IssueLineCard({super.key, required this.entry, required this.onDelete, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 9), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: border)), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.inventory_2_outlined, color: primary)), const SizedBox(width: 10), Expanded(child: Text('${entry['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900))), IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]),
      Row(children: [Expanded(child: _InlineNumber(label: 'Quantity', value: '${entry['quantity'] ?? 1}', onChanged: (v) => onChanged({...entry, 'quantity': int.tryParse(v) ?? 1}))), const SizedBox(width: 8), Expanded(child: _InlineNumber(label: 'Rent Days', value: '${entry['rentDays'] ?? 1}', onChanged: (v) => onChanged({...entry, 'rentDays': int.tryParse(v) ?? 1})))])
    ])));
  }
}

class _InlineNumber extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _InlineNumber({required this.label, required this.value, required this.onChanged});

  @override
  State<_InlineNumber> createState() => _InlineNumberState();
}

class _InlineNumberState extends State<_InlineNumber> {
  late TextEditingController controller;
  @override
  void initState() { super.initState(); controller = TextEditingController(text: widget.value); }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.label), onChanged: widget.onChanged);
}

class CustomerPickerPage extends StatelessWidget {
  final RentStore store;
  const CustomerPickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Customer / Party', child: Column(children: [if (store.customers.isEmpty) const _Empty(text: 'No customers found.') else for (final x in store.customers) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)), child: ListTile(onTap: () => Navigator.pop(context, x), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.person_outline, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${x['mobile'] ?? ''} • ${x['address'] ?? ''}'), trailing: const Icon(Icons.chevron_right)))]));
}

class ItemPickerPage extends StatelessWidget {
  final RentStore store;
  const ItemPickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Inventory Item', child: Column(children: [if (store.items.isEmpty) const _Empty(text: 'No inventory items found.') else for (final x in store.items) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)), child: ListTile(onTap: () => Navigator.pop(context, x), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('Code ${x['code'] ?? '-'} • Qty ${x['quantity'] ?? 0}'), trailing: const Icon(Icons.add_circle_outline, color: primary)))]));
}

class ReturnPage extends StatefulWidget {
  final RentStore store;
  const ReturnPage({super.key, required this.store});
  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  int? selectedIndex;
  late TextEditingController invoice, date, amount, note;

  @override
  void initState() { super.initState(); invoice = TextEditingController(); date = TextEditingController(text: today()); amount = TextEditingController(); note = TextEditingController(); }
  @override
  void dispose() { invoice.dispose(); date.dispose(); amount.dispose(); note.dispose(); super.dispose(); }

  Map<String, dynamic>? get selected => selectedIndex == null ? null : widget.store.issued[selectedIndex!];

  Future<void> chooseIssued() async {
    final x = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => IssuedPickerPage(store: widget.store)));
    if (x != null) setState(() { selectedIndex = x; invoice.text = '${widget.store.issued[x]['invoice'] ?? ''}'; });
  }

  Future<void> save() async {
    if (selected == null) return;
    await widget.store.addRecord('returns', {'id': newId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'originalIssue': selected!['id'], 'customer': selected!['customer'], 'amount': double.tryParse(amount.text) ?? 0, 'note': note.text.trim(), 'lines': selected!['lines'] ?? []});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final issue = selected;
    return ErpPage(title: 'Return Entry', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(onTap: chooseIssued, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(labelText: 'Issued Invoice'), child: Row(children: [Expanded(child: Text(issue == null ? 'Select issued entry' : '${issue['invoice']} • ${issue['customer']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), const Icon(Icons.arrow_drop_down)]))),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _Field(label: 'Return Invoice / No.', controller: invoice)), const SizedBox(width: 10), Expanded(child: _Field(label: 'Return Date', controller: date))]),
      _Field(label: 'Return Amount (manual)', controller: amount, number: true),
      _Field(label: 'Return Note', controller: note, maxLines: 2),
      const SizedBox(height: 8),
      if (issue != null) ...[
        const Text('ITEMS FROM ISSUE', style: TextStyle(color: primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        ...((issue['lines'] is List ? issue['lines'] as List : const []).map<Widget>((raw) { final x = Map<String, dynamic>.from(raw as Map); return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 7), child: ListTile(leading: const Icon(Icons.inventory_2_outlined, color: primary), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Issued Qty ${x['quantity'] ?? 1} • Rent Days ${x['rentDays'] ?? 1}'))); })),
      ],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: issue == null ? null : save, icon: const Icon(Icons.assignment_return_outlined), label: const Text('Save Return'))),
    ]));
  }
}

class IssuedPickerPage extends StatelessWidget {
  final RentStore store;
  const IssuedPickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Issued Entry', child: Column(children: [if (store.issued.isEmpty) const _Empty(text: 'No issued entries found.') else for (int i = 0; i < store.issued.length; i++) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), child: ListTile(onTap: () => Navigator.pop(context, i), leading: const Icon(Icons.outbox_outlined, color: primary), title: Text('${store.issued[i]['invoice']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${store.issued[i]['customer']} • ${store.issued[i]['date']}'), trailing: const Icon(Icons.chevron_right)))]));
}

class ReportsPage extends StatelessWidget {
  final RentStore store;
  const ReportsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Reports', child: Column(children: [
    _ReportBox(title: 'Issued Register', count: store.issued.length, icon: Icons.outbox_outlined, onTap: () => openPage(context, IssueReportPage(store: store))),
    _ReportBox(title: 'Return Register', count: store.returns.length, icon: Icons.assignment_return_outlined, onTap: () => openPage(context, ReturnReportPage(store: store))),
    _ReportBox(title: 'Inventory Summary', count: store.items.length, icon: Icons.inventory_2_outlined, onTap: () => openPage(context, ItemsPage(store: store))),
    _ReportBox(title: 'Customer Register', count: store.customers.length, icon: Icons.people_alt_outlined, onTap: () => openPage(context, CustomersPage(store: store))),
  ]));
}

class _ReportBox extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  const _ReportBox({required this.title, required this.count, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: border)), child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: soft, child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), trailing: Text('$count', style: const TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w900))));
}

class IssueReportPage extends StatelessWidget {
  final RentStore store;
  const IssueReportPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Issued Register', child: Column(children: [if (store.issued.isEmpty) const _Empty(text: 'No issued records.') else for (final x in store.issued) _Record(title: '${x['invoice']}', subtitle: '${x['date']} • ${x['customer']} • ${(x['lines'] is List ? (x['lines'] as List).length : 0)} item lines', onEdit: () {}, onDelete: () {})]));
}

class ReturnReportPage extends StatelessWidget {
  final RentStore store;
  const ReturnReportPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Return Register', child: Column(children: [if (store.returns.isEmpty) const _Empty(text: 'No return records.') else for (final x in store.returns) _Record(title: '${x['invoice']}', subtitle: '${x['date']} • ${x['customer']} • Amount ₹${x['amount'] ?? 0}', onEdit: () {}, onDelete: () {})]));
}

class SettingsPage extends StatelessWidget {
  final RentStore store;
  const SettingsPage({super.key, required this.store});

  Future<void> update(BuildContext context) async {
    final uri = Uri.parse('https://github.com/shanpalia/RentFlow/releases');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => ErpPage(title: 'Settings', child: Column(children: [
    ListTileCard(icon: Icons.store_outlined, title: 'Shop / Company Management', subtitle: '${store.shops.length} registered shop(s)', onTap: () => openPage(context, ShopsPage(store: store))),
    ListTileCard(icon: Icons.system_update_outlined, title: 'Check for Update', subtitle: 'Open RentFlow official release page', onTap: () => update(context)),
    ListTileCard(icon: Icons.info_outline, title: 'About RentFlow', subtitle: 'RentFlow • By PaliaAPK HUB • Developer by ShanPalia', onTap: () => showAboutDialog(context: context, applicationName: 'RentFlow', applicationVersion: '1.0.2', children: const [Text('Rental management app by PaliaAPK HUB.'), Text('Developer by ShanPalia')])),
  ]));
}

class ListTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const ListTileCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 9), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: border)), child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: soft, child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right)));
}

class _Record extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _Record({required this.title, required this.subtitle, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: border)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.description_outlined, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])));
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final int maxLines;
  const _Field({required this.label, required this.controller, this.number = false, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controller, maxLines: maxLines, keyboardType: number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label)));
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)), child: Column(children: [const Icon(Icons.inbox_outlined, color: primary, size: 38), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
}
