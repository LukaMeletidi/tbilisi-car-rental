import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_screen.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict dialog of a status change on the detail page (step 5.3).
/// Every value is made up.
late FakeAdminAuthRepository auth;
late FakeAdminBookingsRepository bookings;

/// A confirmed booking of car-1 from [day] 10:00 to [day] 20:00 UTC in
/// January 2026, which overlaps the detail's booking (10 to 15 Jan).
Booking other(String id, int day) => Booking.fromMap(
  id,
  rawBooking(
    id,
    fullName: 'Other Customer',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 1, day, 10),
    dropoff: DateTime.utc(2026, 1, day, 20),
  ).data,
);

Future<void> pumpDetail(
  WidgetTester tester, {
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  bookings = FakeAdminBookingsRepository()..cars = [testCar()];
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        adminBookingsRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1)),
        pickupLocationsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminBookingDetailScreen(bookingId: 'b1'),
      ),
    ),
  );
  await settle(tester);
  bookings.emitBooking(rawBooking('b1', status: 'pending'));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> tapConfirmed(WidgetTester tester) async {
  final button = find.widgetWithText(
    OutlinedButton,
    adminChangeTo(BookingStatus.confirmed),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

void main() {
  testWidgets('a conflict: the dialog shows the period in Tbilisi time and '
      'no name; Cancel writes nothing', (tester) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [other('o1', 12)],
      unreadable: 0,
    );
    await tapConfirmed(tester);

    expect(inDialog(find.text(adminConflictTitle)), findsOneWidget);
    expect(inDialog(find.text(adminConflictIntro())), findsOneWidget);
    // 10:00 and 20:00 UTC are 14:00 and 00:00 the next day in Tbilisi.
    expect(
      inDialog(find.text('12 Jan 2026 14:00 – 13 Jan 2026 00:00')),
      findsOneWidget,
    );
    expect(inDialog(find.text(adminTbilisiTimeNote)), findsOneWidget);
    expect(inDialog(find.textContaining('Customer')), findsNothing);
    expect(inDialog(find.textContaining('Test Person')), findsNothing);

    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.statusChanges, isEmpty);
  });

  testWidgets('Continue anyway changes the status', (tester) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [other('o1', 12)],
      unreadable: 0,
    );
    await tapConfirmed(tester);
    await tester.tap(find.text(adminContinueAnyway));
    await settle(tester);
    expect(bookings.statusChanges.single.status, BookingStatus.confirmed);
  });

  testWidgets('"Checking…" while the read runs', (tester) async {
    await pumpDetail(tester);
    bookings.confirmedPending = Completer<void>();
    await tapConfirmed(tester);
    expect(find.text(adminChecking), findsOneWidget);
    bookings.confirmedPending!.complete();
    await settle(tester);
    expect(find.text(adminChecking), findsNothing);
    expect(bookings.statusChanges, hasLength(1));
  });

  testWidgets('could not be checked: its own dialog, no causes named', (
    tester,
  ) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.noConnection,
    );
    await tapConfirmed(tester);
    expect(inDialog(find.text(adminConflictUncheckedTitle)), findsOneWidget);
    expect(inDialog(find.text(adminConflictUncheckedText)), findsOneWidget);
    expect(inDialog(find.textContaining('connection')), findsNothing);
    expect(inDialog(find.textContaining('seconds')), findsNothing);
    await tester.tap(find.text(adminCancel));
    await settle(tester);
    expect(bookings.statusChanges, isEmpty);
  });

  testWidgets('five conflicts: three periods and "and 2 more"; the '
      'unreadable line', (tester) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [for (var day = 10; day <= 14; day++) other('o$day', day)],
      unreadable: 1,
    );
    await tapConfirmed(tester);
    expect(inDialog(find.textContaining(' – ')), findsNWidgets(3));
    expect(inDialog(find.text(adminConflictMore(2))), findsOneWidget);
    expect(inDialog(find.text(adminConflictUnreadable(1))), findsOneWidget);
  });

  testWidgets('only unreadable documents: the "not every booking" dialog', (
    tester,
  ) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = const ConfirmedBookingsChecked(
      bookings: [],
      unreadable: 3,
    );
    await tapConfirmed(tester);
    expect(inDialog(find.text(adminConflictPartlyTitle)), findsOneWidget);
    expect(inDialog(find.text(adminConflictUnreadable(3))), findsOneWidget);
  });

  testWidgets('a tap beside the dialog means Cancel', (tester) async {
    await pumpDetail(tester);
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [other('o1', 12)],
      unreadable: 0,
    );
    await tapConfirmed(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bookings.statusChanges, isEmpty);
  });

  testWidgets('320 px wide, the fullest dialog: nothing overflows', (
    tester,
  ) async {
    await pumpDetail(tester, size: const Size(320, 1600));
    bookings.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [for (var day = 10; day <= 14; day++) other('o$day', day)],
      unreadable: 2,
    );
    await tapConfirmed(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
