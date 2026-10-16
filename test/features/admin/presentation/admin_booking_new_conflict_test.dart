import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_new_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict check of a new booking (step 5.3). Every value is made up.
const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Office'),
  ),
];

/// A stored confirmed booking of car-1 with [id] that overlaps the form's
/// times (10 Jan 18:00 to 15 Jan 20:00 in Tbilisi).
Booking stored(String id) => Booking.fromMap(
  id,
  rawBooking(
    id,
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
  final asked = <ConflictCheckOutcome>[];
  bool answer = true;

  AdminBookingNewState get state => container.read(adminBookingNewProvider);

  AdminBookingNewNotifier get notifier =>
      container.read(adminBookingNewProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  /// A complete, valid form; [status] confirmed unless said otherwise.
  void fill({BookingStatus status = BookingStatus.confirmed}) {
    final draft = state.draft;
    notifier.setDraft(
      draft.copyWith(
        status: status,
        fields: draft.fields.copyWith(
          carId: 'car-1',
          input: draft.fields.input.copyWith(
            fullName: 'Test Person',
            phone: '+995555000000',
            email: 'person@example.com',
            pickup: TbilisiDateTime(2026, 1, 10, 18, 0),
            dropoff: TbilisiDateTime(2026, 1, 15, 20, 0),
            pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
            dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
          ),
        ),
      ),
    );
  }

  Future<void> save() async {
    await notifier.save(
      decide: (outcome) async {
        asked.add(outcome);
        return answer;
      },
    );
    await flush();
  }

  void conflicts([String id = 'other']) => bookings.confirmedAnswer =
      ConfirmedBookingsChecked(bookings: [stored(id)], unreadable: 0);
}

Future<Harness> start(WidgetTester tester) async {
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  final bookings = FakeAdminBookingsRepository()..cars = [testCar()];
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      adminBookingsRepositoryProvider.overrideWithValue(bookings),
      pickupLocationsProvider.overrideWith((ref) => Stream.value(places)),
      extrasPricesProvider.overrideWith(
        (ref) => Stream.value(
          ExtrasPrices.fromMap({
            'pricesPerDay': {
              'snowChains': 5,
              'childSeat': 4,
              'infantSeat': 3,
              'boosterSeat': 2.5,
            },
          }),
        ),
      ),
    ],
  );
  final h = Harness(tester, container, bookings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await h.flush();
  final subscription = container.listen(adminBookingNewProvider, (_, _) {});
  addTearDown(subscription.close);
  await h.flush();
  await h.flush();
  return h;
}

void main() {
  testWidgets('saved as "new": no read, no dialog', (tester) async {
    final h = await start(tester)
      ..fill(status: BookingStatus.newBooking);
    await h.save();
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.bookings.creates, hasLength(1));
  });

  testWidgets('saved as confirmed, nothing found: one read, one create', (
    tester,
  ) async {
    final h = await start(tester)
      ..fill();
    await h.save();
    expect(h.bookings.confirmedReads, ['car-1']);
    expect(h.asked, isEmpty);
    expect(h.bookings.creates, hasLength(1));
  });

  testWidgets('a conflict, Continue anyway: one create with the form ID and '
      'the same booking as without a conflict', (tester) async {
    final clear = await start(tester)
      ..fill();
    await clear.save();
    final expected = clear.bookings.creates.single.booking;

    final h = await start(tester)
      ..fill()
      ..conflicts();
    await h.save();
    expect(h.asked.single, isA<ConflictCheckWarning>());
    final created = h.bookings.creates.single;
    expect(created.id, 'new-1');
    expect(created.booking, expected);
  });

  testWidgets('a conflict, Cancel: nothing created; the form as it was and '
      'not locked', (tester) async {
    final h = await start(tester)
      ..fill()
      ..conflicts();
    h.answer = false;
    final draftBefore = h.state.draft;
    await h.save();
    expect(h.bookings.creates, isEmpty);
    expect(h.state.draft, same(draftBefore));
    expect(h.state.saving, false);
    expect(h.state.checking, false);
    expect(h.state.mayAlreadyExist, false);
    expect(h.state.canEdit, true);
  });

  testWidgets('the form ID keeps a stored booking with the same ID from '
      'being its own conflict', (tester) async {
    final h = await start(tester)
      ..fill();
    h.conflicts(h.state.bookingId!);
    await h.save();
    expect(h.asked, isEmpty);
    expect(h.bookings.creates, hasLength(1));
  });

  testWidgets('"Checking…" while the read runs; a double press: one read, '
      'one create', (tester) async {
    final h = await start(tester)
      ..fill();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    expect(h.state.saving, true);
    expect(h.state.checking, true);
    await h.save();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.bookings.creates, hasLength(1));
    expect(h.state.checking, false);
  });

  testWidgets('a dialog that throws counts as Cancel', (tester) async {
    final h = await start(tester)
      ..fill()
      ..conflicts();
    await h.notifier.save(decide: (_) async => throw StateError('failed'));
    await h.flush();
    expect(h.bookings.creates, isEmpty);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
  });

  testWidgets('a sign-out during the read: nothing created', (tester) async {
    final h = await start(tester)
      ..fill()
      ..conflicts();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    h.auth.report(AdminSession.signedOut);
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.asked, isEmpty);
    expect(h.bookings.creates, isEmpty);
  });

  testWidgets('"Check again" after no answer runs no new conflict check', (
    tester,
  ) async {
    final h = await start(tester)
      ..fill();
    h.bookings.createError = const AdminBookingCreateNoAnswer();
    await h.save();
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.state.mayAlreadyExist, true);

    h.bookings.createError = null;
    h.conflicts();
    await h.notifier.checkAgain();
    await h.flush();
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.asked, isEmpty);
    expect(h.bookings.creates, hasLength(2));
  });
}
