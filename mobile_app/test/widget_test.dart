import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LanMusicApp());
    expect(find.byType(LanMusicApp), findsOneWidget);
  });
}
