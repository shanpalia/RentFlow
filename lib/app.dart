import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const primary = Color(0xFF00A889);
const primaryDark = Color(0xFF007C69);
const ink = Color(0xFF10241F);
const muted = Color(0xFF687873);
const pageBg = Color(0xFFF5FAF8);
const mint = Color(0xFFE5F8F2);
const red = Color(0xFFE5484D);
const appVersion = '1.0.2';
const appBuild = 4;
const updateUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update_v2.json';
const websiteUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';

void main() => runApp(const RentFlowApp());

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RentFlow',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: pageBg,
          colorScheme: ColorScheme.fromSeed(seedColor: primary),
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
    Future.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final registered = (prefs.getString('shop_name') ?? '').trim().isNotEmpty;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => registered ? const AppShell() : const ShopRegistrationPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SvgPicture.asset(
            'assets/rentflow_splash.svg',
            width: MediaQuery.sizeOf(context).width * .86,
          ),
        ),
      );
}

class Store {
  late SharedPreferences prefs;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];
  String shopName = '', ownerName = '', phone = '', address = '', city = '', gst = '';

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    items = _read('rf_items');
    customers = _read('rf_customers');
    rentals = _read('rf_rentals');
    shopName = prefs.getString('shop_name') ?? '';
    ownerName = prefs.getString('owner_name') ?? '';
    phone = prefs.getString('shop_phone') ?? '';
    address = prefs.getString('shop_address') ?? '';
    city = prefs.getString('shop_city') ?? '';
    gst = prefs.getString('shop_gst') ?? '';
  }

  List<Map<String, dynamic>> _read(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> save() async {
    await prefs.setString('rf_items', jsonEncode(items));
    await prefs.setString('rf_customers', jsonEncode(customers));
    await prefs.setString('rf_rentals', jsonEncode(rentals));
  }

  Future<void> saveShop({required String name, required String owner, String? mobile, String? addr, String? town, String? gstNo}) async {
    shopName = name.trim();
    ownerName = owner.trim();
    phone = (mobile ?? '').trim();
    address = (addr ?? '').trim();
    city = (town ?? '').trim();
    gst = (gstNo ?? '').trim();
    await prefs.setString('shop_name', shopName);
    await prefs.setString('owner_name', ownerName);
    await prefs.setString('shop_phone', phone);
    await prefs.setString('shop_address', address);
    await prefs.setString('shop_city', city);
    await prefs.setString('shop_gst', gst);
  }
}

int number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double amount(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String rupees(dynamic v) => '₹${amount(v).toStringAsFixed(0)}';
String today() {
  final d = DateTime.now();
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

class ShopRegistrationPage extends StatefulWidget {
  final Store? existing;
  const ShopRegistrationPage({this.existing, super.key});
  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}

class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), owner = TextEditingController(), phone = TextEditingController(), address = TextEditingController(), city = TextEditingController(), gst = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      name.text = s.shopName; owner.text = s.ownerName; phone.text = s.phone;
      address.text = s.address; city.text = s.city; gst.text = s.gst;
    }
  }

  @override
  void dispose() {
    for (final c in [name, owner, phone, address, city, gst]) c.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final s = widget.existing ?? Store();
    if (widget.existing == null) await s.load();
    await s.saveShop(name: name.text, owner: owner.text, mobile: phone.text, addr: address.text, town: city.text, gstNo: gst.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
  }

  InputDecoration dec(String hint, IconData icon) => InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0EBE7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
            child: Form(
              key: form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: SizedBox(width: 125, height: 125, child: SvgPicture.asset('assets/rentflow_logo.svg'))),
                const SizedBox(height: 18),
                const Text('Register Your Shop', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
                const SizedBox(height: 6),
                const Text('Set up your rental business once. Your shop details will appear on the Home screen.', style: TextStyle(color: muted, fontSize: 15)),
                const SizedBox(height: 22),
                TextFormField(controller: name, decoration: dec('Shop Name *', Icons.store_rounded), validator: (v) => v!.trim().isEmpty ? 'Enter shop name' : null),
                const SizedBox(height: 12),
                TextFormField(controller: owner, decoration: dec('Owner Name *', Icons.person_rounded), validator: (v) => v!.trim().isEmpty ? 'Enter owner name' : null),
                const SizedBox(height: 12),
                TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: dec('Mobile Number', Icons.phone_rounded)),
                const SizedBox(height: 12),
                TextFormField(controller: address, decoration: dec('Shop Address', Icons.location_on_rounded), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(controller: city, decoration: dec('City', Icons.location_city_rounded)),
                const SizedBox(height: 12),
                TextFormField(controller: gst, decoration: dec('GST Number (Optional)', Icons.receipt_long_rounded)),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(saving ? 'Saving...' : 'Save & Continue', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  final store = Store(); int selected = 0; bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { await store.load(); if (mounted) setState(() => loading = false); }
  void refresh() => setState(() {});
  void openSettings() { Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(store: store, onChanged: refresh, onCheckUpdates: () => checkForUpdates(context)))); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: primary)));
    final pages = [HomePage(store: store, refresh: refresh, onSettings: openSettings), ItemsPage(store: store, refresh: refresh), CustomersPage(store: store, refresh: refresh), ReportsPage(store: store)];
    return Scaffold(
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: selected, onDestinationSelected: (i) => setState(() => selected = i), backgroundColor: Colors.white, indicatorColor: mint, height: 76, destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: primary), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded, color: primary), label: 'Items'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded, color: primary), label: 'Customers'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded, color: primary), label: 'Reports'),
      ]),
    );
  }
}

class HomePage extends StatelessWidget {
  final Store store; final VoidCallback refresh; final VoidCallback onSettings;
  const HomePage({required this.store, required this.refresh, required this.onSettings, super.key});
  @override Widget build(BuildContext context) {
    final total = store.items.fold<int>(0, (s, i) => s + number(i['qty']));
    final available = store.items.fold<int>(0, (s, i) => s + number(i['available'] ?? i['qty']));
    final issued = (total - available).clamp(0, 999999);
    final due = store.rentals.fold<int>(0, (s, r) => s + (number(r['qty']) - number(r['received'])).clamp(0, 999999));
    final recent = store.rentals.reversed.take(4).toList();
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 10), child: Row(children: [
        SizedBox(width: 175, height: 48, child: SvgPicture.asset('assets/rentflow_logo.svg', fit: BoxFit.contain)), const Spacer(),
        Stack(children: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, size: 29)), if (due > 0) Positioned(right: 4, top: 3, child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: red, shape: BoxShape.circle), child: Center(child: Text('$due', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))))) ]),
        Container(decoration: const BoxDecoration(color: Color(0xFFEAF0F0), shape: BoxShape.circle), child: IconButton(onPressed: onSettings, icon: const Icon(Icons.settings_outlined))),
      ]))),
      SliverToBoxAdapter(child: Container(margin: const EdgeInsets.symmetric(horizontal: 18), height: 155, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)), child: Stack(fit: StackFit.expand, children: [
        SvgPicture.asset('assets/rentflow_banner.svg', fit: BoxFit.cover),
        Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Good Morning,', style: TextStyle(fontSize: 17, color: muted)),
          Text(store.ownerName.isEmpty ? 'Shop Owner' : store.ownerName, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)),
          Text(store.shopName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primaryDark)),
          const Spacer(), const Text('Manage your rental business easily', style: TextStyle(fontSize: 14, color: ink)),
        ])),
      ]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), child: Row(children: [
        StatCard(label: 'Total Items', value: '$total', icon: Icons.inventory_2_rounded), StatCard(label: 'Available', value: '$available', icon: Icons.check_circle_rounded), StatCard(label: 'Issued', value: '$issued', icon: Icons.north_east_rounded), StatCard(label: 'Items Due', value: '$due', icon: Icons.schedule_rounded),
      ]))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), child: FilledButton.icon(onPressed: () => rentalForm(context, store, refresh), style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(62), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: const Icon(Icons.add_circle_rounded, size: 30), label: const Text('New Rental', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 0), child: Row(children: [
        QuickAction(title: 'Add Item', icon: Icons.inventory_2_rounded, onTap: () => itemForm(context, store, refresh)), QuickAction(title: 'New Customer', icon: Icons.person_add_alt_1_rounded, onTap: () => customerForm(context, store, refresh)), QuickAction(title: 'Invoice', icon: Icons.receipt_long_rounded, onTap: () => invoiceDialog(context, store)), QuickAction(title: 'Receive', icon: Icons.undo_rounded, onTap: () => receiveForm(context, store, refresh)),
      ]))),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 22, 18, 8), child: Text('Recent Rentals', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink)))),
      if (recent.isEmpty) const SliverToBoxAdapter(child: EmptyCard(message: 'No rentals yet. Create your first rental.')) else SliverList.builder(itemCount: recent.length, itemBuilder: (_, i) => RentalTile(data: recent[i])),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), child: DueCard(store: store))),
    ]));
  }
}

class StatCard extends StatelessWidget { final String label, value; final IconData icon; const StatCard({required this.label, required this.value, required this.icon, super.key}); @override Widget build(BuildContext c) => Expanded(child: Container(margin: const EdgeInsets.only(right: 7), padding: const EdgeInsets.all(10), height: 105, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: primary, size: 25), const Spacer(), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)), Text(label, style: const TextStyle(fontSize: 11, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)]))); }
class QuickAction extends StatelessWidget { final String title; final IconData icon; final VoidCallback onTap; const QuickAction({required this.title, required this.icon, required this.onTap, super.key}); @override Widget build(BuildContext c) => Expanded(child: Container(margin: const EdgeInsets.only(right: 7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE4ECE9))), child: InkWell(borderRadius: BorderRadius.circular(17), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5), child: Column(children: [Icon(icon, color: primary, size: 28), const SizedBox(height: 7), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])))); }
class RentalTile extends StatelessWidget { final Map<String, dynamic> data; const RentalTile({required this.data, super.key}); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.fromLTRB(18, 0, 18, 7), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_rounded, color: primary)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${data['customer']}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('${data['item']} • Qty ${data['qty']}', style: const TextStyle(color: muted, fontSize: 12))])), Text(rupees(data['amount']), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(width: 7), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(10)), child: Text(number(data['received']) >= number(data['qty']) ? 'Returned' : 'Issued', style: const TextStyle(color: primaryDark, fontSize: 11, fontWeight: FontWeight.w800)))])); }
class DueCard extends StatelessWidget { final Store store; const DueCard({required this.store, super.key}); @override Widget build(BuildContext c) { final active = store.rentals.where((r) => number(r['received']) < number(r['qty'])).toList(); return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF1F1), border: Border.all(color: const Color(0xFFFFD2D2)), borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: red, shape: BoxShape.circle), child: const Icon(Icons.schedule_rounded, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Today's Due", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(active.isEmpty ? 'No pending returns' : '${active.length} rental(s) pending return', style: const TextStyle(color: muted))]))])); } }

class ItemsPage extends StatelessWidget { final Store store; final VoidCallback refresh; const ItemsPage({required this.store, required this.refresh, super.key}); @override Widget build(BuildContext c) => SafeArea(child: Column(children: [PageHeader(title: 'Items', subtitle: 'Manage your rental inventory'), Expanded(child: store.items.isEmpty ? const EmptyCard(message: 'No items added yet.') : ListView.builder(itemCount: store.items.length, itemBuilder: (_, i) { final x = store.items[i]; return ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2_rounded, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Qty ${number(x['qty'])} • Available ${number(x['available'] ?? x['qty'])}')); })), Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: () => itemForm(c, store, refresh), icon: const Icon(Icons.add), label: const Text('Add Item'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: primary)))])); }
class CustomersPage extends StatelessWidget { final Store store; final VoidCallback refresh; const CustomersPage({required this.store, required this.refresh, super.key}); @override Widget build(BuildContext c) => SafeArea(child: Column(children: [PageHeader(title: 'Customers', subtitle: 'Customer records and contacts'), Expanded(child: store.customers.isEmpty ? const EmptyCard(message: 'No customers added yet.') : ListView.builder(itemCount: store.customers.length, itemBuilder: (_, i) { final x = store.customers[i]; return ListTile(leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person_rounded, color: primary)), title: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${x['phone'] ?? 'No phone'}')); })), Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: FilledButton.icon(onPressed: () => customerForm(c, store, refresh), icon: const Icon(Icons.person_add_alt_1), label: const Text('New Customer'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: primary)))])); }
class ReportsPage extends StatelessWidget { final Store store; const ReportsPage({required this.store, super.key}); @override Widget build(BuildContext c) { final revenue = store.rentals.fold<double>(0, (s, r) => s + amount(r['amount'])); return SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [PageHeader(title: 'Reports', subtitle: 'Rental business overview'), Row(children: [Expanded(child: ReportCard(title: 'Rentals', value: '${store.rentals.length}', icon: Icons.swap_horiz_rounded)), Expanded(child: ReportCard(title: 'Revenue', value: rupees(revenue), icon: Icons.payments_rounded))]), Container(margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rental History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)), ...store.rentals.reversed.map((r) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${r['customer']} • ${r['item']}'), trailing: Text(rupees(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900)))]))])); } }
class ReportCard extends StatelessWidget { final String title, value; final IconData icon; const ReportCard({required this.title, required this.value, required this.icon, super.key}); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.fromLTRB(18, 4, 5, 4), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: primary, size: 30), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: muted)), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink))])])); }

class SettingsPage extends StatelessWidget { final Store store; final VoidCallback onChanged, onCheckUpdates; const SettingsPage({required this.store, required this.onChanged, required this.onCheckUpdates, super.key}); @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: pageBg), body: ListView(padding: const EdgeInsets.all(18), children: [
  Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE0EBE7))), child: Row(children: [SizedBox(width: 72, height: 72, child: SvgPicture.asset('assets/rentflow_logo.svg')), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)), Text('Owner: ${store.ownerName}', style: const TextStyle(color: muted)), if (store.phone.isNotEmpty) Text(store.phone, style: const TextStyle(color: muted))]))])),
  const SizedBox(height: 14),
  SettingTile(icon: Icons.store_rounded, title: 'Shop Profile', subtitle: 'Edit shop name and owner details', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ShopRegistrationPage(existing: store))).then((_) => onChanged())),
  SettingTile(icon: Icons.system_update_alt_rounded, title: 'Check for App Update', subtitle: 'Check the latest RentFlow version', onTap: onCheckUpdates),
  SettingTile(icon: Icons.language_rounded, title: 'PaliaAPK HUB Website', subtitle: 'Open website', onTap: () => launchUrl(Uri.parse(websiteUrl), mode: LaunchMode.externalApplication)),
  const SizedBox(height: 20),
  Center(child: Column(children: [Text('RentFlow $appVersion', style: const TextStyle(color: muted)), const SizedBox(height: 5), const Text('By PaliaAPK HUB • Developer by ShanPalia', style: TextStyle(color: muted))]))
])); }
class SettingTile extends StatelessWidget { final IconData icon; final String title, subtitle; final VoidCallback onTap; const SettingTile({required this.icon, required this.title, required this.subtitle, required this.onTap, super.key}); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0EBE7))), child: ListTile(leading: CircleAvatar(backgroundColor: mint, child: Icon(icon, color: primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap)); }
class PageHeader extends StatelessWidget { final String title, subtitle; const PageHeader({required this.title, required this.subtitle, super.key}); @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink)), Text(subtitle, style: const TextStyle(color: muted))])); }
class EmptyCard extends StatelessWidget { final String message; const EmptyCard({required this.message, super.key}); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Center(child: Text(message, style: const TextStyle(color: muted)))); }

Future<void> itemForm(BuildContext c, Store s, VoidCallback refresh) async { final n = TextEditingController(), q = TextEditingController(text: '1'); final ok = await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: const Text('Add Item'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Item name')), TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))])); if (ok != true || n.text.trim().isEmpty) return; final qty = number(q.text); s.items.add({'name': n.text.trim(), 'qty': qty, 'available': qty}); await s.save(); refresh(); }
Future<void> customerForm(BuildContext c, Store s, VoidCallback refresh) async { final n = TextEditingController(), p = TextEditingController(); final ok = await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))])); if (ok != true || n.text.trim().isEmpty) return; s.customers.add({'name': n.text.trim(), 'phone': p.text.trim()}); await s.save(); refresh(); }
Future<void> rentalForm(BuildContext c, Store s, VoidCallback refresh) async { if (s.items.isEmpty || s.customers.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Add an item and customer first.'))); return; } final amountC = TextEditingController(text: '0'), qtyC = TextEditingController(text: '1'); String item = '${s.items.first['name']}', customer = '${s.customers.first['name']}'; final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text('New Rental'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: item, items: s.items.map((e) => DropdownMenuItem(value: '${e['name']}', child: Text('${e['name']}'))).toList(), onChanged: (v) => setD(() => item = v ?? item), decoration: const InputDecoration(labelText: 'Item')), DropdownButtonFormField<String>(value: customer, items: s.customers.map((e) => DropdownMenuItem(value: '${e['name']}', child: Text('${e['name']}'))).toList(), onChanged: (v) => setD(() => customer = v ?? customer), decoration: const InputDecoration(labelText: 'Customer')), TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')), TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))]))); if (ok != true) return; final q = number(qtyC.text), found = s.items.firstWhere((e) => '${e['name']}' == item); found['available'] = (number(found['available'] ?? found['qty']) - q).clamp(0, 999999); s.rentals.add({'item': item, 'customer': customer, 'qty': q, 'received': 0, 'amount': amount(amountC.text), 'date': today()}); await s.save(); refresh(); }
Future<void> receiveForm(BuildContext c, Store s, VoidCallback refresh) async { final active = s.rentals.where((r) => number(r['received']) < number(r['qty'])).toList(); if (active.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('No active rental found.'))); return; } final r = active.last; r['received'] = number(r['qty']); final f = s.items.where((e) => '${e['name']}' == '${r['item']}').toList(); if (f.isNotEmpty) f.first['available'] = number(f.first['available']) + number(r['qty']); await s.save(); refresh(); }
Future<void> invoiceDialog(BuildContext c, Store s) async { if (s.rentals.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('No rental available for invoice.'))); return; } final r = s.rentals.last; await showDialog(context: c, builder: (_) => AlertDialog(title: const Text('Rental Invoice'), content: Text('Customer: ${r['customer']}\nItem: ${r['item']}\nQuantity: ${r['qty']}\nDate: ${r['date']}\nAmount: ${rupees(r['amount'])}'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))])); }
Future<void> checkForUpdates(BuildContext c) async { showDialog(context: c, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(color: primary), SizedBox(width: 16), Text('Checking for updates...')]))); try { final r = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 12)); if (!c.mounted) return; Navigator.pop(c); if (r.statusCode != 200) throw Exception(); final d = jsonDecode(r.body) as Map<String, dynamic>; final latest = number(d['latest_version_code'] ?? d['build']); final version = '${d['latest_version'] ?? d['version'] ?? appVersion}'; if (latest <= appBuild) { await showDialog(context: c, builder: (_) => AlertDialog(title: const Text('You are up to date'), content: Text('RentFlow $appVersion is the latest version.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))])); return; } final notes = '${d['release_notes'] ?? 'New RentFlow update available.'}', link = '${d['apk_url'] ?? d['downloadUrl'] ?? websiteUrl}'; await showDialog(context: c, builder: (_) => AlertDialog(title: const Text('Update available'), content: Text('RentFlow $version is available.\n\n$notes'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')), FilledButton(onPressed: () async { final u = Uri.tryParse(link); if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication); if (c.mounted) Navigator.pop(c); }, child: const Text('Update Now'))])); } catch (_) { if (c.mounted) { Navigator.pop(c); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Could not check updates. Please try again.'))); } } }
