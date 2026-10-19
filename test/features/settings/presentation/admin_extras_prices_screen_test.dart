import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// Made-up sample prices; not the real ones.
ExtrasPrices prices({num snowChains = 7}) => ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': snowChains,
    'childSeat': 4.5,
    'infantSeat': 0,
    'boosterSeat': 3,
  },
});

late FakeSettingsRepository settings;

const settingsPage = 'the settings page';

Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
  ExtrasPrices? stored,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  settings = FakeSettingsRepository();
  final router = GoRouter(
    initialLocation: AppRoutes.adminSettingsExtras,
    routes: [
      GoRoute(
        path: AppRoutes.adminSettings,
        builder: (context, state) => const Scaffold(body: Text(settingsPage)),
        routes: [
          GoRoute(
            path: AppRoutes.adminSettingsExtrasPattern,
            builder: (context, state) => const AdminExtrasPricesScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (stored != null) {
    settings.emitExtras(stored);
    await tester.pump();
    await tester.pump();
  }
}

Finder field(Extra extra) => find.byKey(adminExtraPriceFieldKey(extra));

Finder get saveButton => find.widgetWithText(FilledButton, adminExtrasSave);

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(saveButton).onPressed != null;

Future<void> type(WidgetTester tester, Extra extra, String text) async {
  await tester.enterText(field(extra), text);
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  test('the age ranges are those of the public app (app_en.arb)', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(adminExtraAgeRange(Extra.snowChains), isNull);
    expect(adminExtraAgeRange(Extra.childSeat), arb['extraChildSeatAge']);
    expect(adminExtraAgeRange(Extra.infantSeat), arb['extraInfantSeatAge']);
    expect(adminExtraAgeRange(Extra.boosterSeat), arb['extraBoosterSeatAge']);
    expect(adminExtraName(Extra.childSeat), arb['extraChildSeat']);
    expect(adminExtraName(Extra.snowChains), arb['extraSnowChains']);
  });

  testWidgets('a spinner until the prices come', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(saveButton, findsNothing);
  });

  testWidgets('the four fields with names, ages and the stored prices', (
    tester,
  ) async {
    await pumpScreen(tester, stored: prices());
    expect(find.text(adminSettingsExtrasTitle), findsOneWidget);
    expect(find.text(adminExtrasNote), findsOneWidget);
    for (final (extra, label, text) in [
      (Extra.snowChains, 'Snow chains', '7'),
      (Extra.childSeat, 'Child seat (1–4 years)', '4.5'),
      (Extra.infantSeat, 'Infant seat (0–12 months)', '0'),
      (Extra.boosterSeat, 'Booster seat (3–16 years)', '3'),
    ]) {
      final widget = tester.widget<TextField>(field(extra));
      expect(widget.decoration!.labelText, label);
      expect(widget.controller!.text, text);
    }
    expect(saveEnabled(tester), false);
  });

  testWidgets('a change enables Save; the error shows after Save', (
    tester,
  ) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '100.01');
    expect(saveEnabled(tester), true);
    expect(
      find.text(adminExtraPriceProblemText(ExtraPriceProblem.tooHigh)),
      findsNothing,
    );

    await tester.tap(saveButton);
    await tester.pump();
    expect(
      find.text(adminExtraPriceProblemText(ExtraPriceProblem.tooHigh)),
      findsOneWidget,
    );
    expect(find.text(adminCorrectFields), findsOneWidget);
    expect(settings.extrasSaves, isEmpty);
  });

  testWidgets('saved: "Saved" and back to Settings', (tester) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');
    await tester.tap(saveButton);
    await settle(tester);

    expect(settings.extrasSaves.single.prices, prices(snowChains: 8));
    expect(find.text(adminExtrasSaved), findsOneWidget);
    expect(find.text(settingsPage), findsOneWidget);
  });

  testWidgets('while saving: locked, a spinner line, no Save', (tester) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');
    final gate = settings.writeGate = Completer<void>();
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text(adminSaving), findsOneWidget);
    expect(tester.widget<TextField>(field(Extra.snowChains)).enabled, false);
    expect(saveEnabled(tester), false);
    gate.complete();
    await settle(tester);
  });

  testWidgets('back with changes asks first; Keep editing stays, Discard '
      'leaves', (tester) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text(adminDiscardTitle), findsOneWidget);
    await tester.tap(find.text(adminKeepEditing));
    await settle(tester);
    expect(find.byType(AdminExtrasPricesScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text(adminDiscard));
    await settle(tester);
    expect(find.text(settingsPage), findsOneWidget);
    expect(settings.extrasSaves, isEmpty);
  });

  testWidgets('back without changes leaves without asking', (tester) async {
    await pumpScreen(tester, stored: prices());
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text(adminDiscardTitle), findsNothing);
    expect(find.text(settingsPage), findsOneWidget);
  });

  testWidgets('no answer: the text, "Save again" and "Load the current '
      'prices"; the fields are locked', (tester) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');
    settings.saveError = const SettingsWriteNoAnswer();
    await tester.tap(saveButton);
    await settle(tester);

    expect(
      find.text(adminExtrasSaveNoticeText(ExtrasSaveNotice.noAnswer)),
      findsOneWidget,
    );
    expect(find.text(adminSaveAgain), findsOneWidget);
    expect(find.text(adminLoadCurrentPrices), findsOneWidget);
    expect(saveButton, findsNothing);
    expect(tester.widget<TextField>(field(Extra.snowChains)).enabled, false);
  });

  testWidgets('a failed save shows its text and can be dismissed', (
    tester,
  ) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');
    settings.saveError = const SettingsWriteException(
      SettingsWriteFailure.noConnection,
    );
    await tester.tap(saveButton);
    await settle(tester);
    final text = adminExtrasSaveNoticeText(ExtrasSaveNotice.noConnection);
    expect(find.text(text), findsOneWidget);

    await tester.tap(find.byTooltip(adminDismissNotice));
    await tester.pump();
    expect(find.text(text), findsNothing);
  });

  testWidgets('changed elsewhere while editing: the banner and its button', (
    tester,
  ) async {
    await pumpScreen(tester, stored: prices());
    await type(tester, Extra.snowChains, '8');
    settings.emitExtras(prices(snowChains: 9));
    await tester.pump();
    expect(find.text(adminExtrasChangedElsewhereBanner), findsOneWidget);

    await tester.tap(find.text(adminLoadCurrentPrices));
    await tester.pump();
    expect(find.text(adminExtrasChangedElsewhereBanner), findsNothing);
    expect(
      tester.widget<TextField>(field(Extra.snowChains)).controller!.text,
      '9',
    );
  });

  testWidgets('no connection: the text with Try again and Back to Settings', (
    tester,
  ) async {
    await pumpScreen(tester);
    settings.failExtras(const NoServerAnswerException());
    await tester.pump();
    expect(
      find.text(adminExtrasFailureText(ExtrasLoadFailure.noConnection)),
      findsOneWidget,
    );
    expect(find.text(adminTryAgain), findsOneWidget);
    expect(find.text(adminBackToSettings), findsOneWidget);

    settings.emitExtras(prices());
    await tester.pump();
    expect(field(Extra.snowChains), findsOneWidget);
  });

  testWidgets('a broken document: the unreadable text', (tester) async {
    await pumpScreen(tester);
    settings.failExtras(const FormatException('broken'));
    await tester.pump();
    expect(find.text(adminExtrasUnreadable), findsOneWidget);
    expect(find.text(adminBackToSettings), findsOneWidget);
  });

  testWidgets('320 px wide: nothing overflows, also with every error', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(320, 640), stored: prices());
    for (final extra in Extra.values) {
      await type(tester, extra, 'abc');
    }
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();
    expect(
      find.text(adminExtraPriceProblemText(ExtraPriceProblem.invalid)),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });
}
