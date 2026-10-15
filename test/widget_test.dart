import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_smart_accountant/main.dart';

void main() {
  testWidgets('Arabic accountant home screen renders', (tester) async {
    await tester.pumpWidget(const AccountantApp());
    await tester.pump();
    expect(find.text('المحاسب الذكي اليمني'), findsOneWidget);
  });
}
