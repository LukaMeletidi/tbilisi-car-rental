import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_booking_edit_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_admin_bookings_repository.dart';

/// The conflict check of an edit (step 5.3). Every value is made up.
const id = 'b1';

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

const otherCar = Car(
  id: 'car-2',
  brand: 'Kia',
  model: 'Rio',
  year: 2020,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.manual,
  fuelType: FuelType.petrol,
  seats: 5,
  engineSize: null,
  pricePerDay: 30,
  description: LocalizedText(),
  photos: [],
  active: true,
);

/// A confirmed booking of car-1 that overlaps the edited one.
Booking clash() => Booking.fromMap(
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
  final asked = <ConflictCheckOutcome>[];
  bool answer = true;

  AdminBookingEditState get state =>
      container.read(adminBookingEditProvider(id));

  AdminBookingEditNotifier get notifier =>
      container.read(adminBookingEditProvider(id).notifier);

  AdminBookingDraft get draft => state.draft!;

  Future<void> flush() => tester.pump(Duration.zero);

  void edit(BookingFormInput Function(BookingFormInput input) change) =>
      notifier.setDraft(draft.copyWith(input: change(draft.input)));

  /// A later dropoff: a date change, so a check and a total choice.
  void moveDropoff() {
    edit((i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 17, 20, 0)));
    notifier.chooseTotal(AdminTotalChoice.useNew);
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

  void conflicts() => bookings.confirmedAnswer = ConfirmedBookingsChecked(
    bookings: [clash()],
    unreadable: 0,
  );
}

/// The stored booking is confirmed (car-1, 10 to 15 Jan, total 225).
Future<Harness> start(WidgetTester tester) async {
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  final bookings = FakeAdminBookingsRepository()..cars = [testCar(), otherCar];
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
  final subscription = container.listen(
    adminBookingEditProvider(id),
    (_, _) {},
  );
  addTearDown(subscription.close);
  await h.flush();
  await h.flush();
  bookings.emitBooking(rawBooking(id, status: 'confirmed'));
  await h.flush();
  return h;
}

void main() {
  testWidgets('a notes-only edit of a confirmed booking reads nothing', (
    tester,
  ) async {
    final h = await start(tester);
    h.edit((i) => i.copyWith(notes: 'A note.'));
    await h.save();
    expect(h.bookings.confirmedReads, isEmpty);
    expect(h.bookings.updates, hasLength(1));
  });

  testWidgets('a date change of a confirmed booking is checked', (
    tester,
  ) async {
    final h = await start(tester);
    h.moveDropoff();
    await h.save();
    expect(h.bookings.confirmedReads, ['car-1']);
    expect(h.asked, isEmpty);
    expect(h.bookings.updates, hasLength(1));
  });

  testWidgets('a car change reads the bookings of the NEW car', (tester) async {
    final h = await start(tester);
    h.notifier.setDraft(h.draft.copyWith(carId: 'car-2'));
    h.notifier.chooseTotal(AdminTotalChoice.useNew);
    await h.save();
    expect(h.bookings.confirmedReads, ['car-2']);
  });

  testWidgets('Continue anyway writes exactly what a save without a '
      'conflict writes: the same changes, the same total', (tester) async {
    final clear = await start(tester);
    clear.moveDropoff();
    await clear.save();
    final expected = clear.bookings.updates.single;

    final h = await start(tester)
      ..conflicts();
    h.moveDropoff();
    await h.save();
    expect(h.asked.single, isA<ConflictCheckWarning>());
    final written = h.bookings.updates.single;
    expect(written.base, expected.base);
    expect(written.changes.fields, expected.changes.fields);
    expect(written.changes.values, expected.changes.values);
    expect(written.changes.values['totalPrice'], isNotNull);
  });

  testWidgets('Cancel: nothing written; the form exactly as it was', (
    tester,
  ) async {
    final h = await start(tester)
      ..conflicts();
    h.answer = false;
    h.moveDropoff();
    final draftBefore = h.draft;
    final versionBefore = h.state.formVersion;
    await h.save();
    expect(h.bookings.updates, isEmpty);
    expect(h.draft, same(draftBefore));
    expect(h.draft.totalChoice, AdminTotalChoice.useNew);
    expect(h.state.formVersion, versionBefore);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
    expect(h.state.notice, isNull);
  });

  testWidgets('could not be checked: the dialog decides', (tester) async {
    final h = await start(tester);
    h.bookings.confirmedAnswer = const ConfirmedBookingsUnchecked(
      ConflictCheckFailure.noConnection,
    );
    h.answer = false;
    h.moveDropoff();
    await h.save();
    expect(h.asked.single, isA<ConflictCheckFailed>());
    expect(h.bookings.updates, isEmpty);
  });

  testWidgets('"Checking…" while the read runs; a double press: one read, '
      'one write', (tester) async {
    final h = await start(tester);
    h.moveDropoff();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    expect(h.state.saving, true);
    expect(h.state.checking, true);
    await h.save();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.bookings.confirmedReads, hasLength(1));
    expect(h.bookings.updates, hasLength(1));
    expect(h.state.checking, false);
    expect(h.state.saving, false);
  });

  testWidgets('a dialog that throws counts as Cancel', (tester) async {
    final h = await start(tester)
      ..conflicts();
    h.moveDropoff();
    await h.notifier.save(decide: (_) async => throw StateError('failed'));
    await h.flush();
    expect(h.bookings.updates, isEmpty);
    expect(h.state.saving, false);
    expect(h.state.checking, false);
  });

  testWidgets('a sign-out during the read: nothing written', (tester) async {
    final h = await start(tester)
      ..conflicts();
    h.moveDropoff();
    h.bookings.confirmedPending = Completer<void>();
    final first = h.save();
    await h.flush();
    h.auth.report(AdminSession.signedOut);
    await h.flush();
    h.bookings.confirmedPending!.complete();
    await first;
    expect(h.asked, isEmpty);
    expect(h.bookings.updates, isEmpty);
    expect(h.state.saving, false);
  });

  testWidgets('without a screen the answer is Cancel', (tester) async {
    final h = await start(tester)
      ..conflicts();
    h.moveDropoff();
    await h.notifier.save();
    expect(h.bookings.updates, isEmpty);
    expect(h.state.saving, false);
  });
}
