import 'package:flutter/material.dart';
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
      const ReportsPage(),
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
            return Card(
              elevation: 0, color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: paleBlue, child: Icon(Icons.person_outline, color: blue)),
                title: Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text((phone.isEmpty ? '' : phone + ' • ') + 'الرصيد الافتتاحي: ' + ((row['opening_balance'] as int) / 100).toStringAsFixed(2) + ' ر.ي'),
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

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [
    Text('التقارير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
    SizedBox(height: 12),
    ReportTile(icon: Icons.people_outline, title: 'تقرير الأطراف', subtitle: 'أعداد العملاء والموردين المسجلين.'),
    ReportTile(icon: Icons.inventory_outlined, title: 'تقرير الأصناف', subtitle: 'الأصناف وكمياتها وأسعارها.'),
    ReportTile(icon: Icons.account_balance_outlined, title: 'التقارير المالية', subtitle: 'ستُفعّل بعد استكمال الفواتير والترحيل المحاسبي واختبارات القيود.'),
    SizedBox(height: 10),
    Text('هذه النسخة لا تعرض أرباحاً أو أرصدة مالية نهائية قبل استكمال العمليات المحاسبية.', style: TextStyle(color: Colors.black54)),
  ]);
}

class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white, child: ListTile(
    leading: Icon(icon, color: blue, size: 30), title: Text(title), subtitle: Text(subtitle),
  ));
}

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
