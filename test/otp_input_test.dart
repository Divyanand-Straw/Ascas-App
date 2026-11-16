import 'package:app/core/widgets/otp_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OTP input distributes pasted digits and deletes backwards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OtpInput(fieldKeyPrefix: 'otp-test')),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('otp-test-0')), '123456');
    await tester.pump();

    for (var index = 0; index < 6; index++) {
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('otp-test-$index')))
            .controller
            ?.text,
        '${index + 1}',
      );
    }

    await tester.tap(find.byKey(const ValueKey('otp-test-5')));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('otp-test-5')))
          .controller
          ?.text,
      '',
    );

    for (var count = 0; count < 5; count++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
    }

    for (var index = 0; index < 6; index++) {
      expect(
        tester
            .widget<TextField>(find.byKey(ValueKey('otp-test-$index')))
            .controller
            ?.text,
        '',
      );
    }
  });
}
