import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AccountantApp());
}

const navy = Color(0xFF0B1D3A);
const blue = Color(0xFF1565C0);
const paleBlue = Color(0xFFEAF2FF);

class AccountantApp extends StatelessWidget {
  const AccountantApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'المحاسب الذكي اليمني',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
    ),
    home: const Directionality(textDirection: TextDirection.rtl, child: MainShell()),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  int revision = 0;
  void refresh() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(key: ValueKey('home-$revision'), onNavigate: (i) => setState(() => selected = i)),
      ContactsPage(key: ValueKey('contacts-$revision'), onChanged: refresh),
      ProductsPage(key: ValueKey('products-$revision'), onChanged: refresh),
      AccountingPage(key: ValueKey('accounting-$revision')),
      CompanyPage(key: ValueKey('company-$revision'), onSaved: refresh),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المحاسب الذكي اليمني', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('إدارة مالية أوضح لمشروعك', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh), tooltip: 'تحديث')],
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الأطراف'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'الأصناف'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: 'الشركة'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, int>>(
    future: AppDatabase.instance.stats(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('تعذر تحميل البيانات: ' + snapshot.error.toString()));
      final stats = snapshot.data ?? {};
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [navy, blue]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 30),
            SizedBox(height: 12),
            Text('مرحباً بك', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 4),
            Text('ابدأ بتنظيم حسابات منشأتك', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('بياناتك محفوظة محلياً على جهازك', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('ملخص النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45,
          children: [
            StatCard(title: 'العملاء', value: stats['customers'] ?? 0, icon: Icons.person_outline, onTap: () => onNavigate(1)),
            StatCard(title: 'الموردون', value: stats['suppliers'] ?? 0, icon: Icons.local_shipping_outlined, onTap: () => onNavigate(1)),
            StatCard(title: 'الأصناف', value: stats['products'] ?? 0, icon: Icons.inventory_2_outlined, onTap: () => onNavigate(2)),
            StatCard(title: 'القيود', value: stats['entries'] ?? 0, icon: Icons.receipt_long_outlined, onTap: () => onNavigate(3)),
          ],
        ),
        const SizedBox(height: 18),
        const Text('اختصارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        QuickAction(title: 'إدارة العملاء والموردين', icon: Icons.people_outline, onTap: () => onNavigate(1)),
        QuickAction(title: 'إدارة الأصناف والمخزون', icon: Icons.inventory_2_outlined, onTap: () => onNavigate(2)),
        QuickAction(title: 'التقارير', icon: Icons.analytics_outlined, onTap: () => onNavigate(3)),
        if (!snapshot.hasData) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      ]);
    },
  );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.onTap});
  final String title;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0, color: Colors.white,
    child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: blue, size: 26),
          Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy)),
          Text(title),
        ]),
      ),
    ),
  );
}

class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0, color: Colors.white,
    child: ListTile(
      leading: CircleAvatar(backgroundColor: paleBlue, child: Icon(icon, color: blue)),
      title: Text(title), trailing: const Icon(Icons.chevron_left), onTap: onTap,
    ),
  );
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String kind = 'customer';

  Future<void> openEditor([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final phone = TextEditingController(text: item?['phone'] as String? ?? '');
    final address = TextEditingController(text: item?['address'] as String? ?? '');
    final balance = TextEditingController(text: item == null ? '0' : ((item['opening_balance'] as int) / 100).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? (kind == 'customer' ? 'إضافة عميل' : 'إضافة مورد') : 'تعديل الطرف'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'الاسم *'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
          const SizedBox(height: 8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          const SizedBox(height: 8),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
          const SizedBox(height: 8),
          TextField(controller: balance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي (ر.ي)')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('حفظ')),
        ],
      ),
    );
    if (saved == true && mounted) {
      final amount = double.tryParse(balance.text.replaceAll(',', '').trim()) ?? 0;
      await AppDatabase.instance.saveContact(
        id: item?['id'] as int?, name: name.text, phone: phone.text, address: address.text,
        kind: kind, openingBalance: (amount * 100).round(),
      );
      setState(() {});
      widget.onChanged();
    }
    name.dispose(); phone.dispose(); address.dispose(); balance.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'customer', label: Text('العملاء'), icon: Icon(Icons.people_outline)),
          ButtonSegment(value: 'supplier', label: Text('الموردون'), icon: Icon(Icons.local_shipping_outlined)),
        ],
        selected: {kind}, onSelectionChanged: (v) => setState(() => kind = v.first),
      ),
    ),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: AppDatabase.instance.contacts(kind),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('حدث خطأ: ' + snapshot.error.toString()));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const EmptyState(icon: Icons.people_outline, title: 'لا توجد بيانات بعد', subtitle: 'أضف أول عميل أو مورد.');
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            final phone = row['phone'] as String;
            final currentBalance = (row['opening_balance'] as int) + (row['transaction_total'] as num).toInt() - (row['settled_total'] as num).toInt();
            return Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.person_outline, color: blue)),
                title: Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text((phone.isEmpty ? '' : phone + ' • ') + 'الرصيد الحالي: ' + (currentBalance / 100).toStringAsFixed(2) + ' ر.ي'),
                onTap: () => openEditor(row),
                trailing: IconButton(
                  tooltip: 'حذف', icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    if (await confirmDelete(context) && mounted) {
                      await AppDatabase.instance.deleteContact(row['id'] as int);
                      setState(() {});
                      widget.onChanged();
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    )),
    Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: FilledButton.icon(
      onPressed: () => openEditor(), icon: const Icon(Icons.add), label: Text(kind == 'customer' ? 'إضافة عميل' : 'إضافة مورد'),
    ))),
  ]);
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Future<void> openEditor([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final sku = TextEditingController(text: item?['sku'] as String? ?? '');
    final unit = TextEditingController(text: item?['unit'] as String? ?? 'قطعة');
    final purchase = TextEditingController(text: item == null ? '0' : ((item['purchase_price'] as int) / 100).toStringAsFixed(2));
    final sale = TextEditingController(text: item == null ? '0' : ((item['sale_price'] as int) / 100).toStringAsFixed(2));
    final quantity = TextEditingController(text: item?['quantity']?.toString() ?? '0');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة صنف' : 'تعديل صنف'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم الصنف *'), validator: (v) => v == null || v.trim().isEmpty ? 'اسم الصنف مطلوب' : null),
          const SizedBox(height: 8),
          TextField(controller: sku, decoration: const InputDecoration(labelText: 'رمز الصنف / الباركود')),
          const SizedBox(height: 8),
          TextField(controller: unit, decoration: const InputDecoration(labelText: 'وحدة القياس')),
          const SizedBox(height: 8),
          TextField(controller: purchase, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر الشراء')),
          const SizedBox(height: 8),
          TextField(controller: sale, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'سعر البيع')),
          const SizedBox(height: 8),
          TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية الافتتاحية')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('حفظ')),
        ],
      ),
    );
    if (saved == true && mounted) {
      int minor(TextEditingController c) => (((double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0) * 100).round()).clamp(0, 1 << 62).toInt();
      final qty = double.tryParse(quantity.text.trim()) ?? 0.0;
      await AppDatabase.instance.saveProduct(
        id: item?['id'] as int?, name: name.text, sku: sku.text, unit: unit.text,
        purchasePrice: minor(purchase), salePrice: minor(sale), quantity: qty < 0 ? 0.0 : qty,
      );
      setState(() {});
      widget.onChanged();
    }
    name.dispose(); sku.dispose(); unit.dispose(); purchase.dispose(); sale.dispose(); quantity.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerRight, child: Text('الأصناف والمخزون', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)))),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: AppDatabase.instance.products(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('حدث خطأ: ' + snapshot.error.toString()));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'لا توجد أصناف', subtitle: 'أضف الأصناف ووحداتها وأسعارها وكمياتها.');
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final row = rows[i];
          return Card(elevation: 0, color: Colors.white, child: ListTile(
            leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.inventory_2_outlined, color: blue)),
            title: Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الكمية: ' + row['quantity'].toString() + ' ' + (row['unit'] as String) + ' • البيع: ' + ((row['sale_price'] as int) / 100).toStringAsFixed(2) + ' ر.ي'),
            onTap: () => openEditor(row),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () async {
              if (await confirmDelete(context) && mounted) {
                await AppDatabase.instance.deleteProduct(row['id'] as int);
                setState(() {});
                widget.onChanged();
              }
            }),
          ));
        });
      },
    )),
    Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openEditor(), icon: const Icon(Icons.add), label: const Text('إضافة صنف')))),
  ]);
}

class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});
  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  int revision = 0;
  void reload() => setState(() => revision++);

  String money(Object? minor) => ((minor as num? ?? 0) / 100).toStringAsFixed(2);

  Future<void> addAccount() async {
    final code = TextEditingController();
    final name = TextEditingController();
    String type = 'asset';
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) => AlertDialog(
        title: const Text('إضافة حساب'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: code, decoration: const InputDecoration(labelText: 'رمز الحساب *'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رمز الحساب' : null),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم الحساب *'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم الحساب' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'نوع الحساب'),
            items: const [
              DropdownMenuItem(value: 'asset', child: Text('أصول')),
              DropdownMenuItem(value: 'liability', child: Text('التزامات')),
              DropdownMenuItem(value: 'equity', child: Text('حقوق ملكية')),
              DropdownMenuItem(value: 'revenue', child: Text('إيرادات')),
              DropdownMenuItem(value: 'expense', child: Text('مصروفات')),
            ],
            onChanged: (v) => updateDialog(() => type = v ?? 'asset'),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('حفظ')),
        ],
      )),
    );
    if (saved == true && mounted) {
      try {
        await AppDatabase.instance.createAccount(code: code.text, name: name.text, type: type);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الحساب')));
        reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة الحساب: $e')));
      }
    }
    code.dispose();
    name.dispose();
  }

  Future<void> addInvoice() async {
    final customers = await AppDatabase.instance.contacts('customer');
    final suppliers = await AppDatabase.instance.contacts('supplier');
    final products = await AppDatabase.instance.products();
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صنفاً واحداً على الأقل قبل إنشاء الفاتورة')));
      return;
    }
    if (customers.isEmpty && suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف عميلاً أو مورداً أولاً من شاشة الأطراف')));
      return;
    }
    String invoiceType = customers.isNotEmpty ? 'sale' : 'purchase';
    int? contactId = (invoiceType == 'sale' ? customers : suppliers).first['id'] as int;
    final productIds = <int?>[products.first['id'] as int];
    final quantities = <TextEditingController>[TextEditingController(text: '1')];
    final prices = <TextEditingController>[
      TextEditingController(text: (((invoiceType == 'sale' ? products.first['sale_price'] : products.first['purchase_price']) as int) / 100).toStringAsFixed(2))
    ];
    final discount = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) {
        final availableContacts = invoiceType == 'sale' ? customers : suppliers;
        if (contactId != null && !availableContacts.any((c) => c['id'] == contactId)) {
          contactId = availableContacts.isEmpty ? null : availableContacts.first['id'] as int;
        }
        return AlertDialog(
          title: const Text('فاتورة جديدة متعددة الأصناف'),
          content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: invoiceType,
              decoration: const InputDecoration(labelText: 'نوع الفاتورة'),
              items: const [
                DropdownMenuItem(value: 'sale', child: Text('مبيعات')),
                DropdownMenuItem(value: 'purchase', child: Text('مشتريات')),
              ],
              onChanged: (v) => updateDialog(() {
                invoiceType = v ?? invoiceType;
                final list = invoiceType == 'sale' ? customers : suppliers;
                contactId = list.isEmpty ? null : list.first['id'] as int;
                for (var i = 0; i < productIds.length; i++) {
                  final product = products.firstWhere((p) => p['id'] == productIds[i], orElse: () => products.first);
                  prices[i].text = (((invoiceType == 'sale' ? product['sale_price'] : product['purchase_price']) as int) / 100).toStringAsFixed(2);
                }
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('invoice-contact-$invoiceType'),
              initialValue: contactId,
              isExpanded: true,
              decoration: InputDecoration(labelText: invoiceType == 'sale' ? 'العميل' : 'المورد'),
              items: availableContacts.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String))).toList(),
              onChanged: availableContacts.isEmpty ? null : (v) => updateDialog(() => contactId = v),
            ),
            if (availableContacts.isEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(invoiceType == 'sale' ? 'لا يوجد عملاء مسجلون' : 'لا يوجد موردون مسجلون', style: const TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerRight, child: Text('أصناف الفاتورة', style: TextStyle(fontWeight: FontWeight.bold))),
            ...List.generate(productIds.length, (i) => Card(
              elevation: 0,
              color: const Color(0xFFF6F8FC),
              child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                Row(children: [
                  Expanded(child: Text('الصنف ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (productIds.length > 1) IconButton(
                    tooltip: 'حذف الصنف من الفاتورة',
                    onPressed: () => updateDialog(() {
                      productIds.removeAt(i);
                      quantities.removeAt(i).dispose();
                      prices.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  ),
                ]),
                DropdownButtonFormField<int>(
                  key: ValueKey('invoice-product-$i-${productIds[i]}'),
                  initialValue: productIds[i],
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصنف'),
                  items: products.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['name'] as String))).toList(),
                  onChanged: (v) => updateDialog(() {
                    productIds[i] = v;
                    final product = products.firstWhere((p) => p['id'] == v, orElse: () => products.first);
                    prices[i].text = (((invoiceType == 'sale' ? product['sale_price'] : product['purchase_price']) as int) / 100).toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: quantities[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الكمية *'),
                    validator: (v) {
                      final q = double.tryParse((v ?? '').trim());
                      return q == null || q <= 0 ? 'كمية غير صالحة' : null;
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: prices[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الوحدة *'),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').replaceAll(',', '').trim());
                      return p == null || p <= 0 ? 'سعر غير صالح' : null;
                    },
                  )),
                ]),
              ])),
            )),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () => updateDialog(() {
                productIds.add(products.first['id'] as int);
                quantities.add(TextEditingController(text: '1'));
                final p = products.first;
                prices.add(TextEditingController(text: (((invoiceType == 'sale' ? p['sale_price'] : p['purchase_price']) as int) / 100).toStringAsFixed(2)));
              }),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف آخر'),
            )),
            const SizedBox(height: 8),
            TextFormField(
              controller: discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الخصم الإجمالي (ر.ي)'),
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '').trim());
                return d == null || d < 0 ? 'أدخل خصماً صحيحاً' : null;
              },
            ),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (contactId == null || productIds.any((id) => id == null)) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يلزم اختيار طرف وجميع الأصناف')));
                return;
              }
              Navigator.pop(ctx, true);
            }, child: const Text('حفظ وترحيل')),
          ],
        );
      }),
    );
    if (saved == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final lines = <Map<String, Object>>[];
        for (var i = 0; i < productIds.length; i++) {
          lines.add({
            'product_id': productIds[i]!,
            'quantity': double.parse(quantities[i].text.trim()),
            'unit_price': (double.parse(prices[i].text.replaceAll(',', '').trim()) * 100).round(),
          });
        }
        await AppDatabase.instance.createInvoice(
          invoiceType: invoiceType,
          invoiceDate: DateTime.now().toIso8601String().substring(0, 10),
          contactId: contactId!,
          discount: (double.parse(discount.text.replaceAll(',', '').trim()) * 100).round(),
          lines: lines,
        );
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة وترحيلها وتحديث المخزون')));
        reload();
      } catch (e) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('لم تحفظ الفاتورة: $e')));
      }
    }
    for (final controller in quantities) { controller.dispose(); }
    for (final controller in prices) { controller.dispose(); }
    discount.dispose();
  }

  Future<void> addVoucher() async {
    final customers = await AppDatabase.instance.contacts('customer');
    final suppliers = await AppDatabase.instance.contacts('supplier');
    if (!mounted) return;
    if (customers.isEmpty && suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف عميلاً أو مورداً أولاً')));
      return;
    }
    String type = customers.isNotEmpty ? 'receipt' : 'payment';
    int? contactId = (type == 'receipt' ? customers : suppliers).first['id'] as int;
    String method = 'cash';
    final amount = TextEditingController();
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) {
        final available = type == 'receipt' ? customers : suppliers;
        if (contactId != null && !available.any((c) => c['id'] == contactId)) {
          contactId = available.isEmpty ? null : available.first['id'] as int;
        }
        return AlertDialog(
          title: const Text('سند قبض / صرف'),
          content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع السند'),
              items: const [
                DropdownMenuItem(value: 'receipt', child: Text('قبض من عميل')),
                DropdownMenuItem(value: 'payment', child: Text('صرف لمورد')),
              ],
              onChanged: (v) => updateDialog(() {
                type = v ?? type;
                final list = type == 'receipt' ? customers : suppliers;
                contactId = list.isEmpty ? null : list.first['id'] as int;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('voucher-contact-$type'),
              initialValue: contactId,
              decoration: InputDecoration(labelText: type == 'receipt' ? 'العميل' : 'المورد'),
              items: available.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String))).toList(),
              onChanged: available.isEmpty ? null : (v) => updateDialog(() => contactId = v),
            ),
            if (available.isEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(type == 'receipt' ? 'لا يوجد عملاء مسجلون' : 'لا يوجد موردون مسجلون', style: const TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 8),
            TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ (ر.ي) *'), validator: (v) {
              final value = double.tryParse((v ?? '').replaceAll(',', '').trim());
              return value == null || value <= 0 ? 'أدخل مبلغاً أكبر من صفر' : null;
            }),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'طريقة السداد'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقداً / الصندوق')),
                DropdownMenuItem(value: 'bank', child: Text('تحويل / البنك')),
              ],
              onChanged: (v) => updateDialog(() => method = v ?? 'cash'),
            ),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'البيان')),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (contactId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('اختر الطرف المطلوب')));
                return;
              }
              Navigator.pop(ctx, true);
            }, child: const Text('حفظ وترحيل')),
          ],
        );
      }),
    );
    if (saved == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await AppDatabase.instance.createVoucher(
          voucherType: type,
          voucherDate: DateTime.now().toIso8601String().substring(0, 10),
          contactId: contactId!,
          amount: (double.parse(amount.text.replaceAll(',', '').trim()) * 100).round(),
          method: method,
          note: note.text,
        );
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('تم حفظ السند وترحيله محاسبياً')));
        reload();
      } catch (e) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('لم يُحفظ السند: $e')));
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> addReturn() async {
    final invoices = await AppDatabase.instance.invoices();
    if (!mounted) return;
    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد فواتير يمكن إرجاع أصنافها')));
      return;
    }
    int invoiceId = invoices.first['id'] as int;
    List<Map<String, Object?>> lines = await AppDatabase.instance.invoiceLines(invoiceId);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفاتورة المحددة لا تحتوي أصنافاً')));
      return;
    }
    int lineId = lines.first['id'] as int;
    final quantity = TextEditingController(text: '1');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) => AlertDialog(
        title: const Text('مرتجع مبيعات / مشتريات'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            key: ValueKey('return-invoice-$invoiceId'),
            initialValue: invoiceId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفاتورة الأصلية'),
            items: invoices.map((i) => DropdownMenuItem<int>(
              value: i['id'] as int,
              child: Text('${i['invoice_type'] == 'sale' ? 'مبيعات' : 'مشتريات'} • ${i['invoice_number']} • ${i['contact_name']}'),
            )).toList(),
            onChanged: (value) async {
              if (value == null) return;
              final nextLines = await AppDatabase.instance.invoiceLines(value);
              if (!ctx.mounted || nextLines.isEmpty) return;
              updateDialog(() {
                invoiceId = value;
                lines = nextLines;
                lineId = lines.first['id'] as int;
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey('return-line-$invoiceId-${lines.length}'),
            initialValue: lineId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الصنف'),
            items: lines.map((line) => DropdownMenuItem<int>(
              value: line['id'] as int,
              child: Text('${line['product_name']} • الكمية ${line['quantity']}'),
            )).toList(),
            onChanged: (value) => updateDialog(() => lineId = value ?? lineId),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الكمية المرتجعة *'),
            validator: (v) {
              final q = double.tryParse((v ?? '').trim());
              return q == null || q <= 0 ? 'أدخل كمية أكبر من صفر' : null;
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
          const SizedBox(height: 8),
          const Text('سيتم رفض الكمية التي تتجاوز المتبقي من الصنف في الفاتورة الأصلية.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          }, child: const Text('حفظ المرتجع')),
        ],
      )),
    );
    if (saved == true && mounted) {
      try {
        await AppDatabase.instance.createReturn(
          invoiceId: invoiceId,
          invoiceLineId: lineId,
          quantity: double.parse(quantity.text.trim()),
          returnDate: DateTime.now().toIso8601String().substring(0, 10),
          note: note.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المرتجع وتحديث المخزون والقيود')));
        reload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ المرتجع: $e')));
      }
    }
    quantity.dispose();
    note.dispose();
  }

  Future<void> showStockMovements() async {
    final rows = await AppDatabase.instance.stockMovements();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حركة المخزون'),
        content: SizedBox(
          width: double.maxFinite,
          child: rows.isEmpty
            ? const Text('لا توجد حركات مخزون مسجلة.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (ctx, index) {
                  final row = rows[index];
                  final type = row['movement_type'] as String;
                  final quantity = (row['quantity'] as num).toDouble();
                  final label = switch (type) {
                    'sale' => 'بيع',
                    'purchase' => 'شراء',
                    'sale_return' => 'مرتجع مبيعات',
                    'purchase_return' => 'مرتجع مشتريات',
                    _ => type,
                  };
                  return ListTile(
                    dense: true,
                    title: Text(row['product_name'] as String),
                    subtitle: Text('${row['movement_date']} • $label • ${row['note']}'),
                    trailing: Text('${quantity > 0 ? '+' : ''}$quantity ${row['unit_name']}',
                      style: TextStyle(color: quantity >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<void> manageBackup() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('إنشاء نسخة احتياطية'), subtitle: const Text('نسخ كل البيانات إلى ملف JSON نصي'), onTap: () => Navigator.pop(ctx, 'export')),
        ListTile(leading: const Icon(Icons.restore_outlined), title: const Text('استعادة نسخة احتياطية'), subtitle: const Text('استبدال البيانات الحالية ببيانات نسخة محفوظة'), onTap: () => Navigator.pop(ctx, 'import')),
      ])),
    );
    if (action == null || !mounted) return;
    if (action == 'export') {
      final source = await AppDatabase.instance.exportBackupJson();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('النسخة الاحتياطية'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('انسخ النص واحفظه في ملف آمن. لا تشارك النسخة مع أشخاص غير موثوقين.'),
              const SizedBox(height: 8),
              SizedBox(height: 280, child: SingleChildScrollView(child: SelectableText(source))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: source));
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النسخة الاحتياطية إلى الحافظة')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('نسخ الكل'),
            ),
          ],
        ),
      );
      return;
    }
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: Form(key: formKey, child: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تحذير: الاستعادة تستبدل جميع البيانات الحالية. انسخ بياناتك الحالية أولاً.'),
            const SizedBox(height: 10),
            TextFormField(
              controller: controller,
              minLines: 5,
              maxLines: 9,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'الصق محتوى ملف النسخة الاحتياطية'),
              validator: (v) => v == null || v.trim().isEmpty ? 'ألصق محتوى النسخة الاحتياطية' : null,
            ),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          }, child: const Text('استعادة واستبدال البيانات')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await AppDatabase.instance.importBackupJson(controller.text);
        if (!mounted) return;
        reload();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت الاستعادة: $e')));
      }
    }
    controller.dispose();
  }

  Future<void> addJournalEntry() async {
    final accounts = await AppDatabase.instance.accounts();
    if (!mounted) return;
    if (accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف حسابين على الأقل أولاً')));
      return;
    }
    final description = TextEditingController();
    final reference = TextEditingController();
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String debitCode = accounts.first['code'] as String;
    String creditCode = accounts.firstWhere(
      (a) => a['code'] != debitCode,
      orElse: () => accounts.last,
    )['code'] as String;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) => AlertDialog(
        title: const Text('قيد يومية جديد'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'شرح القيد *'), validator: (v) => v == null || v.trim().isEmpty ? 'شرح القيد مطلوب' : null),
          TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'رقم المرجع (اختياري)')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: debitCode,
            decoration: const InputDecoration(labelText: 'الحساب المدين'),
            items: accounts.map((a) => DropdownMenuItem(value: a['code'] as String, child: Text('${a['code']} - ${a['name']}'))).toList(),
            onChanged: (v) => updateDialog(() => debitCode = v ?? debitCode),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: creditCode,
            decoration: const InputDecoration(labelText: 'الحساب الدائن'),
            items: accounts.map((a) => DropdownMenuItem(value: a['code'] as String, child: Text('${a['code']} - ${a['name']}'))).toList(),
            onChanged: (v) => updateDialog(() => creditCode = v ?? creditCode),
          ),
          const SizedBox(height: 8),
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ (ر.ي) *'), validator: (v) {
            final value = double.tryParse((v ?? '').replaceAll(',', '').trim());
            return value == null || value <= 0 ? 'أدخل مبلغاً أكبر من صفر' : null;
          }),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (!formKey.currentState!.validate()) return;
            if (debitCode == creditCode) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('اختر حسابين مختلفين')));
              return;
            }
            Navigator.pop(ctx, true);
          }, child: const Text('ترحيل القيد')),
        ],
      )),
    );
    if (saved == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final minor = (double.parse(amount.text.replaceAll(',', '').trim()) * 100).round();
        await AppDatabase.instance.createJournalEntry(
          description: description.text,
          reference: reference.text,
          entryDate: DateTime.now().toIso8601String().substring(0, 10),
          lines: [
            {'account_code': debitCode, 'debit': minor, 'credit': 0},
            {'account_code': creditCode, 'debit': 0, 'credit': minor},
          ],
        );
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('تم ترحيل القيد المتوازن بنجاح')));
        reload();
      } catch (e) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('لم يتم ترحيل القيد: $e')));
      }
    }
    description.dispose();
    reference.dispose();
    amount.dispose();
  }

  Future<void> showAccountLedger() async {
    final accounts = await AppDatabase.instance.accounts();
    if (!mounted || accounts.isEmpty) return;
    String code = accounts.first['code'] as String;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, updateDialog) => AlertDialog(
        title: const Text('كشف حركة حساب'),
        content: DropdownButtonFormField<String>(
          initialValue: code,
          decoration: const InputDecoration(labelText: 'الحساب'),
          items: accounts.map((a) => DropdownMenuItem<String>(
            value: a['code'] as String,
            child: Text('${a['code']} - ${a['name']}'),
          )).toList(),
          onChanged: (value) => updateDialog(() => code = value ?? code),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, code), child: const Text('عرض الكشف')),
        ],
      )),
    );
    if (chosen == null || !mounted) return;
    final account = accounts.firstWhere((a) => a['code'] == chosen);
    final rows = await AppDatabase.instance.accountLedger(chosen);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var debit = 0;
        var credit = 0;
        for (final row in rows) {
          debit += (row['debit'] as num).toInt();
          credit += (row['credit'] as num).toInt();
        }
        return AlertDialog(
          title: Text('كشف حساب ${account['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: rows.isEmpty
              ? const Text('لا توجد حركات مرحّلة على هذا الحساب.')
              : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ...rows.map((row) => ListTile(
                    dense: true,
                    title: Text(row['description'] as String),
                    subtitle: Text('${row['entry_date']} • ${(row['reference'] as String).isEmpty ? 'بدون مرجع' : row['reference']}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('مدين ${money(row['debit'])}'),
                      Text('دائن ${money(row['credit'])}'),
                    ]),
                  )),
                  const Divider(),
                  Text('إجمالي المدين: ${money(debit)} ر.ي'),
                  Text('إجمالي الدائن: ${money(credit)} ر.ي'),
                  Text('الرصيد الصافي: ${money((debit - credit).abs())} ${debit >= credit ? 'مدين' : 'دائن'} ر.ي'),
                ])),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('accounts-$revision'),
    future: AppDatabase.instance.accounts(),
    builder: (context, accountSnapshot) {
      if (accountSnapshot.hasError) return Center(child: Text('تعذر تحميل الحسابات: ${accountSnapshot.error}'));
      if (!accountSnapshot.hasData) return const Center(child: CircularProgressIndicator());
      final accounts = accountSnapshot.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('المحاسبة والتقارير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 6),
        const Text('دليل الحسابات وقيود اليومية وميزان المراجعة. لا تُسجل العمليات إلا بعد التحقق من توازنها.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: addJournalEntry, icon: const Icon(Icons.add_chart), label: const Text('قيد يومية')),
          FilledButton.tonalIcon(onPressed: addInvoice, icon: const Icon(Icons.receipt_long), label: const Text('فاتورة')),
          OutlinedButton.icon(onPressed: addVoucher, icon: const Icon(Icons.payments_outlined), label: const Text('سند قبض/صرف')),
          OutlinedButton.icon(onPressed: addAccount, icon: const Icon(Icons.account_tree_outlined), label: const Text('إضافة حساب')),
          OutlinedButton.icon(onPressed: showAccountLedger, icon: const Icon(Icons.menu_book_outlined), label: const Text('كشف حساب')),
          OutlinedButton.icon(onPressed: addReturn, icon: const Icon(Icons.assignment_return_outlined), label: const Text('مرتجع')),
          OutlinedButton.icon(onPressed: showStockMovements, icon: const Icon(Icons.swap_vert_circle_outlined), label: const Text('حركة المخزون')),
          OutlinedButton.icon(onPressed: manageBackup, icon: const Icon(Icons.backup_outlined), label: const Text('النسخ الاحتياطي')),
        ]),
        const SizedBox(height: 20),
        const Text('دليل الحسابات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        ...accounts.map((a) => Card(
          elevation: 0, color: Colors.white,
          child: ListTile(
            dense: true,
            leading: CircleAvatar(backgroundColor: paleBlue, child: Text(a['code'] as String, style: const TextStyle(fontSize: 10, color: blue))),
            title: Text(a['name'] as String),
            subtitle: Text(_accountTypeLabel(a['type'] as String)),
            trailing: const Icon(Icons.account_balance_outlined, color: blue),
          ),
        )),
        const SizedBox(height: 18),
        const Text('ميزان المراجعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey('trial-balance-$revision'),
          future: AppDatabase.instance.trialBalance(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر تحميل الميزان: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final rows = snapshot.data!;
            var totalDebit = 0;
            var totalCredit = 0;
            for (final row in rows) {
              totalDebit += (row['debit_total'] as num).toInt();
              totalCredit += (row['credit_total'] as num).toInt();
            }
            return Column(children: [
              ...rows.where((r) => (r['debit_total'] as num) != 0 || (r['credit_total'] as num) != 0).map((r) => Card(
                elevation: 0, color: Colors.white,
                child: ListTile(
                  title: Text('${r['code']} - ${r['name']}'),
                  subtitle: Text('مدين: ${money(r['debit_total'])} ر.ي  |  دائن: ${money(r['credit_total'])} ر.ي'),
                ),
              )),
              Card(
                color: paleBlue, elevation: 0,
                child: ListTile(
                  title: const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('مدين: ${money(totalDebit)} ر.ي  |  دائن: ${money(totalCredit)} ر.ي'),
                  trailing: Icon(totalDebit == totalCredit ? Icons.check_circle : Icons.warning_amber, color: totalDebit == totalCredit ? Colors.green : Colors.red),
                ),
              ),
            ]);
          },
        ),
        const SizedBox(height: 18),
        const Text('القوائم المالية المختصرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<Map<String, int>>(
          key: ValueKey('financial-summary-$revision'),
          future: AppDatabase.instance.financialSummary(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر إعداد الملخص المالي: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final s = snapshot.data!;
            final assets = s['assets'] ?? 0;
            final liabilities = s['liabilities'] ?? 0;
            final equity = s['equity'] ?? 0;
            final revenue = s['revenue'] ?? 0;
            final expenses = s['expenses'] ?? 0;
            final net = s['net_profit'] ?? 0;
            final rightSide = s['liabilities_and_equity'] ?? 0;
            Widget reportRow(String label, int value, {bool emphasize = false}) => ListTile(
              dense: true,
              title: Text(label, style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.normal)),
              trailing: Text('${money(value)} ر.ي', style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.normal)),
            );
            return Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  const ListTile(title: Text('قائمة الأرباح والخسائر', style: TextStyle(fontWeight: FontWeight.bold))),
                  reportRow('الإيرادات', revenue),
                  reportRow('المصروفات', expenses),
                  reportRow(net >= 0 ? 'صافي الربح' : 'صافي الخسارة', net.abs(), emphasize: true),
                  const Divider(),
                  const ListTile(title: Text('ملخص المركز المالي', style: TextStyle(fontWeight: FontWeight.bold))),
                  reportRow('الأصول', assets),
                  reportRow('الالتزامات', liabilities),
                  reportRow('حقوق الملكية المسجلة', equity),
                  reportRow('الالتزامات وحقوق الملكية مع نتيجة الفترة', rightSide, emphasize: true),
                  ListTile(
                    leading: Icon((assets - rightSide).abs() < 1 ? Icons.check_circle : Icons.info_outline,
                      color: (assets - rightSide).abs() < 1 ? Colors.green : Colors.orange),
                    title: Text((assets - rightSide).abs() < 1 ? 'الجانبان متوازنان' : 'فرق ظاهر: ${money((assets - rightSide).abs())} ر.ي'),
                    subtitle: const Text('قد يظهر فرق بسبب أرصدة افتتاحية الأطراف غير المرحّلة إلى دفتر الأستاذ. راجع الأرصدة قبل اعتماد القوائم.'),
                  ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        const Text('فواتير المبيعات والمشتريات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey('invoices-$revision'),
          future: AppDatabase.instance.invoices(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر تحميل الفواتير: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد فواتير مسجلة بعد.')));
            return Column(children: rows.map((r) => Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: Icon(r['invoice_type'] == 'sale' ? Icons.point_of_sale : Icons.shopping_cart_outlined, color: blue),
                title: Text('${r['invoice_type'] == 'sale' ? 'مبيعات' : 'مشتريات'} • ${r['invoice_number']}'),
                subtitle: Text('${r['contact_name']} • ${r['invoice_date']}'),
                trailing: Text('${money(r['total'])} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 18),
        const Text('المرتجعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey('returns-$revision'),
          future: AppDatabase.instance.returns(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر تحميل المرتجعات: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد مرتجعات مسجلة بعد.')));
            return Column(children: rows.map((r) => Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.assignment_return_outlined, color: blue),
                title: Text('${r['return_type'] == 'sale_return' ? 'مرتجع مبيعات' : 'مرتجع مشتريات'} • ${r['invoice_number']}'),
                subtitle: Text('${r['contact_name']} • ${r['return_date']}${(r['note'] as String).isEmpty ? '' : ' • ${r['note']}'}'),
                trailing: Text('${money(r['amount'])} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 18),
        const Text('سندات القبض والصرف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey('vouchers-$revision'),
          future: AppDatabase.instance.vouchers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر تحميل السندات: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد سندات مسجلة بعد.')));
            return Column(children: rows.map((v) => Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: Icon(v['voucher_type'] == 'receipt' ? Icons.call_received : Icons.call_made, color: blue),
                title: Text('${v['voucher_type'] == 'receipt' ? 'سند قبض' : 'سند صرف'} • ${v['contact_name'] ?? 'بدون طرف'}'),
                subtitle: Text('${v['voucher_date']} • ${v['method'] == 'bank' ? 'البنك' : 'الصندوق'}${(v['note'] as String).isEmpty ? '' : ' • ${v['note']}'}'),
                trailing: Text('${money(v['amount'])} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 18),
        const Text('قيود اليومية المرحّلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey('journal-$revision'),
          future: AppDatabase.instance.journalEntries(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر تحميل القيود: ${snapshot.error}');
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد قيود مرحّلة. أضف أول قيد من زر قيد يومية.')));
            return Column(children: rows.map((r) => Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: blue),
                title: Text(r['description'] as String),
                subtitle: Text('${r['entry_date']} • مرجع: ${(r['reference'] as String).isEmpty ? '—' : r['reference']}'),
                trailing: Text('${money(r['debit_total'])} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )).toList());
          },
        ),
        const SizedBox(height: 12),
        const Text('تنبيه محاسبي: التقارير مبنية على القيود المرحّلة فقط. الأرصدة الافتتاحية للأطراف لا تُرحّل تلقائياً إلى دفتر الأستاذ، لذلك راجع التنبيه الظاهر في ملخص المركز المالي قبل الاعتماد.', style: TextStyle(color: Colors.black54)),
      ]);
    },
  );
}

String _accountTypeLabel(String type) => switch (type) {
  'asset' => 'أصول',
  'liability' => 'التزامات',
  'equity' => 'حقوق ملكية',
  'revenue' => 'إيرادات',
  'expense' => 'مصروفات',
  _ => type,
};

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key, required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final currency = TextEditingController(text: 'ر.ي');
  final formKey = GlobalKey<FormState>();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.company().then((company) {
      if (!mounted) return;
      if (company != null) {
        name.text = company['name'] as String;
        phone.text = company['phone'] as String;
        address.text = company['address'] as String;
        currency.text = company['currency'] as String;
      }
      setState(() => loading = false);
    });
  }

  @override
  void dispose() { name.dispose(); phone.dispose(); address.dispose(); currency.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('بيانات المنشأة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
      const SizedBox(height: 8),
      const Text('أدخل بيانات منشأتك. لا توجد بيانات افتراضية تجريبية.'),
      const SizedBox(height: 18),
      Form(key: formKey, child: Column(children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنشأة *'), validator: (v) => v == null || v.trim().isEmpty ? 'اسم المنشأة مطلوب' : null),
        const SizedBox(height: 12),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
        const SizedBox(height: 12),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
        const SizedBox(height: 12),
        TextField(controller: currency, decoration: const InputDecoration(labelText: 'العملة الأساسية')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            final messenger = ScaffoldMessenger.of(context);
            setState(() => saving = true);
            try {
              await AppDatabase.instance.saveCompany(name: name.text, phone: phone.text, address: address.text, currency: currency.text.trim().isEmpty ? 'ر.ي' : currency.text.trim());
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المنشأة')));
              widget.onSaved();
            } finally {
              if (mounted) setState(() => saving = false);
            }
          },
          icon: const Icon(Icons.save_outlined), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ بيانات المنشأة'),
        )),
      ])),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(30),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 58, color: Colors.blueGrey.shade300),
      const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    ]),
  ));
}

Future<bool> confirmDelete(BuildContext context) async => await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(content: const Text('هل تريد حذف هذا السجل؟'), actions: [
    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
  ]),
) ?? false;
