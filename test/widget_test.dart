import 'package:flutter_test/flutter_test.dart';
import 'package:rentflow/main.dart';

void main() {
  testWidgets('RentFlow app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const RentFlowApp());
    expect(find.text('RentFlow'), findsOneWidget);
  });
}
