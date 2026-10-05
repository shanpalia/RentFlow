import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE7F6F1);
const pageBg = Color(0xFFF5F8F7);
const line = Color(0xFFD8E5E1);
const ink = Color(0xFF172521);

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
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: ink,
            elevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide(color: line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide(color: emerald, width: 2),
            ),
          ),
        ),
        home: const SplashPage(),
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
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 320,
            child: SvgPicture.asset('assets/rentflow_splash.svg'),
          ),
        ),
      );
}

class StoreDB extends ChangeNotifier {
  SharedPreferences? prefs;
  List<Map<String, dynamic>> shops = [];
  int active = 0;

  bool get ready => prefs != null;
  Map<String, dynamic> get shop =>
      shops.isEmpty ? <String, dynamic>{} : shops[active];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs!.getString('rentflow_data') ?? '[]');
      if (raw is List) {
        shops = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      shops = [];
    }
    active = prefs!.getInt('rentflow_active') ?? 0;
    if (shops.isEmpty) active = 0;
    if (shops.isNotEmpty && active >= shops.length) active = shops.length - 1;
    notifyListeners();
  }

  Future<void> save() async {
    await prefs?.setString('rentflow_data', jsonEncode(shops));
    await prefs?.setInt('rentflow_active', active);
    notifyListeners();
  }

  List<Map<String, dynamic>> records(String key) {
    if (shops.isEmpty) return [];
    final value = shop[key];
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addShop(Map<String, dynamic> data) async {
    shops.add({
      ...data,
      'items': <Map<String, dynamic>>[],
      'customers': <Map<String, dynamic>>[],
      'issues': <Map<String, dynamic>>[],
      'returns': <Map<String, dynamic>>[],
    });
    active = shops.length - 1;
    await save();
  }

  Future<void> updateShop(Map<String, dynamic> data) async {
    shop.addAll(data);
    await save();
  }

  Future<void> addRecord(String key, Map<String, dynamic> data) async {
    final list = shop[key];
    if (list is! List) shop[key] = <Map<String, dynamic>>[];
    (shop[key] as List).add(data);
    await save();
  }

  Future<void> editRecord(String key, int index, Map<String, dynamic> data) async {
    (shop[key] as List)[index] = data;
    await save();
  }

  Future<void> deleteRecord(String key, int index) async {
    (shop[key] as List).removeAt(index);
    await save();
  }

  Future<void> updateItemStock(String id, int delta) async {
    final items = shop['items'] as List;
    for (var i = 0; i < items.length; i++) {
      final item = Map<String, dynamic>.from(items[i] as Map);
      if ('${item['id']}' == id) {
        final old = int.tryParse('${item['quantity'] ?? 0}') ?? 0;
        item['quantity'] = old + delta;
        items[i] = item;
        break;
      }
    }
    await save();
  }
}

final store = StoreDB();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(dynamic value) =>
    '₹${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';
void openPage(BuildContext context, Widget page) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  const AppHeader({super.key, this.back = false});
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => AppBar(
        leading: back
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 30),
              )
            : Padding(
                padding: const EdgeInsets.all(11),
                child: SvgPicture.asset('assets/rentflow_logo.svg'),
              ),
        title: const Text(
          'RentFlow by PaliaAPK HUB',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: line),
        ),
      );
}

class PageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const PageFrame({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppHeader(back: true),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
            Container(
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 18),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          if (!store.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: emerald)),
            );
          }
          final has = store.shops.isNotEmpty;
          return Scaffold(
            appBar: const AppHeader(),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Main Menu',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: ink)),
                Text(
                  has
                      ? '${store.shop['name'] ?? 'Shop'} • Emerald workspace'
                      : 'Set up your rental business',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                if (!has)
                  MenuTile(
                    icon: Icons.store_rounded,
                    title: 'Register Shop',
                    subtitle: 'Create your first shop/company',
                    onTap: () => openPage(context, const ShopFormPage()),
                  )
                else ...[
                  const SectionTitle('MASTERS'),
                  MenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventory',
                    subtitle: 'Item master • stock • rent price',
                    onTap: () => openPage(context, const ItemsPage()),
                  ),
                  MenuTile(
                    icon: Icons.people_alt_outlined,
                    title: 'Customers / Parties',
                    subtitle: 'Add, edit and manage parties',
                    onTap: () => openPage(context, const CustomersPage()),
                  ),
                  MenuTile(
                    icon: Icons.store_outlined,
                    title: 'Shop / Company',
                    subtitle: 'Edit or add another company',
                    onTap: () => openPage(context, const ShopsPage()),
                  ),
                  const SectionTitle('TRANSACTIONS'),
                  MenuTile(
                    icon: Icons.outbox_rounded,
                    title: 'Issued',
                    subtitle: 'Customer + invoice + multiple items + rent',
                    onTap: () => openPage(context, const IssuePage()),
                  ),
                  MenuTile(
                    icon: Icons.assignment_return_rounded,
                    title: 'Return',
                    subtitle: 'Select invoice • partial item return',
                    onTap: () => openPage(context, const ReturnPage()),
                  ),
                  const SectionTitle('REGISTERS & REPORTS'),
                  MenuTile(
                    icon: Icons.table_rows_rounded,
                    title: 'Inventory Register',
                    subtitle: 'Current stock • issued • returned',
                    onTap: () =>
                        openPage(context, const InventoryRegisterPage()),
                  ),
                  MenuTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Transactions / Bills',
                    subtitle: 'View entries and print PDF bills',
                    onTap: () =>
                        openPage(context, const TransactionsPage()),
                  ),
                  const SectionTitle('SYSTEM'),
                  MenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Update and app information',
                    onTap: () => openPage(context, const SettingsPage()),
                  ),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'RentFlow • By PaliaAPK HUB • Developer by shanpalia',
                    style: TextStyle(
                        color: Colors.black45, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: emeraldDark,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12)),
      );
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: line),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: emeraldSoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: emeraldDark),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: emerald),
        ),
      );
}

class ShopFormPage extends StatefulWidget {
  final bool edit;
  const ShopFormPage({super.key, this.edit = false});
  @override
  State<ShopFormPage> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopFormPage> {
  late TextEditingController name, owner, mobile, address;
  @override
  void initState() {
    super.initState();
    final x = store.shop;
    name = TextEditingController(text: widget.edit ? '${x['name'] ?? ''}' : '');
    owner = TextEditingController(text: widget.edit ? '${x['owner'] ?? ''}' : '');
    mobile = TextEditingController(text: widget.edit ? '${x['mobile'] ?? ''}' : '');
    address = TextEditingController(text: widget.edit ? '${x['address'] ?? ''}' : '');
  }
  @override
  void dispose() {
    name.dispose(); owner.dispose(); mobile.dispose(); address.dispose();
    super.dispose();
  }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final data = {
      'name': name.text.trim(), 'owner': owner.text.trim(),
      'mobile': mobile.text.trim(), 'address': address.text.trim()
    };
    if (widget.edit) await store.updateShop(data); else await store.addShop(data);
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.edit ? 'Edit Shop' : 'Register Shop',
        child: Column(children: [
          FieldBox('Shop / Company Name', name),
          FieldBox('Owner Name', owner),
          FieldBox('Mobile Number', mobile, keyboard: TextInputType.phone),
          FieldBox('Address', address, maxLines: 3),
          PrimaryButton(
              label: widget.edit ? 'Update Shop' : 'Save Shop', onPressed: save),
        ]),
      );
}

class ShopsPage extends StatelessWidget {
  const ShopsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Shop / Company',
        child: Column(children: [
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.store_rounded, color: emerald),
              title: Text('${store.shop['name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${store.shop['owner'] ?? ''}\n${store.shop['address'] ?? ''}'),
              trailing: IconButton(
                  onPressed: () =>
                      openPage(context, const ShopFormPage(edit: true)),
                  icon: const Icon(Icons.edit, color: emerald)),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Add New Shop',
            icon: Icons.add_business_rounded,
            onPressed: () => openPage(context, const ShopFormPage()),
          ),
        ]),
      );
}

class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = store.records('items');
    return PageFrame(
      title: 'Inventory / Item Master',
      child: Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => openPage(context, const ItemFormPage()),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
        const SizedBox(height: 8),
        if (r.isEmpty) const EmptyState('No inventory items added yet.'),
        ...List.generate(r.length, (i) {
          final x = r[i];
          return DataRowCard(
            title: '${x['name']}',
            subtitle:
                'Code: ${x['code']} • Stock: ${x['quantity']} ${x['unit']} • Rent: ${money(x['rentPrice'])}/day',
            onEdit: () => openPage(context, ItemFormPage(index: i)),
            onDelete: () => store.deleteRecord('items', i),
          );
        }),
      ]),
    );
  }
}

class ItemFormPage extends StatefulWidget {
  final int? index;
  const ItemFormPage({super.key, this.index});
  @override
  State<ItemFormPage> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemFormPage> {
  late TextEditingController code, name, unit, qty, rent;
  @override
  void initState() {
    super.initState();
    final x = widget.index == null
        ? <String, dynamic>{}
        : store.records('items')[widget.index!];
    code = TextEditingController(text: '${x['code'] ?? ''}');
    name = TextEditingController(text: '${x['name'] ?? ''}');
    unit = TextEditingController(text: '${x['unit'] ?? 'pcs'}');
    qty = TextEditingController(text: '${x['quantity'] ?? 0}');
    rent = TextEditingController(text: '${x['rentPrice'] ?? 0}');
  }
  @override
  void dispose() {
    code.dispose(); name.dispose(); unit.dispose(); qty.dispose(); rent.dispose();
    super.dispose();
  }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final old = widget.index == null ? null : store.records('items')[widget.index!];
    final data = {
      'id': old?['id'] ?? newId(),
      'code': code.text.trim(),
      'name': name.text.trim(),
      'unit': unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
      'quantity': int.tryParse(qty.text) ?? 0,
      'rentPrice': double.tryParse(rent.text) ?? 0,
    };
    if (widget.index == null) {
      await store.addRecord('items', data);
    } else {
      await store.editRecord('items', widget.index!, data);
    }
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.index == null ? 'New Inventory Item' : 'Edit Inventory Item',
        child: Column(children: [
          FieldBox('Item Code', code),
          FieldBox('Item Name / Description', name),
          Row(children: [
            Expanded(child: FieldBox('Unit', unit)),
            const SizedBox(width: 10),
            Expanded(child: FieldBox('Opening Quantity', qty, keyboard: TextInputType.number)),
          ]),
          FieldBox('Rent Price / Day', rent,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          PrimaryButton(label: 'Save Item', icon: Icons.save_outlined, onPressed: save),
        ]),
      );
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = store.records('customers');
    return PageFrame(
      title: 'Customer / Party Master',
      child: Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => openPage(context, const CustomerFormPage()),
            icon: const Icon(Icons.add),
            label: const Text('Add Party'),
          ),
        ),
        const SizedBox(height: 8),
        if (r.isEmpty) const EmptyState('No customers added yet.'),
        ...List.generate(r.length, (i) => DataRowCard(
              title: '${r[i]['name']}',
              subtitle: '${r[i]['mobile']} • ${r[i]['address']}',
              onEdit: () => openPage(context, CustomerFormPage(index: i)),
              onDelete: () => store.deleteRecord('customers', i),
            )),
      ]),
    );
  }
}

class CustomerFormPage extends StatefulWidget {
  final int? index;
  const CustomerFormPage({super.key, this.index});
  @override
  State<CustomerFormPage> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerFormPage> {
  late TextEditingController name, mobile, address;
  @override
  void initState() {
    super.initState();
    final x = widget.index == null
        ? <String, dynamic>{}
        : store.records('customers')[widget.index!];
    name = TextEditingController(text: '${x['name'] ?? ''}');
    mobile = TextEditingController(text: '${x['mobile'] ?? ''}');
    address = TextEditingController(text: '${x['address'] ?? ''}');
  }
  @override
  void dispose() {
    name.dispose(); mobile.dispose(); address.dispose(); super.dispose();
  }
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final old = widget.index == null ? null : store.records('customers')[widget.index!];
    final data = {
      'id': old?['id'] ?? newId(),
      'name': name.text.trim(),
      'mobile': mobile.text.trim(),
      'address': address.text.trim(),
    };
    if (widget.index == null) {
      await store.addRecord('customers', data);
    } else {
      await store.editRecord('customers', widget.index!, data);
    }
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.index == null ? 'New Customer / Party' : 'Edit Customer / Party',
        child: Column(children: [
          FieldBox('Customer / Party Name', name),
          FieldBox('Mobile Number', mobile, keyboard: TextInputType.phone),
          FieldBox('Address', address, maxLines: 3),
          PrimaryButton(label: 'Save Party', icon: Icons.save_outlined, onPressed: save),
        ]),
      );
}

class IssueLine {
  String itemId;
  int qty;
  double rent;
  int days;
  IssueLine({required this.itemId, this.qty = 1, this.rent = 0, this.days = 1});
}

class IssuePage extends StatefulWidget {
  const IssuePage({super.key});
  @override
  State<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends State<IssuePage> {
  String? customer;
  final invoice = TextEditingController();
  final lines = <IssueLine>[];

  @override
  void initState() {
    super.initState();
    invoice.text = 'INV-${DateTime.now().millisecondsSinceEpoch}';
  }
  @override
  void dispose() { invoice.dispose(); super.dispose(); }

  void addLine() {
    final items = store.records('items');
    if (items.isEmpty) return;
    final x = items.first;
    setState(() => lines.add(IssueLine(
          itemId: '${x['id']}',
          rent: double.tryParse('${x['rentPrice'] ?? 0}') ?? 0,
        )));
  }

  Future<void> save() async {
    if (customer == null || lines.isEmpty) return;
    final items = store.records('items');
    final saved = <Map<String, dynamic>>[];
    for (final l in lines) {
      final x = items.firstWhere((e) => '${e['id']}' == l.itemId);
      final stock = int.tryParse('${x['quantity'] ?? 0}') ?? 0;
      if (l.qty <= 0 || l.qty > stock) return;
      saved.add({
        'itemId': l.itemId,
        'name': '${x['name']}',
        'qty': l.qty,
        'rentPrice': l.rent,
        'rentDays': l.days,
      });
    }
    final data = {
      'id': newId(), 'invoice': invoice.text.trim(), 'customerId': customer,
      'date': today(), 'items': saved,
    };
    await store.addRecord('issues', data);
    for (final l in lines) await store.updateItemStock(l.itemId, -l.qty);
    if (mounted) {
      await printIssueBill(data);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = store.records('customers');
    final items = store.records('items');
    return PageFrame(
      title: 'Issued / Rental Invoice',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: customer,
              decoration: const InputDecoration(labelText: 'Customer / Party'),
              items: customers
                  .map((x) => DropdownMenuItem<String>(
                        value: '${x['id']}', child: Text('${x['name']}')))
                  .toList(),
              onChanged: (v) => setState(() => customer = v),
            ),
          ),
          IconButton(
            tooltip: 'Add Party',
            onPressed: () => openPage(context, const CustomerFormPage()),
            icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 30),
          ),
        ]),
        const SizedBox(height: 12),
        FieldBox('Invoice Number', invoice),
        const SectionTitle('INVENTORY ITEMS'),
        if (items.isEmpty) const EmptyState('Add inventory items first.'),
        ...List.generate(lines.length, (i) {
          final l = lines[i];
          final item = items.firstWhere((x) => '${x['id']}' == l.itemId, orElse: () => items.first);
          return Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: l.itemId,
                      decoration: const InputDecoration(labelText: 'Inventory Item'),
                      items: items.map((x) => DropdownMenuItem<String>(
                          value: '${x['id']}', child: Text('${x['name']}'))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final x = items.firstWhere((e) => '${e['id']}' == v);
                        setState(() { l.itemId = v; l.rent = double.tryParse('${x['rentPrice'] ?? 0}') ?? 0; });
                      },
                    ),
                  ),
                  IconButton(onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                ]),
                Row(children: [
                  Expanded(child: FieldBox('Qty (stock ${item['quantity'] ?? 0})', TextEditingController(text: '${l.qty}'), keyboard: TextInputType.number, onChanged: (v) => l.qty = int.tryParse(v) ?? 1)),
                  const SizedBox(width: 8),
                  Expanded(child: FieldBox('Rent / Day', TextEditingController(text: '${l.rent}'), keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => l.rent = double.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  Expanded(child: FieldBox('Rent Days', TextEditingController(text: '${l.days}'), keyboard: TextInputType.number, onChanged: (v) => l.days = int.tryParse(v) ?? 1)),
                ]),
              ]),
            ),
          );
        }),
        PrimaryButton(label: 'Add Another Item', icon: Icons.add_rounded, onPressed: addLine),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Save & Print Issue Bill', icon: Icons.picture_as_pdf_rounded, onPressed: save),
      ]),
    );
  }
}

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});
  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  String? customer;
  String? issueId;
  final amount = TextEditingController();
  final notes = TextEditingController();
  final selected = <String, int>{};

  @override
  void dispose() { amount.dispose(); notes.dispose(); super.dispose(); }

  Map<String, dynamic>? get selectedIssue {
    for (final x in store.records('issues')) {
      if ('${x['id']}' == issueId) return x;
    }
    return null;
  }

  Future<void> save() async {
    final issue = selectedIssue;
    if (issue == null || selected.values.every((v) => v <= 0)) return;
    final returnedItems = <Map<String, dynamic>>[];
    final issueItems = (issue['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (final item in issueItems) {
      final id = '${item['itemId']}';
      final n = selected[id] ?? 0;
      final max = int.tryParse('${item['qty'] ?? 0}') ?? 0;
      if (n > 0) {
        returnedItems.add({...item, 'qty': n});
        item['qty'] = max - n;
      }
    }
    if (returnedItems.isEmpty) return;
    final calculated = returnedItems.fold<double>(0, (sum, x) => sum + ((double.tryParse('${x['rentPrice'] ?? 0}') ?? 0) * (int.tryParse('${x['qty'] ?? 0}') ?? 0) * (int.tryParse('${x['rentDays'] ?? 1}') ?? 1)));
    final data = {
      'id': newId(), 'returnInvoice': 'RET-${DateTime.now().millisecondsSinceEpoch}',
      'issueId': issueId, 'customerId': customer, 'date': today(),
      'amount': double.tryParse(amount.text) ?? calculated, 'notes': notes.text.trim(),
      'items': returnedItems,
    };
    await store.addRecord('returns', data);
    final issues = store.records('issues');
    final idx = issues.indexWhere((x) => '${x['id']}' == issueId);
    if (idx >= 0) await store.editRecord('issues', idx, {...issue, 'items': issueItems.where((x) => (int.tryParse('${x['qty']}') ?? 0) > 0).toList()});
    for (final x in returnedItems) await store.updateItemStock('${x['itemId']}', int.tryParse('${x['qty']}') ?? 0);
    if (mounted) {
      await printReturnBill(data);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = store.records('customers');
    final issues = store.records('issues').where((x) => customer == null || '${x['customerId']}' == customer).toList();
    final issue = selectedIssue;
    final issueItems = (issue?['items'] as List? ?? []).where((e) => (int.tryParse('${e['qty'] ?? 0}') ?? 0) > 0).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return PageFrame(
      title: 'Return Entry',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: customer,
            decoration: const InputDecoration(labelText: 'Customer / Party'),
            items: customers.map((x) => DropdownMenuItem<String>(value: '${x['id']}', child: Text('${x['name']}'))).toList(),
            onChanged: (v) => setState(() { customer = v; issueId = null; selected.clear(); }),
          )),
          IconButton(tooltip: 'Add Party', onPressed: () => openPage(context, const CustomerFormPage()), icon: const Icon(Icons.add_circle_rounded, color: emerald, size: 30)),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: issueId,
          decoration: const InputDecoration(labelText: 'Issued Invoice'),
          items: issues.map((x) => DropdownMenuItem<String>(value: '${x['id']}', child: Text('${x['invoice']} • ${customerName('${x['customerId']}')}'))).toList(),
          onChanged: (v) => setState(() { issueId = v; selected.clear(); }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FieldBox('Return Invoice / No.', TextEditingController(text: issueId == null ? '' : 'RET-${DateTime.now().millisecondsSinceEpoch}'), readOnly: true)),
          const SizedBox(width: 10),
          Expanded(child: FieldBox('Return Date', TextEditingController(text: today()), readOnly: true)),
        ]),
        const SectionTitle('ITEMS FROM ISSUE'),
        if (issue == null) const EmptyState('Select a customer and issued invoice.'),
        ...issueItems.map((item) {
          final id = '${item['itemId']}';
          final max = int.tryParse('${item['qty']}') ?? 0;
          final rent = double.tryParse('${item['rentPrice'] ?? 0}') ?? 0;
          final days = int.tryParse('${item['rentDays'] ?? 1}') ?? 1;
          final value = selected[id] ?? 0;
          return Card(
            elevation: 0,
            color: value > 0 ? emeraldSoft : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined, color: emerald),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('Issued Qty $max • Rent ${money(rent)}/day • $days day(s)'),
                  Text('Return Rent: ${money(rent * value * days)}', style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.w800)),
                ])),
                SizedBox(width: 85, child: TextFormField(
                  initialValue: value == 0 ? '' : '$value',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Return', hintText: '0-$max'),
                  onChanged: (v) => setState(() { selected[id] = (int.tryParse(v) ?? 0).clamp(0, max); }),
                )),
              ]),
            ),
          );
        }),
        FieldBox('Return Amount (optional)', amount, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        FieldBox('Return Note', notes, maxLines: 3),
        PrimaryButton(label: 'Save & Print Return', icon: Icons.picture_as_pdf_rounded, onPressed: save),
      ]),
    );
  }
}

String customerName(String? id) {
  for (final x in store.records('customers')) {
    if ('${x['id']}' == id) return '${x['name']}';
  }
  return 'Party';
}

class InventoryRegisterPage extends StatelessWidget {
  const InventoryRegisterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = store.records('items');
    return PageFrame(
      title: 'Inventory Register',
      child: Column(children: [
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => openPage(context, const ItemFormPage()), icon: const Icon(Icons.add), label: const Text('Add Item'))),
        const SizedBox(height: 8),
        if (r.isEmpty) const EmptyState('No inventory records.'),
        ...r.map((x) => Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: emerald),
          title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('Code ${x['code']} • ${x['unit']} • Rent ${money(x['rentPrice'])}/day'),
          trailing: Text('${x['quantity']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: emeraldDark)),
        )))
      ]),
    );
  }
}

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final issues = store.records('issues');
    final returns = store.records('returns');
    return PageFrame(
      title: 'Transactions / Bills',
      child: Column(children: [
        const SectionTitle('ISSUED BILLS'),
        if (issues.isEmpty) const EmptyState('No issued bills yet.'),
        ...issues.map((x) => Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.outbox_rounded, color: emerald),
          title: Text('${x['invoice']} • ${customerName('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${x['date']} • ${(x['items'] as List? ?? []).length} item(s)'),
          trailing: IconButton(tooltip: 'Print PDF', onPressed: () => printIssueBill(x), icon: const Icon(Icons.picture_as_pdf_rounded, color: emerald)),
        ))),
        const SectionTitle('RETURN RECEIPTS'),
        if (returns.isEmpty) const EmptyState('No return entries yet.'),
        ...returns.map((x) => Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.assignment_return_rounded, color: emerald),
          title: Text('${x['returnInvoice'] ?? 'Return'} • ${customerName('${x['customerId']}')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${x['date']} • ${money(x['amount'])}'),
          trailing: IconButton(tooltip: 'Print PDF', onPressed: () => printReturnBill(x), icon: const Icon(Icons.picture_as_pdf_rounded, color: emerald)),
        ))),
      ]),
    );
  }
}

Future<void> printIssueBill(Map<String, dynamic> bill) async {
  final doc = pw.Document();
  final items = (bill['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final total = items.fold<double>(0, (s, x) => s + (double.tryParse('${x['rentPrice']}') ?? 0) * (int.tryParse('${x['qty']}') ?? 0) * (int.tryParse('${x['rentDays']}') ?? 1));
  doc.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text('${store.shop['name'] ?? 'RentFlow'}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
    pw.Text('RENTAL ISSUE INVOICE'),
    pw.SizedBox(height: 8),
    pw.Text('Invoice: ${bill['invoice']}'),
    pw.Text('Customer: ${customerName('${bill['customerId']}')}'),
    pw.Text('Date: ${bill['date']}'),
    pw.SizedBox(height: 12),
    pw.Table.fromTextArray(headers: const ['Item', 'Qty', 'Rent/Day', 'Days', 'Amount'], data: items.map((x) {
      final amount = (double.tryParse('${x['rentPrice']}') ?? 0) * (int.tryParse('${x['qty']}') ?? 0) * (int.tryParse('${x['rentDays']}') ?? 1);
      return ['${x['name']}', '${x['qty']}', money(x['rentPrice']), '${x['rentDays']}', money(amount)];
    }).toList()),
    pw.SizedBox(height: 12),
    pw.Text('Total Rent: ${money(total)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 24),
    pw.Text('By PaliaAPK HUB • Developer by shanpalia'),
  ])));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

Future<void> printReturnBill(Map<String, dynamic> bill) async {
  final doc = pw.Document();
  final items = (bill['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  doc.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text('${store.shop['name'] ?? 'RentFlow'}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
    pw.Text('RENTAL RETURN RECEIPT'),
    pw.SizedBox(height: 8),
    pw.Text('Return: ${bill['returnInvoice']}'),
    pw.Text('Customer: ${customerName('${bill['customerId']}')}'),
    pw.Text('Date: ${bill['date']}'),
    pw.SizedBox(height: 12),
    pw.Table.fromTextArray(headers: const ['Item', 'Returned Qty', 'Rent/Day', 'Days'], data: items.map((x) => ['${x['name']}', '${x['qty']}', money(x['rentPrice']), '${x['rentDays']}']).toList()),
    pw.SizedBox(height: 12),
    pw.Text('Return Amount: ${money(bill['amount'])}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    if ('${bill['notes']}'.trim().isNotEmpty) pw.Text('Note: ${bill['notes']}'),
    pw.SizedBox(height: 24),
    pw.Text('By PaliaAPK HUB • Developer by shanpalia'),
  ])));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Settings',
        child: Column(children: [
          Card(elevation: 0, child: ListTile(
            leading: const Icon(Icons.system_update_alt_rounded, color: emerald),
            title: const Text('Check Update', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Check the latest RentFlow version'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('Check Update'),
              content: const Text('You are using the current installed version.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            )),
          )),
          const SizedBox(height: 8),
          const Card(elevation: 0, child: ListTile(
            leading: Icon(Icons.info_outline, color: emerald),
            title: Text('RentFlow', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Rental Management • By PaliaAPK HUB • Developer by shanpalia'),
          )),
        ]),
      );
}

class FieldBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int maxLines;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  const FieldBox(this.label, this.controller, {super.key, this.keyboard, this.maxLines = 1, this.readOnly = false, this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          readOnly: readOnly,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: emeraldDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.save_outlined),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );
}

class DataRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DataRowCard({super.key, required this.title, required this.subtitle, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: emerald),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(child: Text(text, textAlign: TextAlign.center)),
        ),
      );
}
