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
      version: 2,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (db, version) async {
        await _createBaseSchema(db);
        await _createAccountingSchema(db);
        await _seedAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAccountingSchema(db);
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
    await db.execute("CREATE TABLE vouchers (id INTEGER PRIMARY KEY AUTOINCREMENT, voucher_type TEXT NOT NULL CHECK(voucher_type IN ('receipt','payment')), voucher_date TEXT NOT NULL, contact_id INTEGER REFERENCES contacts(id), amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL DEFAULT 'cash', note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL)");
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
      {'code':'5000','name':'تكلفة البضاعة المباعة','type':'expense'},
      {'code':'6000','name':'المصروفات التشغيلية','type':'expense'},
    ];
    for (final account in defaults) {
      await db.insert('accounts', account, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
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

  Future<List<Map<String, Object?>>> contacts(String kind) async =>
      (await database).query('contacts', where: 'kind=?', whereArgs: [kind], orderBy: 'name COLLATE NOCASE');

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
    final db = await database;
    final values = {'name': name.trim(), 'sku': sku.trim(), 'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(), 'purchase_price': purchasePrice, 'sale_price': salePrice, 'quantity': quantity};
    if (id == null) {
      await db.insert('products', {...values, 'created_at': _now});
    } else {
      await db.update('products', values, where: 'id=?', whereArgs: [id]);
    }
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

  Future<List<Map<String, Object?>>> trialBalance() async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.code, a.name, a.type,
        COALESCE(SUM(l.debit),0) AS debit_total,
        COALESCE(SUM(l.credit),0) AS credit_total
      FROM accounts a LEFT JOIN journal_lines l ON l.account_code=a.code
      WHERE a.active=1
      GROUP BY a.code, a.name, a.type
      ORDER BY a.code
    ''');
  }
}
