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
