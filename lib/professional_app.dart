import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF009E83);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF3F7F5);
const line = Color(0xFFD8E4E0);
const soft = Color(0xFFE3F5EF);

String makeId() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);

void main() async {
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
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
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
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Padding(padding: const EdgeInsets.all(18), child: SvgPicture.asset('assets/rentflow_splash.svg', width: 360))),
    );
  }
}

class RentStore extends ChangeNotifier {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> shops = [];
  int activeShop = 0;

  bool get hasShop => shops.isNotEmpty;
  Map<String, dynamic> get shop => hasShop ? shops[activeShop] : <String, dynamic>{};

  List<Map<String, dynamic>> records(String key) {
    if (!hasShop) return [];
    final value = shop[key];
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get items => records('items');
  List<Map<String, dynamic>> get customers => records('customers');
  List<Map<String, dynamic>> get issued => records('issued');
  List<Map<String, dynamic>> get returns => records('returns');

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString('rentflow_shops') ?? '[]');
      if (raw is List) shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      shops = [];
    }
    activeShop = prefs.getInt('rentflow_active_shop') ?? 0;
    if (shops.isEmpty) activeShop = 0;
    if (shops.isNotEmpty && activeShop >= shops.length) activeShop = shops.length - 1;
    notifyListeners();
  }

  Future<void> save() async {
    await prefs.setString('rentflow_shops', jsonEncode(shops));
    await prefs.setInt('rentflow_active_shop', activeShop);
    notifyListeners();
  }

  Map<String, dynamic> makeShop(String name, String owner, String mobile, String address) => {
    'id': makeId(),
    'name': name,
    'owner': owner,
    'mobile': mobile,
    'address': address,
    'items': <Map<String, dynamic>>[],
    'customers': <Map<String, dynamic>>[],
    'issued': <Map<String, dynamic>>[],
    'returns': <Map<String, dynamic>>[],
  };

  Future<void> addShop(String name, String owner, String mobile, String address) async {
    shops.add(makeShop(name, owner, mobile, address));
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

  Future<void> selectShop(int index) async {
    if (index >= 0 && index < shops.length) {
      activeShop = index;
      await save();
    }
  }

  Future<void> deleteShop(int index) async {
    if (index < 0 || index >= shops.length) return;
    shops.removeAt(index);
    if (shops.isEmpty) activeShop = 0;
    if (shops.isNotEmpty && activeShop >= shops.length) activeShop = shops.length - 1;
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> value) async {
    if (!hasShop) return;
    final list = shop[key];
    if (list is List) {
      list.add(value);
      await save();
    }
  }

  Future<void> updateRecord(String key, int index, Map<String, dynamic> value) async {
    if (!hasShop) return;
    final list = shop[key];
    if (list is List && index >= 0 && index < list.length) {
      list[index] = value;
      await save();
    }
  }

  Future<void> deleteRecord(String key, int index) async {
    if (!hasShop) return;
    final list = shop[key];
    if (list is List && index >= 0 && index < list.length) {
      list.removeAt(index);
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
  final store = RentStore();
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    return AnimatedBuilder(animation: store, builder: (_, __) => HomePage(store: store));
  }
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  final List<Widget> actions;
  const AppHeader({super.key, this.back = false, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      leading: back ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: dark)) : Padding(padding: const EdgeInsets.all(12), child: SvgPicture.asset('assets/rentflow_logo.svg')),
      titleSpacing: 4,
      title: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('RentFlow', style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900)), Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800))]),
      actions: actions,
    );
  }
}

Future<void> openPage(BuildContext context, Widget page) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

Future<bool> confirmDelete(BuildContext context, String title) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: const Text('This action cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ),
  );
  return result ?? false;
}

class HomePage extends StatelessWidget {
  final RentStore store;
  const HomePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(actions: [IconButton(onPressed: () => openPage(context, SettingsPage(store: store)), icon: const Icon(Icons.settings_outlined, color: dark))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        const Text('Main Menu', style: TextStyle(color: dark, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Select a module to continue', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        if (!store.hasShop) _NoShopCard(onTap: () => openPage(context, ShopFormPage(store: store))),
        if (store.hasShop) ...[
          _ActiveShopCard(store: store),
          const SizedBox(height: 18),
          const _SectionTitle('MASTERS'),
          _MenuTile(icon: Icons.inventory_2_outlined, title: 'Item Master', subtitle: '${store.items.length} items • add multiple inventory records', onTap: () => openPage(context, ItemsPage(store: store))),
          _MenuTile(icon: Icons.people_alt_outlined, title: 'Customer / Party Master', subtitle: '${store.customers.length} customers • party records', onTap: () => openPage(context, CustomersPage(store: store))),
          _MenuTile(icon: Icons.store_outlined, title: 'Shop / Company', subtitle: '${store.shops.length} registered shops', onTap: () => openPage(context, ShopsPage(store: store))),
          const SizedBox(height: 16),
          const _SectionTitle('TRANSACTIONS'),
          _MenuTile(icon: Icons.outbox_outlined, title: 'Issue / Delivery Entry', subtitle: 'Create voucher with multiple item lines', onTap: () => openPage(context, IssuePage(store: store))),
          _MenuTile(icon: Icons.assignment_return_outlined, title: 'Return / Receive Entry', subtitle: 'Receive items and enter return amount manually', onTap: () => openPage(context, ReturnsPage(store: store))),
          const SizedBox(height: 16),
          const _SectionTitle('REPORTS'),
          _MenuTile(icon: Icons.inventory_outlined, title: 'Stock / Inventory Report', subtitle: 'Current item balances', onTap: () => openPage(context, StockReportPage(store: store))),
          _MenuTile(icon: Icons.receipt_long_outlined, title: 'Issue & Return Register', subtitle: '${store.issued.length} issues • ${store.returns.length} returns', onTap: () => openPage(context, RegisterPage(store: store))),
          const SizedBox(height: 16),
          const _SectionTitle('SYSTEM'),
          _MenuTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Shop, backup and update settings', onTap: () => openPage(context, SettingsPage(store: store))),
        ],
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)));
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        leading: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primary)),
        title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: dark),
      ),
    );
  }
}

class _NoShopCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NoShopCard({required this.onTap});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)), child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [const Icon(Icons.store_mall_directory_outlined, color: primary, size: 52), const SizedBox(height: 12), const Text('Register your shop first', style: TextStyle(color: dark, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Create a company profile before entering items and transactions.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)), const SizedBox(height: 16), FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.add_business), label: const Text('Register Shop'))])));
}

class _ActiveShopCard extends StatelessWidget {
  final RentStore store;
  const _ActiveShopCard({required this.store});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_outlined, color: primary, size: 28)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${store.shop['name']}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), Text('${store.shop['address'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))])), IconButton(onPressed: () => openPage(context, ShopsPage(store: store)), icon: const Icon(Icons.swap_horiz, color: Colors.white))]));
}

class ErpPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const ErpPage({super.key, required this.title, required this.child, this.actions = const []});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppHeader(back: true, actions: actions), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [Text(title, style: const TextStyle(color: dark, fontSize: 26, fontWeight: FontWeight.w900)), const SizedBox(height: 14), child]));
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final int maxLines;
  const _FormField({required this.label, required this.controller, this.number = false, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label)));
}

class ShopFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ShopFormPage({super.key, required this.store, this.index});
  @override
  State<ShopFormPage> createState() => _ShopFormPageState();
}

class _ShopFormPageState extends State<ShopFormPage> {
  late final TextEditingController name;
  late final TextEditingController owner;
  late final TextEditingController mobile;
  late final TextEditingController address;

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
  void dispose() { name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }

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
  Widget build(BuildContext context) => ErpPage(title: widget.index == null ? 'Register New Shop' : 'Edit Shop', child: Column(children: [_FormField(label: 'Shop / Company Name', controller: name), _FormField(label: 'Owner Name', controller: owner), _FormField(label: 'Mobile Number', controller: mobile, number: true), _FormField(label: 'Shop Address', controller: address, maxLines: 3), const SizedBox(height: 6), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: Text(widget.index == null ? 'Save Shop' : 'Update Shop')))]));
}

class ShopsPage extends StatelessWidget {
  final RentStore store;
  const ShopsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Shop / Company Master', actions: [IconButton(onPressed: () => openPage(context, ShopFormPage(store: store)), icon: const Icon(Icons.add_business, color: primary))], child: Column(children: [for (int i = 0; i < store.shops.length; i++) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: i == store.activeShop ? primary : line, width: i == store.activeShop ? 1.5 : 1)), child: ListTile(onTap: () async { await store.selectShop(i); if (context.mounted) Navigator.pop(context); }, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: CircleAvatar(backgroundColor: soft, child: const Icon(Icons.store_outlined, color: primary)), title: Text('${store.shops[i]['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${store.shops[i]['owner'] ?? ''} • ${store.shops[i]['mobile'] ?? ''}\n${store.shops[i]['address'] ?? ''}'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await openPage(context, ShopFormPage(store: store, index: i)); if (v == 'delete' && await confirmDelete(context, 'Delete shop?')) await store.deleteShop(i); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]))), if (store.shops.isEmpty) const _EmptyState(text: 'No shop registered yet.'), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, ShopFormPage(store: store)), icon: const Icon(Icons.add), label: const Text('Add New Shop'))]));
}

class ItemsPage extends StatelessWidget {
  final RentStore store;
  const ItemsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Item Master', actions: [IconButton(onPressed: () => openPage(context, ItemFormPage(store: store)), icon: const Icon(Icons.add_box_outlined, color: primary))], child: Column(children: [if (store.items.isEmpty) const _EmptyState(text: 'No items. Add as many inventory entries as required.') else for (int i = 0; i < store.items.length; i++) _RecordCard(title: '${store.items[i]['name']}', subtitle: 'Code: ${store.items[i]['code'] ?? '-'} • Unit: ${store.items[i]['unit'] ?? 'pcs'} • Qty: ${store.items[i]['quantity'] ?? 0}', trailing: '₹${store.items[i]['rate'] ?? 0}', onEdit: () => openPage(context, ItemFormPage(store: store, index: i)), onDelete: () async { if (await confirmDelete(context, 'Delete item?')) await store.deleteRecord('items', i); }), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, ItemFormPage(store: store)), icon: const Icon(Icons.add), label: const Text('Add Another Item'))]));
}

class ItemFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ItemFormPage({super.key, required this.store, this.index});
  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  late final TextEditingController code, name, unit, quantity, rate;
  @override
  void initState() {
    super.initState();
    final x = widget.index == null ? <String, dynamic>{} : widget.store.items[widget.index!];
    code = TextEditingController(text: '${x['code'] ?? ''}'); name = TextEditingController(text: '${x['name'] ?? ''}'); unit = TextEditingController(text: '${x['unit'] ?? 'pcs'}'); quantity = TextEditingController(text: '${x['quantity'] ?? 0}'); rate = TextEditingController(text: '${x['rate'] ?? 0}');
  }
  @override
  void dispose() { code.dispose(); name.dispose(); unit.dispose(); quantity.dispose(); rate.dispose(); super.dispose(); }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final value = {'id': widget.index == null ? makeId() : widget.store.items[widget.index!]['id'], 'code': code.text.trim(), 'name': name.text.trim(), 'unit': unit.text.trim(), 'quantity': int.tryParse(quantity.text) ?? 0, 'rate': double.tryParse(rate.text) ?? 0};
    if (widget.index == null) await widget.store.addRecord('items', value); else await widget.store.updateRecord('items', widget.index!, value);
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => ErpPage(title: widget.index == null ? 'New Item' : 'Edit Item', child: Column(children: [_FormField(label: 'Item Code', controller: code), _FormField(label: 'Item Name / Description', controller: name), Row(children: [Expanded(child: _FormField(label: 'Unit', controller: unit)), const SizedBox(width: 10), Expanded(child: _FormField(label: 'Opening Quantity', controller: quantity, number: true))]), _FormField(label: 'Rental Rate', controller: rate, number: true), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Item')))]));
}

class CustomersPage extends StatelessWidget {
  final RentStore store;
  const CustomersPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Customer / Party Master', actions: [IconButton(onPressed: () => openPage(context, CustomerFormPage(store: store)), icon: const Icon(Icons.person_add_alt_1_outlined, color: primary))], child: Column(children: [if (store.customers.isEmpty) const _EmptyState(text: 'No customers. Add as many parties as you need.') else for (int i = 0; i < store.customers.length; i++) _RecordCard(title: '${store.customers[i]['name']}', subtitle: '${store.customers[i]['mobile'] ?? ''} • ${store.customers[i]['address'] ?? ''}', onEdit: () => openPage(context, CustomerFormPage(store: store, index: i)), onDelete: () async { if (await confirmDelete(context, 'Delete customer?')) await store.deleteRecord('customers', i); }), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openPage(context, CustomerFormPage(store: store)), icon: const Icon(Icons.add), label: const Text('Add Another Customer'))]));
}

class CustomerFormPage extends StatefulWidget {
  final RentStore store;
  final int? index;
  const CustomerFormPage({super.key, required this.store, this.index});
  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  late final TextEditingController name, mobile, address;
  @override
  void initState() { super.initState(); final x = widget.index == null ? <String, dynamic>{} : widget.store.customers[widget.index!]; name = TextEditingController(text: '${x['name'] ?? ''}'); mobile = TextEditingController(text: '${x['mobile'] ?? ''}'); address = TextEditingController(text: '${x['address'] ?? ''}'); }
  @override
  void dispose() { name.dispose(); mobile.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async { if (name.text.trim().isEmpty) return; final value = {'id': widget.index == null ? makeId() : widget.store.customers[widget.index!]['id'], 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}; if (widget.index == null) await widget.store.addRecord('customers', value); else await widget.store.updateRecord('customers', widget.index!, value); if (mounted) Navigator.pop(context); }
  @override
  Widget build(BuildContext context) => ErpPage(title: widget.index == null ? 'New Customer / Party' : 'Edit Customer / Party', child: Column(children: [_FormField(label: 'Customer / Party Name', controller: name), _FormField(label: 'Mobile Number', controller: mobile, number: true), _FormField(label: 'Address', controller: address, maxLines: 3), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Customer')))]));
}

class IssuePage extends StatefulWidget {
  final RentStore store;
  const IssuePage({super.key, required this.store});
  @override
  State<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends State<IssuePage> {
  late final TextEditingController invoice, date, address;
  String? customerId;
  final List<Map<String, dynamic>> lines = [];

  @override
  void initState() { super.initState(); invoice = TextEditingController(text: 'RF-${DateTime.now().millisecondsSinceEpoch}'); date = TextEditingController(text: today()); address = TextEditingController(); }
  @override
  void dispose() { invoice.dispose(); date.dispose(); address.dispose(); super.dispose(); }

  String customerName() { for (final x in widget.store.customers) { if ('${x['id']}' == customerId) return '${x['name']}'; } return 'Select Customer / Party'; }

  Future<void> pickCustomer() async { final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => CustomerPickerPage(store: widget.store))); if (x != null) setState(() { customerId = '${x['id']}'; address.text = '${x['address'] ?? ''}'; }); }
  Future<void> pickItem() async { final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ItemPickerPage(store: widget.store))); if (x != null) setState(() => lines.add({'itemId': x['id'], 'name': x['name'], 'unit': x['unit'], 'quantity': 1, 'rentDays': 1})); }

  Future<void> save() async {
    if (customerId == null || lines.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer and add at least one item.'))); return; }
    await widget.store.addRecord('issued', {'id': makeId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'customerId': customerId, 'customer': customerName(), 'address': address.text.trim(), 'lines': lines.map((e) => Map<String, dynamic>.from(e)).toList()});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ErpPage(title: 'Issue / Delivery Entry', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Voucher Entry', style: TextStyle(color: Colors.black54)), const SizedBox(height: 14), Row(children: [Expanded(child: _FormField(label: 'Invoice / Issue No.', controller: invoice)), const SizedBox(width: 10), Expanded(child: _FormField(label: 'Issue Date', controller: date))]), InkWell(onTap: pickCustomer, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(labelText: 'Customer / Party'), child: Row(children: [Expanded(child: Text(customerName(), style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), const Icon(Icons.arrow_drop_down)]))), const SizedBox(height: 12), _FormField(label: 'Site / Delivery Address', controller: address, maxLines: 2), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ITEM ENTRIES', style: TextStyle(color: primary, fontWeight: FontWeight.w900, letterSpacing: 1)), FilledButton.icon(onPressed: pickItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'))]), const SizedBox(height: 8), if (lines.isEmpty) const _EmptyState(text: 'Add multiple inventory lines. Each item is a separate entry.'), for (int i = 0; i < lines.length; i++) _IssueLine(line: lines[i], onChanged: (v) => setState(() => lines[i] = v), onDelete: () => setState(() => lines.removeAt(i))), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Issue Entry'))]));
}

class _IssueLine extends StatelessWidget {
  final Map<String, dynamic> line;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;
  const _IssueLine({required this.line, required this.onChanged, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: Column(children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.inventory_2_outlined, color: primary)), const SizedBox(width: 10), Expanded(child: Text('${line['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900))), IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]), Row(children: [Expanded(child: _LineNumber(label: 'Qty', value: '${line['quantity'] ?? 1}', onChanged: (v) => onChanged({...line, 'quantity': int.tryParse(v) ?? 1}))), const SizedBox(width: 8), Expanded(child: _LineNumber(label: 'Rent Days', value: '${line['rentDays'] ?? 1}', onChanged: (v) => onChanged({...line, 'rentDays': int.tryParse(v) ?? 1})))])])));
}

class _LineNumber extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _LineNumber({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextFormField(initialValue: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label), onChanged: onChanged);
}

class CustomerPickerPage extends StatelessWidget {
  final RentStore store;
  const CustomerPickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Customer / Party', child: Column(children: [if (store.customers.isEmpty) const _EmptyState(text: 'No customers found. Add one from Customer Master.') else for (final x in store.customers) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), child: ListTile(onTap: () => Navigator.pop(context, x), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.person_outline, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${x['mobile'] ?? ''} • ${x['address'] ?? ''}'), trailing: const Icon(Icons.chevron_right)))]));
}

class ItemPickerPage extends StatelessWidget {
  final RentStore store;
  const ItemPickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Inventory Item', child: Column(children: [if (store.items.isEmpty) const _EmptyState(text: 'No items found. Add items from Item Master.') else for (final x in store.items) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), child: ListTile(onTap: () => Navigator.pop(context, x), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('Code ${x['code'] ?? '-'} • Unit ${x['unit'] ?? 'pcs'} • Rate ₹${x['rate'] ?? 0}'), trailing: const Icon(Icons.add_circle_outline, color: primary)))]));
}

class ReturnsPage extends StatefulWidget {
  final RentStore store;
  const ReturnsPage({super.key, required this.store});
  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  late final TextEditingController invoice, date, amount, note;
  Map<String, dynamic>? selected;
  final List<Map<String, dynamic>> lines = [];

  @override
  void initState() { super.initState(); invoice = TextEditingController(text: 'RET-${DateTime.now().millisecondsSinceEpoch}'); date = TextEditingController(text: today()); amount = TextEditingController(text: '0'); note = TextEditingController(); }
  @override
  void dispose() { invoice.dispose(); date.dispose(); amount.dispose(); note.dispose(); super.dispose(); }

  Future<void> pickIssue() async { final x = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => IssuePickerPage(store: widget.store))); if (x != null) { setState(() { selected = x; lines.clear(); final raw = x['lines']; if (raw is List) lines.addAll(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e))); }); } }

  Future<void> save() async {
    if (selected == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an issued voucher first.'))); return; }
    await widget.store.addRecord('returns', {'id': makeId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'issueInvoice': selected!['invoice'], 'customer': selected!['customer'], 'amount': double.tryParse(amount.text) ?? 0, 'note': note.text.trim(), 'lines': lines.map((e) => Map<String, dynamic>.from(e)).toList()});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ErpPage(title: 'Return / Receive Entry', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: _FormField(label: 'Return No.', controller: invoice)), const SizedBox(width: 10), Expanded(child: _FormField(label: 'Return Date', controller: date))]), InkWell(onTap: pickIssue, child: InputDecorator(decoration: const InputDecoration(labelText: 'Issued Voucher / Customer'), child: Row(children: [Expanded(child: Text(selected == null ? 'Select Issued Voucher' : '${selected!['invoice']} • ${selected!['customer']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), const Icon(Icons.arrow_drop_down)]))), const SizedBox(height: 14), const Text('RETURN ITEMS', style: TextStyle(color: primary, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), if (lines.isEmpty) const _EmptyState(text: 'Select an issued voucher to load its inventory lines.'), for (int i = 0; i < lines.length; i++) _ReturnLine(line: lines[i], onChanged: (v) => setState(() => lines[i] = v)), const SizedBox(height: 12), _FormField(label: 'Return Amount (Manual)', controller: amount, number: true), _FormField(label: 'Remarks', controller: note, maxLines: 2), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Save Return Entry'))]));
}

class _ReturnLine extends StatelessWidget {
  final Map<String, dynamic> line;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const _ReturnLine({required this.line, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: Row(children: [Expanded(child: Text('${line['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900))), SizedBox(width: 95, child: TextFormField(initialValue: '${line['quantity'] ?? 1}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Return Qty'), onChanged: (v) => onChanged({...line, 'returnQuantity': int.tryParse(v) ?? 0})))]));
}

class IssuePickerPage extends StatelessWidget {
  final RentStore store;
  const IssuePickerPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Select Issued Voucher', child: Column(children: [if (store.issued.isEmpty) const _EmptyState(text: 'No issued vouchers found.') else for (final x in store.issued) Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), child: ListTile(onTap: () => Navigator.pop(context, x), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.receipt_long_outlined, color: primary)), title: Text('${x['invoice']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text('${x['customer']} • ${x['date']}'), trailing: const Icon(Icons.chevron_right)))]));
}

class StockReportPage extends StatelessWidget {
  final RentStore store;
  const StockReportPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Stock / Inventory Report', child: Column(children: [if (store.items.isEmpty) const _EmptyState(text: 'No inventory records.') else for (final x in store.items) _ReportRow(title: '${x['name']}', left: 'Code ${x['code'] ?? '-'}', right: 'Qty ${x['quantity'] ?? 0}')])));
}

class RegisterPage extends StatelessWidget {
  final RentStore store;
  const RegisterPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ErpPage(title: 'Issue & Return Register', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ISSUE REGISTER', style: TextStyle(color: primary, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (store.issued.isEmpty) const _EmptyState(text: 'No issue entries.') else for (final x in store.issued) _ReportRow(title: '${x['invoice']}', left: '${x['customer']} • ${x['date']}', right: 'Issue'), const SizedBox(height: 18), const Text('RETURN REGISTER', style: TextStyle(color: primary, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (store.returns.isEmpty) const _EmptyState(text: 'No return entries.') else for (final x in store.returns) _ReportRow(title: '${x['invoice']}', left: '${x['customer']} • ${x['date']}', right: '₹${x['amount'] ?? 0}')])));
}

class _RecordCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RecordCard({required this.title, required this.subtitle, this.trailing, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: line)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.description_outlined, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (trailing != null) Text(trailing!, style: const TextStyle(color: primary, fontWeight: FontWeight.w900)), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])])));
}

class _ReportRow extends StatelessWidget {
  final String title;
  final String left;
  final String right;
  const _ReportRow({required this.title, required this.left, required this.right});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: line)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w900)), Text(left, style: const TextStyle(color: Colors.black54, fontSize: 12))])), Text(right, style: const TextStyle(color: primary, fontWeight: FontWeight.w800))]));
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(24), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)), child: Column(children: [const Icon(Icons.inbox_outlined, color: primary, size: 38), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
}

class SettingsPage extends StatelessWidget {
  final RentStore store;
  const SettingsPage({super.key, required this.store});

  Future<void> checkUpdate(BuildContext context) async {
    final uri = Uri.parse('https://github.com/shanpalia/RentFlow/releases');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => ErpPage(title: 'Settings', child: Column(children: [Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)), child: Column(children: [ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.store_outlined, color: primary)), title: const Text('Shop / Company Management', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${store.shops.length} registered shop(s)'), trailing: const Icon(Icons.chevron_right), onTap: () => openPage(context, ShopsPage(store: store))), const Divider(height: 1), ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.system_update_outlined, color: primary)), title: const Text('Check for Update', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Open the official RentFlow release page'), trailing: const Icon(Icons.open_in_new), onTap: () => checkUpdate(context)), const Divider(height: 1), ListTile(leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.info_outline, color: primary)), title: const Text('About RentFlow', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('RentFlow • By PaliaAPK HUB • Developer by ShanPalia'))])), const SizedBox(height: 14), const Text('Version 1.0.2', style: TextStyle(color: Colors.black45))]));
}
