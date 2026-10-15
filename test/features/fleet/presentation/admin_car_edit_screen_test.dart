import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

const carId = 'car-1';
const listText = 'The fleet list';

late FakeAdminAuthRepository auth;
late FakeFleetRepository fleet;
DateTime now = DateTime.utc(2026, 10, 14, 12);

/// The edit form at its real address, with a stand-in for the list below
/// it, so Back and a successful save can be followed.
Future<void> pumpEdit(
  WidgetTester tester, {
  Size size = const Size(800, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  fleet = FakeFleetRepository();
  now = DateTime.utc(2026, 10, 14, 12);
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        fleetRepositoryProvider.overrideWithValue(fleet),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: AppRoutes.adminCarEdit(carId),
          routes: [
            GoRoute(
              path: AppRoutes.adminCars,
              builder: (context, state) => const Scaffold(body: Text(listText)),
              routes: [
                GoRoute(
                  path: AppRoutes.adminCarEditPattern,
                  builder: (context, state) =>
                      AdminCarEditScreen(carId: state.pathParameters['carId']!),
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

/// pumpAndSettle is not used: a spinner never stops animating.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> emit(
  WidgetTester tester,
  Map<String, dynamic>? data, {
  bool fromCache = false,
}) async {
  fleet.emitCar(carId, data, fromCache: fromCache);
  await settle(tester);
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> type(WidgetTester tester, String label, String text) async {
  await tester.enterText(field(label), text);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await settle(tester);
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, adminSave));

void main() {
  group('the states', () {
    testWidgets('a spinner until the car arrives', (tester) async {
      await pumpEdit(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('missing: its text and the way back', (tester) async {
      await pumpEdit(tester);
      await emit(tester, null);
      expect(find.text(adminCarMissing), findsOneWidget);
      await tapText(tester, adminBackToCars);
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('unreadable: its text', (tester) async {
      await pumpEdit(tester);
      await emit(tester, {'brand': 5});
      expect(find.text(adminCarUnreadableText), findsOneWidget);
    });

    testWidgets('no answer within 3 s: "No connection" and Try again', (
      tester,
    ) async {
      await pumpEdit(tester);
      await emit(tester, null, fromCache: true);
      await tester.pump(serverAnswerWait);
      await settle(tester);
      expect(
        find.text('No connection. The car could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text(adminTryAgain), findsOneWidget);
    });
  });

  group('the form', () {
    testWidgets('every field holds the stored value', (tester) async {
      await pumpEdit(tester);
      await emit(
        tester,
        rawCar(change: (d) => d['photos'] = ['https://a.example/1.jpg']),
      );
      expect(find.text(adminCarEditTitle), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('Civic'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('FWD'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('1.8'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('ქართული'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('https://a.example/1.jpg'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(find.text(adminCarRepairNote), findsNothing);
    });

    testWidgets('a complete car without a change: Save is disabled', (
      tester,
    ) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      expect(saveButton(tester).onPressed, isNull);
      await type(tester, adminCarLabelSeats, '4');
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('a car without descriptions: the repair note and the errors '
        'at once; Save can be pressed', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar(change: (d) => d.remove('description')));
      expect(find.text(adminCarRepairNote), findsOneWidget);
      expect(
        find.text(adminCarErrorText(CarError.descriptionKaRequired)),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('errors appear only after Save', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelBrand, '');
      final error = adminCarErrorText(CarError.brandRequired);
      expect(find.text(error), findsNothing);

      await tapText(tester, adminSave);
      expect(find.text(error), findsOneWidget);
      expect(find.text(adminCorrectFields), findsOneWidget);
      expect(fleet.replaced, isEmpty);
    });

    testWidgets('photo rows: add, check, move and remove', (tester) async {
      await pumpEdit(tester);
      await emit(
        tester,
        rawCar(change: (d) => d['photos'] = ['https://a.example/1.jpg']),
      );
      await tapText(tester, adminCarAddPhoto);
      await type(tester, adminCarPhotoLabel(1), 'http://b.example/2.jpg');
      await tapText(tester, adminSave);
      expect(
        find.text(adminCarPhotoErrorText(CarPhotoError.notHttps)),
        findsOneWidget,
      );

      // Move the second row up: it becomes the first.
      await tester.tap(find.byTooltip(adminCarMovePhotoUp).at(1));
      await settle(tester);
      final first = tester.widget<TextField>(field(adminCarPhotoLabel(0)));
      expect(first.controller!.text, 'http://b.example/2.jpg');

      await tester.tap(find.byTooltip(adminCarRemovePhoto).first);
      await settle(tester);
      expect(find.text('http://b.example/2.jpg'), findsNothing);
      expect(find.text('https://a.example/1.jpg'), findsOneWidget);
    });

    testWidgets('at most $carMaxPhotos photo rows', (tester) async {
      await pumpEdit(tester);
      await emit(
        tester,
        rawCar(
          change: (d) => d['photos'] = [
            for (var i = 0; i < carMaxPhotos; i++) 'https://a.example/$i',
          ],
        ),
      );
      final add = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(adminCarAddPhoto),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(add.onPressed, isNull);
    });
  });

  group('save', () {
    testWidgets('saved: back to the list with "Saved"', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      await tapText(tester, adminSave);
      expect(fleet.replaced.single.car.seats, 4);
      expect(find.text(listText), findsOneWidget);
      expect(find.text(adminCarSaved), findsOneWidget);
    });

    testWidgets('while it runs: "Saving…", the fields and Save locked, and '
        'Back does nothing', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      fleet.writeGate = Completer<void>();
      await tapText(tester, adminSave);
      expect(find.text(adminSaving), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(
        tester.widget<TextField>(field(adminCarLabelBrand)).enabled,
        false,
      );

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(listText), findsNothing);

      fleet.writeGate!.complete();
      await settle(tester);
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('no answer: the fields locked, "Save again" and "Load the '
        'current car"', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      fleet.replaceError = const CarWriteNoAnswer();
      await tapText(tester, adminSave);

      expect(
        find.text(adminCarSaveNoticeText(CarSaveNotice.noAnswer)),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, adminSave), findsNothing);
      expect(
        tester.widget<TextField>(field(adminCarLabelSeats)).enabled,
        false,
      );

      fleet.replaceError = null;
      await tapText(tester, adminSaveAgain);
      expect(fleet.replaced, hasLength(2));
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('no answer, then "Load the current car": the stored values, '
        'unlocked', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      fleet.replaceError = const CarWriteNoAnswer();
      await tapText(tester, adminSave);
      await tapText(tester, adminLoadCurrentCar);
      expect(
        tester.widget<TextField>(field(adminCarLabelSeats)).controller!.text,
        '5',
      );
      expect(tester.widget<TextField>(field(adminCarLabelSeats)).enabled, true);
    });

    testWidgets('changed elsewhere: its notice; "Load the current car" '
        'shows the stored car', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelModel, 'Accord');
      await emit(tester, rawCar(change: (d) => d['seats'] = 3));
      expect(find.text(adminCarChangedElsewhereBanner), findsOneWidget);

      fleet.replaceError = const CarWriteException(
        CarWriteFailure.changedElsewhere,
      );
      await tapText(tester, adminSave);
      expect(
        find.text(adminCarSaveNoticeText(CarSaveNotice.changedElsewhere)),
        findsOneWidget,
      );
      await tapText(tester, adminLoadCurrentCar);
      expect(find.text('Accord'), findsNothing);
      expect(
        tester.widget<TextField>(field(adminCarLabelSeats)).controller!.text,
        '3',
      );
    });

    testWidgets('hiding through the switch asks first; Cancel sends '
        'nothing, Hide saves', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await settle(tester);
      await tapText(tester, adminSave);
      expect(find.text(adminHideCarTitle), findsOneWidget);

      await tester.tap(find.text(adminCancel));
      await settle(tester);
      expect(fleet.replaced, isEmpty);

      await tapText(tester, adminSave);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(adminCarHide),
        ),
      );
      await settle(tester);
      expect(fleet.replaced.single.car.active, false);
    });
  });

  group('leaving', () {
    testWidgets('the back arrow with changes: "Discard your changes?"', (
      tester,
    ) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);

      await tester.tap(find.text(adminKeepEditing));
      // The closing dialog still covers the page for a moment.
      await tester.pumpAndSettle();
      expect(find.text(listText), findsNothing);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);
      await tester.tap(find.text(adminDiscard));
      await tester.pumpAndSettle();
      expect(find.text(listText), findsOneWidget);
    });

    testWidgets('the system Back with changes asks too', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await type(tester, adminCarLabelSeats, '4');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(adminDiscardTitle), findsOneWidget);
    });

    testWidgets('without changes: back at once, no question', (tester) async {
      await pumpEdit(tester);
      await emit(tester, rawCar());
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(listText), findsOneWidget);
    });
  });

  testWidgets('320 px wide, errors and the notice shown: nothing overflows', (
    tester,
  ) async {
    await pumpEdit(tester, size: const Size(320, 3000));
    await emit(
      tester,
      rawCar(
        change: (d) {
          d.remove('description');
          d['photos'] = ['https://a.example/1.jpg', 'https://a.example/2'];
        },
      ),
    );
    fleet.replaceError = const CarWriteNoAnswer();
    await type(tester, adminCarLabelDescriptionKa, 'ka');
    await type(tester, adminCarLabelDescriptionRu, 'ru');
    await type(tester, adminCarLabelDescriptionEn, 'en');
    await tapText(tester, adminSave);
    expect(tester.takeException(), isNull);
  });
}
