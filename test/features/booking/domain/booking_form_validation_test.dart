import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

/// The current moment in the tests: 1 January 2026, 12:00 in Tbilisi.
final now = DateTime.utc(2026, 1, 1, 8);

const locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Tbilisi Office'),
  ),
];

Car car({bool active = true}) {
  return Car(
    id: 'car-1',
    brand: 'Toyota',
    model: 'Prius',
    year: 2019,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: FuelType.hybrid,
    seats: 5,
    engineSize: 1.8,
    pricePerDay: 45,
    description: const LocalizedText(),
    photos: const [],
    active: active,
  );
}

const _unset = Object();

/// A complete, valid form. Each argument replaces one value; passing null
/// for a date or a location means "not chosen".
BookingFormInput input({
  String fullName = 'Nino Beridze',
  String phone = '+995 555 12-34-56',
  String email = 'nino@example.com',
  Object? pickup = _unset,
  Object? dropoff = _unset,
  Object? pickupLocation = _unset,
  Object? dropoffLocation = _unset,
  Set<Extra> extras = const {},
  String notes = '',
}) {
  return BookingFormInput(
    fullName: fullName,
    phone: phone,
    email: email,
    pickup: identical(pickup, _unset)
        ? TbilisiDateTime(2026, 1, 10, 18)
        : pickup as TbilisiDateTime?,
    dropoff: identical(dropoff, _unset)
        ? TbilisiDateTime(2026, 1, 15, 20)
        : dropoff as TbilisiDateTime?,
    pickupLocation: identical(pickupLocation, _unset)
        ? const BookingLocation.fixed('tbilisiAirport')
        : pickupLocation as BookingLocation?,
    dropoffLocation: identical(dropoffLocation, _unset)
        ? const BookingLocation.other('Hotel in Batumi')
        : dropoffLocation as BookingLocation?,
    extras: extras,
    notes: notes,
  );
}

Set<BookingFormError> validate(BookingFormInput form, {Car? forCar}) {
  return validateBookingForm(
    form,
    car: forCar ?? car(),
    locations: locations,
    now: now,
  );
}

void main() {
  test('a complete, valid form has no errors', () {
    expect(validate(input()), isEmpty);
    expect(
      validate(input(extras: {Extra.childSeat}, notes: 'Late arrival')),
      isEmpty,
    );
  });

  test('throws when "now" is not a UTC date', () {
    expect(
      () => validateBookingForm(
        input(),
        car: car(),
        locations: locations,
        now: DateTime(2026, 1, 1, 12),
      ),
      throwsArgumentError,
    );
  });

  group('name', () {
    test('empty or only spaces is required', () {
      expect(validate(input(fullName: '')), {BookingFormError.nameRequired});
      expect(validate(input(fullName: '   ')), {BookingFormError.nameRequired});
    });

    test('one letter is too short; two are enough', () {
      expect(validate(input(fullName: 'N')), {BookingFormError.nameTooShort});
      expect(validate(input(fullName: ' N ')), {BookingFormError.nameTooShort});
      expect(validate(input(fullName: 'Li')), isEmpty);
    });

    test('100 characters are fine; 101 are too long', () {
      expect(validate(input(fullName: 'a' * 100)), isEmpty);
      expect(validate(input(fullName: 'a' * 101)), {
        BookingFormError.nameTooLong,
      });
    });
  });

  group('phone', () {
    test('empty or only spaces is required', () {
      expect(validate(input(phone: '')), {BookingFormError.phoneRequired});
      expect(validate(input(phone: '  ')), {BookingFormError.phoneRequired});
    });

    test('must be in international format', () {
      for (final phone in [
        '555123456',
        '00995555123456',
        '+0995555123456',
        '+995 555 abc',
        '+1234567',
        '+1234567890123456',
        '+',
      ]) {
        expect(validate(input(phone: phone)), {
          BookingFormError.phoneInvalid,
        }, reason: 'phone "$phone"');
      }
    });

    test('8 to 15 digits are accepted, with or without separators', () {
      expect(validate(input(phone: '+12345678')), isEmpty);
      expect(validate(input(phone: '+123456789012345')), isEmpty);
      expect(validate(input(phone: '+995 (555) 12-34-56')), isEmpty);
      expect(validate(input(phone: '+995.555.123.456')), isEmpty);
    });
  });

  group('normalizePhone', () {
    test('removes spaces, hyphens, dots and brackets', () {
      expect(normalizePhone('+995 555 12-34-56'), '+995555123456');
      expect(normalizePhone(' +995 (555) 123.456 '), '+995555123456');
      expect(normalizePhone('+995555123456'), '+995555123456');
    });

    test('returns null when it is not a phone number', () {
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('555123456'), isNull);
      expect(normalizePhone('+995 555 abc'), isNull);
    });
  });

  group('email', () {
    test('empty or only spaces is required', () {
      expect(validate(input(email: '')), {BookingFormError.emailRequired});
      expect(validate(input(email: '   ')), {BookingFormError.emailRequired});
    });

    test('must look like an address', () {
      for (final email in [
        'nino',
        'nino@',
        '@example.com',
        'nino@example',
        'nino@@example.com',
        'nino@exa mple.com',
        'ni no@example.com',
        'nino@example.',
        'nino@.com',
        'nino@example..com',
      ]) {
        expect(validate(input(email: email)), {
          BookingFormError.emailInvalid,
        }, reason: 'email "$email"');
      }
    });

    test('accepts usual addresses, also with spaces around them', () {
      expect(validate(input(email: 'nino@example.com')), isEmpty);
      expect(validate(input(email: '  n.b+cars@mail.example.com ')), isEmpty);
    });

    test('254 characters are fine; 255 are too long', () {
      final local = 'a' * 242;
      expect('$local@example.com'.length, 254);
      expect(validate(input(email: '$local@example.com')), isEmpty);
      expect(validate(input(email: 'a$local@example.com')), {
        BookingFormError.emailTooLong,
      });
    });

    test('isValidEmail gives the same answers on its own', () {
      expect(isValidEmail('nino@example.com'), true);
      expect(isValidEmail('nino@example'), false);
      expect(isValidEmail(''), false);
    });
  });

  group('pickup and dropoff', () {
    test('pickup is required', () {
      expect(validate(input(pickup: null)), {BookingFormError.pickupRequired});
    });

    test('dropoff is required', () {
      expect(validate(input(dropoff: null)), {
        BookingFormError.dropoffRequired,
      });
    });

    test('pickup in the past is refused', () {
      expect(validate(input(pickup: TbilisiDateTime(2025, 12, 31, 18))), {
        BookingFormError.pickupNotInFuture,
      });
    });

    test('pickup exactly now is refused; one minute later is accepted', () {
      // "now" is 12:00 in Tbilisi.
      expect(validate(input(pickup: TbilisiDateTime(2026, 1, 1, 12))), {
        BookingFormError.pickupNotInFuture,
      });
      expect(
        validate(input(pickup: TbilisiDateTime(2026, 1, 1, 12, 1))),
        isEmpty,
      );
    });

    test('times are compared in UTC, not as plain numbers', () {
      // 11:59 Tbilisi is 07:59 UTC, one minute before "now" (08:00 UTC),
      // although 11:59 is a larger number than 08:00.
      expect(validate(input(pickup: TbilisiDateTime(2026, 1, 1, 11, 59))), {
        BookingFormError.pickupNotInFuture,
      });
    });

    test('dropoff equal to pickup is refused', () {
      expect(
        validate(
          input(
            pickup: TbilisiDateTime(2026, 1, 10, 18),
            dropoff: TbilisiDateTime(2026, 1, 10, 18),
          ),
        ),
        {BookingFormError.dropoffNotAfterPickup},
      );
    });

    test('dropoff before pickup is refused', () {
      expect(validate(input(dropoff: TbilisiDateTime(2026, 1, 10, 17, 59))), {
        BookingFormError.dropoffNotAfterPickup,
      });
    });

    test('one minute after pickup is accepted', () {
      expect(
        validate(input(dropoff: TbilisiDateTime(2026, 1, 10, 18, 1))),
        isEmpty,
      );
    });

    test('exactly 365 days is accepted', () {
      expect(
        validate(input(dropoff: TbilisiDateTime(2027, 1, 10, 18))),
        isEmpty,
      );
    });

    test('365 days and one minute is too long', () {
      expect(validate(input(dropoff: TbilisiDateTime(2027, 1, 10, 18, 1))), {
        BookingFormError.rentalTooLong,
      });
    });

    test('with no pickup, the dropoff is not compared', () {
      expect(
        validate(input(pickup: null, dropoff: TbilisiDateTime(2020, 1, 1))),
        {BookingFormError.pickupRequired},
      );
    });
  });

  group('locations', () {
    test('both must be chosen', () {
      expect(validate(input(pickupLocation: null)), {
        BookingFormError.pickupLocationRequired,
      });
      expect(validate(input(dropoffLocation: null)), {
        BookingFormError.dropoffLocationRequired,
      });
    });

    test('a fixed place must be one from settings', () {
      expect(
        validate(input(pickupLocation: const BookingLocation.fixed('moon'))),
        {BookingFormError.pickupLocationUnknown},
      );
      expect(
        validate(input(dropoffLocation: const BookingLocation.fixed('moon'))),
        {BookingFormError.dropoffLocationUnknown},
      );
    });

    test('"other" needs a text', () {
      expect(validate(input(pickupLocation: const BookingLocation.other(''))), {
        BookingFormError.pickupLocationTextRequired,
      });
      expect(
        validate(input(dropoffLocation: const BookingLocation.other('   '))),
        {BookingFormError.dropoffLocationTextRequired},
      );
    });

    test('"other": 200 characters are fine; 201 are too long', () {
      expect(
        validate(input(pickupLocation: BookingLocation.other('a' * 200))),
        isEmpty,
      );
      expect(
        validate(input(pickupLocation: BookingLocation.other('a' * 201))),
        {BookingFormError.pickupLocationTextTooLong},
      );
      expect(
        validate(input(dropoffLocation: BookingLocation.other('a' * 201))),
        {BookingFormError.dropoffLocationTextTooLong},
      );
    });

    test('pickup and dropoff may be the same place or different ones', () {
      expect(
        validate(
          input(
            pickupLocation: const BookingLocation.fixed('tbilisiOffice'),
            dropoffLocation: const BookingLocation.fixed('tbilisiOffice'),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('notes', () {
    test('empty notes are fine', () {
      expect(validate(input(notes: '')), isEmpty);
      expect(validate(input(notes: '   ')), isEmpty);
    });

    test('500 characters are fine; 501 are too long', () {
      expect(validate(input(notes: 'a' * 500)), isEmpty);
      expect(validate(input(notes: 'a' * 501)), {
        BookingFormError.notesTooLong,
      });
    });
  });

  test('a car that is not active is refused', () {
    expect(validate(input(), forCar: car(active: false)), {
      BookingFormError.carNotAvailable,
    });
  });

  test('several problems are all reported together', () {
    final errors = validate(
      input(
        fullName: '',
        phone: 'abc',
        email: 'nino@',
        pickup: null,
        dropoffLocation: null,
        notes: 'a' * 501,
      ),
    );
    expect(errors, {
      BookingFormError.nameRequired,
      BookingFormError.phoneInvalid,
      BookingFormError.emailInvalid,
      BookingFormError.pickupRequired,
      BookingFormError.dropoffLocationRequired,
      BookingFormError.notesTooLong,
    });
  });
}
