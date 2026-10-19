import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_screen.dart';
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

  for (final page in [
    (
      const AdminExtrasPricesScreen(),
      adminSettingsExtrasTitle,
      adminSettingsExtrasDescription,
    ),
    (
      const AdminCompanyInfoScreen(),
      adminSettingsCompanyTitle,
      adminSettingsCompanyDescription,
    ),
  ]) {
    testWidgets('${page.$2}: a placeholder with nothing to change', (
      tester,
    ) async {
      await pumpScreen(tester, page.$1);

      expect(find.text(page.$2), findsOneWidget);
      expect(find.text(page.$3), findsOneWidget);
      expect(find.text(adminSettingsNotReady), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });
  }

  testWidgets('320 px wide: nothing overflows', (tester) async {
    for (final screen in const [
      AdminSettingsScreen(),
      AdminExtrasPricesScreen(),
      AdminCompanyInfoScreen(),
    ]) {
      await pumpScreen(tester, screen, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    }
  });
}
