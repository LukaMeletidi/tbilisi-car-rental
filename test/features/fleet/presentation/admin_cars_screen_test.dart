import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_screen.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_card.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_fleet_repository.dart';

late FakeAdminAuthRepository auth;
late FakeFleetRepository fleet;

/// The clock of the tests; a test moves it to make time "pass".
DateTime now = DateTime.utc(2026, 10, 14, 12);

Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
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
      // A small router: the list, and a stand-in for the edit form at its
      // real address, so a tap on a card can be followed.
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: AppRoutes.adminCars,
          routes: [
            GoRoute(
              path: AppRoutes.adminCars,
              builder: (context, state) => const AdminCarsScreen(),
              routes: [
                GoRoute(
                  path: AppRoutes.adminCarEditPattern,
                  builder: (context, state) =>
                      Text('Edit form of ${state.pathParameters['carId']}'),
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
  List<FleetRawDocument> documents, {
  bool fromCache = false,
}) async {
  fleet.emit(documents, fromCache: fromCache);
  await settle(tester);
}

void main() {
  testWidgets('a spinner until the first answer', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(adminNoCars), findsNothing);
  });

  testWidgets('no cars, said by the server: "No cars yet."', (tester) async {
    await pumpScreen(tester);
    await emit(tester, const []);
    expect(find.text(adminNoCars), findsOneWidget);
  });

  testWidgets('no answer within 3 seconds: the connection text and Try '
      'again; the cars appear by themselves later', (tester) async {
    await pumpScreen(tester);
    await emit(tester, const [], fromCache: true);
    expect(find.text(adminNoCars), findsNothing);

    await tester.pump(serverAnswerWait);
    await settle(tester);
    expect(
      find.text('No connection. The cars could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text(adminTryAgain), findsOneWidget);

    await emit(tester, [(id: 'a', data: rawCar())]);
    expect(find.byType(AdminCarCard), findsOneWidget);
  });

  testWidgets('refused: its own text; Try again asks again', (tester) async {
    await pumpScreen(tester);
    fleet.fail(const FleetLoadException(FleetLoadFailure.permissionDenied));
    await settle(tester);
    expect(find.text(adminCarsNoAccess), findsOneWidget);

    await tester.tap(find.text(adminTryAgain));
    await settle(tester);
    expect(fleet.queries, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('another error: "Could not load the cars."', (tester) async {
    await pumpScreen(tester);
    fleet.fail(StateError('broken'));
    await settle(tester);
    expect(find.text(adminCarsLoadError), findsOneWidget);
    expect(find.text(adminTryAgain), findsOneWidget);
  });

  testWidgets('a card: brand and model, year, price, badges', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [
      (id: 'a', data: rawCar(brand: 'Kia', model: 'Rio')),
      (
        id: 'b',
        data: rawCar(
          brand: 'Audi',
          model: 'A4',
          active: false,
          change: (d) {
            d.remove('description');
            d['pricePerDay'] = 45.5;
          },
        ),
      ),
    ]);

    expect(find.text('Kia Rio'), findsOneWidget);
    expect(find.text('Audi A4'), findsOneWidget);
    expect(find.text('Year 2019'), findsNWidgets(2));
    expect(find.text('\$45 per day'), findsOneWidget);
    expect(find.text('\$45.50 per day'), findsOneWidget);
    expect(find.text(adminCarBadgeVisible), findsOneWidget);
    expect(find.text(adminCarBadgeHidden), findsOneWidget);
    expect(find.text(adminCarNeedsRepair), findsOneWidget);
    expect(
      find.text('2 cars: 1 visible, 1 hidden. 1 needs repair.'),
      findsOneWidget,
    );
    // The visible car comes first.
    final kia = tester.getTopLeft(find.text('Kia Rio')).dy;
    final audi = tester.getTopLeft(find.text('Audi A4')).dy;
    expect(kia, lessThan(audi));
  });

  testWidgets('an unreadable document: a warning and its short ID only', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [
      (id: 'abcdefghijkl', data: {'brand': 5}),
    ]);
    expect(find.text(adminCarUnreadable), findsOneWidget);
    expect(find.text('ID: abcdefgh…'), findsOneWidget);
    expect(find.text('2 cars: 0 visible, 0 hidden.'), findsNothing);
    expect(
      find.text('1 car: 0 visible, 0 hidden, 1 unreadable.'),
      findsOneWidget,
    );
  });

  testWidgets('a tap on a card opens the edit form of that car', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [(id: 'car-7', data: rawCar())]);
    await tester.tap(find.text('Honda Civic'));
    await settle(tester);
    expect(find.text('Edit form of car-7'), findsOneWidget);
  });

  testWidgets('an unreadable card cannot be tapped and has no button', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [
      (id: 'abcdefghijkl', data: {'brand': 5}),
    ]);
    final card = tester.widget<AppCard>(
      find.descendant(
        of: find.byType(AdminCarCard),
        matching: find.byType(AppCard),
      ),
    );
    expect(card.onTap, isNull);
    expect(find.text(adminCarHide), findsNothing);
    expect(find.text(adminCarShow), findsNothing);
  });

  group('hide and show', () {
    testWidgets('Hide asks first; Cancel changes nothing', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'a', data: rawCar())]);
      await tester.tap(find.text(adminCarHide));
      await settle(tester);
      expect(find.text(adminHideCarTitle), findsOneWidget);
      expect(find.text(adminHiddenCarNote), findsOneWidget);

      await tester.tap(find.text(adminCancel));
      await settle(tester);
      expect(fleet.activeChanges, isEmpty);
    });

    testWidgets('Hide, confirmed: active false, then a notice', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'a', data: rawCar())]);
      await tester.tap(find.text(adminCarHide));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(adminCarHide),
        ),
      );
      await settle(tester);
      expect(fleet.activeChanges, [(id: 'a', active: false)]);
      expect(find.text('The car is hidden.'), findsOneWidget);
    });

    testWidgets('Show on a hidden car: at once, without a question', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'h', data: rawCar(active: false))]);
      await tester.tap(find.text(adminCarShow));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fleet.activeChanges, [(id: 'h', active: true)]);
      expect(find.text('The car is visible.'), findsOneWidget);
    });

    testWidgets('while it runs: a spinner instead of the button, and the '
        'card cannot be opened', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'h', data: rawCar(active: false))]);
      fleet.writeGate = Completer<void>();
      await tester.tap(find.text(adminCarShow));
      await settle(tester);
      expect(find.text(adminCarShow), findsNothing);
      await tester.tap(find.text('Honda Civic'));
      await settle(tester);
      expect(find.textContaining('Edit form'), findsNothing);

      fleet.writeGate!.complete();
      await settle(tester);
      expect(find.text(adminCarShow), findsOneWidget);
    });

    testWidgets('no answer: says that the list will show the real state', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'h', data: rawCar(active: false))]);
      fleet.setActiveError = const CarWriteNoAnswer();
      await tester.tap(find.text(adminCarShow));
      await settle(tester);
      expect(
        find.text(adminCarActiveNoticeText(CarActiveNotice.noAnswer)),
        findsOneWidget,
      );
    });

    testWidgets('refused: "Not changed"', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [(id: 'h', data: rawCar(active: false))]);
      fleet.setActiveError = const CarWriteException(CarWriteFailure.refused);
      await tester.tap(find.text(adminCarShow));
      await settle(tester);
      expect(find.text('Not changed. The server refused it.'), findsOneWidget);
    });
  });

  testWidgets('the offline note after 3 seconds of data from memory', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [(id: 'a', data: rawCar())], fromCache: true);
    expect(find.text(adminOfflineNote), findsNothing);
    now = now.add(serverAnswerWait);
    await tester.pump(serverAnswerWait);
    await settle(tester);
    expect(find.text(adminOfflineNote), findsOneWidget);

    await emit(tester, [(id: 'a', data: rawCar())]);
    expect(find.text(adminOfflineNote), findsNothing);
  });

  testWidgets('320 px wide: nothing overflows', (tester) async {
    await pumpScreen(tester, size: const Size(320, 900));
    await emit(tester, [
      (
        id: 'a',
        data: rawCar(
          brand: 'Mercedes-Benz',
          model: 'Sprinter Long',
          active: false,
          change: (d) => d.remove('description'),
        ),
      ),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1200 px wide: one centred column, at most carDetailMaxWidth', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(1200, 900));
    await emit(tester, [(id: 'a', data: rawCar())]);
    final card = tester.getRect(find.byType(AdminCarCard));
    expect(card.width, lessThanOrEqualTo(carDetailMaxWidth));
    expect(card.center.dx, moreOrLessEquals(600, epsilon: 1));
  });

  testWidgets('the photo is a small square', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [(id: 'a', data: rawCar())]);
    final photo = tester.getSize(
      find.descendant(
        of: find.byType(AdminCarCard),
        matching: find.byType(CarPhoto),
      ),
    );
    expect(photo, const Size.square(adminCarPhotoSize));
  });

  testWidgets('Sign out closes the cars listener first', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [(id: 'a', data: rawCar())]);
    expect(fleet.activeListeners, 1);

    await tester.tap(find.byTooltip(adminSignOutButton));
    await settle(tester);

    expect(auth.signOuts, 1);
    expect(fleet.activeListeners, 0);
  });

  group('the count line', () {
    test('plural, singular and none', () {
      expect(
        adminFleetCounts(
          const FleetCounts(
            visible: 6,
            hidden: 1,
            needRepair: 6,
            unreadable: 0,
          ),
        ),
        '7 cars: 6 visible, 1 hidden. 6 need repair.',
      );
      expect(
        adminFleetCounts(
          const FleetCounts(
            visible: 1,
            hidden: 1,
            needRepair: 1,
            unreadable: 0,
          ),
        ),
        '2 cars: 1 visible, 1 hidden. 1 needs repair.',
      );
      expect(
        adminFleetCounts(
          const FleetCounts(
            visible: 1,
            hidden: 0,
            needRepair: 0,
            unreadable: 0,
          ),
        ),
        '1 car: 1 visible, 0 hidden.',
      );
    });
  });
}
