import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app.dart';

void main() {
  testWidgets('Thaai Seyazhi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThaaiSeyazhiApp());

    expect(find.text('THAAI SEYAZHI'), findsOneWidget);
  });
}