import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF009E83);
const dark = Color(0xFF10241F);
const bg = Color(0xFFF4F8F6);
const line = Color(0xFFD7E5E0);
const soft = Color(0xFFE4F5EF);

String makeId() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);

Future<void> main() async {
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
        fontFamily: 'sans-serif',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
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
    Future.delayed(const Duration(milliseconds: 1500), () {
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
          padding: const EdgeInsets.all(18),
          child: SvgPicture.asset('assets/rentflow_splash.svg', width: 360),
        ),
      ),
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
      if (raw is List) {
        shops = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      shops = [];
    }
    activeShop = prefs.getInt('rentflow_active_shop') ?? 0;
    if (shops.isEmpty) {
      activeShop = 0;
    } else if (activeShop >= shops.length) {
      activeShop = shops.length - 1;
    }
    notifyListeners();
  }

  Future<void> save() async {
    await prefs.setString('rentflow_shops', jsonEncode(shops));
    await prefs.setInt('rentflow_active_shop', activeShop);
    notifyListeners();
  }

  Map<String, dynamic> newShop(String name, String owner, String mobile, String address) {
    return {
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
  }

  Future<void> addShop(String name, String owner, String mobile, String address) async {
    shops.add(newShop(name, owner, mobile, address));
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
    if (index < 0 || index >= shops.length) return;
    activeShop = index;
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
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    }
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => HomePage(store: store),
    );
  }
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  final List<Widget> actions;

  const AppHeader({super.key, this.back = false, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: dark),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 12),
              child: SvgPicture.asset('assets/rentflow_logo.svg'),
            ),
      leadingWidth: 58,
      titleSpacing: 4,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('RentFlow', style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w900)),
          Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
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
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
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
      appBar: AppHeader(
        actions: [
          if (store.hasShop)
            IconButton(
              tooltip: 'Shops',
              onPressed: () => openPage(context, ShopsPage(store: store)),
              icon: const Icon(Icons.storefront_outlined, color: dark),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => openPage(context, SettingsPage(store: store)),
            icon: const Icon(Icons.settings_outlined, color: dark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
        children: [
          if (!store.hasShop) _RegisterCard(store: store) else _ShopBanner(store: store),
          const SizedBox(height: 20),
          const Text('MAIN MENU', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Business Dashboard', style: TextStyle(color: dark, fontSize: 29, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Manage your rental business like an ERP.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          _MenuSection(
            title: 'MASTERS',
            items: [
              _MenuItem('Item Master', 'Items, units, stock & rates', Icons.inventory_2_outlined, (c) => openPage(c, ItemsPage(store: store))),
              _MenuItem('Customer / Party', 'Customer master & ledger', Icons.people_outline, (c) => openPage(c, CustomersPage(store: store))),
              _MenuItem('Shop / Company', 'Multiple shops & addresses', Icons.storefront_outlined, (c) => openPage(c, ShopsPage(store: store))),
            ],
          ),
          const SizedBox(height: 14),
          _MenuSection(
            title: 'TRANSACTIONS',
            items: [
              _MenuItem('Issue / Delivery', 'Create multi-item issue voucher', Icons.outbox_outlined, (c) => openPage(c, IssuePage(store: store))),
              _MenuItem('Return / Receive', 'Receive issued items', Icons.move_to_inbox_outlined, (c) => openPage(c, ReturnsPage(store: store))),
            ],
          ),
          const SizedBox(height: 14),
          _MenuSection(
            title: 'REPORTS',
            items: [
              _MenuItem('Stock Report', 'Current item and issue status', Icons.assessment_outlined, (c) => openPage(c, ReportsPage(store: store))),
              _MenuItem('Customer Ledger', 'Issue, return & outstanding', Icons.account_balance_wallet_outlined, (c) => openPage(c, ReportsPage(store: store))),
              _MenuItem('Rental Reports', 'Transaction summary', Icons.bar_chart_outlined, (c) => openPage(c, ReportsPage(store: store))),
            ],
          ),
          const SizedBox(height: 14),
          _MenuSection(
            title: 'SYSTEM',
            items: [
              _MenuItem('Settings', 'Backup, update & preferences', Icons.settings_outlined, (c) => openPage(c, SettingsPage(store: store))),
            ],
          ),
          const SizedBox(height: 22),
          Row(children: [_CountBox(label: 'Items', value: store.items.length.toString()), const SizedBox(width: 8), _CountBox(label: 'Customers', value: store.customers.length.toString()), const SizedBox(width: 8), _CountBox(label: 'Issued', value: store.issued.length.toString())]),
          const SizedBox(height: 24),
          const Center(child: Text('RentFlow  •  By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          const Center(child: Text('Developer by ShanPalia', style: TextStyle(color: Colors.black45, fontSize: 12))),
        ],
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final RentStore store;
  const _RegisterCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primary.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.storefront_outlined, color: primary, size: 30)),
          const SizedBox(width: 13),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Register your shop', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Start with your company and address.', style: TextStyle(color: Colors.white70))])),
          FilledButton(onPressed: () => openPage(context, ShopForm(store: store)), child: const Text('Register')),
        ]),
      ),
    );
  }
}

class _ShopBanner extends StatelessWidget {
  final RentStore store;
  const _ShopBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openPage(context, ShopsPage(store: store)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_outlined, color: primary, size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${store.shop['name']}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text('${store.shop['owner']}  •  ${store.shop['mobile']}', style: const TextStyle(color: Colors.white70)), Text('${store.shop['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60))])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ]),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext) onTap;
  _MenuItem(this.title, this.subtitle, this.icon, this.onTap);
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 3, bottom: 7), child: Text(title, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1))),
      Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)), child: Icon(items[i].icon, color: primary, size: 22)),
              title: Text(items[i].title, style: const TextStyle(color: dark, fontWeight: FontWeight.w800)),
              subtitle: Text(items[i].subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black45),
              onTap: () => items[i].onTap(context),
            ),
            if (i != items.length - 1) const Divider(height: 1, indent: 68, endIndent: 12),
          ],
        ]),
      ),
    ]);
  }
}

class _CountBox extends StatelessWidget {
  final String label;
  final String value;
  const _CountBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: line)), child: Column(children: [Text(value, style: const TextStyle(color: dark, fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11))])));
  }
}

class ErpPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const ErpPage({super.key, required this.title, required this.child, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(back: true, actions: actions),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [Text(title, style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 4), child]),
    );
  }
}

class ItemsPage extends StatelessWidget {
  final RentStore store;
  const ItemsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(
      title: 'Item Master',
      actions: [IconButton(onPressed: () => openPage(context, ItemForm(store: store)), icon: const Icon(Icons.add_circle_outline, color: primary))],
      child: Column(children: [
        const SizedBox(height: 12),
        const _TableHead(cells: ['Item / Description', 'Unit', 'Qty', 'Rate']),
        if (store.items.isEmpty) const _Empty(text: 'No items added. Use Add Item to create multiple stock records.')
        else for (int i = 0; i < store.items.length; i++) _ItemRow(store: store, index: i),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => openPage(context, ItemForm(store: store)), icon: const Icon(Icons.add), label: const Text('Add Item'))),
      ]),
    );
  }
}

class _TableHead extends StatelessWidget {
  final List<String> cells;
  const _TableHead({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: const BoxDecoration(color: dark, borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: Row(children: [for (int i = 0; i < cells.length; i++) Expanded(flex: i == 0 ? 3 : 1, child: Text(cells[i], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))]));
  }
}

class _ItemRow extends StatelessWidget {
  final RentStore store;
  final int index;
  const _ItemRow({required this.store, required this.index});

  @override
  Widget build(BuildContext context) {
    final x = store.items[index];
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: line))), child: Row(children: [Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), Text('Code: ${x['code'] ?? '-'}', style: const TextStyle(color: Colors.black45, fontSize: 10))])), Expanded(child: Text('${x['unit']}', style: const TextStyle(color: dark, fontSize: 12))), Expanded(child: Text('${x['quantity']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), Expanded(child: Text('₹${x['rate']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w700))), PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await openPage(context, ItemForm(store: store, index: index)); if (v == 'delete' && await confirmDelete(context, 'Delete item?')) await store.deleteRecord('items', index); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])])));
  }
}

class ItemForm extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ItemForm({super.key, required this.store, this.index});

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final code = TextEditingController();
  final name = TextEditingController();
  final unit = TextEditingController(text: 'pcs');
  final quantity = TextEditingController(text: '0');
  final rate = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    if (widget.index != null) {
      final x = widget.store.items[widget.index!];
      code.text = '${x['code'] ?? ''}';
      name.text = '${x['name'] ?? ''}';
      unit.text = '${x['unit'] ?? 'pcs'}';
      quantity.text = '${x['quantity'] ?? 0}';
      rate.text = '${x['rate'] ?? 0}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormPage(title: widget.index == null ? 'Add Item' : 'Edit Item', fields: [_Field(label: 'Item Code', controller: code), _Field(label: 'Item Name / Description', controller: name), Row(children: [Expanded(child: _Field(label: 'Unit', controller: unit)), const SizedBox(width: 10), Expanded(child: _Field(label: 'Opening Qty', controller: quantity, number: true))]), _Field(label: 'Rental Rate', controller: rate, number: true)], onSave: () async { if (name.text.trim().isEmpty) return; final value = {'id': widget.index == null ? makeId() : widget.store.items[widget.index!]['id'], 'code': code.text.trim(), 'name': name.text.trim(), 'unit': unit.text.trim(), 'quantity': int.tryParse(quantity.text) ?? 0, 'rate': double.tryParse(rate.text) ?? 0}; if (widget.index == null) await widget.store.addRecord('items', value); else await widget.store.updateRecord('items', widget.index!, value); if (context.mounted) Navigator.pop(context); });
  }
}

class CustomersPage extends StatelessWidget {
  final RentStore store;
  const CustomersPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Customer / Party Master', actions: [IconButton(onPressed: () => openPage(context, CustomerForm(store: store)), icon: const Icon(Icons.person_add_alt_1_outlined, color: primary))], child: Column(children: [const SizedBox(height: 12), const _TableHead(cells: ['Party / Customer', 'Mobile', 'Address']), if (store.customers.isEmpty) const _Empty(text: 'No customers added. Add multiple parties for issue and return entries.') else for (int i = 0; i < store.customers.length; i++) _CustomerRow(store: store, index: i), const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => openPage(context, CustomerForm(store: store)), icon: const Icon(Icons.add), label: const Text('Add Customer')))]));
  }
}

class _CustomerRow extends StatelessWidget {
  final RentStore store;
  final int index;
  const _CustomerRow({required this.store, required this.index});

  @override
  Widget build(BuildContext context) {
    final x = store.customers[index];
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9), decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: line))), child: Row(children: [Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), Text('${x['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 10))])), Expanded(child: Text('${x['mobile']}', style: const TextStyle(fontSize: 12))), PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await openPage(context, CustomerForm(store: store, index: index)); if (v == 'delete' && await confirmDelete(context, 'Delete customer?')) await store.deleteRecord('customers', index); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])])));
  }
}

class CustomerForm extends StatefulWidget {
  final RentStore store;
  final int? index;
  const CustomerForm({super.key, required this.store, this.index});

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
      final x = widget.store.customers[widget.index!];
      name.text = '${x['name'] ?? ''}';
      mobile.text = '${x['mobile'] ?? ''}';
      address.text = '${x['address'] ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormPage(title: widget.index == null ? 'Add Customer' : 'Edit Customer', fields: [_Field(label: 'Customer / Party Name', controller: name), _Field(label: 'Mobile', controller: mobile, number: true), _Field(label: 'Address', controller: address, maxLines: 3)], onSave: () async { if (name.text.trim().isEmpty) return; final value = {'id': widget.index == null ? makeId() : widget.store.customers[widget.index!]['id'], 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()}; if (widget.index == null) await widget.store.addRecord('customers', value); else await widget.store.updateRecord('customers', widget.index!, value); if (context.mounted) Navigator.pop(context); });
  }
}

class IssuePage extends StatefulWidget {
  final RentStore store;
  const IssuePage({super.key, required this.store});

  @override
  State<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends State<IssuePage> {
  final invoice = TextEditingController(text: 'RF-${DateTime.now().millisecondsSinceEpoch}');
  final date = TextEditingController(text: today());
  final address = TextEditingController();
  String? customerId;
  final List<Map<String, dynamic>> lines = [];

  String get customerName {
    for (final c in widget.store.customers) {
      if ('${c['id']}' == customerId) return '${c['name']}';
    }
    return 'Select Customer / Party';
  }

  Future<void> pickCustomer() async {
    final selected = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => CustomerPickerPage(store: widget.store)));
    if (selected != null) setState(() { customerId = '${selected['id']}'; address.text = '${selected['address'] ?? ''}'; });
  }

  Future<void> pickItem() async {
    final selected = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ItemPickerPage(store: widget.store)));
    if (selected != null) setState(() { lines.add({'itemId': selected['id'], 'name': selected['name'], 'unit': selected['unit'], 'quantity': 1, 'rentDays': 1}); });
  }

  Future<void> saveIssue() async {
    if (customerId == null || lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer and add at least one item.')));
      return;
    }
    await widget.store.addRecord('issued', {'id': makeId(), 'invoice': invoice.text.trim(), 'date': date.text.trim(), 'customerId': customerId, 'customer': customerName, 'address': address.text.trim(), 'lines': lines.map((e) => Map<String, dynamic>.from(e)).toList()});
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue entry saved.'))); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(back: true),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        const Text('Issue / Delivery Entry', style: TextStyle(color: dark, fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Tally / BUSY-style voucher entry', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: _Field(label: 'Invoice / Issue No.', controller: invoice)), const SizedBox(width: 10), Expanded(child: _Field(label: 'Issue Date', controller: date))]),
        InkWell(onTap: pickCustomer, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(labelText: 'Customer / Party'), child: Row(children: [Expanded(child: Text(customerName, style: TextStyle(color: customerId == null ? Colors.black54 : dark, fontWeight: FontWeight.w600))), const Icon(Icons.arrow_drop_down)]))),
        const SizedBox(height: 12),
        _Field(label: 'Site / Delivery Address', controller: address, maxLines: 2),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ITEM ENTRIES', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)), FilledButton.icon(onPressed: pickItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'))]),
        const SizedBox(height: 8),
        if (lines.isEmpty) const _Empty(text: 'No item lines. Add as many inventory items as required.'),
        for (int i = 0; i < lines.length; i++) _IssueLine(line: lines[i], onChanged: (v) => setState(() => lines[i] = v), onDelete: () => setState(() => lines.removeAt(i))),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: saveIssue, icon: const Icon(Icons.save_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Save Issue Entry'))),
      ]),
    );
  }
}

class _IssueLine extends StatelessWidget {
  final Map<String, dynamic> line;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;
  const _IssueLine({required this.line, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: Column(children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.inventory_2_outlined, color: primary, size: 20)), const SizedBox(width: 10), Expanded(child: Text('${line['name']}', style: const TextStyle(color: dark, fontWeight: FontWeight.w800))), IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]), const SizedBox(height: 8), Row(children: [Expanded(child: TextFormField(initialValue: '${line['quantity'] ?? 1}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Issued Qty'), onChanged: (v) => onChanged({...line, 'quantity': int.tryParse(v) ?? 1}))), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: '${line['rentDays'] ?? 1}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent Days'), onChanged: (v) => onChanged({...line, 'rentDays': int.tryParse(v) ?? 1})))])])));
  }
}

class CustomerPickerPage extends StatelessWidget {
  final RentStore store;
  const CustomerPickerPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Select Customer / Party', child: Column(children: [const SizedBox(height: 12), if (store.customers.isEmpty) const _Empty(text: 'No customers found. Add a customer from Customer Master first.') else for (final c in store.customers) ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.person_outline, color: primary)), title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${c['mobile']}  •  ${c['address']}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(context, c)), const SizedBox(height: 10)]));
  }
}

class ItemPickerPage extends StatelessWidget {
  final RentStore store;
  const ItemPickerPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Select Inventory Item', child: Column(children: [const SizedBox(height: 12), if (store.items.isEmpty) const _Empty(text: 'No items found. Add items from Item Master first.') else for (final x in store.items) ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.inventory_2_outlined, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Code ${x['code'] ?? '-'}  •  Unit ${x['unit']}  •  Rate ₹${x['rate']}'), trailing: const Icon(Icons.add_circle_outline, color: primary), onTap: () => Navigator.pop(context, x)), const SizedBox(height: 8)]));
  }
}

class ReturnsPage extends StatefulWidget {
  final RentStore store;
  const ReturnsPage({super.key, required this.store});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final amount = TextEditingController();
  final date = TextEditingController(text: today());
  Map<String, dynamic>? selected;

  Future<void> selectIssue() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => IssuePickerPage(store: widget.store)));
    if (result != null) setState(() => selected = result);
  }

  Future<void> saveReturn() async {
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an issued invoice first.')));
      return;
    }
    await widget.store.addRecord('returns', {'id': makeId(), 'invoice': selected!['invoice'], 'date': date.text.trim(), 'customer': selected!['customer'], 'customerId': selected!['customerId'], 'amount': double.tryParse(amount.text) ?? 0, 'lines': selected!['lines']});
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return entry saved.'))); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Return / Receive Entry', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      InkWell(onTap: selectIssue, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(labelText: 'Issued Invoice'), child: Row(children: [Expanded(child: Text(selected == null ? 'Select issued invoice' : '${selected!['invoice']}  •  ${selected!['customer']}', style: TextStyle(color: selected == null ? Colors.black54 : dark, fontWeight: FontWeight.w600))), const Icon(Icons.arrow_drop_down)]))),
      const SizedBox(height: 12),
      _Field(label: 'Return Date', controller: date),
      _Field(label: 'Return Amount (Manual)', controller: amount, number: true),
      const SizedBox(height: 8),
      if (selected != null) ...[
        const Text('ISSUED ITEMS', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final x in (selected!['lines'] as List? ?? const [])) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)), child: Row(children: [Expanded(child: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800))), Text('Qty ${x['quantity']}  •  ${x['rentDays']} days', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
      ],
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saveReturn, icon: const Icon(Icons.save_outlined), label: const Text('Save Return'))),
    ]));
  }
}

class IssuePickerPage extends StatelessWidget {
  final RentStore store;
  const IssuePickerPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Select Issued Invoice', child: Column(children: [const SizedBox(height: 12), if (store.issued.isEmpty) const _Empty(text: 'No issued entries found.') else for (final x in store.issued.reversed) ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: const CircleAvatar(backgroundColor: soft, child: Icon(Icons.receipt_long_outlined, color: primary)), title: Text('${x['invoice']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${x['customer']}  •  ${x['date']}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(context, x))]));
  }
}

class ShopsPage extends StatelessWidget {
  final RentStore store;
  const ShopsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Shop / Company Master', actions: [IconButton(onPressed: () => openPage(context, ShopForm(store: store)), icon: const Icon(Icons.add_business_outlined, color: primary))], child: Column(children: [
      const SizedBox(height: 12),
      if (store.shops.isEmpty) const _Empty(text: 'No shop registered. Add your first shop.') else for (int i = 0; i < store.shops.length; i++) _ShopRow(store: store, index: i),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => openPage(context, ShopForm(store: store)), icon: const Icon(Icons.add_business_outlined), label: const Text('Add New Shop / Address')),
    ]));
  }
}

class _ShopRow extends StatelessWidget {
  final RentStore store;
  final int index;
  const _ShopRow({required this.store, required this.index});

  @override
  Widget build(BuildContext context) {
    final s = store.shops[index];
    final active = index == store.activeShop;
    return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: active ? dark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? dark : line)), child: Row(children: [Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: active ? primary.withValues(alpha: .18) : soft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.storefront_outlined, color: primary)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${s['name']}', style: TextStyle(color: active ? Colors.white : dark, fontWeight: FontWeight.w900)), Text('${s['owner']}  •  ${s['mobile']}', style: TextStyle(color: active ? Colors.white70 : Colors.black54, fontSize: 12)), Text('${s['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white60 : Colors.black45, fontSize: 11))])), if (active) const Icon(Icons.check_circle, color: primary), PopupMenuButton<String>(onSelected: (v) async { if (v == 'select') await store.selectShop(index); if (v == 'edit') await openPage(context, ShopForm(store: store, index: index)); if (v == 'delete' && await confirmDelete(context, 'Delete shop?')) await store.deleteShop(index); }, itemBuilder: (_) => const [PopupMenuItem(value: 'select', child: Text('Use this shop')), PopupMenuItem(value: 'edit', child: Text('Edit shop')), PopupMenuItem(value: 'delete', child: Text('Delete shop'))])])));
  }
}

class ShopForm extends StatefulWidget {
  final RentStore store;
  final int? index;
  const ShopForm({super.key, required this.store, this.index});

  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  final name = TextEditingController();
  final owner = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.index != null) {
      final s = widget.store.shops[widget.index!];
      name.text = '${s['name'] ?? ''}';
      owner.text = '${s['owner'] ?? ''}';
      mobile.text = '${s['mobile'] ?? ''}';
      address.text = '${s['address'] ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormPage(title: widget.index == null ? 'Register Shop' : 'Edit Shop', fields: [_Field(label: 'Shop / Company Name', controller: name), _Field(label: 'Owner Name', controller: owner), _Field(label: 'Mobile', controller: mobile, number: true), _Field(label: 'Shop Address', controller: address, maxLines: 4)], onSave: () async { if (name.text.trim().isEmpty) return; if (widget.index == null) { await widget.store.addShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); } else { await widget.store.selectShop(widget.index!); await widget.store.updateShop(name.text.trim(), owner.text.trim(), mobile.text.trim(), address.text.trim()); } if (context.mounted) Navigator.pop(context); });
  }
}

class ReportsPage extends StatelessWidget {
  final RentStore store;
  const ReportsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Reports', child: Column(children: [
      const SizedBox(height: 12),
      _ReportTile(title: 'Stock Register', subtitle: '${store.items.length} item master records', icon: Icons.inventory_2_outlined),
      _ReportTile(title: 'Issue Register', subtitle: '${store.issued.length} issue vouchers', icon: Icons.outbox_outlined),
      _ReportTile(title: 'Return Register', subtitle: '${store.returns.length} return vouchers', icon: Icons.move_to_inbox_outlined),
      _ReportTile(title: 'Customer Ledger', subtitle: '${store.customers.length} customer accounts', icon: Icons.account_balance_wallet_outlined),
      const SizedBox(height: 12),
      _SummaryPanel(store: store),
    ]));
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _ReportTile({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line), borderRadius: BorderRadius.circular(13)), child: ListTile(leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded));
}

class _SummaryPanel extends StatelessWidget {
  final RentStore store;
  const _SummaryPanel({required this.store});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('BUSINESS SUMMARY', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 12), Text('Items: ${store.items.length}', style: const TextStyle(color: Colors.white)), Text('Customers: ${store.customers.length}', style: const TextStyle(color: Colors.white)), Text('Issued vouchers: ${store.issued.length}', style: const TextStyle(color: Colors.white)), Text('Return vouchers: ${store.returns.length}', style: const TextStyle(color: Colors.white))]);
}

class SettingsPage extends StatelessWidget {
  final RentStore store;
  const SettingsPage({super.key, required this.store});

  Future<void> checkUpdate(BuildContext context) async {
    final uri = Uri.parse('https://github.com/shanpalia/RentFlow/releases');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open update page.')));
  }

  @override
  Widget build(BuildContext context) {
    return ErpPage(title: 'Settings', child: Column(children: [
      const SizedBox(height: 12),
      _SettingTile(title: 'Shop / Company', subtitle: 'Manage shop, owner and address', icon: Icons.storefront_outlined, onTap: () => openPage(context, ShopsPage(store: store))),
      _SettingTile(title: 'Check for Update', subtitle: 'Open latest RentFlow release', icon: Icons.system_update_outlined, onTap: () => checkUpdate(context)),
      _SettingTile(title: 'Backup / Data', subtitle: 'Your records are stored locally on this device', icon: Icons.backup_outlined, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data storage is active.')))),
      _SettingTile(title: 'About RentFlow', subtitle: 'RentFlow • By PaliaAPK HUB • Developer by ShanPalia', icon: Icons.info_outline, onTap: () => showAboutDialog(context: context, applicationName: 'RentFlow', applicationVersion: '1.0.2', applicationLegalese: 'By PaliaAPK HUB • Developer by ShanPalia')),
    ]));
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _SettingTile({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line), borderRadius: BorderRadius.circular(13)), child: ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)));
}

class _FormPage extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final Future<void> Function() onSave;
  const _FormPage({required this.title, required this.fields, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: const AppHeader(back: true), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [Text(title, style: const TextStyle(color: dark, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), ...fields, const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.save_outlined), label: const Text('Save')))]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final int maxLines;
  const _Field({required this.label, required this.controller, this.number = false, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: maxLines, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label)));
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))), child: Column(children: [const Icon(Icons.inbox_outlined, color: primary, size: 35), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
}
