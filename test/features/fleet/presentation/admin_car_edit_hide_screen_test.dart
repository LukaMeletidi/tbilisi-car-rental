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
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// The Visible switch of the edit form with the bookings ahead (step 5.4).
/// Every value is made up.
const carId = 'car-1';
const listText = 'The fleet list';

late FakeAdminAuthRepository auth;
late FakeFleetRepository fleet;
late FakeAdminBookingsRepository bookings;

Future<void> pumpEdit(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
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
  fleet.emitCar(carId, rawCar());
  await settle(tester);
  await tester.ensureVisible(find.byType(SwitchListTile));
  await tester.tap(find.byType(SwitchListTile));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, adminSave);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

void bookingAhead() => bookings.confirmedAnswer = ConfirmedBookingsChecked(
  bookings: [
    Booking.fromMap(
      'ahead',
      rawBooking(
        'ahead',
        status: 'confirmed',
        pickup: DateTime.utc(2026, 10, 20, 10),
        dropoff: DateTime.utc(2026, 10, 22, 10),
      ).data,
    ),
  ],
  unreadable: 0,
);

void main() {
  testWidgets('the switch off, Save: the dialog with the booking ahead; '
      'Cancel keeps the switch off and saves nothing', (tester) async {
    await pumpEdit(tester);
    bookingAhead();
    await tapSave(tester);
    expect(inDialog(find.text(adminHideCarTitle)), findsOneWidget);
    expect(
      inDialog(find.text('20 Oct 2026 14:00 – 22 Oct 2026 14:00')),
      findsOneWidget,
    );
    expect(inDialog(find.text(adminHiddenCarNote)), findsOneWidget);

    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(fleet.replaced, isEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    expect(find.text(listText), findsNothing);
  });

  testWidgets('"Checking…" while the read runs; then "Hide" saves', (
    tester,
  ) async {
    await pumpEdit(tester);
    bookings.confirmedPending = Completer<void>();
    await tapSave(tester);
    expect(find.text(adminChecking), findsOneWidget);
    bookings.confirmedPending!.complete();
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(adminCarHide),
      ),
    );
    await settle(tester);
    expect(fleet.replaced.single.car.active, false);
    expect(find.text(listText), findsOneWidget);
  });
}
