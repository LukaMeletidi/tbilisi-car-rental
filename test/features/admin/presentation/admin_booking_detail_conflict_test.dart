import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_detail_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict check of a status change (step 5.3). Every value is made
/// up. testWidgets is used only for its clock.
const id = 'b1';

/// The booking of the detail: pending, car-1, 10 Jan 14:00 to 15 Jan 16:00
/// UTC (the defaults of rawBooking).
final pending = rawBooking(id, status: 'pending');

/// Another confirmed booking of car-1 that overlaps it.
Booking other() => Booking.fromMap(
  'other',
  rawBooking(
    'other',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 1, 12, 10),
    dropoff: DateTime.utc(2026, 1, 13, 10),
  ).data,
);

class Harness {
  Harness(this.tester, this.container, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;

  /// What the fake dialog was asked, and what it answers.
  final asked = <ConflictCheckOutcome>[];
  bool answer = true;

  AdminBookingDetailState get state =>
      container.read(adminBookingDetailProvider(id));

  AdminBookingDetailNotifier get notifier =>
      container.read(adminBookingDetailProvider(id).notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<bool> decide(ConflictCheckOutcome outcome) async {
    asked.add(outcome);
    return answer;
  }

  Future<void> change(BookingStatus to) =>
      notifier.changeStatus(to, decide: decide);

  void conflicts() => bookings.confirmedAnswer = ConfirmedBookingsChecked(
    bookings: [other()],
    unreadable: 0,
  );
}

Future<Harness> start(WidgetTester tester) async {
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  final bookings = FakeAdminBookingsRepository()..cars = [testCar()];
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1)),
    ],
  );
  final h = Harness(tester, container, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await h.flush();
  final subscription = container.listen(
    adminBookingDetailProvider(id),
    (_, _) {},
  );
  addTearDown(subscription.close);
  await h.flush();
  bookings.emitBooking(pending);
  await h.flush();
  return h;
}

void main() {
  testWidgets('a change that needs no check reads nothing', (tester) async {
    final h = await start(tester);
    await h.change(BookingStatus.cancelled);
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.bookings.statusChanges.single.status, BookingStatus.cancelled);
  });

  testWidgets('to confirmed, nothing found: no dialog, one write', (
    tester,
  ) async {
    final h = await start(tester);
    await h.change(BookingStatus.confirmed);
    expect(h.bookings.confirmedReads, ['car-1']);
    expect(h.asked, isEmpty);
    expect(h.bookings.statusChanges.single.status, BookingStatus.confirmed);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
  });

  testWidgets('a conflict, Continue anyway: one write', (tester) async {
    final h = await start(tester)
      ..conflicts();
    await h.change(BookingStatus.confirmed);
    final warning = h.asked.single as ConflictCheckWarning;
    expect(warning.conflicts.single.id, 'other');
    expect(h.bookings.statusChanges, hasLength(1));
  });

  testWidgets('a conflict, Cancel: nothing written, nothing shown', (
    tester,
  ) async {
    final h = await start(tester)
      ..conflicts();
    h.answer = false;
    await h.change(BookingStatus.confirmed);
    expect(h.bookings.statusChanges, isEmpty);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
    expect(h.state.notice, isNull);
    expect(h.state.booking!.status, BookingStatus.pending);
  });

  testWidgets('could not be checked: the dialog decides', (tester) async {
    final h = await start(tester);
    h.bookings.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.timeout,
    );
    h.answer = false;
    await h.change(BookingStatus.confirmed);
    expect(h.asked.single, isA<ConflictCheckFailed>());
    expect(h.bookings.statusChanges, isEmpty);
    h.answer = true;
    await h.change(BookingStatus.confirmed);
    expect(h.bookings.statusChanges, hasLength(1));
  });

  testWidgets('without a screen the answer is Cancel', (tester) async {
    final h = await start(tester)
      ..conflicts();
    await h.notifier.changeStatus(BookingStatus.confirmed);
    expect(h.bookings.statusChanges, isEmpty);
    expect(h.state.saving, false);
  });

  testWidgets('a dialog that throws counts as Cancel; nothing stays locked', (
    tester,
  ) async {
    final h = await start(tester)
      ..conflicts();
    await h.notifier.changeStatus(
      BookingStatus.confirmed,
      decide: (_) async => throw StateError('dialog failed'),
    );
    expect(h.bookings.statusChanges, isEmpty);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
  });

  testWidgets('"Checking…" while the read runs; a second press does nothing: '
      'one read, one write', (tester) async {
    final h = await start(tester);
    h.bookings.confirmedPending = Completer<void>();
    final first = h.change(BookingStatus.confirmed);
    await h.flush();
    expect(h.state.saving, true);
    expect(h.state.checking, true);
    await h.change(BookingStatus.confirmed);
    await h.change(BookingStatus.cancelled);

    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.bookings.statusChanges, hasLength(1));
    expect(h.state.checking, false);
    expect(h.state.saving, false);
  });

  testWidgets('a sign-out during the read: nothing written', (tester) async {
    final h = await start(tester)
      ..conflicts();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.change(BookingStatus.confirmed);
    await h.flush();
    h.auth.report(AdminSession.signedOut);
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    await h.flush();
    expect(h.asked, isEmpty);
    expect(h.bookings.statusChanges, isEmpty);
    expect(h.state.saving, false);
  });

  testWidgets('the page left during the read: nothing written', (tester) async {
    final h = await start(tester)
      ..conflicts();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.change(BookingStatus.confirmed);
    await h.flush();
    h.container.invalidate(adminBookingDetailProvider(id));
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.asked, isEmpty);
    expect(h.bookings.statusChanges, isEmpty);
  });
}
