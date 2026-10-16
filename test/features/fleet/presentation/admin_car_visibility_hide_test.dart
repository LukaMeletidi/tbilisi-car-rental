import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/hide_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_visibility_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// Hiding from the list after the check of the bookings ahead (step 5.4).
/// Every value is made up. testWidgets is used only for its clock.
class Harness {
  Harness(this.tester, this.container, this.fleet, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeFleetRepository fleet;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;
  final asked = <HideCheckOutcome>[];
  bool answer = true;

  AdminCarVisibilityState get state =>
      container.read(adminCarVisibilityProvider);

  AdminCarVisibilityNotifier get notifier =>
      container.read(adminCarVisibilityProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> hide(String id) => notifier.hide(
    id,
    decide: (outcome) async {
      asked.add(outcome);
      return answer;
    },
  );

  /// A confirmed booking of car "a" from 20 to 22 Oct 2026: ahead.
  void bookingAhead() => bookings.confirmedAnswer = ConfirmedBookingsChecked(
    bookings: [
      Booking.fromMap(
        'ahead',
        rawBooking(
          'ahead',
          carId: 'a',
          status: 'confirmed',
          pickup: DateTime.utc(2026, 10, 20, 10),
          dropoff: DateTime.utc(2026, 10, 22, 10),
        ).data,
      ),
    ],
    unreadable: 0,
  );
}

Future<Harness> start(WidgetTester tester) async {
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  final fleet = FakeFleetRepository();
  final bookings = FakeAdminBookingsRepository();
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      fleetRepositoryProvider.overrideWithValue(fleet),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 16, 8)),
    ],
  );
  final h = Harness(tester, container, fleet, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await h.flush();
  final subscription = container.listen(adminCarVisibilityProvider, (_, _) {});
  addTearDown(subscription.close);
  return h;
}

void main() {
  testWidgets('Hide: the bookings ahead go to the dialog; "Hide" writes '
      'once', (tester) async {
    final h = await start(tester)
      ..bookingAhead();
    await h.hide('a');
    expect(h.bookings.confirmedReads, ['a']);
    expect((h.asked.single as HideCheckBookings).ahead.single.id, 'ahead');
    expect(h.fleet.activeChanges, [(id: 'a', active: false)]);
    expect(h.state.notice, CarActiveNotice.hidden);
    expect(h.state.busy, isEmpty);
    expect(h.state.checking, isEmpty);
  });

  testWidgets('nothing ahead: the dialog is still asked (clear)', (
    tester,
  ) async {
    final h = await start(tester);
    await h.hide('a');
    expect(h.asked.single, isA<HideCheckClear>());
    expect(h.fleet.activeChanges, hasLength(1));
  });

  testWidgets('Cancel: nothing written; the card as it was', (tester) async {
    final h = await start(tester)
      ..bookingAhead();
    h.answer = false;
    await h.hide('a');
    expect(h.fleet.activeChanges, isEmpty);
    expect(h.state.busy, isEmpty);
    expect(h.state.checking, isEmpty);
    expect(h.state.notice, isNull);
  });

  testWidgets('could not be checked, then "Hide": hidden all the same', (
    tester,
  ) async {
    final h = await start(tester);
    h.bookings.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.timeout,
    );
    await h.hide('a');
    expect(h.asked.single, isA<HideCheckFailed>());
    expect(h.fleet.activeChanges, hasLength(1));
  });

  testWidgets('Show reads nothing and asks nothing', (tester) async {
    final h = await start(tester);
    await h.notifier.setActive('a', active: true);
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.asked, isEmpty);
    expect(h.fleet.activeChanges, [(id: 'a', active: true)]);
  });

  testWidgets('"Checking…" while the read runs; a double press: one read, '
      'one write', (tester) async {
    final h = await start(tester);
    h.bookings.confirmedPending = Completer<void>();
    final first = h.hide('a');
    await h.flush();
    expect(h.state.busy, {'a'});
    expect(h.state.checking, {'a'});
    await h.hide('a');
    await h.notifier.setActive('a', active: true);
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.fleet.activeChanges, hasLength(1));
    expect(h.state.checking, isEmpty);
    expect(h.state.busy, isEmpty);
  });

  testWidgets('a dialog that throws counts as Cancel; nothing stays busy', (
    tester,
  ) async {
    final h = await start(tester);
    await h.notifier.hide('a', decide: (_) async => throw StateError('x'));
    expect(h.fleet.activeChanges, isEmpty);
    expect(h.state.busy, isEmpty);
    expect(h.state.checking, isEmpty);
  });

  testWidgets('a failed write: its notice; nothing stays busy', (tester) async {
    final h = await start(tester);
    h.fleet.setActiveError = const CarWriteException(
      CarWriteFailure.noConnection,
    );
    await h.hide('a');
    expect(h.state.notice, CarActiveNotice.noConnection);
    expect(h.state.busy, isEmpty);
  });

  testWidgets('a sign-out during the read: nothing written', (tester) async {
    final h = await start(tester);
    h.bookings.confirmedPending = Completer<void>();
    final first = h.hide('a');
    await h.flush();
    h.auth.report(AdminSession.signedOut);
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.asked, isEmpty);
    expect(h.fleet.activeChanges, isEmpty);
    expect(h.state.busy, isEmpty);
  });

  testWidgets('without a screen the answer is Cancel', (tester) async {
    final h = await start(tester);
    await h.notifier.hide('a');
    expect(h.fleet.activeChanges, isEmpty);
    expect(h.state.busy, isEmpty);
  });
}
