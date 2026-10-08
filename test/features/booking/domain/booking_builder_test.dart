import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_builder.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_rental.dart';

/// The current moment in the tests: 1 January 2026, 12:00 in Tbilisi.
final now = DateTime.utc(2026, 1, 1, 8);

const locations = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Tbilisi Airport'),
  ),
];

final extrasPrices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 4.5,
    'boosterSeat': 3,
  },
});

Car car({double pricePerDay = 45}) {
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
    pricePerDay: pricePerDay,
    description: const LocalizedText(),
    photos: const [],
    active: true,
  );
}

/// Pickup on the 10th at 18:00 Tbilisi time, as in the plan's examples.
BookingFormInput input({
  required TbilisiDateTime dropoff,
  Set<Extra> extras = const {},
  String fullName = '  Nino Beridze ',
  String phone = '+995 555 12-34-56',
  String email = ' nino@example.com ',
  String notes = '  Late arrival  ',
  BookingLocation dropoffLocation = const BookingLocation.other(
    '  Hotel in Batumi ',
  ),
}) {
  return BookingFormInput(
    fullName: fullName,
    phone: phone,
    whatsapp: true,
    email: email,
    pickup: TbilisiDateTime(2026, 1, 10, 18),
    dropoff: dropoff,
    pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
    dropoffLocation: dropoffLocation,
    extras: extras,
    notes: notes,
  );
}

Booking build(
  BookingFormInput form, {
  double pricePerDay = 45,
  AppLanguage language = AppLanguage.en,
}) {
  return buildBooking(
    input: form,
    car: car(pricePerDay: pricePerDay),
    extrasPrices: extrasPrices,
    locations: locations,
    language: language,
    now: now,
  );
}

void main() {
  test('builds a new booking without id, createdAt or createdBy', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20)));

    expect(booking.status, BookingStatus.newBooking);
    expect(booking.id, isNull);
    expect(booking.createdAt, isNull);
    expect(booking.createdBy, isNull);
    expect(booking.carId, 'car-1');
  });

  test('converts the Tbilisi times to UTC', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20)));

    expect(booking.pickup, DateTime.utc(2026, 1, 10, 14));
    expect(booking.dropoff, DateTime.utc(2026, 1, 15, 16));
    expect(booking.pickup.isUtc, true);
    expect(booking.dropoff.isUtc, true);
  });

  test('trims the texts and stores the cleaned phone number', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20)));

    expect(booking.customer.fullName, 'Nino Beridze');
    expect(booking.customer.phone, '+995555123456');
    expect(booking.customer.email, 'nino@example.com');
    expect(booking.customer.whatsapp, true);
    expect(booking.customer.telegram, false);
    expect(booking.notes, 'Late arrival');
    expect(
      booking.pickupLocation,
      const BookingLocation.fixed('tbilisiAirport'),
    );
    expect(
      booking.dropoffLocation,
      const BookingLocation.other('Hotel in Batumi'),
    );
  });

  test('an empty note is stored as an empty text', () {
    final booking = build(
      input(dropoff: TbilisiDateTime(2026, 1, 15, 20), notes: '   '),
    );
    expect(booking.notes, '');
  });

  test('stores the language of the customer', () {
    final booking = build(
      input(dropoff: TbilisiDateTime(2026, 1, 15, 20)),
      language: AppLanguage.ka,
    );
    expect(booking.language, AppLanguage.ka);
  });

  test('the total is days times the car price', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20)));

    expect(booking.rentalDays, 5);
    expect(booking.totalPriceCents, 22500);
    expect(booking.totalPrice, 225.0);
    expect(booking.isIndividualPrice, false);
  });

  test('selected extras are added per day', () {
    final booking = build(
      input(
        dropoff: TbilisiDateTime(2026, 1, 15, 20),
        extras: {Extra.snowChains, Extra.infantSeat},
      ),
    );

    // 5 days * (45 + 5 + 4.50) = 272.50
    expect(booking.extras, {Extra.snowChains, Extra.infantSeat});
    expect(booking.totalPriceCents, 27250);
    expect(booking.totalPrice, 272.5);
  });

  test('the total has no rounding noise: 3 * 19.99 is 59.97', () {
    final booking = build(
      input(dropoff: TbilisiDateTime(2026, 1, 13, 18)),
      pricePerDay: 19.99,
    );

    expect(booking.rentalDays, 3);
    expect(booking.totalPriceCents, 5997);
    expect(booking.totalPrice, 59.97);
  });

  test('within the 2 hour grace period no extra day is charged', () {
    final onTime = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20)));
    expect(onTime.rentalDays, 5);
    expect(onTime.totalPriceCents, 22500);

    final late = build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20, 1)));
    expect(late.rentalDays, 6);
    expect(late.totalPriceCents, 27000);
  });

  test('exactly 7 days is a normal price', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 17, 18)));

    expect(booking.rentalDays, 7);
    expect(booking.isIndividualPrice, false);
    expect(booking.totalPriceCents, 31500);
  });

  test('7 days and 3 hours is an estimate with the flag set', () {
    final booking = build(input(dropoff: TbilisiDateTime(2026, 1, 17, 21)));

    expect(booking.rentalDays, 8);
    expect(booking.isIndividualPrice, true);
    expect(booking.totalPriceCents, 36000);
    expect(booking.totalPrice, 360.0);
  });

  test('the built booking can be stored and read back unchanged', () {
    final booking = build(
      input(
        dropoff: TbilisiDateTime(2026, 1, 15, 20),
        extras: {Extra.childSeat},
      ),
    );
    final stored = Booking.fromMap('new-id', booking.toMap());

    expect(stored.customer, booking.customer);
    expect(stored.pickup, booking.pickup);
    expect(stored.dropoff, booking.dropoff);
    expect(stored.extras, booking.extras);
    expect(stored.totalPriceCents, booking.totalPriceCents);
    expect(stored.status, BookingStatus.newBooking);
  });

  test('throws for an invalid form', () {
    expect(
      () => build(input(dropoff: TbilisiDateTime(2026, 1, 10, 18))),
      throwsArgumentError,
    );
    expect(
      () => build(input(dropoff: TbilisiDateTime(2026, 1, 15, 20), phone: '')),
      throwsArgumentError,
    );
    expect(
      () => build(
        input(
          dropoff: TbilisiDateTime(2026, 1, 15, 20),
          dropoffLocation: const BookingLocation.other('  '),
        ),
      ),
      throwsArgumentError,
    );
  });
}
