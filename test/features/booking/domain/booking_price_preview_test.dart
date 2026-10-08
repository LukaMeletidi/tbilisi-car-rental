import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_price_preview.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

const car = Car(
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
  description: LocalizedText(),
  photos: [],
  active: true,
);

final extrasPrices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 4.5,
    'boosterSeat': 3,
  },
});

/// Pickup on the 10th at 18:00 Tbilisi time, as in the plan's examples.
final pickup = TbilisiDateTime(2026, 1, 10, 18);

RentalPrice? preview(BookingFormInput input) =>
    previewRentalPrice(input: input, car: car, extrasPrices: extrasPrices);

void main() {
  test('no preview without both dates', () {
    expect(preview(const BookingFormInput()), isNull);
    expect(preview(BookingFormInput(pickup: pickup)), isNull);
    expect(
      preview(BookingFormInput(dropoff: TbilisiDateTime(2026, 1, 15, 20))),
      isNull,
    );
  });

  test('no preview when the dropoff is not after the pickup', () {
    expect(preview(BookingFormInput(pickup: pickup, dropoff: pickup)), isNull);
    expect(
      preview(
        BookingFormInput(
          pickup: pickup,
          dropoff: TbilisiDateTime(2026, 1, 9, 18),
        ),
      ),
      isNull,
    );
  });

  test('exactly 365 days has a preview; one minute more has none', () {
    final lastMoment = TbilisiDateTime(2027, 1, 10, 18);
    expect(
      preview(BookingFormInput(pickup: pickup, dropoff: lastMoment))!.days,
      365,
    );
    expect(
      preview(
        BookingFormInput(
          pickup: pickup,
          dropoff: TbilisiDateTime(2027, 1, 10, 18, 1),
        ),
      ),
      isNull,
    );
  });

  test('5 days times the car price', () {
    final price = preview(
      BookingFormInput(
        pickup: pickup,
        dropoff: TbilisiDateTime(2026, 1, 15, 20),
      ),
    )!;
    expect(price.days, 5);
    expect(price.totalCents, 22500);
    expect(price.isIndividualPrice, false);
  });

  test('one minute after the grace period is one more day', () {
    final price = preview(
      BookingFormInput(
        pickup: pickup,
        dropoff: TbilisiDateTime(2026, 1, 15, 20, 1),
      ),
    )!;
    expect(price.days, 6);
    expect(price.totalCents, 27000);
  });

  test('selected extras are added per day', () {
    final price = preview(
      BookingFormInput(
        pickup: pickup,
        dropoff: TbilisiDateTime(2026, 1, 15, 20),
        extras: const {Extra.snowChains, Extra.infantSeat},
      ),
    )!;
    // 5 days * (45 + 5 + 4.50) = 272.50
    expect(price.totalCents, 27250);
  });

  test('exactly 7 days is a normal price; 7 days and 3 hours is not', () {
    final sevenDays = preview(
      BookingFormInput(
        pickup: pickup,
        dropoff: TbilisiDateTime(2026, 1, 17, 18),
      ),
    )!;
    expect(sevenDays.days, 7);
    expect(sevenDays.isIndividualPrice, false);

    final longer = preview(
      BookingFormInput(
        pickup: pickup,
        dropoff: TbilisiDateTime(2026, 1, 17, 21),
      ),
    )!;
    expect(longer.days, 8);
    expect(longer.isIndividualPrice, true);
    expect(longer.totalCents, 36000);
  });

  test('other problems of the form do not hide the price', () {
    // No name, no phone, and a pickup that may already be in the past.
    final price = preview(
      BookingFormInput(
        pickup: TbilisiDateTime(2020, 1, 10, 18),
        dropoff: TbilisiDateTime(2020, 1, 11, 18),
      ),
    );
    expect(price!.days, 1);
    expect(price.totalCents, 4500);
  });
}
