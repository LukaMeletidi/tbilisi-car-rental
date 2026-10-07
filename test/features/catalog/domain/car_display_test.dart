import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';

void main() {
  test('carTitle is "Brand Model, year"', () {
    const car = Car(
      id: 'id',
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
    expect(carTitle(car), 'Toyota Prius, 2019');
  });

  group('formatPrice', () {
    test('shows a whole price without decimals', () {
      expect(formatPrice(45), '45');
      expect(formatPrice(120.0), '120');
    });

    test('shows a price with a fraction with two decimals', () {
      expect(formatPrice(45.5), '45.50');
      expect(formatPrice(45.4), '45.40');
      expect(formatPrice(45.99), '45.99');
    });
  });

  group('formatEngineSize', () {
    test('shows one decimal and the unit', () {
      expect(formatEngineSize(1.8), '1.8 L');
      expect(formatEngineSize(2), '2.0 L');
      expect(formatEngineSize(2.4), '2.4 L');
    });

    test('rounds to one decimal', () {
      expect(formatEngineSize(1.84), '1.8 L');
      expect(formatEngineSize(1.96), '2.0 L');
    });
  });

  test('drivetrainLabel is always uppercase', () {
    expect(drivetrainLabel(Drivetrain.fwd), 'FWD');
    expect(drivetrainLabel(Drivetrain.rwd), 'RWD');
    expect(drivetrainLabel(Drivetrain.awd), 'AWD');
  });
}
