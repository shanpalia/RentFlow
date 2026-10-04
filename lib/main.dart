import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const teal = Color(0xFF00A982);
const mint = Color(0xFFE9FBF6);

void main() => runApp(const RentFlowApp());

class RentFlowApp extends StatelessWidget {
  const RentFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentFlow',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FFFC),
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
      ),
      home: const AppShell(),
    );
  }
}

class Store {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> rentals = [];
  List<Map<String, dynamic>> invoices = [];
  late SharedPreferences prefs;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    items = _read('items');
    customers = _read('customers');
    rentals = _read('rentals');
    invoices = _read('invoices');
  }

  List<Map<String, dynamic>> _read(String key) {
    final value = prefs.getString(key);
    if (value == null) return [];
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> save() async {
    await prefs.setString('items', jsonEncode(items));
    await prefs.setString('customers', jsonEncode(customers));
    await prefs.setString('rentals', jsonEncode(rentals));
    await prefs.setString('invoices', jsonEncode(invoices));
  }

  String id() => DateTime.now().microsecondsSinceEpoch.toString();
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Store data = Store();
  int tab = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await data.load();
    if (mounted) setState(() => loading = false);
  }

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Splash();
    final pages = <Widget>[
      Home(data: data, onChanged: refresh),
      ItemsPage(data: data, onChanged: refresh),
      CustomersPage(data: data, onChanged: refresh),
      ReportsPage(data: data),
    ];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandIcon(size: 92),
            SizedBox(height: 18),
            Text('RentFlow', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
            Text('By PaliaAPK HUB', style: TextStyle(color: teal, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Developer by ShanPalia', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  final double size;
  const _BrandIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(size * .28)),
      child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: size * .62),
    );
  }
}

class Home extends StatelessWidget {
  final Store data;
  final VoidCallback onChanged;
  const Home({super.key, required this.data, required this.onChanged});

  int get totalItems => data.items.fold<int>(0, (sum, item) => sum + _int(item['qty']));
  int get availableItems => data.items.fold<int>(0, (sum, item) => sum + _int(item['available']));
  int get issuedItems => totalItems - availableItems;
  int get activeRentals => data.rentals.where((r) => r['status'] == 'issued').length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Row(children: [
            const _BrandIcon(size: 48),
            const SizedBox(width: 10),
            const Expanded(child: Text('RentFlow', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => _about(context), icon: const Icon(Icons.info_outline)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(20)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rental Management', style: TextStyle(color: Colors.black54, fontSize: 15)),
              SizedBox(height: 2),
              Text('Manage your business', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
              Text('Items, customers, rentals and invoices in one place', style: TextStyle(color: Colors.black54)),
            ]),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: [
              _stat('Total Items', '$totalItems', Icons.inventory_2),
              _stat('Available', '$availableItems', Icons.check_circle),
              _stat('Issued', '$issuedItems', Icons.north_east),
              _stat('Items Due', '$activeRentals', Icons.schedule),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            onPressed: () => _newRental(context),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('New Rental', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _action('Add Item', Icons.inventory_2_outlined, () => _addItem(context))),
            Expanded(child: _action('Customer', Icons.person_add_alt_1, () => _addCustomer(context))),
            Expanded(child: _action('Invoice', Icons.receipt_long, () => _showInvoices(context))),
            Expanded(child: _action('Receive', Icons.undo, () => _receive(context))),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Recent Rentals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => _showInvoices(context), child: const Text('Invoices')),
          ]),
          ...data.rentals.reversed.take(5).map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2, color: teal)),
                  title: Text('${r['customer']} • ${r['item']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r['date']} • Qty: ${r['qty']} • ${r['days']} day(s)'),
                  trailing: Text('₹${_money(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => _makeInvoice(context, r),
                ),
              )),
          if (data.rentals.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No rentals yet'))),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: teal),
        const Spacer(),
        Text(title, style: const TextStyle(color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _action(String text, IconData icon, VoidCallback action) {
    return InkWell(
      onTap: action,
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
        child: Column(children: [Icon(icon, color: teal), const SizedBox(height: 5), Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  void _about(BuildContext context) {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('RentFlow'),
      content: const Text('RentFlow\nBy PaliaAPK HUB\nDeveloper by ShanPalia'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
  }

  Future<void> _addItem(BuildContext context) async {
    final name = TextEditingController();
    final category = TextEditingController();
    final qty = TextEditingController(text: '1');
    final rate = TextEditingController(text: '0');
    String type = 'Per Day';
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Add Item'),
      content: SingleChildScrollView(child: Column(children: [
        _field(name, 'Item Name'),
        _field(category, 'Category'),
        _field(qty, 'Total Quantity', number: true),
        _field(rate, 'Rent Price', number: true),
        DropdownButtonFormField<String>(
          initialValue: type,
          items: const ['Per Day', 'Per Hour', 'Per Event'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (value) => setDialogState(() => type = value ?? type),
          decoration: const InputDecoration(labelText: 'Rent Type'),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
      ],
    )));
    if (saved != true || name.text.trim().isEmpty) return;
    final quantity = int.tryParse(qty.text) ?? 0;
    data.items.add({'id': data.id(), 'name': name.text.trim(), 'category': category.text.trim(), 'qty': quantity, 'available': quantity, 'rate': double.tryParse(rate.text) ?? 0, 'type': type});
    await data.save();
    onChanged();
  }

  Future<void> _addCustomer(BuildContext context) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final address = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('New Customer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Customer Name'), _field(mobile, 'Mobile'), _field(address, 'Address')]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
      ],
    ));
    if (saved != true || name.text.trim().isEmpty) return;
    data.customers.add({'id': data.id(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()});
    await data.save();
    onChanged();
  }

  Future<void> _newRental(BuildContext context) async {
    if (data.customers.isEmpty || data.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one customer and one item first.')));
      return;
    }
    String customer = data.customers.first['name'] as String;
    String item = data.items.first['name'] as String;
    final qty = TextEditingController(text: '1');
    final days = TextEditingController(text: '1');
    final rate = TextEditingController(text: '${_num(data.items.first['rate'])}');
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('New Rental'),
      content: SingleChildScrollView(child: Column(children: [
        DropdownButtonFormField<String>(
          initialValue: customer,
          items: data.customers.map((x) => DropdownMenuItem(value: x['name'] as String, child: Text(x['name'] as String))).toList(),
          onChanged: (value) => setDialogState(() => customer = value ?? customer),
          decoration: const InputDecoration(labelText: 'Customer'),
        ),
        DropdownButtonFormField<String>(
          initialValue: item,
          items: data.items.map((x) => DropdownMenuItem(value: x['name'] as String, child: Text(x['name'] as String))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setDialogState(() {
              item = value;
              final selected = data.items.firstWhere((x) => x['name'] == item);
              rate.text = '${_num(selected['rate'])}';
            });
          },
          decoration: const InputDecoration(labelText: 'Item'),
        ),
        _field(qty, 'Quantity', number: true),
        _field(days, 'Days', number: true),
        _field(rate, 'Rate (manual edit allowed)', number: true),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
      ],
    )));
    if (saved != true) return;
    final selected = data.items.firstWhere((x) => x['name'] == item);
    final quantity = int.tryParse(qty.text) ?? 0;
    final rentalDays = int.tryParse(days.text) ?? 1;
    final rentalRate = double.tryParse(rate.text) ?? 0;
    if (quantity <= 0 || rentalDays <= 0) return;
    if (quantity > _int(selected['available'])) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough available quantity.')));
      return;
    }
    final amount = quantity * rentalRate * rentalDays;
    selected['available'] = _int(selected['available']) - quantity;
    final rental = <String, dynamic>{
      'id': data.id(),
      'date': _date(),
      'customer': customer,
      'item': item,
      'qty': quantity,
      'issued': quantity,
      'received': 0,
      'days': rentalDays,
      'rate': rentalRate,
      'amount': amount,
      'status': 'issued',
    };
    data.rentals.add(rental);
    data.invoices.add({...rental, 'invoice': 'INV-${data.invoices.length + 1}'});
    await data.save();
    onChanged();
  }

  Future<void> _receive(BuildContext context) async {
    final active = data.rentals.where((r) => r['status'] == 'issued').toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No issued items found.')));
      return;
    }
    String rentalId = active.first['id'] as String;
    final received = TextEditingController(text: '${_int(active.first['qty'])}');
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Receive Item'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          initialValue: rentalId,
          items: active.map((x) => DropdownMenuItem(value: x['id'] as String, child: Text('${x['customer']} • ${x['item']}'))).toList(),
          onChanged: (value) {
            if (value == null) return;
            rentalId = value;
            final current = active.firstWhere((x) => x['id'] == rentalId);
            received.text = '${_int(current['qty'])}';
            setDialogState(() {});
          },
          decoration: const InputDecoration(labelText: 'Rental'),
        ),
        _field(received, 'Received Quantity', number: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Receive')),
      ],
    )));
    if (saved != true) return;
    final rental = data.rentals.firstWhere((x) => x['id'] == rentalId);
    final returned = int.tryParse(received.text) ?? 0;
    final outstanding = _int(rental['qty']);
    if (returned <= 0 || returned > outstanding) return;
    final item = data.items.firstWhere((x) => x['name'] == rental['item']);
    item['available'] = _int(item['available']) + returned;
    rental['received'] = _int(rental['received']) + returned;
    rental['qty'] = outstanding - returned;
    if (_int(rental['qty']) == 0) rental['status'] = 'received';
    await data.save();
    onChanged();
  }

  void _showInvoices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Invoices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...data.invoices.reversed.map((invoice) => ListTile(
              title: Text(invoice['invoice'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${invoice['customer']} • ${invoice['item']} • ${invoice['date']}'),
              trailing: Text('₹${_money(invoice['amount'])}'),
              onTap: () => _makeInvoice(context, invoice),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _makeInvoice(BuildContext context, Map<String, dynamic> rental) async {
    final document = pw.Document();
    final amount = _num(rental['amount']);
    document.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RENTFLOW', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
      pw.Text('By PaliaAPK HUB'),
      pw.Text('Developer by ShanPalia'),
      pw.SizedBox(height: 18),
      pw.Text('RENTAL INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Text('Invoice: ${rental['invoice'] ?? 'INV-${rental['id']}'}'),
      pw.Text('Date: ${rental['date']}'),
      pw.Text('Customer: ${rental['customer']}'),
      pw.SizedBox(height: 16),
      pw.Table(border: pw.TableBorder.all(), children: [
        _pdfRow(['Item', 'Qty', 'Days', 'Rate', 'Amount'], bold: true),
        _pdfRow(['${rental['item']}', '${rental['issued'] ?? rental['qty']}', '${rental['days']}', '₹${_money(rental['rate'])}', '₹${_money(amount)}']),
      ]),
      pw.SizedBox(height: 14),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL: ₹${_money(amount)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
    ])));
    await Printing.layoutPdf(onLayout: (_) async => document.save());
  }

  pw.TableRow _pdfRow(List<String> values, {bool bold = false}) {
    return pw.TableRow(children: values.map((value) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null))).toList());
  }
}

class ItemsPage extends StatelessWidget {
  final Store data;
  final VoidCallback onChanged;
  const ItemsPage({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Items', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: data.items.isEmpty
          ? const Center(child: Text('No items added yet'))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: data.items.length, itemBuilder: (_, index) {
              final item = data.items[index];
              return Card(child: ListTile(
                leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.inventory_2, color: teal)),
                title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${item['category']} • ${item['type']} • ₹${_money(item['rate'])}'),
                trailing: Text('${item['available']}/${item['qty']}'),
              ));
            }),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addItem(context), backgroundColor: teal, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Add Item')),
    ));
  }

  Future<void> _addItem(BuildContext context) async {
    final name = TextEditingController();
    final category = TextEditingController();
    final qty = TextEditingController(text: '1');
    final rate = TextEditingController(text: '0');
    String type = 'Per Day';
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Add Item'),
      content: SingleChildScrollView(child: Column(children: [
        _field(name, 'Item Name'), _field(category, 'Category'), _field(qty, 'Total Quantity', number: true), _field(rate, 'Rent Price', number: true),
        DropdownButtonFormField<String>(initialValue: type, items: const ['Per Day', 'Per Hour', 'Per Event'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setDialogState(() => type = v ?? type), decoration: const InputDecoration(labelText: 'Rent Type')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    )));
    if (saved != true || name.text.trim().isEmpty) return;
    final quantity = int.tryParse(qty.text) ?? 0;
    data.items.add({'id': data.id(), 'name': name.text.trim(), 'category': category.text.trim(), 'qty': quantity, 'available': quantity, 'rate': double.tryParse(rate.text) ?? 0, 'type': type});
    await data.save();
    onChanged();
  }
}

class CustomersPage extends StatelessWidget {
  final Store data;
  final VoidCallback onChanged;
  const CustomersPage({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: data.customers.isEmpty
          ? const Center(child: Text('No customers added yet'))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: data.customers.length, itemBuilder: (_, index) {
              final customer = data.customers[index];
              return Card(child: ListTile(
                leading: const CircleAvatar(backgroundColor: mint, child: Icon(Icons.person, color: teal)),
                title: Text(customer['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${customer['mobile']}\n${customer['address']}'),
                isThreeLine: true,
                onTap: () => _customerReport(context, customer['name'] as String),
              ));
            }),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addCustomer(context), backgroundColor: teal, foregroundColor: Colors.white, icon: const Icon(Icons.person_add), label: const Text('New Customer')),
    ));
  }

  void _customerReport(BuildContext context, String customer) {
    final rows = data.rentals.where((r) => r['customer'] == customer).toList();
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheetContext) => DraggableScrollableSheet(expand: false, builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.all(18), children: [
      Text(customer, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (rows.isEmpty) const Text('No rental history.'),
      ...rows.reversed.map((r) => Card(child: ListTile(title: Text('${r['item']} • ${r['date']}'), subtitle: Text('Issued: ${r['issued'] ?? r['qty']}   Received: ${r['received'] ?? 0}   Due Item: ${r['qty']}\nDays: ${r['days']}   Rate: ₹${_money(r['rate'])}   Amount: ₹${_money(r['amount'])}')))),
    ])));
  }

  Future<void> _addCustomer(BuildContext context) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final address = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('New Customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Customer Name'), _field(mobile, 'Mobile'), _field(address, 'Address')]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
    if (saved != true || name.text.trim().isEmpty) return;
    data.customers.add({'id': data.id(), 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'address': address.text.trim()});
    await data.save();
    onChanged();
  }
}

class ReportsPage extends StatelessWidget {
  final Store data;
  const ReportsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: data.rentals.isEmpty
          ? const Center(child: Text('No report data yet'))
          : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Issued')),
                DataColumn(label: Text('Received')),
                DataColumn(label: Text('Days')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Due')),
              ],
              rows: data.rentals.reversed.map((r) => DataRow(cells: [
                DataCell(Text('${r['date']}')),
                DataCell(Text('${r['customer']}')),
                DataCell(Text('${r['item']}')),
                DataCell(Text('${r['issued'] ?? r['qty']}')),
                DataCell(Text('${r['received'] ?? 0}')),
                DataCell(Text('${r['days']}')),
                DataCell(Text('₹${_money(r['rate'])}')),
                DataCell(Text('₹${_money(r['amount'])}')),
                DataCell(Text('${r['qty']}')),
              ])).toList(),
            ))),
    ));
  }
}

Widget _field(TextEditingController controller, String label, {bool number = false}) {
  return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controller, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
}

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(dynamic value) => _num(value).toStringAsFixed(0);
String _date() {
  final now = DateTime.now();
  return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
}
