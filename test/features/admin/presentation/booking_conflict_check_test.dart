import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/booking_conflict_check.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// Hands out a Ref, so the helper can be called as a notifier calls it.
final _refProvider = Provider<Ref>((ref) => ref);

DateTime at(int hour) => DateTime.utc(2026, 6, 1, hour);

Booking booking(
  String id, {
  String status = 'confirmed',
  String carId = 'car-1',
  int from = 10,
  int to = 12,
}) => Booking.fromMap(
  id,
  rawBooking(
    id,
    status: status,
    carId: carId,
    pickup: at(from),
    dropoff: at(to),
  ).data,
);

void main() {
  late FakeAdminBookingsRepository fake;
  late ProviderContainer container;
  late List<ConflictCheckOutcome> asked;
  late List<bool> checking;

  setUp(() {
    fake = FakeAdminBookingsRepository();
    container = ProviderContainer(
      overrides: [adminBookingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    asked = [];
    checking = [];
  });

  Future<bool> run({
    Booking? base,
    required Booking edited,
    bool answer = true,
    ConflictDecision? decide,
  }) {
    return checkConflictsBeforeWrite(
      container.read(_refProvider),
      base: base,
      edited: edited,
      selfId: edited.id,
      decide:
          decide ??
          (outcome) async {
            asked.add(outcome);
            return answer;
          },
      setChecking: checking.add,
    );
  }

  test('no check needed: nothing is read, the write may go ahead', () async {
    final pending = booking('b', status: 'pending');
    expect(await run(base: pending, edited: pending), true);
    expect(fake.confirmedReads, isEmpty);
    expect(checking, isEmpty);
    expect(asked, isEmpty);
  });

  test('nothing found: true, no dialog; "Checking…" on and off', () async {
    expect(await run(edited: booking('new')), true);
    expect(fake.confirmedReads, ['car-1']);
    expect(checking, [true, false]);
    expect(asked, isEmpty);
  });

  test('the bookings of the edited car are read', () async {
    final base = booking('b');
    final moved = booking('b', carId: 'car-2');
    await run(base: base, edited: moved);
    expect(fake.confirmedReads, ['car-2']);
  });

  test('a conflict: the screen decides; its answer counts', () async {
    fake.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [booking('other', from: 11, to: 13)],
      unreadable: 0,
    );
    expect(await run(edited: booking('new'), answer: true), true);
    expect(await run(edited: booking('new'), answer: false), false);
    expect(asked, hasLength(2));
    expect(asked.first, isA<ConflictCheckWarning>());
  });

  test('could not be checked: the screen decides too', () async {
    fake.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.timeout,
    );
    expect(await run(edited: booking('new'), answer: false), false);
    expect(
      (asked.single as ConflictCheckFailed).failure,
      ConflictCheckFailure.timeout,
    );
  });

  test('a decision that throws counts as Cancel', () async {
    fake.confirmedAnswer = ConfirmedBookingsChecked(
      bookings: [booking('other', from: 11, to: 13)],
      unreadable: 0,
    );
    final result = await run(
      edited: booking('new'),
      decide: (outcome) async => throw StateError('dialog failed'),
    );
    expect(result, false);
    expect(checking, [true, false]);
  });

  test('the default answer without a screen is Cancel', () async {
    expect(
      await cancelOnConflict(
        const ConflictCheckFailed(ConflictCheckFailure.other),
      ),
      false,
    );
  });

  test('a status change to cancelled is never checked', () async {
    final confirmed = booking('b');
    final cancelled = bookingWithStatus(confirmed, BookingStatus.cancelled);
    expect(await run(base: confirmed, edited: cancelled), true);
    expect(fake.confirmedReads, isEmpty);
  });
}
