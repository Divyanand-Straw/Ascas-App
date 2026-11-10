import 'package:app/features/auth/presentation/login_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login explains that backend authentication is not integrated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in to continue your journey.'), findsOneWidget);
    expect(find.textContaining('No backend'), findsNothing);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(find.textContaining('123456'), findsNothing);

    await tester.ensureVisible(find.byType(ElevatedButton).first);
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();

    expect(find.text('No backend is integrated yet.'), findsOneWidget);
  });
}

Widget _loginApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const LoginScreen(),
);
