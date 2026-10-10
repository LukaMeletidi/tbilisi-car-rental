import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_sign_in_failure.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_login_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';

// Made-up values; no real account is used anywhere in the tests.
const testEmail = 'someone@example.com';
const testPassword = 'made-up-password-123';

late FakeAdminAuthRepository repository;

Future<void> pumpLogin(
  WidgetTester tester, {
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminAuthRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminLoginScreen(),
      ),
    ),
  );
  await settle(tester);
}

/// pumpAndSettle is not used: the spinner of the button never stops.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder emailField() => find.widgetWithText(TextField, adminEmailLabel);
Finder passwordField() => find.widgetWithText(TextField, adminPasswordLabel);
Finder signInButton() => find.widgetWithText(FilledButton, adminSignInButton);

String textOf(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

Future<void> fill(
  WidgetTester tester, {
  String email = testEmail,
  String password = testPassword,
}) async {
  await tester.enterText(emailField(), email);
  await tester.enterText(passwordField(), password);
  await settle(tester);
}

Future<void> tapSignIn(WidgetTester tester) async {
  await tester.tap(signInButton());
  await settle(tester);
}

void main() {
  setUp(() {
    repository = FakeAdminAuthRepository();
    addTearDown(repository.close);
  });

  testWidgets('shows the title, the two fields and the button', (tester) async {
    await pumpLogin(tester);

    expect(find.text(adminSignInTitle), findsOneWidget);
    expect(emailField(), findsOneWidget);
    expect(passwordField(), findsOneWidget);
    expect(signInButton(), findsOneWidget);
    expect(tester.widget<FilledButton>(signInButton()).onPressed, isNotNull);
    // No failure text at first.
    for (final failure in AdminSignInFailure.values) {
      expect(find.text(adminSignInFailureText(failure)), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the password is hidden; the eye button shows and hides it', (
    tester,
  ) async {
    await pumpLogin(tester);
    await fill(tester);

    expect(tester.widget<TextField>(passwordField()).obscureText, true);
    expect(tester.widget<TextField>(emailField()).obscureText, false);

    await tester.tap(find.byTooltip(adminShowPassword));
    await settle(tester);
    expect(tester.widget<TextField>(passwordField()).obscureText, false);

    await tester.tap(find.byTooltip(adminHidePassword));
    await settle(tester);
    expect(tester.widget<TextField>(passwordField()).obscureText, true);
  });

  testWidgets('the fields have autofill hints and the right keyboards', (
    tester,
  ) async {
    await pumpLogin(tester);

    final email = tester.widget<TextField>(emailField());
    expect(email.autofillHints, [AutofillHints.username]);
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.textInputAction, TextInputAction.next);
    expect(email.autocorrect, false);

    final password = tester.widget<TextField>(passwordField());
    expect(password.autofillHints, [AutofillHints.password]);
    expect(password.textInputAction, TextInputAction.done);
    expect(password.autocorrect, false);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('Sign in sends the trimmed e-mail and the password once', (
    tester,
  ) async {
    await pumpLogin(tester);
    await fill(tester, email: '  $testEmail ');

    await tapSignIn(tester);

    expect(repository.signIns, hasLength(1));
    expect(repository.signIns.single.email, testEmail);
    expect(repository.signIns.single.password, testPassword);
    // The password field is emptied after a successful sign-in.
    expect(textOf(tester, passwordField()), '');
  });

  testWidgets('empty fields: the text is shown and nothing is sent', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tapSignIn(tester);

    expect(
      find.text(adminSignInFailureText(AdminSignInFailure.missingInput)),
      findsOneWidget,
    );
    expect(repository.signIns, isEmpty);
  });

  testWidgets('an empty e-mail keeps the typed password', (tester) async {
    await pumpLogin(tester);
    await fill(tester, email: '');

    await tapSignIn(tester);

    expect(repository.signIns, isEmpty);
    // Nothing was sent, so there is no reason to make the admin retype it.
    expect(textOf(tester, passwordField()), testPassword);
  });

  for (final failure in AdminSignInFailure.values) {
    if (failure == AdminSignInFailure.missingInput) continue;
    testWidgets('${failure.name}: its text is shown, the password is cleared '
        'and the e-mail kept', (tester) async {
      await pumpLogin(tester);
      repository.error = AdminSignInException(failure);
      await fill(tester);

      await tapSignIn(tester);

      expect(find.text(adminSignInFailureText(failure)), findsOneWidget);
      expect(textOf(tester, passwordField()), '');
      expect(textOf(tester, emailField()), testEmail);
      // The button works again.
      expect(tester.widget<FilledButton>(signInButton()).onPressed, isNotNull);
    });
  }

  testWidgets('every failure has its own text, and none shows a code', (
    tester,
  ) async {
    final texts = {
      for (final failure in AdminSignInFailure.values)
        adminSignInFailureText(failure),
    };
    expect(texts, hasLength(AdminSignInFailure.values.length));
    const codes = [
      'invalid-credential',
      'wrong-password',
      'user-not-found',
      'invalid-email',
      'too-many-requests',
      'network-request-failed',
      'user-disabled',
    ];
    for (final text in texts) {
      for (final code in codes) {
        expect(text.contains(code), false, reason: '"$text" shows $code');
      }
      expect(text.toLowerCase().contains('firebase'), false, reason: text);
    }
  });

  testWidgets('a wrong e-mail and a wrong password give the same text', (
    tester,
  ) async {
    expect(
      adminSignInFailureText(adminSignInFailureFromCode('user-not-found')),
      adminSignInFailureText(adminSignInFailureFromCode('wrong-password')),
    );
  });

  testWidgets('while working: a spinner, disabled fields and button, and a '
      'second tap sends nothing', (tester) async {
    await pumpLogin(tester);
    repository.pending = Completer<void>();
    await fill(tester);

    await tapSignIn(tester);

    expect(find.text(adminSigningIn), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = find.widgetWithText(FilledButton, adminSigningIn);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.widget<TextField>(emailField()).enabled, false);
    expect(tester.widget<TextField>(passwordField()).enabled, false);

    await tester.tap(button, warnIfMissed: false);
    await settle(tester);
    expect(repository.signIns, hasLength(1));

    repository.pending!.complete();
    await settle(tester);
    expect(find.text(adminSigningIn), findsNothing);
    expect(signInButton(), findsOneWidget);
  });

  testWidgets('Done on the password field sends the form', (tester) async {
    await pumpLogin(tester);
    await fill(tester);

    await tester.tap(passwordField());
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(repository.signIns, hasLength(1));
  });

  testWidgets('Next on the e-mail field moves to the password', (tester) async {
    await pumpLogin(tester);

    await tester.tap(emailField());
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await settle(tester);

    expect(tester.widget<TextField>(passwordField()).focusNode!.hasFocus, true);
    expect(repository.signIns, isEmpty);
  });

  testWidgets('a new attempt after a failure can succeed', (tester) async {
    await pumpLogin(tester);
    repository.error = const AdminSignInException(
      AdminSignInFailure.wrongCredentials,
    );
    await fill(tester);
    await tapSignIn(tester);

    repository.error = null;
    await tester.enterText(passwordField(), testPassword);
    await tapSignIn(tester);

    expect(repository.signIns, hasLength(2));
    expect(
      find.text(adminSignInFailureText(AdminSignInFailure.wrongCredentials)),
      findsNothing,
    );
  });

  testWidgets('320 px wide: nothing overflows, with a long failure text', (
    tester,
  ) async {
    await pumpLogin(tester, size: const Size(320, 640));
    repository.error = const AdminSignInException(
      AdminSignInFailure.tooManyAttempts,
    );
    await fill(tester);
    await tapSignIn(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text(adminSignInFailureText(AdminSignInFailure.tooManyAttempts)),
      findsOneWidget,
    );
  });
}
