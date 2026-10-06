import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emerald = Color(0xFF008F78);
const emeraldDark = Color(0xFF006B5A);
const emeraldSoft = Color(0xFFE7F6F1);
const pageBg = Color(0xFFF5F8F7);
const ink = Color(0xFF172521);
const line = Color(0xFFD8E5E1);

String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String today() => DateTime.now().toIso8601String().substring(0, 10);
int numInt(dynamic v) => int.tryParse('$v') ?? 0;
double numDouble(dynamic v) => double.tryParse('$v') ?? 0;
List<Map<String, dynamic>> maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

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
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
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
      'items': <dynamic>[],
      'customers': <dynamic>[],
      'issues': <dynamic>[],
      'returns': <dynamic>[],
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

  Future<void> updateItemQuantity(String id, int delta) async {
    final list = shop['items'] as List? ?? <dynamic>[];
    for (var i = 0; i < list.length; i++) {
      final item = Map<String, dynamic>.from(list[i] as Map);
      if ('${item['id']}' == id) {
        item['quantity'] = numInt(item['quantity']) + delta;
        list[i] = item;
        break;
      }
    }
    await save();
  }
}

final db = RentDb();

Future<void> openPage(BuildContext context, Widget page) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: emerald, width: 1.5),
          ),
        ),
      ),
      home: const CompanySelectPage(),
    );
  }
}

class Header extends StatelessWidget implements PreferredSizeWidget {
  final bool back;
  final String title;
  const Header({super.key, this.back = false, this.title = 'RentFlow • PaliaAPK HUB'});

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : Builder(
              builder: (c) => IconButton(
                onPressed: () => Scaffold.of(c).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 28),
              ),
            ),
      title: Row(
        children: [
          SvgPicture.asset('assets/rentflow_logo.svg', width: 34, height: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
    Navigator.of(context).pop();
    openPage(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final entries = <Map<String, dynamic>>[
      {'t': 'Dashboard', 'i': Icons.dashboard_rounded, 'p': const HomePage()},
      {'t': 'Inventory / Items', 'i': Icons.inventory_2_rounded, 'p': const ItemsPage()},
      {'t': 'Customers / Parties', 'i': Icons.people_alt_rounded, 'p': const CustomersPage()},
      {'t': 'Issued / New Invoice', 'i': Icons.outbox_rounded, 'p': const IssuePage()},
      {'t': 'Returns / Receive', 'i': Icons.assignment_return_rounded, 'p': const ReturnPage()},
      {'t': 'Inventory Register', 'i': Icons.table_rows_rounded, 'p': const InventoryPage()},
      {'t': 'Reports / Bills', 'i': Icons.receipt_long_rounded, 'p': const BillsPage()},
      {'t': 'Shop / Company', 'i': Icons.store_rounded, 'p': const ShopPage()},
      {'t': 'Settings / About', 'i': Icons.settings_rounded, 'p': const SettingsPage()},
    ];
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  SvgPicture.asset('assets/rentflow_logo.svg', width: 46, height: 46),
                  const SizedBox(width: 12),
                  const Text('RentFlow\nPaliaAPK HUB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return ListTile(
                    leading: Icon(e['i'] as IconData, color: emerald),
                    title: Text(e['t'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => go(context, e['p'] as Widget),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('By PaliaAPK HUB\nDeveloper by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final bool back;
  const PageShell({super.key, required this.title, required this.child, this.back = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(title: title, back: back),
      drawer: back ? null : const AppDrawer(),
      body: child,
    );
  }
}

class CompanySelectPage extends StatefulWidget {
  const CompanySelectPage({super.key});
  @override
  State<CompanySelectPage> createState() => _CompanySelectPageState();
}

class _CompanySelectPageState extends State<CompanySelectPage> {
  @override
  void initState() {
    super.initState();
    db.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) {
        if (!db.ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: line)),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          SvgPicture.asset('assets/rentflow_logo.svg', width: 76, height: 76),
                          const SizedBox(height: 16),
                          const Text('Select Company', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Choose the company you want to open in RentFlow.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 24),
                          if (db.shops.isEmpty)
                            const Text('No company registered yet. Create your first company below.')
                          else
                            ...List.generate(db.shops.length, (index) {
                              final s = db.shops[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: CompanyCard(
                                  shop: s,
                                  onOpen: () async {
                                    db.active = index;
                                    await db.save();
                                    if (context.mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (r) => false);
                                    }
                                  },
                                ),
                              );
                            }),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => openPage(context, const ShopPage(createMode: true)),
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Create New Company'),
                            style: FilledButton.styleFrom(backgroundColor: emeraldSoft, foregroundColor: emeraldDark),
                          ),
                          const SizedBox(height: 18),
                          const Text('By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompanyCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onOpen;
  const CompanyCard({super.key, required this.shop, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final image = '${shop['image'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(18)),
            child: image.isNotEmpty
                ? Image.file(File(image), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 36))
                : const Icon(Icons.store_rounded, color: emerald, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${shop['name'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${shop['owner'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${shop['mobile'] ?? ''}  •  ${shop['address'] ?? ''}', style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onOpen, child: const Text('Open Company')),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) {
        if (!db.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: emerald)));
        return PageShell(
          title: 'RentFlow • PaliaAPK HUB',
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _ShopBanner(onEdit: () => openPage(context, const ShopPage())),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: StatCard(label: 'Items', value: db.records('items').length.toString(), icon: Icons.inventory_2_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Parties', value: db.records('customers').length.toString(), icon: Icons.people_alt_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Issued', value: db.records('issues').length.toString(), icon: Icons.outbox_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Returns', value: db.records('returns').length.toString(), icon: Icons.assignment_return_rounded)),
              ]),
              const SizedBox(height: 20),
              const Text('Quick Actions', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.25,
                children: [
                  ActionCard('Issued / New Invoice', Icons.outbox_rounded, () => openPage(context, const IssuePage())),
                  ActionCard('Returns / Receive', Icons.assignment_return_rounded, () => openPage(context, const ReturnPage())),
                  ActionCard('Add Item', Icons.add_box_rounded, () => openPage(context, const ItemForm())),
                  ActionCard('Add Party', Icons.person_add_rounded, () => openPage(context, const CustomerForm())),
                  ActionCard('Inventory Register', Icons.table_rows_rounded, () => openPage(context, const InventoryPage())),
                  ActionCard('Reports / Bills', Icons.receipt_long_rounded, () => openPage(context, const BillsPage())),
                ],
              ),
              const SizedBox(height: 24),
              const Center(child: Text('RentFlow • By PaliaAPK HUB • Developer by shanpalia', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
            ],
          ),
        );
      },
    );
  }
}

class _ShopBanner extends StatelessWidget {
  final VoidCallback onEdit;
  const _ShopBanner({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final image = '${db.shop['image'] ?? ''}';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: line)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(18)),
            child: image.isNotEmpty
                ? Image.file(File(image), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 36))
                : const Icon(Icons.store_rounded, color: emerald, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${db.shop['name'] ?? 'Register your shop'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            Text('${db.shop['owner'] ?? ''} • ${db.shop['mobile'] ?? ''}', style: const TextStyle(color: Colors.black54)),
            Text('${db.shop['address'] ?? 'Add your shop information'}', style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Company')),
        ]),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const StatCard({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: emerald)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))])),
      ]),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: emerald)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          const Icon(Icons.arrow_forward_rounded, color: Colors.black38),
        ]),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  const SectionCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)), child: Padding(padding: const EdgeInsets.all(18), child: child));
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool requiredField;
  final int maxLines;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;
  const Field({super.key, required this.label, required this.controller, this.hint, this.keyboardType, this.requiredField = false, this.maxLines = 1, this.onSubmitted, this.textInputAction});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: textInputAction ?? (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      onFieldSubmitted: (_) {
        onSubmitted?.call();
        if (onSubmitted == null) FocusScope.of(context).nextFocus();
      },
      decoration: InputDecoration(labelText: requiredField ? '$label *' : label, hintText: hint),
      validator: requiredField ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}

class ResponsiveFields extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveFields({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final two = c.maxWidth >= 800;
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += two ? 2 : 1) {
        final row = children.skip(i).take(two ? 2 : 1).toList();
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12, bottom: 14), child: w))).toList()));
      }
      return Column(children: rows);
    });
  }
}

class ItemForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ItemForm({super.key, this.existing});
  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final code = TextEditingController();
  final category = TextEditingController();
  final rent = TextEditingController();
  final rateBasis = TextEditingController();
  final notes = TextEditingController();
  String? unit;
  String? period;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    if (x != null) {
      name.text = '${x['name'] ?? ''}';
      code.text = '${x['code'] ?? ''}';
      category.text = '${x['category'] ?? ''}';
      rent.text = '${x['rentPrice'] ?? ''}';
      rateBasis.text = '${x['rateBasis'] ?? ''}';
      notes.text = '${x['notes'] ?? ''}';
      unit = '${x['unit'] ?? ''}'.isEmpty ? null : '${x['unit']}';
      period = '${x['ratePeriod'] ?? ''}'.isEmpty ? null : '${x['ratePeriod']}';
    }
  }

  @override
  void dispose() {
    name.dispose(); code.dispose(); category.dispose(); rent.dispose(); rateBasis.dispose(); notes.dispose(); super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (unit == null || period == null) {
      snack(context, 'Please select Unit and Rate Period.');
      return;
    }
    setState(() => saving = true);
    final item = <String, dynamic>{
      'id': widget.existing?['id'] ?? uid(),
      'name': name.text.trim(),
      'code': code.text.trim(),
      'category': category.text.trim(),
      'unit': unit,
      'rentPrice': numDouble(rent.text),
      'rateBasis': numInt(rateBasis.text),
      'ratePeriod': period,
      'notes': notes.text.trim(),
      'quantity': numInt(widget.existing?['quantity']),
    };
    final list = db.shop['items'] as List? ?? <dynamic>[];
    final oldId = widget.existing?['id'];
    final index = oldId == null ? -1 : list.indexWhere((e) => '${(e as Map)['id']}' == '$oldId');
    if (index >= 0) list[index] = item; else list.add(item);
    await db.save();
    if (mounted) {
      setState(() => saving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: widget.existing == null ? 'Add Item' : 'Edit Item',
      back: true,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('INVENTORY MASTER', style: TextStyle(color: emeraldDark, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 5),
              Text(widget.existing == null ? 'Create rental item' : 'Edit rental item', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Set the item master and rental rate. Stock is handled by transactions.', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              ResponsiveFields(children: [
                Field(label: 'Item Name', controller: name, hint: 'e.g. Centering Plate', requiredField: true),
                Field(label: 'Item Code', controller: code, hint: 'e.g. CP-001'),
                Field(label: 'Category', controller: category, hint: 'e.g. General'),
                DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'Unit *'), items: const [DropdownMenuItem(value: 'Pcs', child: Text('Pcs')), DropdownMenuItem(value: 'Set', child: Text('Set')), DropdownMenuItem(value: 'Box', child: Text('Box')), DropdownMenuItem(value: 'Kg', child: Text('Kg')), DropdownMenuItem(value: 'Nos', child: Text('Nos'))], onChanged: (v) => setState(() => unit = v), validator: (v) => v == null ? 'Required' : null),
                Field(label: 'Rent Price', controller: rent, hint: 'e.g. 15', keyboardType: const TextInputType.numberWithOptions(decimal: true), requiredField: true),
                Field(label: 'Rate Basis (Qty)', controller: rateBasis, hint: 'e.g. 100', keyboardType: TextInputType.number, requiredField: true),
                DropdownButtonFormField<String>(value: period, decoration: const InputDecoration(labelText: 'Rate Period *'), items: const [DropdownMenuItem(value: 'Day', child: Text('Day')), DropdownMenuItem(value: 'Week', child: Text('Week')), DropdownMenuItem(value: 'Month', child: Text('Month'))], onChanged: (v) => setState(() => period = v), validator: (v) => v == null ? 'Required' : null),
              ]),
              const SizedBox(height: 14),
              Field(label: 'Description / Notes', controller: notes, hint: 'Optional item details, size, condition or notes', maxLines: 4),
              const SizedBox(height: 18),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_rounded), label: Text(saving ? 'Saving...' : 'Save Item'))),
            ])),
          ],
        ),
      ),
    );
  }
}

class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) => PageShell(
        title: 'Inventory / Items',
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inventory', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), Text('Manage rental item masters and rates.', style: TextStyle(color: Colors.black54))])), FilledButton.icon(onPressed: () => openPage(context, const ItemForm()), icon: const Icon(Icons.add_rounded), label: const Text('Add Item'))]),
            const SizedBox(height: 16),
            if (db.records('items').isEmpty)
              const SectionCard(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No items yet. Add your first rental item.'))))
            else
              ...db.records('items').map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ItemTile(item: item))),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemTile({required this.item});
  @override
  Widget build(BuildContext context) {
    return SectionCard(child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.inventory_2_rounded, color: emerald)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['name'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('${item['code'] ?? ''} • ${item['category'] ?? ''} • ${item['unit'] ?? ''}', style: const TextStyle(color: Colors.black54)), Text('Rent ${item['rentPrice'] ?? 0} / ${item['rateBasis'] ?? 0} ${item['ratePeriod'] ?? ''}', style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.w700))])),
      IconButton(onPressed: () => openPage(context, ItemForm(existing: item)), icon: const Icon(Icons.edit_rounded)),
    ]));
  }
}

class CustomerForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const CustomerForm({super.key, this.existing});
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); final x = widget.existing; if (x != null) { name.text = '${x['name'] ?? ''}'; mobile.text = '${x['mobile'] ?? ''}'; address.text = '${x['address'] ?? ''}'; notes.text = '${x['notes'] ?? ''}'; } }
  @override
  void dispose() { name.dispose(); mobile.dispose(); address.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final data = {'id': widget.existing?['id'] ?? uid(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'notes': notes.text.trim()};
    final list = db.shop['customers'] as List? ?? <dynamic>[];
    final old = widget.existing?['id'];
    final i = old == null ? -1 : list.indexWhere((e) => '${(e as Map)['id']}' == '$old');
    if (i >= 0) list[i] = data; else list.add(data);
    await db.save();
    if (mounted) Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) => PageShell(title: widget.existing == null ? 'Add Party' : 'Edit Party', back: true, child: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [SectionCard(child: Column(children: [Field(label: 'Party / Customer Name', controller: name, requiredField: true), const SizedBox(height: 14), Field(label: 'Mobile', controller: mobile, keyboardType: TextInputType.phone), const SizedBox(height: 14), Field(label: 'Address', controller: address), const SizedBox(height: 14), Field(label: 'Notes', controller: notes, maxLines: 3), const SizedBox(height: 18), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('Save Party')))]))])));
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: db, builder: (_, __) => PageShell(title: 'Customers / Parties', child: ListView(padding: const EdgeInsets.all(18), children: [Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Customers / Parties', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), Text('Manage customers used on invoices.', style: TextStyle(color: Colors.black54))])), FilledButton.icon(onPressed: () => openPage(context, const CustomerForm()), icon: const Icon(Icons.person_add_rounded), label: const Text('Add Party'))]), const SizedBox(height: 16), if (db.records('customers').isEmpty) const SectionCard(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No parties added yet.')))) else ...db.records('customers').map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SectionCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: emeraldSoft, child: Text('${c['name'] ?? '?'}'.isEmpty ? '?' : '${c['name']}'.substring(0, 1).toUpperCase(), style: const TextStyle(color: emeraldDark, fontWeight: FontWeight.w900))), title: Text('${c['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${c['mobile'] ?? ''}\n${c['address'] ?? ''}'), trailing: IconButton(onPressed: () => openPage(context, CustomerForm(existing: c)), icon: const Icon(Icons.edit_rounded))))))])));
}

class IssueLine {
  String? itemId;
  final TextEditingController qty = TextEditingController();
  final TextEditingController unit = TextEditingController();
  IssueLine();
  void dispose() { qty.dispose(); unit.dispose(); }
}

class IssuePage extends StatefulWidget {
  const IssuePage({super.key});
  @override
  State<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends State<IssuePage> {
  final form = GlobalKey<FormState>();
  final invoice = TextEditingController();
  final date = TextEditingController(text: today());
  String? customerId;
  final lines = <IssueLine>[];

  @override
  void dispose() { invoice.dispose(); date.dispose(); for (final x in lines) x.dispose(); super.dispose(); }

  void addLine() => setState(() => lines.add(IssueLine()));
  void removeLine(int i) { lines[i].dispose(); setState(() => lines.removeAt(i)); }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (customerId == null) { snack(context, 'Select a party/customer.'); return; }
    if (lines.isEmpty) { snack(context, 'Add at least one item.'); return; }
    final clean = <Map<String, dynamic>>[];
    for (final lineItem in lines) {
      if (lineItem.itemId == null || lineItem.itemId!.isEmpty) { snack(context, 'Select an item in every row.'); return; }
      final qty = numInt(lineItem.qty.text);
      if (qty <= 0) { snack(context, 'Enter issued quantity in every row.'); return; }
      clean.add({'itemId': lineItem.itemId, 'qty': qty, 'unit': lineItem.unit.text.trim()});
    }
    final data = {'id': uid(), 'invoice': invoice.text.trim(), 'issueDate': date.text.trim(), 'customerId': customerId, 'items': clean};
    await db.addRecord('issues', data);
    for (final row in clean) await db.updateItemQuantity('${row['itemId']}', -numInt(row['qty']));
    if (mounted) { snack(context, 'Issued invoice saved.'); Navigator.of(context).pop(); }
  }

  @override
  Widget build(BuildContext context) {
    final items = db.records('items');
    final customers = db.records('customers');
    final total = lines.fold<int>(0, (sum, x) => sum + numInt(x.qty.text));
    return PageShell(
      title: 'Issued / New Invoice',
      back: true,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)), child: const Text('✦ Manual invoice number: enter your own invoice number. Press Enter to move through the fields.', style: TextStyle(color: Colors.black54))),
            const SizedBox(height: 12),
            SectionCard(child: ResponsiveFields(children: [
              Field(label: 'Invoice No.', controller: invoice, hint: 'e.g. INV-1025', requiredField: true),
              TextFormField(controller: date, readOnly: true, decoration: const InputDecoration(labelText: 'Issue Date *', suffixIcon: Icon(Icons.calendar_month_rounded)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: DateTime.tryParse(date.text) ?? DateTime.now()); if (d != null) setState(() => date.text = d.toIso8601String().substring(0, 10)); }),
              Row(children: [Expanded(child: DropdownButtonFormField<String>(value: customerId, decoration: const InputDecoration(labelText: 'Party / Customer *'), items: customers.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text('${c['name'] ?? ''} • ${c['mobile'] ?? ''}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => customerId = v), validator: (v) => v == null ? 'Required' : null)), const SizedBox(width: 8), IconButton.filled(onPressed: () async { await openPage(context, const CustomerForm()); if (mounted) setState(() {}); }, icon: const Icon(Icons.add_rounded))]),
            ])),
            const SizedBox(height: 14),
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Issued Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Select item and enter issued quantity.', style: TextStyle(color: Colors.black54))])), Chip(label: Text('Total Issued Qty: $total'))]),
              const SizedBox(height: 14),
              if (lines.isEmpty)
                Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: pageBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: const Center(child: Text('No item added yet. Click “Add Item”.')))
              else
                ...List.generate(lines.length, (i) => _IssueRow(key: ValueKey(lines[i]), line: lines[i], index: i, items: items, onChanged: () => setState(() {}), onRemove: () => removeLine(i))),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [OutlinedButton.icon(onPressed: addLine, icon: const Icon(Icons.add_rounded), label: const Text('Add Item')), Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Total issued quantity', style: TextStyle(color: Colors.black54)), Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: emeraldDark))]))]),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.check_rounded), label: const Text('Save Issued Invoice'))),
            ])),
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final IssueLine line;
  final int index;
  final List<Map<String, dynamic>> items;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _IssueRow({super.key, required this.line, required this.index, required this.items, required this.onChanged, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: index.isEven ? lineColor : emerald.withAlpha(55))),
      child: LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 720;
        final fields = <Widget>[
          Expanded(child: DropdownButtonFormField<String>(value: line.itemId, decoration: InputDecoration(labelText: 'Item ${index + 1} *'), items: items.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['name'] ?? ''}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { line.itemId = v; final item = items.firstWhere((x) => '${x['id']}' == '$v'); line.unit.text = '${item['unit'] ?? ''}'; onChanged(); }, validator: (v) => v == null ? 'Select' : null)),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: line.unit, readOnly: true, decoration: const InputDecoration(labelText: 'Unit'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: line.qty, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onChanged: (_) => onChanged(), onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(), decoration: const InputDecoration(labelText: 'Issued Qty *'), validator: (v) => numInt(v) > 0 ? null : 'Enter qty')),
        ];
        if (compact) {
          return Column(
            children: [
              ...fields.map((x) => Padding(padding: const EdgeInsets.only(bottom: 10), child: x)),
              Align(alignment: Alignment.centerRight, child: IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded))),
            ],
          );
        }
        return Row(children: [...fields, IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded))]);
      }),
    );
  }
}

Color lineColor(int index) => index.isEven ? line : emerald.withAlpha(55);

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});
  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  String? issueId;
  final qty = <String, TextEditingController>{};

  @override
  void dispose() { for (final c in qty.values) c.dispose(); super.dispose(); }

  Map<String, dynamic>? get issue {
    for (final x in db.records('issues')) {
      if ('${x['id']}' == '$issueId') return x;
    }
    return null;
  }

  Future<void> save() async {
    final selected = issue;
    if (selected == null) { snack(context, 'Select an issued invoice.'); return; }
    final returnedItems = <Map<String, dynamic>>[];
    for (final x in maps(selected['items'])) {
      final id = '${x['itemId']}';
      final n = numInt(qty[id]?.text);
      if (n > 0) returnedItems.add({'itemId': id, 'qty': n, 'unit': x['unit']});
    }
    if (returnedItems.isEmpty) { snack(context, 'Enter return quantity.'); return; }
    await db.addRecord('returns', {'id': uid(), 'issueId': selected['id'], 'invoice': selected['invoice'], 'returnDate': today(), 'items': returnedItems});
    for (final row in returnedItems) await db.updateItemQuantity('${row['itemId']}', numInt(row['qty']));
    if (mounted) { snack(context, 'Return saved.'); Navigator.of(context).pop(); }
  }

  @override
  Widget build(BuildContext context) {
    final issues = db.records('issues');
    final selected = issue;
    return PageShell(
      title: 'Returns / Receive',
      back: true,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Receive Returned Items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Select an issued invoice, then enter the quantity actually returned.', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(value: issueId, decoration: const InputDecoration(labelText: 'Issued Invoice *'), items: issues.map((x) => DropdownMenuItem(value: '${x['id']}', child: Text('${x['invoice'] ?? ''}'))).toList(), onChanged: (v) { setState(() { issueId = v; for (final c in qty.values) c.dispose(); qty.clear(); }); }),
              if (selected != null) ...[
                const SizedBox(height: 18),
                Text('Invoice ${selected['invoice']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ...maps(selected['items']).map((x) {
                  final id = '${x['itemId']}';
                  qty.putIfAbsent(id, () => TextEditingController());
                  final item = db.records('items').firstWhere((i) => '${i['id']}' == id, orElse: () => <String, dynamic>{});
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Expanded(child: Text('${item['name'] ?? 'Item'} • ${x['qty']} issued', style: const TextStyle(fontWeight: FontWeight.w800))), const SizedBox(width: 12), SizedBox(width: 170, child: TextFormField(controller: qty[id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Returned Qty')))]));
                }),
              ],
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.assignment_return_rounded), label: const Text('Save Return'))),
            ]),
          ),
        ],
      ),
    );
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) {
        final items = db.records('items');
        return PageShell(
          title: 'Inventory Register',
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Inventory Register', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text('No items yet.')
                  else
                    ...items.map((x) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_rounded, color: emerald),
                      title: Text('${x['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('${x['unit'] ?? ''} • Current quantity ${x['quantity'] ?? 0}'),
                      trailing: Text('${x['quantity'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    )),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (_, __) {
        final issues = db.records('issues');
        return PageShell(
          title: 'Reports / Bills',
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Issued Bills', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (issues.isEmpty)
                    const Text('No issued invoices yet.')
                  else
                    ...issues.map((x) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_rounded, color: emerald),
                      title: Text('Invoice ${x['invoice'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('Issued ${x['issueDate'] ?? ''} • ${maps(x['items']).fold<int>(0, (s, r) => s + numInt(r['qty']))} units'),
                    )),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShopPage extends StatefulWidget {
  final bool createMode;
  const ShopPage({super.key, this.createMode = false});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final owner = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  String? image;

  @override
  void initState() {
    super.initState();
    final x = widget.createMode ? null : db.shop;
    if (x != null && x.isNotEmpty) {
      name.text = '${x['name'] ?? ''}';
      owner.text = '${x['owner'] ?? ''}';
      mobile.text = '${x['mobile'] ?? ''}';
      address.text = '${x['address'] ?? ''}';
      notes.text = '${x['notes'] ?? ''}';
      final path = '${x['image'] ?? ''}';
      image = path.isEmpty ? null : path;
    }
  }

  @override
  void dispose() {
    name.dispose(); owner.dispose(); mobile.dispose(); address.dispose(); notes.dispose(); super.dispose();
  }

  Future<void> pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null && mounted) setState(() => image = p.path);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final data = <String, dynamic>{'name': name.text.trim(), 'owner': owner.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim(), 'notes': notes.text.trim(), 'image': image ?? ''};
    if (widget.createMode || db.shops.isEmpty) {
      await db.addShop(data);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (r) => false);
      }
    } else {
      await db.updateShop(data);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: widget.createMode ? 'Create Company' : 'Shop / Company',
      back: true,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 72, height: 72, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: emeraldSoft, borderRadius: BorderRadius.circular(18)), child: image == null ? const Icon(Icons.store_rounded, color: emerald, size: 36) : Image.file(File(image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: emerald, size: 36))),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(onPressed: pickImage, icon: const Icon(Icons.photo_library_rounded), label: const Text('Choose Shop Logo')),
                ]),
                const SizedBox(height: 20),
                ResponsiveFields(children: [
                  Field(label: 'Shop / Company Name', controller: name, requiredField: true),
                  Field(label: 'Owner Name', controller: owner, requiredField: true),
                  Field(label: 'Mobile', controller: mobile),
                  Field(label: 'Address', controller: address),
                ]),
                const SizedBox(height: 14),
                Field(label: 'Notes', controller: notes, maxLines: 3),
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('Save Company'))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => PageShell(title: 'Settings / About', child: ListView(padding: const EdgeInsets.all(18), children: [SectionCard(child: Column(children: [ListTile(leading: const Icon(Icons.store_rounded, color: emerald), title: Text('${db.shop['name'] ?? 'RentFlow'}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Active company')), const Divider(), const ListTile(leading: Icon(Icons.info_outline_rounded, color: emerald), title: Text('RentFlow'), subtitle: Text('By PaliaAPK HUB • Developer by shanpalia'))]))]));
}
