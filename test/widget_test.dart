import 'package:flutter_test/flutter_test.dart';
import 'package:photoforge_studio/main.dart';

void main() {
  testWidgets('PhotoForge Studio app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoForgeApp());

    expect(find.text('PhotoForge'), findsOneWidget);
    expect(find.text('Professional Photo Studio'), findsOneWidget);
  });
}
