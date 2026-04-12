import 'package:flutter_test/flutter_test.dart';
import 'package:elysium_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ElysiumApp());
    expect(find.byType(ElysiumApp), findsOneWidget);
  });
}
