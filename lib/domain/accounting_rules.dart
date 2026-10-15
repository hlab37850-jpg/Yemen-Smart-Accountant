class JournalLineInput {
  const JournalLineInput({required this.accountId, required this.debit, required this.credit});
  final int accountId;
  final int debit;
  final int credit;
}

class AccountingRules {
  AccountingRules._();

  static bool isBalanced(List<JournalLineInput> lines) {
    if (lines.length < 2) return false;
    if (lines.any((x) => x.accountId <= 0 || x.debit < 0 || x.credit < 0 || (x.debit > 0 && x.credit > 0))) return false;
    final debit = lines.fold<int>(0, (sum, x) => sum + x.debit);
    final credit = lines.fold<int>(0, (sum, x) => sum + x.credit);
    return debit > 0 && debit == credit;
  }

  static int parseMinorUnits(String input) {
    final value = double.tryParse(input.trim().replaceAll(',', ''));
    if (value == null || !value.isFinite || value < 0) throw const FormatException('المبلغ غير صالح');
    return (value * 100).round();
  }
}
