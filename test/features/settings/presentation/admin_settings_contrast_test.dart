import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_screen.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_settings_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  // The Extras & Prices form reads the prices (step 6.6).
  final settings = FakeSettingsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
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
  if (screen is AdminExtrasPricesScreen) {
    // Made-up sample prices; not the real ones.
    settings.emitExtras(
      ExtrasPrices.fromMap({
        'pricesPerDay': {
          'snowChains': 7,
          'childSeat': 4.5,
          'infantSeat': 0,
          'boosterSeat': 3,
        },
      }),
    );
    await tester.pump();
    await tester.pump();
  }
}

/// Every text drawn on a white card of the screen is readable: its colour,
/// as it is really painted, has a contrast of at least 4.5 with the colour
/// of the card (the WCAG level for normal text).
void expectReadableCards(WidgetTester tester) {
  final cards = find.byType(Card);
  expect(cards, findsWidgets);
  for (final card in cards.evaluate()) {
    final material = find
        .descendant(
          of: find.byWidget(card.widget),
          matching: find.byType(Material),
        )
        .first;
    final background = tester.widget<Material>(material).color!;
    final paragraphs = find.descendant(
      of: find.byWidget(card.widget),
      matching: find.byType(RichText),
    );
    expect(paragraphs, findsWidgets);
    for (final element in paragraphs.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final color = paragraph.text.style!.color!;
      expect(
        contrast(color, background),
        greaterThanOrEqualTo(4.5),
        reason: '"${paragraph.text.toPlainText()}" is $color on $background',
      );
    }
  }
}

void main() {
  for (final screen in const <(String, Widget)>[
    ('the Settings page', AdminSettingsScreen()),
    ('Extras & Prices', AdminExtrasPricesScreen()),
    ('Company Info', AdminCompanyInfoScreen()),
  ]) {
    testWidgets('${screen.$1}: the text on every card is readable', (
      tester,
    ) async {
      await pumpScreen(tester, screen.$2);
      expectReadableCards(tester);
    });
  }

  testWidgets('Extras & Prices with every error shown: still readable', (
    tester,
  ) async {
    await pumpScreen(tester, const AdminExtrasPricesScreen());
    for (final extra in Extra.values) {
      await tester.enterText(find.byKey(adminExtraPriceFieldKey(extra)), 'x');
    }
    await tester.pump();
    final save = find.widgetWithText(FilledButton, adminExtrasSave);
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(
      find.text(adminExtraPriceProblemText(ExtraPriceProblem.invalid)),
      findsNWidgets(Extra.values.length),
    );
    expectReadableCards(tester);
  });

  testWidgets('a card that is pressed keeps its text readable', (tester) async {
    await pumpScreen(tester, const AdminSettingsScreen());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(adminSettingsExtrasKey)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expectReadableCards(tester);
    // Cancelled, not released: a release would open the page, and this
    // test has no router.
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
