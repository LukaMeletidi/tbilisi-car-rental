import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The "Hide this car?" dialog of the Cars list with the bookings ahead
/// (step 5.4). Every value is made up.
late FakeAdminAuthRepository auth;
late FakeFleetRepository fleet;
late FakeAdminBookingsRepository bookings;

Future<void> pumpList(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  fleet = FakeFleetRepository();
  bookings = FakeAdminBookingsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        fleetRepositoryProvider.overrideWithValue(fleet),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 16, 8)),
      ],
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
            ),
          ],
        ),
      ),
    ),
  );
  await settle(tester);
  fleet.emit([(id: 'a', data: rawCar())]);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A confirmed booking of car "a" from [from] to [to] October 2026, 10:00
/// UTC (14:00 in Tbilisi).
Booking ahead(String id, int from, int to) => Booking.fromMap(
  id,
  rawBooking(
    id,
    carId: 'a',
    fullName: 'Other Customer',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 10, from, 10),
    dropoff: DateTime.utc(2026, 10, to, 10),
  ).data,
);

Future<void> tapHide(WidgetTester tester) async {
  await tester.tap(find.text(adminCarHide));
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

void main() {
  testWidgets('bookings ahead: the periods in Tbilisi time, the note, no '
      'names; Cancel writes nothing', (tester) async {
    await pumpList(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [ahead('later', 20, 22), ahead('running', 15, 25)],
      unreadable: 0,
    );
    await tapHide(tester);

    expect(inDialog(find.text(adminHideCarTitle)), findsOneWidget);
    expect(inDialog(find.text(adminHideAheadIntro)), findsOneWidget);
    final periods = tester
        .widgetList<Text>(inDialog(find.textContaining(' – ')))
        .map((text) => text.data)
        .toList();
    expect(periods, [
      '15 Oct 2026 14:00 – 25 Oct 2026 14:00',
      '20 Oct 2026 14:00 – 22 Oct 2026 14:00',
    ]);
    expect(inDialog(find.text(adminTbilisiTimeNote)), findsOneWidget);
    expect(inDialog(find.text(adminHiddenCarNote)), findsOneWidget);
    expect(inDialog(find.textContaining('Customer')), findsNothing);
    expect(inDialog(find.textContaining('Test Person')), findsNothing);

    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(fleet.activeChanges, isEmpty);
  });

  testWidgets('nothing ahead: the dialog exactly as before Phase 5', (
    tester,
  ) async {
    await pumpList(tester);
    await tapHide(tester);
    expect(inDialog(find.text(adminHideCarTitle)), findsOneWidget);
    expect(inDialog(find.text(adminHiddenCarNote)), findsOneWidget);
    expect(inDialog(find.text(adminHideAheadIntro)), findsNothing);
    expect(inDialog(find.byType(Text)), findsNWidgets(4));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(adminCarHide),
      ),
    );
    await settle(tester);
    expect(fleet.activeChanges, [(id: 'a', active: false)]);
  });

  testWidgets('five ahead and one unreadable: three periods, "and 2 more", '
      'the unreadable line', (tester) async {
    await pumpList(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [for (var day = 17; day <= 21; day++) ahead('b$day', day, 28)],
      unreadable: 1,
    );
    await tapHide(tester);
    expect(inDialog(find.textContaining(' – ')), findsNWidgets(3));
    expect(inDialog(find.text(adminConflictMore(2))), findsOneWidget);
    expect(inDialog(find.text(adminHideUnreadable(1))), findsOneWidget);
  });

  testWidgets('could not be checked: its line and the note; Hide hides', (
    tester,
  ) async {
    await pumpList(tester);
    bookings.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.noConnection,
    );
    await tapHide(tester);
    expect(inDialog(find.text(adminHideUnchecked)), findsOneWidget);
    expect(inDialog(find.text(adminHiddenCarNote)), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(adminCarHide),
      ),
    );
    await settle(tester);
    expect(fleet.activeChanges, hasLength(1));
  });

  testWidgets('"Checking…" on the card while the read runs', (tester) async {
    await pumpList(tester);
    bookings.confirmedPending = Completer<void>();
    await tapHide(tester);
    expect(find.text(adminChecking), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    bookings.confirmedPending!.complete();
    await settle(tester);
    expect(find.text(adminChecking), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Show on a hidden car: no read, no dialog', (tester) async {
    await pumpList(tester);
    fleet.emit([(id: 'h', data: rawCar(active: false))]);
    await settle(tester);
    await tester.tap(find.text(adminCarShow));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.confirmedReads, isEmpty);
    expect(fleet.activeChanges, [(id: 'h', active: true)]);
  });

  testWidgets('320 px wide, the fullest dialog: nothing overflows', (
    tester,
  ) async {
    await pumpList(tester, size: const Size(320, 1400));
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [for (var day = 17; day <= 21; day++) ahead('b$day', day, 28)],
      unreadable: 2,
    );
    await tapHide(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
