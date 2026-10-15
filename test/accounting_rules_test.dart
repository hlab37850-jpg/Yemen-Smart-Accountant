import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_smart_accountant/domain/accounting_rules.dart';

void main() {
  group('Double-entry accounting rules', () {
    test('accepts equal debit and credit totals', () {
      expect(AccountingRules.isBalanced(const [
        JournalLineInput(accountId: 1, debit: 12500, credit: 0),
        JournalLineInput(accountId: 2, debit: 0, credit: 12500),
      ]), isTrue);
    });
    test('rejects unequal totals', () {
      expect(AccountingRules.isBalanced(const [
        JournalLineInput(accountId: 1, debit: 10000, credit: 0),
        JournalLineInput(accountId: 2, debit: 0, credit: 9000),
      ]), isFalse);
    });
    test('rejects a single line and debit plus credit on one line', () {
      expect(AccountingRules.isBalanced(const [
        JournalLineInput(accountId: 1, debit: 100, credit: 0),
      ]), isFalse);
      expect(AccountingRules.isBalanced(const [
        JournalLineInput(accountId: 1, debit: 100, credit: 100),
        JournalLineInput(accountId: 2, debit: 0, credit: 200),
      ]), isFalse);
    });
  });
  group('Minor currency units', () {
    test('converts decimal amounts', () {
      expect(AccountingRules.parseMinorUnits('12.50'), 1250);
      expect(AccountingRules.parseMinorUnits('1,200.75'), 120075);
    });
    test('rejects invalid and negative amounts', () {
      expect(() => AccountingRules.parseMinorUnits('abc'), throwsFormatException);
      expect(() => AccountingRules.parseMinorUnits('-2'), throwsFormatException);
    });
  });
}
