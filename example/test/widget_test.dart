import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const SessionExampleApp());
    expect(find.text('Synheart Session'), findsOneWidget);
  });
}
