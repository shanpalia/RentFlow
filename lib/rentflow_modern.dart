import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app.dart' as old;

const rp = Color(0xFF00A889);
const rd = Color(0xFF10241F);
const rb = Color(0xFFF5FAF8);
const rs = Color(0xFFE7F7F2);
const rl = Color(0xFFDDEBE6);

Future<void> runModern() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ModernApp());
}

class ModernApp extends StatelessWidget {
  const ModernApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentFlow',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: rb,
        colorScheme: ColorScheme.fromSeed(seedColor: rp),
        appBarTheme: const AppBarTheme(backgroundColor: rb, foregroundColor: rd, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: rl)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: rp, width: 1.5)),
        ),
      ),
      home: const Splash(),
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({this.size = 48, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .07),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .27), border: Border.all(color: rl)),
      child: SvgPicture.asset('assets/rentflow_logo.svg'),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override State<Splash> createState() => _SplashState();
}
class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Logo(size: 108),
          SizedBox(height: 18),
          Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: rd)),
          SizedBox(height: 4),
          Text('By PaliaAPK HUB', style: TextStyle(color: rp, fontWeight: FontWeight.w800)),
          SizedBox(height: 3),
          Text('Developer by shanpalia', style: TextStyle(color: Colors.black45)),
        ]),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}
class _ShellState extends State<Shell> {
  final old.Store store = old.Store();
  int tab = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    store.load().then((_) { if (mounted) setState(() => loading = false); });
  }

  void refresh() { if (mounted) setState(() {}); }

  Future<void> register() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => old.ShopRegistrationPage(store: store)));
    refresh();
  }

  Future<bool> gate(BuildContext context) async {
    if (store.registered) return true;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Register your shop first'),
        content: const Text('Register your shop before making an entry. You can continue browsing by choosing Later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Later')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.storefront_rounded), label: const Text('Register Shop')),
        ],
      ),
    );
    if (choice == true && context.mounted) await register();
    return store.registered;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: rp)));
    final pages = <Widget>[
      Home(store: store, register: register, gate: gate),
      Inventory(store: store, gate: gate, refresh: refresh),
      Customers(store: store, gate: gate, refresh: refresh),
      Rentals(store: store, gate: gate, refresh: refresh),
      Settings(store: store, register: register),
    ];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && tab != 0) setState(() => tab = 0); },
      child: Scaffold(
        body: pages[tab],
        bottomNavigationBar: NavigationBar(
          height: 76,
          backgroundColor: Colors.white,
          indicatorColor: rs,
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Items'),
            NavigationDestination(icon: Icon(Icons.people_outline_rounded), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Rentals'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class Home extends StatelessWidget {
  final old.Store store;
  final VoidCallback register;
  final Future<bool> Function(BuildContext) gate;
  const Home({required this.store, required this.register, required this.gate, super.key});

  @override
  Widget build(BuildContext context) {
    final issued = store.rentals.fold<int>(0, (sum, r) => sum + old.asInt(r['qty']));
    final active = store.rentals.where((r) => old.asInt(r['received']) < old.asInt(r['qty'])).length;
    final total = store.rentals.fold<double>(0, (sum, r) => sum + old.asDouble(r['amount']));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          Row(children: [
            const Logo(size: 48),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RentFlow', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: rd)),
              Text('By PaliaAPK HUB', style: TextStyle(fontSize: 12, color: rp, fontWeight: FontWeight.w800)),
            ])),
            InkWell(
              onTap: register,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 154,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: rl)),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.storefront_rounded, color: rp)),
                  const SizedBox(width: 7),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SHOP', style: TextStyle(fontSize: 8, color: rp, fontWeight: FontWeight.w900)),
                    Text(store.registered ? store.shop : 'Register shop', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: rd)),
                    Text(store.registered ? store.owner : 'Tap to setup', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                  ])),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          if (!store.registered) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: rd, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                const Icon(Icons.storefront_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(child: Text('Register your shop to unlock entries.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                TextButton(onPressed: register, child: const Text('Register', style: TextStyle(color: Colors.white))),
              ]),
            ),
            const SizedBox(height: 18),
          ],
          Row(children: [Stat('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10), Stat('Customers', '${store.customers.length}', Icons.people_outline_rounded)]),
          const SizedBox(height: 10),
          Row(children: [Stat('Active', '$active', Icons.assignment_outlined), const SizedBox(width: 10), Stat('Issued Qty', '$issued', Icons.local_shipping_outlined)]),
          const SizedBox(height: 24),
          const Text('Quick actions', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: rd)),
          const SizedBox(height: 11),
          Row(children: [
            ActionTile('Add Item', Icons.add_box_outlined, () async { if (await gate(context) && context.mounted) { await itemEditor(context, store); } }),
            const SizedBox(width: 10),
            ActionTile('Customer', Icons.person_add_alt_1_outlined, () async { if (await gate(context) && context.mounted) { await customerEditor(context, store); } }),
            const SizedBox(width: 10),
            ActionTile('New Rental', Icons.receipt_long_outlined, () async { if (await gate(context) && context.mounted) { await rentalEditor(context, store); } }),
          ]),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent rentals', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: rd)),
            Text(old.money(total), style: const TextStyle(color: rp, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          if (store.rentals.isEmpty) const Empty() else ...store.rentals.reversed.take(5).map((r) => RentalCard(r)),
        ],
      ),
    );
  }
}

class Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const Stat(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: rl)),
      child: Row(children: [
        Container(width: 43, height: 43, decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: rp)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: rd)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ]),
    ));
  }
}

class ActionTile extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const ActionTile(this.text, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 104,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: rl)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: rp)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: rd)),
        ]),
      ),
    ));
  }
}

class Empty extends StatelessWidget {
  const Empty({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: rl)),
      child: const Column(children: [
        Icon(Icons.receipt_long_outlined, color: rp, size: 45),
        SizedBox(height: 12),
        Text('No rentals yet', style: TextStyle(fontWeight: FontWeight.w900, color: rd, fontSize: 16)),
        SizedBox(height: 5),
        Text('Saved rental invoices will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

class Inventory extends StatelessWidget {
  final old.Store store;
  final Future<bool> Function(BuildContext) gate;
  final VoidCallback refresh;
  const Inventory({required this.store, required this.gate, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w900)), actions: [
        IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await itemEditor(context, store); refresh(); } }, icon: const Icon(Icons.add_rounded)),
      ]),
      body: store.items.isEmpty
          ? const Padding(padding: EdgeInsets.all(18), child: Empty())
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: store.items.length,
              itemBuilder: (context, index) {
                final item = store.items[index];
                final qty = old.asInt(item['qty']);
                final issued = old.asInt(item['issued_qty']);
                final available = (qty - issued).clamp(0, qty);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: rl)),
                  child: Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(14)), child: Center(child: Text('${item['serial'] ?? index + 1}', style: const TextStyle(color: rp, fontWeight: FontWeight.w900)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: rd)),
                      Text('Total $qty  •  Issued $issued  •  Available $available', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      Text('${old.money(item['rent'])} / day', style: const TextStyle(color: rp, fontWeight: FontWeight.w800)),
                    ])),
                    IconButton.filledTonal(onPressed: () async { await addInventory(context, store, item); refresh(); }, icon: const Icon(Icons.add_rounded, color: rp), tooltip: 'Add more inventory'),
                    IconButton(onPressed: () async { await itemEditor(context, store, existing: item); refresh(); }, icon: const Icon(Icons.edit_outlined)),
                  ]),
                );
              },
            ),
    );
  }
}

Future<void> itemEditor(BuildContext context, old.Store store, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final qty = TextEditingController(text: '${existing?['qty'] ?? 1}');
  final rent = TextEditingController(text: '${existing?['rent'] ?? 0}');
  final days = TextEditingController(text: '${existing?['rent_days'] ?? 1}');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Add Rental Item' : 'Edit Rental Item'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
        const SizedBox(height: 10),
        TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total quantity')),
        const SizedBox(height: 10),
        TextField(controller: rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent price per day')),
        const SizedBox(height: 10),
        TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default rent days')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty) return;
          final q = int.tryParse(qty.text) ?? 0;
          final r = double.tryParse(rent.text) ?? 0;
          final d = int.tryParse(days.text) ?? 1;
          if (existing == null) {
            store.items.add({'serial': store.items.length + 1, 'name': name.text.trim(), 'qty': q, 'issued_qty': 0, 'rent': r, 'rent_days': d});
          } else {
            existing['name'] = name.text.trim();
            existing['qty'] = q;
            existing['rent'] = r;
            existing['rent_days'] = d;
          }
          await store.save();
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('Save')),
      ],
    ),
  );
  name.dispose(); qty.dispose(); rent.dispose(); days.dispose();
}

Future<void> addInventory(BuildContext context, old.Store store, Map<String, dynamic> item) async {
  final qty = TextEditingController(text: '1');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Add more: ${item['name']}'),
      content: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity to add')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final value = int.tryParse(qty.text) ?? 0;
          if (value > 0) {
            item['qty'] = old.asInt(item['qty']) + value;
            await store.save();
          }
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('Add Inventory')),
      ],
    ),
  );
  qty.dispose();
}

class Customers extends StatelessWidget {
  final old.Store store;
  final Future<bool> Function(BuildContext) gate;
  final VoidCallback refresh;
  const Customers({required this.store, required this.gate, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w900)), actions: [
        IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await customerEditor(context, store); refresh(); } }, icon: const Icon(Icons.person_add_alt_1_rounded)),
      ]),
      body: store.customers.isEmpty
          ? const Padding(padding: EdgeInsets.all(18), child: Empty())
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: store.customers.length,
              itemBuilder: (context, index) {
                final customer = store.customers[index];
                final name = '${customer['name'] ?? ''}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: rl)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: rs, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: rp, fontWeight: FontWeight.w900))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${customer['phone'] ?? ''}\n${customer['address'] ?? ''}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

Future<void> customerEditor(BuildContext context, old.Store store) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add Customer'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Party name')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
        const SizedBox(height: 10),
        TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty) return;
          store.customers.add({'name': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim()});
          await store.save();
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('Save')),
      ],
    ),
  );
  name.dispose(); phone.dispose(); address.dispose();
}

class Rentals extends StatelessWidget {
  final old.Store store;
  final Future<bool> Function(BuildContext) gate;
  final VoidCallback refresh;
  const Rentals({required this.store, required this.gate, required this.refresh, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental Invoices', style: TextStyle(fontWeight: FontWeight.w900)), actions: [
        IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await rentalEditor(context, store); refresh(); } }, icon: const Icon(Icons.add_rounded)),
      ]),
      body: store.rentals.isEmpty
          ? const Padding(padding: EdgeInsets.all(18), child: Empty())
          : ListView.builder(padding: const EdgeInsets.all(18), itemCount: store.rentals.length, itemBuilder: (context, index) {
              final rental = store.rentals[store.rentals.length - 1 - index];
              return RentalCard(rental);
            }),
    );
  }
}

class RentalCard extends StatelessWidget {
  final Map<String, dynamic> rental;
  const RentalCard(this.rental, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: rl)),
      child: Row(children: [
        Container(width: 45, height: 45, decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.receipt_long_rounded, color: rp)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${rental['invoice_no'] ?? 'Invoice'}', style: const TextStyle(color: rp, fontWeight: FontWeight.w900)),
          Text('${rental['customer'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, color: rd)),
          Text('${rental['item'] ?? ''} • Qty ${rental['qty'] ?? 0} • ${rental['date'] ?? ''}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ])),
        Text(old.money(rental['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: rp)),
      ]),
    );
  }
}

Future<void> rentalEditor(BuildContext context, old.Store store) async {
  if (store.items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an inventory item first.')));
    return;
  }
  if (store.customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a customer first.')));
    return;
  }
  Map<String, dynamic> item = store.items.first;
  Map<String, dynamic> customer = store.customers.first;
  final qty = TextEditingController(text: '1');
  final days = TextEditingController(text: '${old.asInt(item['rent_days']) == 0 ? 1 : old.asInt(item['rent_days'])}');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setState) {
      final available = old.asInt(item['qty']) - old.asInt(item['issued_qty']);
      final rentPerDay = old.asDouble(item['rent']);
      final amount = rentPerDay * (int.tryParse(qty.text) ?? 0) * (int.tryParse(days.text) ?? 1);
      return AlertDialog(
        title: const Text('New Rental'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: item,
            decoration: const InputDecoration(labelText: 'Inventory item'),
            items: store.items.map((x) => DropdownMenuItem(value: x, child: Text('${x['serial']}. ${x['name']}'))).toList(),
            onChanged: (value) { if (value != null) { setState(() { item = value; days.text = '${old.asInt(item['rent_days']) == 0 ? 1 : old.asInt(item['rent_days'])}'; }); } },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: customer,
            decoration: const InputDecoration(labelText: 'Party'),
            items: store.customers.map((x) => DropdownMenuItem(value: x, child: Text('${x['name']}'))).toList(),
            onChanged: (value) { if (value != null) setState(() => customer = value); },
          ),
          const SizedBox(height: 10),
          TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Issued quantity (available $available)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent days'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: rs, borderRadius: BorderRadius.circular(16)), child: Text('Total rent: ${old.money(amount)}', style: const TextStyle(fontWeight: FontWeight.w900, color: rd))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            final q = int.tryParse(qty.text) ?? 0;
            final d = int.tryParse(days.text) ?? 0;
            final availableNow = old.asInt(item['qty']) - old.asInt(item['issued_qty']);
            if (q <= 0 || d <= 0 || q > availableNow) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check quantity and available inventory.')));
              return;
            }
            final invoice = 'RF-${DateTime.now().millisecondsSinceEpoch}';
            final total = old.asDouble(item['rent']) * q * d;
            final rental = <String, dynamic>{
              'invoice_no': invoice,
              'date': DateTime.now().toIso8601String().substring(0, 10),
              'customer': '${customer['name']}',
              'phone': '${customer['phone'] ?? ''}',
              'address': '${customer['address'] ?? ''}',
              'item': '${item['name']}',
              'item_serial': item['serial'] ?? store.items.indexOf(item) + 1,
              'qty': q,
              'received': 0,
              'rent_days': d,
              'amount': total,
            };
            item['issued_qty'] = old.asInt(item['issued_qty']) + q;
            store.rentals.add(rental);
            await store.save();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) await invoicePreview(context, store, rental);
          }, child: const Text('Save & Preview')),
        ],
      );
    }),
  );
  qty.dispose(); days.dispose();
}

Future<void> invoicePreview(BuildContext context, old.Store store, Map<String, dynamic> rental) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Invoice Preview'),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(store.shop.isEmpty ? 'RentFlow' : store.shop, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: rd)),
        const Text('RentFlow • By PaliaAPK HUB', style: TextStyle(color: rp, fontWeight: FontWeight.w800)),
        const Divider(height: 24),
        Text('Invoice: ${rental['invoice_no']}'),
        Text('Issued Date: ${rental['date']}'),
        const SizedBox(height: 10),
        Text('Party: ${rental['customer']}'),
        Text('Mobile: ${rental['phone']}'),
        Text('Address: ${rental['address']}'),
        const SizedBox(height: 14),
        Text('Srl / Inventory: ${rental['item_serial']} / ${rental['item']}'),
        Text('Issued Quantity: ${rental['qty']}'),
        Text('Rent Days: ${rental['rent_days']}'),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: Text('TOTAL ${old.money(rental['amount'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: rp))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        FilledButton.icon(onPressed: () => printInvoice(store, rental), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Save PDF')),
      ],
    ),
  );
}

Future<void> printInvoice(old.Store store, Map<String, dynamic> rental) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: pw.PdfPageFormat.a4,
    build: (_) => pw.Padding(
      padding: const pw.EdgeInsets.all(28),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(store.shop.isEmpty ? 'RentFlow' : store.shop, style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold)),
        pw.Text('RentFlow • By PaliaAPK HUB'),
        pw.SizedBox(height: 18),
        pw.Text('INVOICE ${rental['invoice_no']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Issued Date: ${rental['date']}'),
        pw.SizedBox(height: 12),
        pw.Text('Party: ${rental['customer']}'),
        pw.Text('Mobile: ${rental['phone']}'),
        pw.Text('Address: ${rental['address']}'),
        pw.SizedBox(height: 18),
        pw.Table(border: pw.TableBorder.all(), children: [
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Srl / Inventory')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Issued Qty')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rent Days')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${rental['item_serial']} / ${rental['item']}')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${rental['qty']}')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${rental['rent_days']}')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(old.money(rental['amount']))),
          ]),
        ]),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL ${old.money(rental['amount'])}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Spacer(),
        pw.Text('Developer by shanpalia'),
      ]),
    ),
  ));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

class Settings extends StatelessWidget {
  final old.Store store;
  final VoidCallback register;
  const Settings({required this.store, required this.register, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
        if (store.registered) Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: rd, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.storefront_rounded, color: rp, size: 30)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.shop, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(store.owner, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              Text(store.phone, style: const TextStyle(color: Colors.white70)),
            ])),
            IconButton(onPressed: register, icon: const Icon(Icons.edit, color: Colors.white)),
          ]),
        ) else FilledButton.icon(onPressed: register, icon: const Icon(Icons.storefront_rounded), label: const Text('Register Your Shop')),
        const SizedBox(height: 22),
        const Text('App', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 8),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.system_update_alt_rounded, color: rp), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Check the latest RentFlow version'), onTap: () async { final uri = Uri.parse(old.updateUrl); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
          ListTile(leading: const Icon(Icons.public_rounded, color: rp), title: const Text('PaliaAPK HUB Website'), onTap: () async { final uri = Uri.parse(old.website); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
        ])),
        const SizedBox(height: 20),
        const Text('About', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 8),
        Card(child: const ListTile(leading: Icon(Icons.info_outline_rounded, color: rp), title: Text('RentFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), subtitle: Text('By PaliaAPK HUB • Developer by shanpalia'))),
      ],),
    );
  }
}
