import 'package:flutter_test/flutter_test.dart';
import 'package:inflow_web/app.dart';

void main() {
  testWidgets('InflowApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const InflowApp());
    expect(find.text('inFlow for Stellar'), findsOneWidget);
  });
}
