import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yemen_smart_accountant/data/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('default chart of accounts is initialized', () async {
    final accounts = await AppDatabase.instance.accounts();
    expect(accounts.any((a) => a['code'] == '1000'), isTrue);
    expect(accounts.any((a) => a['code'] == '3000'), isTrue);
  });

  test('balanced journal entry posts and updates trial balance equally', () async {
    final db = await AppDatabase.instance.database;
    final before = await AppDatabase.instance.trialBalance();
    int balanceFor(List<Map<String, Object?>> rows, String code, String column) {
      final row = rows.firstWhere((r) => r['code'] == code);
      return (row[column] as num).toInt();
    }
    const amount = 12500;
    final marker = 'TEST-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.createJournalEntry(
      description: marker,
      reference: 'AUTOTEST',
      entryDate: '2026-10-15',
      lines: [
        {'account_code': '1000', 'debit': amount, 'credit': 0},
        {'account_code': '3000', 'debit': 0, 'credit': amount},
      ],
    );
    final after = await AppDatabase.instance.trialBalance();
    expect(balanceFor(after, '1000', 'debit_total') - balanceFor(before, '1000', 'debit_total'), amount);
    expect(balanceFor(after, '3000', 'credit_total') - balanceFor(before, '3000', 'credit_total'), amount);
    final entries = await AppDatabase.instance.journalEntries();
    final entry = entries.firstWhere((e) => e['description'] == marker);
    expect(entry['debit_total'], amount);
    expect(entry['credit_total'], amount);
    expect(await db.query('journal_entries', where: 'description=?', whereArgs: [marker]), hasLength(1));
  });

  test('unbalanced journal entry is rejected without saving', () async {
    final marker = 'INVALID-${DateTime.now().microsecondsSinceEpoch}';
    await expectLater(
      AppDatabase.instance.createJournalEntry(
        description: marker,
        entryDate: '2026-10-15',
        lines: [
          {'account_code': '1000', 'debit': 10000, 'credit': 0},
          {'account_code': '3000', 'debit': 0, 'credit': 9000},
        ],
      ),
      throwsArgumentError,
    );
    final entries = await AppDatabase.instance.journalEntries();
    expect(entries.any((e) => e['description'] == marker), isFalse);
  });
}

  test('sales invoice posts accounting entries and reduces stock atomically', () async {
    final marker = 'INV-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.saveContact(
      name: marker, phone: '', address: '', kind: 'customer', openingBalance: 0,
    );
    final contacts = await AppDatabase.instance.contacts('customer');
    final contact = contacts.firstWhere((c) => c['name'] == marker);
    await AppDatabase.instance.saveProduct(
      name: marker, sku: marker, unit: 'قطعة',
      purchasePrice: 5000, salePrice: 8000, quantity: 5,
    );
    final products = await AppDatabase.instance.products();
    final product = products.firstWhere((p) => p['sku'] == marker);
    final invoiceId = await AppDatabase.instance.createInvoice(
      invoiceType: 'sale',
      invoiceDate: '2026-10-15',
      contactId: contact['id'] as int,
      discount: 1000,
      lines: [
        {'product_id': product['id'] as int, 'quantity': 2.5, 'unit_price': 8000},
      ],
    );
    final refreshed = (await AppDatabase.instance.products()).firstWhere((p) => p['id'] == product['id']);
    expect((refreshed['quantity'] as num).toDouble(), 2.5);
    final invoices = await AppDatabase.instance.invoices();
    final invoice = invoices.firstWhere((i) => i['id'] == invoiceId);
    expect(invoice['total'], 19000);
    final lines = await AppDatabase.instance.invoiceLines(invoiceId);
    expect(lines, hasLength(1));
    expect(lines.first['cost_total'], 12500);
    final movements = await (await AppDatabase.instance.database).query(
      'stock_movements', where: 'product_id=? AND note LIKE ?', whereArgs: [product['id'], '%${invoice['invoice_number']}%'],
    );
    expect(movements, hasLength(1));
    expect((movements.first['quantity'] as num).toDouble(), -2.5);
  });

  test('sales invoice with insufficient stock is rejected and does not create invoice', () async {
    final marker = 'LOW-STOCK-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.saveContact(
      name: marker, phone: '', address: '', kind: 'customer', openingBalance: 0,
    );
    final contact = (await AppDatabase.instance.contacts('customer')).firstWhere((c) => c['name'] == marker);
    await AppDatabase.instance.saveProduct(
      name: marker, sku: marker, unit: 'قطعة',
      purchasePrice: 1000, salePrice: 2000, quantity: 1,
    );
    final product = (await AppDatabase.instance.products()).firstWhere((p) => p['sku'] == marker);
    await expectLater(
      AppDatabase.instance.createInvoice(
        invoiceType: 'sale', invoiceDate: '2026-10-15',
        contactId: contact['id'] as int,
        lines: [{'product_id': product['id'] as int, 'quantity': 2, 'unit_price': 2000}],
      ),
      throwsArgumentError,
    );
    final invoices = await AppDatabase.instance.invoices();
    expect(invoices.any((i) => i['contact_name'] == marker), isFalse);
    final refreshed = (await AppDatabase.instance.products()).firstWhere((p) => p['id'] == product['id']);
    expect((refreshed['quantity'] as num).toDouble(), 1);
  });
