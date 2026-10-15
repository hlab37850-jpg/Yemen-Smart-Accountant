import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'yemen_smart_accountant.db'),
      version: 5,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (db, version) async {
        await _createBaseSchema(db);
        await _createAccountingSchema(db);
        await _seedAccounts(db);
        await _createInvoiceSchema(db);
        await _createReturnsSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAccountingSchema(db);
          await _seedAccounts(db);
        }
        if (oldVersion < 3) await _createInvoiceSchema(db);
        if (oldVersion < 4) await db.execute('ALTER TABLE vouchers ADD COLUMN journal_entry_id INTEGER REFERENCES journal_entries(id)');
        if (oldVersion < 5) {
          await _createReturnsSchema(db);
          await _seedAccounts(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createBaseSchema(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE company_settings (id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '', currency TEXT NOT NULL DEFAULT 'ر.ي')");
    await db.execute("CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL CHECK(kind IN ('customer','supplier')), opening_balance INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)");
    await db.execute('CREATE INDEX idx_contacts_kind ON contacts(kind)');
    await db.execute("CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, sku TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT 'قطعة', purchase_price INTEGER NOT NULL DEFAULT 0 CHECK(purchase_price>=0), sale_price INTEGER NOT NULL DEFAULT 0 CHECK(sale_price>=0), quantity REAL NOT NULL DEFAULT 0 CHECK(quantity>=0), created_at TEXT NOT NULL)");
    await db.execute("CREATE TABLE journal_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_date TEXT NOT NULL, description TEXT NOT NULL, reference TEXT NOT NULL DEFAULT '', posted INTEGER NOT NULL DEFAULT 0 CHECK(posted IN (0,1)), created_at TEXT NOT NULL)");
    await db.execute('CREATE TABLE journal_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE, account_code TEXT NOT NULL, account_name TEXT NOT NULL, debit INTEGER NOT NULL DEFAULT 0 CHECK(debit>=0), credit INTEGER NOT NULL DEFAULT 0 CHECK(credit>=0), CHECK(debit=0 OR credit=0))');
    await db.execute('CREATE TABLE stock_movements (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL REFERENCES products(id), movement_date TEXT NOT NULL, movement_type TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity!=0), note TEXT NOT NULL DEFAULT "")');
    await db.execute("CREATE TABLE vouchers (id INTEGER PRIMARY KEY AUTOINCREMENT, voucher_type TEXT NOT NULL CHECK(voucher_type IN ('receipt','payment')), voucher_date TEXT NOT NULL, contact_id INTEGER REFERENCES contacts(id), amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL DEFAULT 'cash', note TEXT NOT NULL DEFAULT '', journal_entry_id INTEGER REFERENCES journal_entries(id), created_at TEXT NOT NULL)");
  }

  Future<void> _createAccountingSchema(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS accounts (code TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('asset','liability','equity','revenue','expense')), is_system INTEGER NOT NULL DEFAULT 1 CHECK(is_system IN (0,1)), active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)))");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_code)');
  }

  Future<void> _seedAccounts(DatabaseExecutor db) async {
    const defaults = <Map<String, Object>>[
      {'code':'1000','name':'الصندوق','type':'asset'},
      {'code':'1010','name':'البنك','type':'asset'},
      {'code':'1100','name':'العملاء','type':'asset'},
      {'code':'1200','name':'المخزون','type':'asset'},
      {'code':'2000','name':'الموردون','type':'liability'},
      {'code':'2100','name':'ضرائب مستحقة','type':'liability'},
      {'code':'3000','name':'رأس المال','type':'equity'},
      {'code':'3100','name':'الأرباح المحتجزة','type':'equity'},
      {'code':'4000','name':'المبيعات','type':'revenue'},
      {'code':'4100','name':'إيرادات أخرى','type':'revenue'},
      {'code':'4200','name':'مرتجعات المبيعات','type':'revenue'},
      {'code':'5000','name':'تكلفة البضاعة المباعة','type':'expense'},
      {'code':'6000','name':'المصروفات التشغيلية','type':'expense'},
    ];
    for (final account in defaults) {
      await db.insert('accounts', account, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createInvoiceSchema(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_type TEXT NOT NULL CHECK(invoice_type IN ('sale','purchase')), invoice_number TEXT NOT NULL UNIQUE, invoice_date TEXT NOT NULL, contact_id INTEGER NOT NULL REFERENCES contacts(id), subtotal INTEGER NOT NULL CHECK(subtotal>=0), discount INTEGER NOT NULL DEFAULT 0 CHECK(discount>=0), total INTEGER NOT NULL CHECK(total>0), journal_entry_id INTEGER REFERENCES journal_entries(id), created_at TEXT NOT NULL)");
    await db.execute("CREATE TABLE IF NOT EXISTS invoice_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE, product_id INTEGER NOT NULL REFERENCES products(id), quantity REAL NOT NULL CHECK(quantity>0), unit_price INTEGER NOT NULL CHECK(unit_price>=0), unit_cost INTEGER NOT NULL CHECK(unit_cost>=0), line_total INTEGER NOT NULL CHECK(line_total>=0), cost_total INTEGER NOT NULL CHECK(cost_total>=0))");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(invoice_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_lines_invoice ON invoice_lines(invoice_id)');
  }


  Future<void> _createReturnsSchema(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS returns (id INTEGER PRIMARY KEY AUTOINCREMENT, return_type TEXT NOT NULL CHECK(return_type IN ('sale_return','purchase_return')), invoice_id INTEGER NOT NULL REFERENCES invoices(id), return_date TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), journal_entry_id INTEGER REFERENCES journal_entries(id), note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL)");
    await db.execute("CREATE TABLE IF NOT EXISTS return_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL REFERENCES returns(id) ON DELETE CASCADE, original_line_id INTEGER NOT NULL REFERENCES invoice_lines(id), product_id INTEGER NOT NULL REFERENCES products(id), quantity REAL NOT NULL CHECK(quantity>0), unit_price INTEGER NOT NULL CHECK(unit_price>=0), unit_cost INTEGER NOT NULL CHECK(unit_cost>=0), line_total INTEGER NOT NULL CHECK(line_total>0))");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_invoice ON returns(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_return_lines_original ON return_lines(original_line_id)');
  }

  String get _now => DateTime.now().toIso8601String();

  Future<Map<String, int>> stats() async {
    final db = await database;
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ' + table)) ?? 0;
    final customers = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM contacts WHERE kind='customer'")) ?? 0;
    final suppliers = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM contacts WHERE kind='supplier'")) ?? 0;
    return {'customers': customers, 'suppliers': suppliers, 'products': await count('products'), 'entries': await count('journal_entries')};
  }

  Future<List<Map<String, Object?>>> contacts(String kind) async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.*,
        COALESCE((
          SELECT SUM(i.total) FROM invoices i
          WHERE i.contact_id=c.id
            AND i.invoice_type=CASE WHEN c.kind='customer' THEN 'sale' ELSE 'purchase' END
        ),0) - COALESCE((
          SELECT SUM(r.amount) FROM returns r
          JOIN invoices ri ON ri.id=r.invoice_id
          WHERE ri.contact_id=c.id
            AND r.return_type=CASE WHEN c.kind='customer' THEN 'sale_return' ELSE 'purchase_return' END
        ),0) AS transaction_total,
        COALESCE((
          SELECT SUM(v.amount) FROM vouchers v
          WHERE v.contact_id=c.id
            AND v.voucher_type=CASE WHEN c.kind='customer' THEN 'receipt' ELSE 'payment' END
        ),0) AS settled_total
      FROM contacts c
      WHERE c.kind=?
      ORDER BY c.name COLLATE NOCASE
    ''', [kind]);
  }

  Future<List<Map<String, Object?>>> contactStatement(int contactId) async {
    final db = await database;
    final contactRows = await db.query('contacts', where: 'id=?', whereArgs: [contactId], limit: 1);
    if (contactRows.isEmpty) throw ArgumentError('الطرف غير موجود');
    final contact = contactRows.first;
    final kind = contact['kind'] as String;
    final opening = (contact['opening_balance'] as num).toInt();
    final events = <Map<String, Object?>>[];
    if (opening != 0) {
      events.add({
        'date': (contact['created_at'] as String).substring(0, 10),
        'description': 'الرصيد الافتتاحي',
        'reference': '',
        'debit': kind == 'customer' ? opening : 0,
        'credit': kind == 'supplier' ? opening : 0,
        'sort_order': 0,
      });
    }
    final invoices = await db.query('invoices',
      where: 'contact_id=? AND invoice_type=?',
      whereArgs: [contactId, kind == 'customer' ? 'sale' : 'purchase']);
    for (final invoice in invoices) {
      final amount = (invoice['total'] as num).toInt();
      events.add({
        'date': invoice['invoice_date'], 'description': kind == 'customer' ? 'فاتورة مبيعات' : 'فاتورة مشتريات',
        'reference': invoice['invoice_number'],
        'debit': kind == 'customer' ? amount : 0,
        'credit': kind == 'supplier' ? amount : 0,
        'sort_order': 1,
      });
    }
    final vouchers = await db.query('vouchers', where: 'contact_id=?', whereArgs: [contactId]);
    for (final voucher in vouchers) {
      final amount = (voucher['amount'] as num).toInt();
      final isReceipt = voucher['voucher_type'] == 'receipt';
      events.add({
        'date': voucher['voucher_date'],
        'description': isReceipt ? 'سند قبض' : 'سند صرف',
        'reference': '${isReceipt ? 'R' : 'P'}-${voucher['id']}',
        'debit': kind == 'supplier' && !isReceipt ? amount : 0,
        'credit': kind == 'customer' && isReceipt ? amount : 0,
        'sort_order': 2,
      });
    }
    final returns = await db.rawQuery('''
      SELECT r.id, r.return_type, r.return_date, r.amount
      FROM returns r JOIN invoices i ON i.id=r.invoice_id
      WHERE i.contact_id=?
    ''', [contactId]);
    for (final item in returns) {
      final isSaleReturn = item['return_type'] == 'sale_return';
      final amount = (item['amount'] as num).toInt();
      events.add({
        'date': item['return_date'],
        'description': isSaleReturn ? 'مرتجع مبيعات' : 'مرتجع مشتريات',
        'reference': 'RET-${item['id']}',
        'debit': kind == 'supplier' && !isSaleReturn ? amount : 0,
        'credit': kind == 'customer' && isSaleReturn ? amount : 0,
        'sort_order': 3,
      });
    }
    events.sort((a, b) {
      final dateCompare = (a['date'] as String).compareTo(b['date'] as String);
      if (dateCompare != 0) return dateCompare;
      return (a['sort_order'] as int).compareTo(b['sort_order'] as int);
    });
    var running = 0;
    for (final event in events) {
      final debit = (event['debit'] as num).toInt();
      final credit = (event['credit'] as num).toInt();
      running += kind == 'customer' ? debit - credit : credit - debit;
      event['balance'] = running;
    }
    return events;
  }

  Future<void> saveContact({int? id, required String name, required String phone, required String address, required String kind, required int openingBalance}) async {
    final db = await database;
    final values = {'name': name.trim(), 'phone': phone.trim(), 'address': address.trim(), 'kind': kind, 'opening_balance': openingBalance};
    if (id == null) {
      await db.insert('contacts', {...values, 'created_at': _now});
    } else {
      await db.update('contacts', values, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> deleteContact(int id) async { await (await database).delete('contacts', where: 'id=?', whereArgs: [id]); }
  Future<List<Map<String, Object?>>> products() async => (await database).query('products', orderBy: 'name COLLATE NOCASE');

  Future<void> saveProduct({int? id, required String name, required String sku, required String unit, required int purchasePrice, required int salePrice, required double quantity}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('اسم الصنف مطلوب');
    if (purchasePrice < 0 || salePrice < 0 || quantity < 0) throw ArgumentError('السعر والكمية لا يمكن أن تكون سالبة');
    final db = await database;
    await db.transaction((txn) async {
      final values = <String, Object>{
        'name': normalizedName, 'sku': sku.trim(),
        'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(),
        'purchase_price': purchasePrice, 'sale_price': salePrice, 'quantity': quantity,
      };
      if (id == null) {
        final productId = await txn.insert('products', {...values, 'created_at': _now});
        if (quantity > 0) {
          await txn.insert('stock_movements', {
            'product_id': productId, 'movement_date': DateTime.now().toIso8601String().substring(0, 10),
            'movement_type': 'opening', 'quantity': quantity, 'note': 'رصيد مخزون افتتاحي',
          });
          final openingValue = (quantity * purchasePrice).round();
          if (openingValue > 0) {
            await _insertPostedEntry(txn,
              description: 'رصيد مخزون افتتاحي: $normalizedName',
              entryDate: DateTime.now().toIso8601String().substring(0, 10),
              reference: 'STOCK-OPEN-$productId',
              lines: [
                {'account_code':'1200','debit':openingValue,'credit':0},
                {'account_code':'3000','debit':0,'credit':openingValue},
              ]);
          }
        }
        return;
      }
      final existingRows = await txn.query('products', where: 'id=?', whereArgs: [id], limit: 1);
      if (existingRows.isEmpty) throw ArgumentError('الصنف غير موجود');
      final existing = existingRows.first;
      final oldQuantity = (existing['quantity'] as num).toDouble();
      final difference = quantity - oldQuantity;
      await txn.update('products', values, where: 'id=?', whereArgs: [id]);
      if (difference.abs() > 0.000001) {
        final date = DateTime.now().toIso8601String().substring(0, 10);
        await txn.insert('stock_movements', {
          'product_id': id, 'movement_date': date, 'movement_type': 'adjustment',
          'quantity': difference, 'note': 'تسوية كمية يدوية',
        });
        final priceForAdjustment = purchasePrice > 0 ? purchasePrice : (existing['purchase_price'] as int);
        final adjustmentValue = (difference.abs() * priceForAdjustment).round();
        if (adjustmentValue > 0) {
          await _insertPostedEntry(txn,
            description: 'تسوية مخزون يدوية: $normalizedName',
            entryDate: date, reference: 'STOCK-ADJ-$id-${DateTime.now().microsecondsSinceEpoch}',
            lines: difference > 0
              ? [
                  {'account_code':'1200','debit':adjustmentValue,'credit':0},
                  {'account_code':'4100','debit':0,'credit':adjustmentValue},
                ]
              : [
                  {'account_code':'6000','debit':adjustmentValue,'credit':0},
                  {'account_code':'1200','debit':0,'credit':adjustmentValue},
                ]);
        }
      }
    });
  }

  Future<void> deleteProduct(int id) async { await (await database).delete('products', where: 'id=?', whereArgs: [id]); }
  Future<Map<String, Object?>?> company() async {
    final rows = await (await database).query('company_settings', where: 'id=1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveCompany({required String name, required String phone, required String address, required String currency}) async {
    await (await database).insert('company_settings', {'id': 1, 'name': name.trim(), 'phone': phone.trim(), 'address': address.trim(), 'currency': currency}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> accounts() async =>
      (await database).query('accounts', where: 'active=1', orderBy: 'code');

  Future<void> createAccount({required String code, required String name, required String type}) async {
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    if (normalizedCode.isEmpty || normalizedName.isEmpty) throw ArgumentError('رمز الحساب واسم الحساب مطلوبان');
    const validTypes = {'asset','liability','equity','revenue','expense'};
    if (!validTypes.contains(type)) throw ArgumentError('نوع الحساب غير صالح');
    await (await database).insert('accounts', {
      'code': normalizedCode, 'name': normalizedName, 'type': type, 'is_system': 0, 'active': 1,
    });
  }

  Future<void> createJournalEntry({
    required String description,
    required String entryDate,
    String reference = '',
    required List<Map<String, Object>> lines,
  }) async {
    if (description.trim().isEmpty) throw ArgumentError('وصف القيد مطلوب');
    if (lines.length < 2) throw ArgumentError('يجب أن يحتوي القيد على سطرين على الأقل');
    var debitTotal = 0;
    var creditTotal = 0;
    final db = await database;
    final normalizedLines = <Map<String, Object>>[];
    for (final line in lines) {
      final code = (line['account_code'] ?? '').toString();
      final debit = line['debit'] as int? ?? 0;
      final credit = line['credit'] as int? ?? 0;
      if (debit < 0 || credit < 0 || (debit > 0 && credit > 0) || (debit == 0 && credit == 0)) {
        throw ArgumentError('كل سطر يجب أن يحتوي مديناً أو دائناً موجباً فقط');
      }
      final found = await db.query('accounts', columns: ['code','name'], where: 'code=? AND active=1', whereArgs: [code], limit: 1);
      if (found.isEmpty) throw ArgumentError('الحساب غير موجود: ' + code);
      debitTotal += debit;
      creditTotal += credit;
      normalizedLines.add({
        'account_code': code, 'account_name': found.first['name'] as String,
        'debit': debit, 'credit': credit,
      });
    }
    if (debitTotal <= 0 || debitTotal != creditTotal) {
      throw ArgumentError('القيد غير متوازن: إجمالي المدين يجب أن يساوي إجمالي الدائن');
    }
    await db.transaction((txn) async {
      final entryId = await txn.insert('journal_entries', {
        'entry_date': entryDate, 'description': description.trim(),
        'reference': reference.trim(), 'posted': 1, 'created_at': _now,
      });
      for (final line in normalizedLines) {
        await txn.insert('journal_lines', {...line, 'entry_id': entryId});
      }
    });
  }

  Future<List<Map<String, Object?>>> journalEntries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT e.id, e.entry_date, e.description, e.reference,
        COALESCE(SUM(l.debit),0) AS debit_total,
        COALESCE(SUM(l.credit),0) AS credit_total
      FROM journal_entries e LEFT JOIN journal_lines l ON l.entry_id=e.id
      GROUP BY e.id ORDER BY e.entry_date DESC, e.id DESC
    ''');
  }

  Future<int> createInvoice({
    required String invoiceType,
    required String invoiceDate,
    required int contactId,
    required List<Map<String, Object>> lines,
    int discount = 0,
  }) async {
    if (invoiceType != 'sale' && invoiceType != 'purchase') throw ArgumentError('نوع الفاتورة غير صالح');
    if (lines.isEmpty) throw ArgumentError('أضف صنفاً واحداً على الأقل');
    if (discount < 0) throw ArgumentError('الخصم لا يمكن أن يكون سالباً');
    final db = await database;
    return db.transaction<int>((txn) async {
      final expectedKind = invoiceType == 'sale' ? 'customer' : 'supplier';
      final contact = await txn.query('contacts', where: 'id=? AND kind=?', whereArgs: [contactId, expectedKind], limit: 1);
      if (contact.isEmpty) throw ArgumentError(invoiceType == 'sale' ? 'اختر عميلاً صحيحاً' : 'اختر مورداً صحيحاً');
      var subtotal = 0;
      var costTotal = 0;
      final prepared = <Map<String, Object>>[];
      final requestedByProduct = <int, double>{};
      for (final line in lines) {
        final productId = line['product_id'] as int;
        final quantity = (line['quantity'] as num).toDouble();
        final unitPrice = line['unit_price'] as int;
        if (quantity <= 0 || unitPrice < 0) throw ArgumentError('الكمية والسعر غير صالحين');
        final productRows = await txn.query('products', where: 'id=?', whereArgs: [productId], limit: 1);
        if (productRows.isEmpty) throw ArgumentError('الصنف غير موجود');
        final product = productRows.first;
        final stock = (product['quantity'] as num).toDouble();
        final unitCost = invoiceType == 'purchase' ? unitPrice : (product['purchase_price'] as int);
        final requested = (requestedByProduct[productId] ?? 0) + quantity;
        requestedByProduct[productId] = requested;
        if (invoiceType == 'sale' && stock < requested - 0.000001) {
          throw ArgumentError('الكمية المتوفرة من ${product['name']} غير كافية للكمية الإجمالية المطلوبة');
        }
        final lineTotal = (quantity * unitPrice).round();
        final lineCost = (quantity * unitCost).round();
        subtotal += lineTotal;
        costTotal += lineCost;
        prepared.add({
          'product_id': productId, 'quantity': quantity, 'unit_price': unitPrice,
          'unit_cost': unitCost, 'line_total': lineTotal, 'cost_total': lineCost,
          'product_name': product['name'] as String,
          'old_quantity': stock,
        });
      }
      if (discount > subtotal) throw ArgumentError('الخصم أكبر من إجمالي الفاتورة');
      final total = subtotal - discount;
      if (total <= 0) throw ArgumentError('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
      var allocatedDiscount = 0;
      for (var i = 0; i < prepared.length; i++) {
        final line = prepared[i];
        final grossLineTotal = line['line_total'] as int;
        final share = i == prepared.length - 1
          ? discount - allocatedDiscount
          : (discount * grossLineTotal / subtotal).round().clamp(0, discount - allocatedDiscount).toInt();
        allocatedDiscount += share;
        final netLineTotal = grossLineTotal - share;
        line['line_total'] = netLineTotal;
        if (invoiceType == 'purchase') {
          final quantity = line['quantity'] as double;
          final effectiveUnitCost = (netLineTotal / quantity).round();
          line['unit_cost'] = effectiveUnitCost;
          line['cost_total'] = netLineTotal;
        }
      }
      final invoiceNumber = (invoiceType == 'sale' ? 'S-' : 'P-') +
          DateTime.now().microsecondsSinceEpoch.toString();
      final invoiceId = await txn.insert('invoices', {
        'invoice_type': invoiceType, 'invoice_number': invoiceNumber,
        'invoice_date': invoiceDate, 'contact_id': contactId,
        'subtotal': subtotal, 'discount': discount, 'total': total,
        'created_at': _now,
      });
      final purchasePriceByProduct = <int, int>{};
      for (final line in prepared) {
        await txn.insert('invoice_lines', {
          'invoice_id': invoiceId, 'product_id': line['product_id'],
          'quantity': line['quantity'], 'unit_price': line['unit_price'],
          'unit_cost': line['unit_cost'], 'line_total': line['line_total'],
          'cost_total': line['cost_total'],
        });
        final productId = line['product_id'] as int;
        final quantity = line['quantity'] as double;
        await txn.insert('stock_movements', {
          'product_id': productId,
          'movement_date': invoiceDate,
          'movement_type': invoiceType == 'sale' ? 'sale' : 'purchase',
          'quantity': invoiceType == 'sale' ? -quantity : quantity,
          'note': 'فاتورة $invoiceNumber',
        });
        if (invoiceType == 'purchase') purchasePriceByProduct[productId] = line['unit_cost'] as int;
      }
      for (final entry in requestedByProduct.entries) {
        final productRows = await txn.query('products', columns: ['quantity'], where: 'id=?', whereArgs: [entry.key], limit: 1);
        final current = (productRows.first['quantity'] as num).toDouble();
        final next = invoiceType == 'sale' ? current - entry.value : current + entry.value;
        final values = <String, Object>{'quantity': next};
        if (invoiceType == 'purchase') values['purchase_price'] = purchasePriceByProduct[entry.key]!;
        await txn.update('products', values, where: 'id=?', whereArgs: [entry.key]);
      }
      final mainLines = invoiceType == 'sale'
          ? [
              {'account_code': '1100', 'debit': total, 'credit': 0},
              {'account_code': '4000', 'debit': 0, 'credit': total},
            ]
          : [
              {'account_code': '1200', 'debit': total, 'credit': 0},
              {'account_code': '2000', 'debit': 0, 'credit': total},
            ];
      final entryId = await _insertPostedEntry(
        txn,
        description: (invoiceType == 'sale' ? 'فاتورة مبيعات ' : 'فاتورة مشتريات ') + invoiceNumber,
        entryDate: invoiceDate,
        reference: invoiceNumber,
        lines: mainLines,
      );
      if (invoiceType == 'sale' && costTotal > 0) {
        await _insertPostedEntry(
          txn,
          description: 'تكلفة بضاعة الفاتورة $invoiceNumber',
          entryDate: invoiceDate,
          reference: invoiceNumber,
          lines: [
            {'account_code': '5000', 'debit': costTotal, 'credit': 0},
            {'account_code': '1200', 'debit': 0, 'credit': costTotal},
          ],
        );
      }
      await txn.update('invoices', {'journal_entry_id': entryId}, where: 'id=?', whereArgs: [invoiceId]);
      return invoiceId;
    });
  }

  Future<int> _insertPostedEntry(
    Transaction txn, {
    required String description,
    required String entryDate,
    required String reference,
    required List<Map<String, Object>> lines,
  }) async {
    var debitTotal = 0;
    var creditTotal = 0;
    final resolved = <Map<String, Object>>[];
    for (final line in lines) {
      final code = line['account_code'] as String;
      final debit = line['debit'] as int;
      final credit = line['credit'] as int;
      if ((debit > 0 && credit > 0) || debit < 0 || credit < 0) {
        throw ArgumentError('سطر قيد غير صالح');
      }
      final accountsFound = await txn.query('accounts', columns: ['name'], where: 'code=? AND active=1', whereArgs: [code], limit: 1);
      if (accountsFound.isEmpty) throw ArgumentError('الحساب غير موجود: ' + code);
      debitTotal += debit;
      creditTotal += credit;
      resolved.add({
        'account_code': code, 'account_name': accountsFound.first['name'] as String,
        'debit': debit, 'credit': credit,
      });
    }
    if (debitTotal <= 0 || debitTotal != creditTotal) throw ArgumentError('القيد المحاسبي غير متوازن');
    final entryId = await txn.insert('journal_entries', {
      'entry_date': entryDate, 'description': description, 'reference': reference,
      'posted': 1, 'created_at': _now,
    });
    for (final line in resolved) {
      await txn.insert('journal_lines', {...line, 'entry_id': entryId});
    }
    return entryId;
  }

  Future<int> createVoucher({
    required String voucherType,
    required String voucherDate,
    required int contactId,
    required int amount,
    required String method,
    String note = '',
  }) async {
    if (voucherType != 'receipt' && voucherType != 'payment') throw ArgumentError('نوع السند غير صالح');
    if (amount <= 0) throw ArgumentError('مبلغ السند يجب أن يكون أكبر من صفر');
    if (!{'cash','bank'}.contains(method)) throw ArgumentError('طريقة السداد غير صالحة');
    final db = await database;
    return db.transaction<int>((txn) async {
      final expectedKind = voucherType == 'receipt' ? 'customer' : 'supplier';
      final contact = await txn.query('contacts', where: 'id=? AND kind=?', whereArgs: [contactId, expectedKind], limit: 1);
      if (contact.isEmpty) throw ArgumentError(voucherType == 'receipt' ? 'اختر عميلاً صحيحاً' : 'اختر مورداً صحيحاً');
      final voucherId = await txn.insert('vouchers', {
        'voucher_type': voucherType, 'voucher_date': voucherDate,
        'contact_id': contactId, 'amount': amount, 'method': method,
        'note': note.trim(), 'created_at': _now,
      });
      final reference = (voucherType == 'receipt' ? 'R-' : 'P-') + voucherId.toString();
      final lines = voucherType == 'receipt'
          ? [
              {'account_code': method == 'bank' ? '1010' : '1000', 'debit': amount, 'credit': 0},
              {'account_code': '1100', 'debit': 0, 'credit': amount},
            ]
          : [
              {'account_code': '2000', 'debit': amount, 'credit': 0},
              {'account_code': method == 'bank' ? '1010' : '1000', 'debit': 0, 'credit': amount},
            ];
      final entryId = await _insertPostedEntry(
        txn,
        description: (voucherType == 'receipt' ? 'سند قبض ' : 'سند صرف ') + reference,
        entryDate: voucherDate,
        reference: reference,
        lines: lines,
      );
      await txn.update('vouchers', {'journal_entry_id': entryId}, where: 'id=?', whereArgs: [voucherId]);
      return voucherId;
    });
  }

  Future<List<Map<String, Object?>>> vouchers() async {
    final db = await database;
    return db.rawQuery('''
      SELECT v.id, v.voucher_type, v.voucher_date, v.amount, v.method, v.note,
        c.name AS contact_name
      FROM vouchers v LEFT JOIN contacts c ON c.id=v.contact_id
      ORDER BY v.voucher_date DESC, v.id DESC
    ''');
  }

  Future<List<Map<String, Object?>>> invoices() async {
    final db = await database;
    return db.rawQuery('''
      SELECT i.id, i.invoice_type, i.invoice_number, i.invoice_date, i.subtotal,
        i.discount, i.total, c.name AS contact_name
      FROM invoices i JOIN contacts c ON c.id=i.contact_id
      ORDER BY i.invoice_date DESC, i.id DESC
    ''');
  }

  Future<List<Map<String, Object?>>> invoiceLines(int invoiceId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT il.*, p.name AS product_name, p.unit AS unit_name
      FROM invoice_lines il JOIN products p ON p.id=il.product_id
      WHERE il.invoice_id=? ORDER BY il.id
    ''', [invoiceId]);
  }

  Future<List<Map<String, Object?>>> trialBalance() async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.code, a.name, a.type,
        COALESCE(SUM(l.debit),0) AS debit_total,
        COALESCE(SUM(l.credit),0) AS credit_total
      FROM accounts a LEFT JOIN journal_lines l ON l.account_code=a.code AND l.entry_id IN (SELECT id FROM journal_entries WHERE posted=1)
      WHERE a.active=1
      GROUP BY a.code, a.name, a.type
      ORDER BY a.code
    ''');
  }

  Future<List<Map<String, Object?>>> accountLedger(String accountCode) async {
    final db = await database;
    return db.rawQuery('''
      SELECT e.id AS entry_id, e.entry_date, e.description, e.reference,
        l.debit, l.credit, l.account_name
      FROM journal_lines l
      JOIN journal_entries e ON e.id=l.entry_id
      WHERE l.account_code=? AND e.posted=1
      ORDER BY e.entry_date, e.id, l.id
    ''', [accountCode]);
  }

  Future<Map<String, int>> financialSummary() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.type,
        COALESCE(SUM(l.debit),0) AS debits,
        COALESCE(SUM(l.credit),0) AS credits
      FROM accounts a
      LEFT JOIN journal_lines l ON l.account_code=a.code AND l.entry_id IN (SELECT id FROM journal_entries WHERE posted=1)
      WHERE a.active=1
      GROUP BY a.type
    ''');
    final totals = <String, int>{'assets':0,'liabilities':0,'equity':0,'revenue':0,'expenses':0};
    for (final row in rows) {
      final type = row['type'] as String;
      final debit = (row['debits'] as num).toInt();
      final credit = (row['credits'] as num).toInt();
      switch (type) {
        case 'asset': totals['assets'] = (totals['assets'] ?? 0) + debit - credit; break;
        case 'liability': totals['liabilities'] = (totals['liabilities'] ?? 0) + credit - debit; break;
        case 'equity': totals['equity'] = (totals['equity'] ?? 0) + credit - debit; break;
        case 'revenue': totals['revenue'] = (totals['revenue'] ?? 0) + credit - debit; break;
        case 'expense': totals['expenses'] = (totals['expenses'] ?? 0) + debit - credit; break;
      }
    }
    totals['net_profit'] = (totals['revenue'] ?? 0) - (totals['expenses'] ?? 0);
    totals['liabilities_and_equity'] = (totals['liabilities'] ?? 0) + (totals['equity'] ?? 0) + (totals['net_profit'] ?? 0);
    return totals;
  }

  Future<List<Map<String, Object?>>> stockMovements({int? productId}) async {
    final db = await database;
    if (productId == null) {
      return db.rawQuery('''
        SELECT m.*, p.name AS product_name, p.unit AS unit_name
        FROM stock_movements m JOIN products p ON p.id=m.product_id
        ORDER BY m.movement_date DESC, m.id DESC
      ''');
    }
    return db.rawQuery('''
      SELECT m.*, p.name AS product_name, p.unit AS unit_name
      FROM stock_movements m JOIN products p ON p.id=m.product_id
      WHERE m.product_id=?
      ORDER BY m.movement_date DESC, m.id DESC
    ''', [productId]);
  }


  Future<List<Map<String, Object?>>> returns() async {
    final db = await database;
    return db.rawQuery('''
      SELECT r.id, r.return_type, r.return_date, r.amount, r.note,
        i.invoice_number, c.name AS contact_name
      FROM returns r JOIN invoices i ON i.id=r.invoice_id
      JOIN contacts c ON c.id=i.contact_id
      ORDER BY r.return_date DESC, r.id DESC
    ''');
  }

  Future<int> createReturn({
    required int invoiceId,
    required int invoiceLineId,
    required double quantity,
    required String returnDate,
    String note = '',
  }) async {
    if (quantity <= 0) throw ArgumentError('كمية المرتجع يجب أن تكون أكبر من صفر');
    final db = await database;
    return db.transaction<int>((txn) async {
      final invoices = await txn.query('invoices', where: 'id=?', whereArgs: [invoiceId], limit: 1);
      if (invoices.isEmpty) throw ArgumentError('الفاتورة الأصلية غير موجودة');
      final invoice = invoices.first;
      final invoiceType = invoice['invoice_type'] as String;
      final returnType = invoiceType == 'sale' ? 'sale_return' : 'purchase_return';
      final lines = await txn.rawQuery('''
        SELECT il.*, p.name AS product_name, p.quantity AS stock
        FROM invoice_lines il JOIN products p ON p.id=il.product_id
        WHERE il.id=? AND il.invoice_id=?
      ''', [invoiceLineId, invoiceId]);
      if (lines.isEmpty) throw ArgumentError('الصنف لا يتبع الفاتورة المحددة');
      final line = lines.first;
      final priorRows = await txn.rawQuery('SELECT COALESCE(SUM(quantity),0) AS qty FROM return_lines WHERE original_line_id=?', [invoiceLineId]);
      final returned = (priorRows.first['qty'] as num).toDouble();
      final originalQuantity = (line['quantity'] as num).toDouble();
      final remaining = originalQuantity - returned;
      if (quantity > remaining + 0.000001) throw ArgumentError('الكمية تتجاوز المتبقي القابل للإرجاع: $remaining');
      final productId = line['product_id'] as int;
      final unitCost = line['unit_cost'] as int;
      final netLineTotal = line['line_total'] as int;
      final amount = (quantity * netLineTotal / originalQuantity).round();
      final returnUnitPrice = (netLineTotal / originalQuantity).round();
      final cost = (quantity * unitCost).round();
      if (amount <= 0) throw ArgumentError('قيمة المرتجع يجب أن تكون أكبر من صفر');
      final stock = (line['stock'] as num).toDouble();
      if (returnType == 'purchase_return' && stock < quantity) {
        throw ArgumentError('لا يمكن إرجاع كمية أكبر من المخزون المتاح');
      }
      final returnId = await txn.insert('returns', {
        'return_type': returnType, 'invoice_id': invoiceId, 'return_date': returnDate,
        'amount': amount, 'note': note.trim(), 'created_at': _now,
      });
      await txn.insert('return_lines', {
        'return_id': returnId, 'original_line_id': invoiceLineId,
        'product_id': productId, 'quantity': quantity, 'unit_price': returnUnitPrice,
        'unit_cost': unitCost, 'line_total': amount,
      });
      await txn.update('products', {
        'quantity': returnType == 'sale_return' ? stock + quantity : stock - quantity,
      }, where: 'id=?', whereArgs: [productId]);
      await txn.insert('stock_movements', {
        'product_id': productId, 'movement_date': returnDate,
        'movement_type': returnType, 'quantity': returnType == 'sale_return' ? quantity : -quantity,
        'note': 'مرتجع الفاتورة ${invoice['invoice_number']}',
      });
      final mainLines = returnType == 'sale_return'
        ? [
            {'account_code':'4200','debit':amount,'credit':0},
            {'account_code':'1100','debit':0,'credit':amount},
          ]
        : [
            {'account_code':'2000','debit':amount,'credit':0},
            {'account_code':'1200','debit':0,'credit':amount},
          ];
      final entryId = await _insertPostedEntry(
        txn,
        description: returnType == 'sale_return' ? 'مرتجع مبيعات ${invoice['invoice_number']}' : 'مرتجع مشتريات ${invoice['invoice_number']}',
        entryDate: returnDate,
        reference: 'RET-$returnId',
        lines: mainLines,
      );
      if (returnType == 'sale_return' && cost > 0) {
        await _insertPostedEntry(txn,
          description: 'إعادة تكلفة مخزون مرتجع ${invoice['invoice_number']}',
          entryDate: returnDate, reference: 'RET-$returnId',
          lines: [
            {'account_code':'1200','debit':cost,'credit':0},
            {'account_code':'5000','debit':0,'credit':cost},
          ]);
      }
      await txn.update('returns', {'journal_entry_id':entryId}, where:'id=?', whereArgs:[returnId]);
      return returnId;
    });
  }

  Future<String> exportBackupJson() async {
    final db = await database;
    const tables = [
      'company_settings','accounts','contacts','products','journal_entries',
      'journal_lines','stock_movements','invoices','invoice_lines','vouchers',
      'returns','return_lines'
    ];
    final payload = <String, Object?>{
      'format': 'yemen-smart-accountant-backup',
      'version': 1,
      'exported_at': _now,
      'tables': <String, Object?>{},
    };
    final resultTables = payload['tables'] as Map<String, Object?>;
    for (final table in tables) {
      try {
        resultTables[table] = await db.query(table);
      } catch (_) {
        resultTables[table] = <Map<String, Object?>>[];
      }
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackupJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['format'] != 'yemen-smart-accountant-backup' ||
        decoded['version'] != 1 || decoded['tables'] is! Map) {
      throw const FormatException('ملف النسخة الاحتياطية غير معروف أو غير مدعوم');
    }
    final tables = decoded['tables'] as Map;
    const allowed = {
      'company_settings','accounts','contacts','products','journal_entries',
      'journal_lines','stock_movements','invoices','invoice_lines','vouchers',
      'returns','return_lines'
    };
    for (final key in tables.keys) {
      if (!allowed.contains(key)) throw FormatException('جدول غير مسموح: $key');
      if (tables[key] is! List) throw FormatException('بيانات الجدول غير صالحة: $key');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in [
        'return_lines','returns','invoice_lines','invoices','vouchers',
        'stock_movements','journal_lines','journal_entries','contacts',
        'products','company_settings','accounts'
      ]) {
        await txn.delete(table);
      }
      const insertOrder = [
        'company_settings','accounts','contacts','products','journal_entries',
        'journal_lines','stock_movements','invoices','invoice_lines','vouchers',
        'returns','return_lines'
      ];
      for (final table in insertOrder) {
        final rows = tables[table];
        if (rows == null) continue;
        for (final raw in rows as List) {
          if (raw is! Map) throw FormatException('سجل غير صالح في $table');
          final values = <String, Object?>{};
          raw.forEach((key, value) {
            if (key is String) values[key] = value;
          });
          await txn.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }


}
