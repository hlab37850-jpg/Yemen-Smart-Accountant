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
  test('purchase invoice increases stock and updates purchase cost', () async {
    final marker = 'PURCHASE-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.saveContact(
      name: marker, phone: '', address: '', kind: 'supplier', openingBalance: 0,
    );
    final contact = (await AppDatabase.instance.contacts('supplier')).firstWhere((c) => c['name'] == marker);
    await AppDatabase.instance.saveProduct(
      name: marker, sku: marker, unit: 'قطعة',
      purchasePrice: 1000, salePrice: 2000, quantity: 1,
    );
    final product = (await AppDatabase.instance.products()).firstWhere((p) => p['sku'] == marker);
    final invoiceId = await AppDatabase.instance.createInvoice(
      invoiceType: 'purchase', invoiceDate: '2026-10-15',
      contactId: contact['id'] as int,
      lines: [{'product_id': product['id'] as int, 'quantity': 3, 'unit_price': 4000}],
    );
    final refreshed = (await AppDatabase.instance.products()).firstWhere((p) => p['id'] == product['id']);
    expect((refreshed['quantity'] as num).toDouble(), 4);
    expect(refreshed['purchase_price'], 4000);
    final invoice = (await AppDatabase.instance.invoices()).firstWhere((i) => i['id'] == invoiceId);
    expect(invoice['total'], 12000);
  });

  test('receipt voucher is saved and creates a balanced journal entry', () async {
    final marker = 'RECEIPT-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.saveContact(
      name: marker, phone: '', address: '', kind: 'customer', openingBalance: 0,
    );
    final contact = (await AppDatabase.instance.contacts('customer')).firstWhere((c) => c['name'] == marker);
    final voucherId = await AppDatabase.instance.createVoucher(
      voucherType: 'receipt', voucherDate: '2026-10-15',
      contactId: contact['id'] as int, amount: 7500, method: 'cash', note: 'اختبار',
    );
    final vouchers = await AppDatabase.instance.vouchers();
    final voucher = vouchers.firstWhere((v) => v['id'] == voucherId);
    expect(voucher['amount'], 7500);
    expect(voucher['contact_name'], marker);
    final db = await AppDatabase.instance.database;
    final row = (await db.query('vouchers', where: 'id=?', whereArgs: [voucherId])).single;
    expect(row['journal_entry_id'], isNotNull);
    final entry = (await AppDatabase.instance.journalEntries()).firstWhere((e) => e['id'] == row['journal_entry_id']);
    expect(entry['debit_total'], 7500);
    expect(entry['credit_total'], 7500);
  });

  test('customer current balance includes opening balance, invoices and receipts', () async {
    final marker = 'BALANCE-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.saveContact(
      name: marker, phone: '', address: '', kind: 'customer', openingBalance: 10000,
    );
    final contact = (await AppDatabase.instance.contacts('customer')).firstWhere((c) => c['name'] == marker);
    await AppDatabase.instance.saveProduct(
      name: marker, sku: marker, unit: 'قطعة',
      purchasePrice: 1000, salePrice: 5000, quantity: 5,
    );
    final product = (await AppDatabase.instance.products()).firstWhere((p) => p['sku'] == marker);
    await AppDatabase.instance.createInvoice(
      invoiceType: 'sale', invoiceDate: '2026-10-15',
      contactId: contact['id'] as int,
      lines: [{'product_id': product['id'] as int, 'quantity': 1, 'unit_price': 5000}],
    );
    await AppDatabase.instance.createVoucher(
      voucherType: 'receipt', voucherDate: '2026-10-15',
      contactId: contact['id'] as int, amount: 2000, method: 'cash',
    );
    final updated = (await AppDatabase.instance.contacts('customer')).firstWhere((c) => c['id'] == contact['id']);
    final current = (updated['opening_balance'] as int) +
        (updated['transaction_total'] as num).toInt() -
        (updated['settled_total'] as num).toInt();
    expect(current, 13000);
  });


  test('account ledger returns the posted debit and credit lines', () async {
    final marker = 'LEDGER-${DateTime.now().microsecondsSinceEpoch}';
    const amount = 432100;
    await AppDatabase.instance.createJournalEntry(
      description: marker,
      reference: 'LEDGER-REF',
      entryDate: '2026-10-15',
      lines: [
        {'account_code': '1000', 'debit': amount, 'credit': 0},
        {'account_code': '4000', 'debit': 0, 'credit': amount},
      ],
    );
    final cashLedger = await AppDatabase.instance.accountLedger('1000');
    final row = cashLedger.firstWhere((r) => r['description'] == marker);
    expect(row['debit'], amount);
    expect(row['credit'], 0);
    expect(row['reference'], 'LEDGER-REF');
  });

  test('financial summary calculates revenue, assets and net profit from posted entries', () async {
    final marker = 'SUMMARY-${DateTime.now().microsecondsSinceEpoch}';
    const amount = 876500;
    final before = await AppDatabase.instance.financialSummary();
    await AppDatabase.instance.createJournalEntry(
      description: marker,
      entryDate: '2026-10-15',
      lines: [
        {'account_code': '1000', 'debit': amount, 'credit': 0},
        {'account_code': '4000', 'debit': 0, 'credit': amount},
      ],
    );
    final after = await AppDatabase.instance.financialSummary();
    expect(after['assets']! - before['assets']!, amount);
    expect(after['revenue']! - before['revenue']!, amount);
    expect(after['net_profit']! - before['net_profit']!, amount);
    expect(after['liabilities_and_equity']! - before['liabilities_and_equity']!, amount);
  });

}
