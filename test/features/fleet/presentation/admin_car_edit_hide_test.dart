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
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';
import '../../../support/fake_fleet_repository.dart';

/// Hiding through the Visible switch of the edit form, after the check of
/// the bookings ahead (step 5.4). Every value is made up. testWidgets is
/// used only for its clock.
const carId = 'car-1';

class Harness {
  Harness(this.tester, this.container, this.fleet, this.bookings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeFleetRepository fleet;
  final FakeAdminBookingsRepository bookings;
  final FakeAdminAuthRepository auth;
  final asked = <HideCheckOutcome>[];
  bool answer = true;

  AdminCarEditState get state => container.read(adminCarEditProvider(carId));

  AdminCarEditNotifier get notifier =>
      container.read(adminCarEditProvider(carId).notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  void edit(CarDraft Function(CarDraft draft) change) =>
      notifier.setDraft(change(state.draft!));

  Future<void> save() => notifier.save(
    decideHide: (outcome) async {
      asked.add(outcome);
      return answer;
    },
  );

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
}

/// The form of a complete car, [active] as stored.
Future<Harness> start(WidgetTester tester, {bool active = true}) async {
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
  final subscription = container.listen(adminCarEditProvider(carId), (_, _) {});
  addTearDown(subscription.close);
  await h.flush();
  fleet.emitCar(carId, rawCar(active: active));
  await h.flush();
  expect(h.state.status, AdminCarEditStatus.editing);
  return h;
}

void main() {
  testWidgets('switch off, "Hide": the bookings ahead are shown; one save, '
      'the same car as before Phase 5', (tester) async {
    final h = await start(tester)
      ..bookingAhead();
    h.edit((d) => d.copyWith(active: false));
    await h.save();
    expect(h.bookings.confirmedReads, [carId]);
    expect((h.asked.single as HideCheckBookings).ahead.single.id, 'ahead');
    final written = h.fleet.replaced.single.car;
    expect(written.active, false);
    expect(written.brand, 'Honda');
    expect(h.state.saving, false);
    expect(h.state.checking, false);
    expect(h.state.notice, CarSaveNotice.saved);
  });

  testWidgets('Cancel: nothing saved; the form exactly as it was', (
    tester,
  ) async {
    final h = await start(tester)
      ..bookingAhead();
    h.answer = false;
    h.edit((d) => d.copyWith(active: false));
    final draftBefore = h.state.draft;
    final showErrorsBefore = h.state.showErrors;
    await h.save();
    expect(h.fleet.replaced, isEmpty);
    expect(h.state.draft, same(draftBefore));
    expect(h.state.draft!.active, false);
    expect(h.state.isDirty, true);
    expect(h.state.showErrors, showErrorsBefore);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
    expect(h.state.locked, false);
    expect(h.state.notice, isNull);
  });

  testWidgets('a save that does not hide reads nothing', (tester) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(seats: '4'));
    await h.save();
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.asked, isEmpty);
    expect(h.fleet.replaced, hasLength(1));
  });

  testWidgets('a hidden car shown again reads nothing', (tester) async {
    final h = await start(tester, active: false);
    h.edit((d) => d.copyWith(active: true));
    await h.save();
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.fleet.replaced.single.car.active, true);
  });

  testWidgets('"Checking…" while the read runs; a double press: one read, '
      'one save', (tester) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(active: false));
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    expect(h.state.saving, true);
    expect(h.state.checking, true);
    await h.save();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.fleet.replaced, hasLength(1));
    expect(h.state.checking, false);
    expect(h.state.saving, false);
  });

  testWidgets('a dialog that throws counts as Cancel', (tester) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(active: false));
    await h.notifier.save(decideHide: (_) async => throw StateError('x'));
    expect(h.fleet.replaced, isEmpty);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
  });

  testWidgets('a sign-out during the read: nothing saved', (tester) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(active: false));
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    h.auth.report(AdminSession.signedOut);
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.asked, isEmpty);
    expect(h.fleet.replaced, isEmpty);
    expect(h.state.saving, false);
  });

  testWidgets('without a screen the answer is Cancel', (tester) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(active: false));
    await h.notifier.save();
    expect(h.fleet.replaced, isEmpty);
    expect(h.state.saving, false);
  });

  testWidgets('"Save again" after "No answer" does not ask or read again', (
    tester,
  ) async {
    final h = await start(tester);
    h.edit((d) => d.copyWith(active: false));
    h.fleet.replaceError = const CarWriteNoAnswer();
    await h.save();
    expect(h.state.locked, true);
    expect(h.bookings.confirmedReads, hasLength(1));

    h.fleet.replaceError = null;
    await h.save();
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.asked, hasLength(1));
    expect(h.fleet.replaced, hasLength(2));
  });
}
