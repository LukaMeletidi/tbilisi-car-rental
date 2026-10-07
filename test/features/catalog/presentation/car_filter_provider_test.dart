import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  CarFilter filter() => container.read(carFilterProvider);
  CarFilterNotifier notifier() => container.read(carFilterProvider.notifier);

  test('starts with no filter set', () {
    expect(filter(), const CarFilter());
    expect(filter().activeCount, 0);
  });

  test('setting one field keeps the other two', () {
    notifier().setSeats(SeatsFilter.five);
    notifier().setFuelType(FuelType.hybrid);
    notifier().setTransmission(Transmission.automatic);

    expect(
      filter(),
      const CarFilter(
        seats: SeatsFilter.five,
        fuelType: FuelType.hybrid,
        transmission: Transmission.automatic,
      ),
    );

    notifier().setSeats(SeatsFilter.sevenPlus);

    expect(filter().seats, SeatsFilter.sevenPlus);
    expect(filter().fuelType, FuelType.hybrid);
    expect(filter().transmission, Transmission.automatic);
  });

  test('fuel type and transmission can be set back to Any', () {
    notifier().setFuelType(FuelType.diesel);
    notifier().setTransmission(Transmission.manual);

    notifier().setFuelType(null);
    expect(filter().fuelType, isNull);
    expect(filter().transmission, Transmission.manual);

    notifier().setTransmission(null);
    expect(filter(), const CarFilter());
  });

  test('reset clears every filter', () {
    notifier().setSeats(SeatsFilter.two);
    notifier().setFuelType(FuelType.petrol);
    notifier().setTransmission(Transmission.manual);

    notifier().reset();

    expect(filter(), const CarFilter());
  });
}
