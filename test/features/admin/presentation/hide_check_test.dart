import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/hide_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/hide_check.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// Hands out a Ref, so the helper can be called as a notifier calls it.
final _refProvider = Provider<Ref>((ref) => ref);

/// A made-up confirmed booking of car-1, 20 to 22 Oct 2026.
Booking ahead() => Booking.fromMap(
  'ahead',
  rawBooking(
    'ahead',
    status: 'confirmed',
    pickup: DateTime.utc(2026, 10, 20, 10),
    dropoff: DateTime.utc(2026, 10, 22, 10),
  ).data,
);

void main() {
  late FakeAdminBookingsRepository fake;
  late ProviderContainer container;
  late DateTime now;
  late List<HideCheckOutcome> asked;
  late List<bool> checking;

  setUp(() {
    fake = FakeAdminBookingsRepository();
    now = DateTime.utc(2026, 10, 16, 8);
    container = ProviderContainer(
      overrides: [
        adminBookingsRepositoryProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    asked = [];
    checking = [];
  });

  Future<bool> run({bool answer = true, HideDecision? decide}) {
    return askBeforeHide(
      container.read(_refProvider),
      carId: 'car-1',
      decide:
          decide ??
          (outcome) async {
            asked.add(outcome);
            return answer;
          },
      setChecking: checking.add,
    );
  }

  test(
    'nothing ahead: the dialog is still asked; "Checking…" on and off',
    () async {
      expect(await run(), true);
      expect(fake.confirmedReads, ['car-1']);
      expect(asked.single, isA<HideCheckClear>());
      expect(checking, [true, false]);
    },
  );

  test('bookings ahead: the dialog gets them; its answer counts', () async {
    fake.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [ahead()],
      unreadable: 0,
    );
    expect(await run(answer: false), false);
    expect((asked.single as HideCheckBookings).ahead.single.id, 'ahead');
  });

  test('"now" comes from the clock', () async {
    fake.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [ahead()],
      unreadable: 0,
    );
    now = DateTime.utc(2026, 10, 23);
    await run();
    expect(asked.single, isA<HideCheckClear>());
  });

  test('could not be read: failed, and the dialog decides', () async {
    fake.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.noConnection,
    );
    expect(await run(answer: true), true);
    expect(
      (asked.single as HideCheckFailed).failure,
      ConflictCheckFailure.noConnection,
    );
  });

  test('a decision that throws counts as Cancel', () async {
    final result = await run(
      decide: (_) async => throw StateError('dialog failed'),
    );
    expect(result, false);
    expect(checking, [true, false]);
  });

  test('the default answer without a screen is Cancel', () async {
    expect(await cancelHide(const HideCheckClear()), false);
  });
}
