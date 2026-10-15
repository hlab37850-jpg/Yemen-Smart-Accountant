import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yemen_smart_accountant/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Arabic accountant home screen renders', (tester) async {
    await tester.pumpWidget(const AccountantApp());
    await tester.pump();
    expect(find.text('المحاسب الذكي اليمني'), findsOneWidget);
  });
}
