import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

const listText = 'The fleet list';

late FakeAdminAuthRepository auth;
late FakeFleetRepository fleet;

/// The "new car" form at its real address, with a stand-in for the list
/// below it, so Back and a successful save can be followed.
Future<void> pumpNew(
  WidgetTester tester, {
  Size size = const Size(800, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  fleet = FakeFleetRepository();
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        fleetRepositoryProvider.overrideWithValue(fleet),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 14, 12)),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: AppRoutes.adminCarNew,
          routes: [
            GoRoute(
              path: AppRoutes.adminCars,
              builder: (context, state) => const Scaffold(body: Text(listText)),
              routes: [
                GoRoute(
                  path: AppRoutes.adminCarNewPattern,
                  builder: (context, state) => const AdminCarNewScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
}

/// pumpAndSettle is not used while a spinner may run.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String item) async {
  await tapText(tester, label);
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

/// Fills every required field with made-up values.
Future<void> fillValid(WidgetTester tester) async {
  await type(tester, adminCarLabelBrand, 'Kia');
  await type(tester, adminCarLabelModel, 'Rio');
  await type(tester, adminCarLabelYear, '2020');
  await choose(tester, adminCarLabelDrivetrain, 'FWD');
  await choose(tester, adminCarLabelTransmission, 'Manual');
  await choose(tester, adminCarLabelFuelType, 'Diesel');
  await type(tester, adminCarLabelSeats, '5');
  await type(tester, adminCarLabelPrice, '40');
  await type(tester, adminCarLabelDescriptionKa, 'ka text');
  await type(tester, adminCarLabelDescriptionRu, 'ru text');
  await type(tester, adminCarLabelDescriptionEn, 'en text');
}

FilledButton? saveButton(WidgetTester tester) {
  final finder = find.widgetWithText(FilledButton, adminSave);
  return finder.evaluate().isEmpty ? null : tester.widget(finder);
}

void main() {
  testWidgets('an empty form, hidden, with Save enabled', (tester) async {
    await pumpNew(tester);
    expect(find.text(adminNewCarTitle), findsOneWidget);
    expect(find.text(adminNewCarVisibilityNote), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    expect(
      tester.widget<TextField>(field(adminCarLabelBrand)).controller!.text,
      '',
    );
    expect(saveButton(tester)!.onPressed, isNotNull);
  });

  testWidgets('Save on the empty form shows every error', (tester) async {
    await pumpNew(tester);
    await tapText(tester, adminSave);
    for (final error in [
      CarError.brandRequired,
      CarError.modelRequired,
      CarError.yearRequired,
      CarError.drivetrainRequired,
      CarError.transmissionRequired,
      CarError.fuelTypeRequired,
      CarError.seatsRequired,
      CarError.priceRequired,
      CarError.descriptionKaRequired,
      CarError.descriptionRuRequired,
      CarError.descriptionEnRequired,
    ]) {
      expect(
        find.text(adminCarErrorText(error)),
        findsOneWidget,
        reason: error.name,
      );
    }
    expect(find.text(adminCorrectFields), findsOneWidget);
    expect(fleet.created, isEmpty);
  });

  testWidgets('a hidden car is saved: back to the list with the "hidden" '
      'message', (tester) async {
    await pumpNew(tester);
    await fillValid(tester);
    await tapText(tester, adminSave);
    final car = fleet.created.single;
    expect(car.id, 'new-1');
    expect(car.brand, 'Kia');
    expect(car.active, false);
    expect(find.text(listText), findsOneWidget);
    expect(find.text(adminNewCarSavedHidden), findsOneWidget);
  });

  testWidgets('the switch on: saved visible, "Saved."', (tester) async {
    await pumpNew(tester);
    await fillValid(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    await tapText(tester, adminSave);
    expect(find.byType(AlertDialog), findsNothing);
    expect(fleet.created.single.active, true);
    expect(find.text(adminNewCarSavedVisible), findsOneWidget);
  });

  testWidgets('while it runs: "Saving…", locked, Back does nothing', (
    tester,
  ) async {
    await pumpNew(tester);
    await fillValid(tester);
    fleet.writeGate = Completer<void>();
    final save = find.text(adminSave);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(find.text(adminSaving), findsOneWidget);
    expect(saveButton(tester)!.onPressed, isNull);
    expect(tester.widget<TextField>(field(adminCarLabelBrand)).enabled, false);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);

    fleet.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(listText), findsOneWidget);
  });

  for (final (name, error, notice) in [
    ('no answer', const CarWriteNoAnswer(), CarCreateNotice.noAnswer),
    (
      'an unknown failure',
      const CarWriteException(CarWriteFailure.unknown),
      CarCreateNotice.unknown,
    ),
  ]) {
    testWidgets('$name: the note, the fields locked, "Check again" instead '
        'of Save; Check again sends the same car', (tester) async {
      await pumpNew(tester);
      await fillValid(tester);
      fleet.createError = error;
      await tapText(tester, adminSave);

      expect(find.text(adminCarCreateNoticeText(notice)), findsOneWidget);
      expect(saveButton(tester), isNull);
      expect(
        tester.widget<TextField>(field(adminCarLabelBrand)).enabled,
        false,
      );

      fleet.createError = null;
      fleet.createResult = CarCreateResult.alreadyCreated;
      await tapText(tester, adminCheckAgain);
      expect(fleet.created, hasLength(2));
      expect(fleet.created[1], fleet.created[0]);
      expect(find.text(listText), findsOneWidget);
    });
  }

  testWidgets('no connection: its note; the fields stay editable', (
    tester,
  ) async {
    await pumpNew(tester);
    await fillValid(tester);
    fleet.createError = const CarWriteException(CarWriteFailure.noConnection);
    await tapText(tester, adminSave);
    expect(
      find.text(adminCarCreateNoticeText(CarCreateNotice.noConnection)),
      findsOneWidget,
    );
    expect(saveButton(tester)!.onPressed, isNotNull);
    expect(tester.widget<TextField>(field(adminCarLabelBrand)).enabled, true);
  });

  group('leaving', () {
    testWidgets('an empty form: back at once', (tester) async {
      await pumpNew(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('with a typed field: "Discard your changes?" on the arrow '
        'and on the system Back', (tester) async {
      await pumpNew(tester);
      await type(tester, adminCarLabelBrand, 'Kia');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(adminDiscardTitle), findsOneWidget);
      await tester.tap(find.text(adminKeepEditing));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(adminDiscardTitle), findsOneWidget);
      await tester.tap(find.text(adminDiscard));
      await tester.pumpAndSettle();
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('after "No answer": "Leave this form?" with the note', (
      tester,
    ) async {
      await pumpNew(tester);
      await fillValid(tester);
      fleet.createError = const CarWriteNoAnswer();
      await tapText(tester, adminSave);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(adminLeaveTitle), findsOneWidget);
      expect(find.text(adminCarMayExistText), findsOneWidget);
      await tester.tap(find.text(adminStay));
      await tester.pumpAndSettle();
      expect(find.text(listText), findsNothing);
    });
  });

  testWidgets('320 px wide with every error: nothing overflows', (
    tester,
  ) async {
    await pumpNew(tester, size: const Size(320, 3200));
    await tapText(tester, adminSave);
    expect(tester.takeException(), isNull);
  });
}
