import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_settings_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminAuthRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the Settings page shows its two entries with their lines', (
    tester,
  ) async {
    await pumpScreen(tester, const AdminSettingsScreen());

    expect(find.text(adminSettingsTitle), findsOneWidget);
    for (final entry in [
      (
        adminSettingsExtrasKey,
        adminSettingsExtrasTitle,
        adminSettingsExtrasDescription,
      ),
      (
        adminSettingsCompanyKey,
        adminSettingsCompanyTitle,
        adminSettingsCompanyDescription,
      ),
    ]) {
      final card = find.byKey(entry.$1);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(entry.$2)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(entry.$3)),
        findsOneWidget,
      );
    }
    expect(find.byTooltip(adminSignOutButton), findsOneWidget);
  });

  // The two pages below Settings are real forms since steps 6.6 and 6.7;
  // their tests are in admin_extras_prices_screen_test.dart and
  // admin_company_info_screen_test.dart.

  testWidgets('320 px wide: nothing overflows', (tester) async {
    await pumpScreen(
      tester,
      const AdminSettingsScreen(),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
