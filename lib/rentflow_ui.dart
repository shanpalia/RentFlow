import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app.dart' as legacy;

const uiPrimary = Color(0xFF00A889);
const uiDark = Color(0xFF10241F);
const uiBg = Color(0xFFF5FAF8);
const uiSoft = Color(0xFFE7F7F2);
const uiBorder = Color(0xFFDDEBE6);

Future<void> runRentFlow() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentFlowModernApp());
}

class RentFlowModernApp extends StatelessWidget {
  const RentFlowModernApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RentFlow',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: uiBg,
      colorScheme: ColorScheme.fromSeed(seedColor: uiPrimary),
      appBarTheme: const AppBarTheme(backgroundColor: uiBg, foregroundColor: uiDark, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: uiBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: uiPrimary, width: 1.6)),
        prefixIconColor: uiPrimary,
      ),
    ),
    home: const ModernSplash(),
  );
}

class RentLogo extends StatelessWidget {
  final double size;
  const RentLogo({this.size = 48, super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size, padding: EdgeInsets.all(size * .07),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .28), border: Border.all(color: uiBorder)),
    child: SvgPicture.asset('assets/rentflow_logo.svg'),
  );
}

class ModernSplash extends StatefulWidget {
  const ModernSplash({super.key});
  @override State<ModernSplash> createState() => _ModernSplashState();
}
class _ModernSplashState extends State<ModernSplash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ModernShell()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
      RentLogo(size: 108), SizedBox(height: 20),
      Text('RentFlow', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: uiDark)),
      SizedBox(height: 4), Text('By PaliaAPK HUB', style: TextStyle(color: uiPrimary, fontWeight: FontWeight.w800)),
      SizedBox(height: 3), Text('Developer by shanpalia', style: TextStyle(color: Colors.black45)),
    ])),
  );
}

class ModernShell extends StatefulWidget {
  const ModernShell({super.key});
  @override State<ModernShell> createState() => _ModernShellState();
}
class _ModernShellState extends State<ModernShell> {
  final legacy.Store store = legacy.Store();
  int index = 0;
  bool loading = true;
  @override
  void initState() { super.initState(); store.load().then((_) { if (mounted) setState(() => loading = false); }); }
  void refresh() { if (mounted) setState(() {}); }
  Future<void> register() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ModernRegistration(store: store)));
    refresh();
  }
  Future<bool> gate(BuildContext context) async {
    if (store.registered) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Register your shop first'),
        content: const Text('Before you add an item, customer or rental, register your shop. You can skip registration and browse the app first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.storefront_rounded), label: const Text('Register Shop')),
        ],
      ),
    );
    if (go == true && context.mounted) await register();
    return store.registered;
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: uiPrimary)));
    final pages = [
      ModernHome(store: store, register: register, gate: gate),
      ModernItems(store: store, gate: gate, refresh: refresh),
      ModernCustomers(store: store, gate: gate, refresh: refresh),
      ModernRentals(store: store, gate: gate, refresh: refresh),
      ModernSettings(store: store, register: register),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && index != 0) setState(() => index = 0); },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          height: 76, backgroundColor: Colors.white, indicatorColor: uiSoft, selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
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

class ModernHome extends StatelessWidget {
  final legacy.Store store;
  final VoidCallback register;
  final Future<bool> Function(BuildContext) gate;
  const ModernHome({required this.store, required this.register, required this.gate, super.key});
  @override
  Widget build(BuildContext context) {
    final active = store.rentals.where((r) => legacy.asInt(r['received']) < legacy.asInt(r['qty'])).length;
    final issued = store.rentals.fold<int>(0, (n, r) => n + legacy.asInt(r['qty']) - legacy.asInt(r['received']));
    final total = store.rentals.fold<double>(0, (n, r) => n + legacy.asDouble(r['amount']));
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 26), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const RentLogo(size: 48), const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RentFlow', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: uiDark)),
          Text('By PaliaAPK HUB', style: TextStyle(fontSize: 13, color: uiPrimary, fontWeight: FontWeight.w800)),
        ])),
        _ShopBadge(store: store, onTap: register),
      ]),
      const SizedBox(height: 22),
      if (!store.registered) ...[_registerBanner(register), const SizedBox(height: 18)],
      Row(children: [
        _stat('Items', '${store.items.length}', Icons.inventory_2_outlined), const SizedBox(width: 10),
        _stat('Customers', '${store.customers.length}', Icons.people_outline_rounded),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _stat('Active', '$active', Icons.assignment_outlined), const SizedBox(width: 10),
        _stat('Issued Qty', '$issued', Icons.local_shipping_outlined),
      ]),
      const SizedBox(height: 24),
      const Text('Quick actions', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: uiDark)),
      const SizedBox(height: 11),
      Row(children: [
        _quick('Add Item', Icons.add_box_outlined, () async { if (await gate(context) && context.mounted) await modernItemDialog(context, store); }),
        const SizedBox(width: 10),
        _quick('Customer', Icons.person_add_alt_1_outlined, () async { if (await gate(context) && context.mounted) await legacy.customerDialog(context, store); }),
        const SizedBox(width: 10),
        _quick('New Rental', Icons.add_business_outlined, () async { if (await gate(context) && context.mounted) await modernRentalDialog(context, store); }),
      ]),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent rentals', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: uiDark)), Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: uiPrimary, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 10),
      if (store.rentals.isEmpty) _empty(Icons.receipt_long_outlined, 'No rentals yet', 'Your latest rental entries will appear here.') else ...store.rentals.reversed.take(6).map(_rentalCard),
    ]));
  }
}

class _ShopBadge extends StatelessWidget {
  final legacy.Store store; final VoidCallback onTap;
  const _ShopBadge({required this.store, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(
    constraints: const BoxConstraints(maxWidth: 165), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: uiBorder)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.storefront_rounded, color: uiPrimary, size: 20)),
      const SizedBox(width: 8), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SHOP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: uiPrimary)),
        Text(store.registered ? store.shop : 'Register shop', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: uiDark)),
        Text(store.registered ? store.owner : 'Tap to setup', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
      ])),
    ]),
  ));
}

Widget _registerBanner(VoidCallback register) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: uiDark, borderRadius: BorderRadius.circular(23)), child: Row(children: [
  Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.storefront_rounded, color: Colors.white)),
  const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Register your shop', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Shop details will appear on your dashboard.', style: TextStyle(color: Colors.white70, fontSize: 12))])),
  TextButton(onPressed: register, child: const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
]));

Widget _stat(String label, String value, IconData icon) => Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: uiBorder)), child: Row(children: [
  Container(width: 43, height: 43, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: uiPrimary)), const SizedBox(width: 10),
  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: uiDark)), Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))])),
])));
Widget _quick(String label, IconData icon, VoidCallback tap) => Expanded(child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(20), child: Container(height: 104, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: uiBorder)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Container(width: 43, height: 43, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: uiPrimary)), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: uiDark)),
]))));
Widget _empty(IconData icon, String title, String subtitle) => Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: uiBorder)), child: Column(children: [
  Container(width: 64, height: 64, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: uiPrimary, size: 34)), const SizedBox(height: 13), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: uiDark, fontSize: 16)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
]));
Widget _rentalCard(Map<String, dynamic> r) { final done = legacy.asInt(r['received']) >= legacy.asInt(r['qty']); return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: uiBorder)), child: Row(children: [
  CircleAvatar(backgroundColor: done ? const Color(0xFFE7F7EA) : uiSoft, child: Icon(done ? Icons.check : Icons.schedule, color: done ? Colors.green : uiPrimary)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['customer']}', style: const TextStyle(fontWeight: FontWeight.w900, color: uiDark)), Text('${r['item']} • Qty ${r['qty']} • ${r['date']}', style: const TextStyle(color: Colors.black54, fontSize: 12))])), Text('₹${legacy.asDouble(r['amount']).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: uiPrimary)),
])); }

class ModernItems extends StatelessWidget {
  final legacy.Store store; final Future<bool> Function(BuildContext) gate; final VoidCallback refresh;
  const ModernItems({required this.store, required this.gate, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Items', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await modernItemDialog(context, store); refresh(); } }, icon: const Icon(Icons.add_rounded))]), body: store.items.isEmpty ? Padding(padding: const EdgeInsets.all(18), child: _empty(Icons.inventory_2_outlined, 'No items added', 'Add rental inventory without uploading item photos.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), itemCount: store.items.length, itemBuilder: (_, i) => _itemTile(context, store, store.items[i], refresh)));
}
Widget _itemTile(BuildContext context, legacy.Store store, Map<String, dynamic> item, VoidCallback refresh) {
  final rented = store.rentals.where((r) => '${r['item']}' == '${item['name']}' && legacy.asInt(r['received']) < legacy.asInt(r['qty'])).fold<int>(0, (n, r) => n + legacy.asInt(r['qty']) - legacy.asInt(r['received']));
  return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: uiBorder)), child: Row(children: [
    Container(width: 50, height: 50, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.inventory_2_rounded, color: uiPrimary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w900, color: uiDark)), Text('Total ${legacy.asInt(item['qty'])} • Available ${legacy.asInt(item['qty']) - rented}', style: const TextStyle(color: Colors.black54)), Text('₹${legacy.asDouble(item['rent']).toStringAsFixed(0)} / ${legacy.asInt(item['rent_days'] ?? 1)} day(s)', style: const TextStyle(color: uiPrimary, fontWeight: FontWeight.w800))])), IconButton(onPressed: () async { await modernItemDialog(context, store, existing: item); refresh(); }, icon: const Icon(Icons.edit_outlined)),
  ]));
}

class ModernCustomers extends StatelessWidget {
  final legacy.Store store; final Future<bool> Function(BuildContext) gate; final VoidCallback refresh;
  const ModernCustomers({required this.store, required this.gate, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await legacy.customerDialog(context, store); refresh(); } }, icon: const Icon(Icons.person_add_alt_1_rounded))]), body: store.customers.isEmpty ? Padding(padding: const EdgeInsets.all(18), child: _empty(Icons.people_outline_rounded, 'No customers yet', 'Customer records will appear here.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), itemCount: store.customers.length, itemBuilder: (_, i) { final c = store.customers[i]; final name = '${c['name']}'.trim(); return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: uiBorder)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), leading: CircleAvatar(backgroundColor: uiSoft, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: uiPrimary, fontWeight: FontWeight.w900))), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: uiDark)), subtitle: Text('${c['phone'] ?? ''}'), onTap: () => legacy.customerReport(context, store, name), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') { await legacy.customerDialog(context, store, existing: c); refresh(); } if (v == 'delete' && await legacy.confirmDelete(context, 'Delete customer?', 'Customer record will be removed.')) { store.customers.remove(c); await store.save(); refresh(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])); });
}

class ModernRentals extends StatelessWidget {
  final legacy.Store store; final Future<bool> Function(BuildContext) gate; final VoidCallback refresh;
  const ModernRentals({required this.store, required this.gate, required this.refresh, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Rentals', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () async { if (await gate(context) && context.mounted) { await modernRentalDialog(context, store); refresh(); } }, icon: const Icon(Icons.add_business_outlined))]), body: store.rentals.isEmpty ? Padding(padding: const EdgeInsets.all(18), child: _empty(Icons.assignment_outlined, 'No rental entries', 'Create a rental after adding an item and customer.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), itemCount: store.rentals.length, itemBuilder: (_, i) { final r = store.rentals[store.rentals.length - 1 - i]; final done = legacy.asInt(r['received']) >= legacy.asInt(r['qty']); final pending = legacy.asInt(r['qty']) - legacy.asInt(r['received']); return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: uiBorder)), child: Column(children: [Row(children: [CircleAvatar(backgroundColor: done ? const Color(0xFFE7F7EA) : uiSoft, child: Icon(done ? Icons.check : Icons.schedule, color: done ? Colors.green : uiPrimary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['item']}', style: const TextStyle(fontWeight: FontWeight.w900, color: uiDark)), Text('${r['customer']} • ${r['date']}', style: const TextStyle(color: Colors.black54))])), Text('₹${legacy.asDouble(r['amount']).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: uiPrimary))]), const SizedBox(height: 12), Row(children: [_chip(done ? 'Returned' : '$pending pending', done), const Spacer(), if (!done) OutlinedButton.icon(onPressed: () async { await legacy.returnRental(context, store, r, refresh); }, icon: const Icon(Icons.assignment_return_outlined, size: 18), label: const Text('Return'))]) ])); });
}
Widget _chip(String text, bool done) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: done ? const Color(0xFFE7F7EA) : const Color(0xFFFFF4D8), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: done ? Colors.green.shade700 : Colors.orange.shade800)));

class ModernSettings extends StatelessWidget {
  final legacy.Store store; final VoidCallback register;
  const ModernSettings({required this.store, required this.register, super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: uiDark, borderRadius: BorderRadius.circular(25)), child: Row(children: [const RentLogo(size: 62), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.registered ? store.shop : 'Shop not registered', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text(store.registered ? store.owner : 'Register your shop', style: const TextStyle(color: Colors.white70)), if (store.registered && store.phone.isNotEmpty) Text(store.phone, style: const TextStyle(color: Colors.white70))])), IconButton(onPressed: register, icon: Icon(store.registered ? Icons.edit_outlined : Icons.add_business_rounded, color: Colors.white))])),
    const SizedBox(height: 18),
    _section('App', [ListTile(leading: _settingIcon(Icons.system_update_alt_rounded), title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('Check the latest RentFlow version'), onTap: () => legacy.checkUpdate(context)), ListTile(leading: _settingIcon(Icons.language_rounded), title: const Text('PaliaAPK HUB Website'), onTap: () => legacy.launchUrl(legacy.Uri.parse(legacy.website), mode: legacy.LaunchMode.externalApplication))]),
    const SizedBox(height: 14),
    _section('About', [ListTile(leading: const RentLogo(size: 46), title: const Text('RentFlow', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), subtitle: const Text('By PaliaAPK HUB\nDeveloper by shanpalia'))]),
  ]));
}
Widget _settingIcon(IconData icon) => Container(width: 42, height: 42, decoration: BoxDecoration(color: uiSoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: uiPrimary));
Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black54))), Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: uiBorder)), child: Column(children: children))]);

class ModernRegistration extends StatefulWidget {
  final legacy.Store store;
  const ModernRegistration({required this.store, super.key});
  @override State<ModernRegistration> createState() => _ModernRegistrationState();
}
class _ModernRegistrationState extends State<ModernRegistration> {
  late final TextEditingController shop, owner, phone, address;
  @override void initState() { super.initState(); shop = TextEditingController(text: widget.store.shop); owner = TextEditingController(text: widget.store.owner); phone = TextEditingController(text: widget.store.phone); address = TextEditingController(text: widget.store.address); }
  @override void dispose() { shop.dispose(); owner.dispose(); phone.dispose(); address.dispose(); super.dispose(); }
  Future<void> save() async {
    if (shop.text.trim().isEmpty || owner.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop name and owner name are required.'))); return; }
    widget.store.shop = shop.text.trim(); widget.store.owner = owner.text.trim(); widget.store.phone = phone.text.trim(); widget.store.address = address.text.trim(); widget.store.skippedRegistration = false; await widget.store.save(); if (mounted) Navigator.pop(context);
  }
  Future<void> skip() async { widget.store.skippedRegistration = true; await widget.store.save(); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Register Your Shop', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
    Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0E5D50), uiPrimary]), borderRadius: BorderRadius.circular(27)), child: Row(children: [const RentLogo(size: 64), const SizedBox(width: 15), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your shop, your dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Register once and your shop details stay on the dashboard.', style: TextStyle(color: Colors.white70, height: 1.3))]))])),
    const SizedBox(height: 22), _field(shop, 'Shop name *', Icons.storefront_outlined), const SizedBox(height: 12), _field(owner, 'Owner name *', Icons.person_outline_rounded), const SizedBox(height: 12), _field(phone, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone), const SizedBox(height: 12), TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Shop address', prefixIcon: Icon(Icons.location_on_outlined))),
    const SizedBox(height: 22), FilledButton.icon(onPressed: save, icon: const Icon(Icons.check_circle_outline), label: const Text('Save & Continue'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: uiDark)),
    TextButton(onPressed: skip, child: const Text('Skip for now')),
  ]));
  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? type}) => TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));
}

Future<void> modernItemDialog(BuildContext context, legacy.Store store, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: '${existing?['name'] ?? ''}');
  final qty = TextEditingController(text: existing == null ? '1' : '${legacy.asInt(existing['qty'])}');
  final rent = TextEditingController(text: existing == null ? '' : '${legacy.asDouble(existing['rent'])}');
  final days = TextEditingController(text: existing == null ? '1' : '${legacy.asInt(existing['rent_days'] ?? 1)}');
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(existing == null ? 'Add Rental Item' : 'Edit Rental Item'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name', prefixIcon: Icon(Icons.inventory_2_outlined))), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total quantity', prefixIcon: Icon(Icons.numbers_rounded))), const SizedBox(height: 10), TextField(controller: rent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rent price per day', prefixIcon: Icon(Icons.currency_rupee_rounded))), const SizedBox(height: 10), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent days', prefixIcon: Icon(Icons.calendar_month_outlined))),])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))]));
  if (ok != true || name.text.trim().isEmpty) return;
  final data = {'name': name.text.trim(), 'qty': legacy.asInt(qty.text), 'rent': legacy.asDouble(rent.text), 'rent_days': legacy.asInt(days.text) <= 0 ? 1 : legacy.asInt(days.text)};
  if (existing == null) store.items.add(data); else { existing..clear()..addAll(data); }
  await store.save();
}

Future<void> modernRentalDialog(BuildContext context, legacy.Store store) async {
  if (store.items.isEmpty || store.customers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an item and customer first.'))); return; }
  String customer = '${store.customers.first['name']}'; String item = '${store.items.first['name']}';
  final qty = TextEditingController(text: '1'); final days = TextEditingController(text: '${legacy.asInt(store.items.first['rent_days'] ?? 1)}'); final due = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('New Rental'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: customer, decoration: const InputDecoration(labelText: 'Customer'), items: store.customers.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) => setState(() => customer = v ?? customer)), const SizedBox(height: 10), DropdownButtonFormField<String>(value: item, decoration: const InputDecoration(labelText: 'Item'), items: store.items.map((x) => DropdownMenuItem(value: '${x['name']}', child: Text('${x['name']}'))).toList(), onChanged: (v) { item = v ?? item; final found = store.items.firstWhere((x) => '${x['name']}' == item); days.text = '${legacy.asInt(found['rent_days'] ?? 1)}'; setState(() {}); }), const SizedBox(height: 10), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), const SizedBox(height: 10), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rent days')), const SizedBox(height: 10), TextField(controller: due, decoration: const InputDecoration(labelText: 'Due date (optional)'))])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create Rental'))])));
  if (ok != true) return;
  final q = legacy.asInt(qty.text); final rentDays = legacy.asInt(days.text) <= 0 ? 1 : legacy.asInt(days.text); final inv = store.items.firstWhere((x) => '${x['name']}' == item);
  final available = legacy.asInt(inv['qty']) - store.rentals.where((r) => '${r['item']}' == item && legacy.asInt(r['received']) < legacy.asInt(r['qty'])).fold<int>(0, (n, r) => n + legacy.asInt(r['qty']) - legacy.asInt(r['received']));
  if (q <= 0 || q > available) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $available quantity is available.'))); return; }
  final daily = legacy.asDouble(inv['rent']);
  store.rentals.add({'customer': customer, 'item': item, 'qty': q, 'received': 0, 'rent_days': rentDays, 'daily_rent': daily, 'amount': q * daily * rentDays, 'date': DateTime.now().toString().substring(0, 10), 'due': due.text.trim()});
  await store.save();
}
