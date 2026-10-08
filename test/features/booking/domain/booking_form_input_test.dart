import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

final full = BookingFormInput(
  fullName: 'Nino Beridze',
  phone: '+995555123456',
  whatsapp: true,
  telegram: true,
  email: 'nino@example.com',
  pickup: TbilisiDateTime(2026, 1, 10, 18),
  dropoff: TbilisiDateTime(2026, 1, 15, 20),
  pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
  dropoffLocation: const BookingLocation.other('Hotel in Batumi'),
  extras: const {Extra.childSeat},
  notes: 'Late arrival',
);

void expectSame(BookingFormInput actual, BookingFormInput expected) {
  expect(actual.fullName, expected.fullName);
  expect(actual.phone, expected.phone);
  expect(actual.whatsapp, expected.whatsapp);
  expect(actual.telegram, expected.telegram);
  expect(actual.email, expected.email);
  expect(actual.pickup, expected.pickup);
  expect(actual.dropoff, expected.dropoff);
  expect(actual.pickupLocation, expected.pickupLocation);
  expect(actual.dropoffLocation, expected.dropoffLocation);
  expect(actual.extras, expected.extras);
  expect(actual.notes, expected.notes);
}

void main() {
  group('BookingFormInput.copyWith', () {
    test('without arguments gives the same values', () {
      expectSame(full.copyWith(), full);
    });

    test('changes only the given value', () {
      final changed = full.copyWith(email: 'other@example.com');
      expect(changed.email, 'other@example.com');
      expectSame(changed.copyWith(email: full.email), full);
    });

    test('can change every value', () {
      const empty = BookingFormInput();
      final copy = empty.copyWith(
        fullName: full.fullName,
        phone: full.phone,
        whatsapp: full.whatsapp,
        telegram: full.telegram,
        email: full.email,
        pickup: full.pickup,
        dropoff: full.dropoff,
        pickupLocation: full.pickupLocation,
        dropoffLocation: full.dropoffLocation,
        extras: full.extras,
        notes: full.notes,
      );
      expectSame(copy, full);
    });

    test('a checkbox can be switched off and a text emptied', () {
      final changed = full.copyWith(
        whatsapp: false,
        notes: '',
        extras: const {},
      );
      expect(changed.whatsapp, false);
      expect(changed.notes, '');
      expect(changed.extras, isEmpty);
    });

    test('the original is not changed', () {
      full.copyWith(fullName: 'Somebody Else');
      expect(full.fullName, 'Nino Beridze');
    });
  });
}
