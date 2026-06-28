import 'package:flutter_test/flutter_test.dart';
import 'package:horus_app/app.dart';

void main() {
  testWidgets('Horus app renders rescue screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HorusApp());
    expect(find.text('HORUS'), findsOneWidget);
  });
}
