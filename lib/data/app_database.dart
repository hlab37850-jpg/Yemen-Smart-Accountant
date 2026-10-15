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
      version: 1,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (db, version) async {
        await db.execute("CREATE TABLE company_settings (id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '', currency TEXT NOT NULL DEFAULT 'ر.ي')");
        await db.execute("CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL CHECK(kind IN ('customer','supplier')), opening_balance INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)");
        await db.execute('CREATE INDEX idx_contacts_kind ON contacts(kind)');
        await db.execute("CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, sku TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT 'قطعة', purchase_price INTEGER NOT NULL DEFAULT 0 CHECK(purchase_price>=0), sale_price INTEGER NOT NULL DEFAULT 0 CHECK(sale_price>=0), quantity REAL NOT NULL DEFAULT 0 CHECK(quantity>=0), created_at TEXT NOT NULL)");
        await db.execute("CREATE TABLE journal_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_date TEXT NOT NULL, description TEXT NOT NULL, reference TEXT NOT NULL DEFAULT '', posted INTEGER NOT NULL DEFAULT 0 CHECK(posted IN (0,1)), created_at TEXT NOT NULL)");
        await db.execute('CREATE TABLE journal_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE, account_code TEXT NOT NULL, account_name TEXT NOT NULL, debit INTEGER NOT NULL DEFAULT 0 CHECK(debit>=0), credit INTEGER NOT NULL DEFAULT 0 CHECK(credit>=0), CHECK(debit=0 OR credit=0))');
        await db.execute('CREATE TABLE stock_movements (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL REFERENCES products(id), movement_date TEXT NOT NULL, movement_type TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity!=0), note TEXT NOT NULL DEFAULT "")');
        await db.execute("CREATE TABLE vouchers (id INTEGER PRIMARY KEY AUTOINCREMENT, voucher_type TEXT NOT NULL CHECK(voucher_type IN ('receipt','payment')), voucher_date TEXT NOT NULL, contact_id INTEGER REFERENCES contacts(id), amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL DEFAULT 'cash', note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL)");
      },
    );
    return _db!;
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
}
