import 'package:tbilisi_car_rental/core/models/car.dart';

/// The seats filter: Any / 2 / 4 / 5 / 7+.
enum SeatsFilter {
  any,
  two,
  four,
  five,
  sevenPlus;

  bool matches(int seats) => switch (this) {
    SeatsFilter.any => true,
    SeatsFilter.two => seats == 2,
    SeatsFilter.four => seats == 4,
    SeatsFilter.five => seats == 5,
    SeatsFilter.sevenPlus => seats >= 7,
  };
}

/// The visitor's filter choices. A null fuel type or transmission means "Any".
class CarFilter {
  const CarFilter({
    this.seats = SeatsFilter.any,
    this.fuelType,
    this.transmission,
  });

  final SeatsFilter seats;
  final FuelType? fuelType;
  final Transmission? transmission;

  /// How many of the three filters are set (shown on the Filters button).
  int get activeCount =>
      (seats == SeatsFilter.any ? 0 : 1) +
      (fuelType == null ? 0 : 1) +
      (transmission == null ? 0 : 1);

  /// A car matches when all three filters accept it.
  bool matches(Car car) =>
      seats.matches(car.seats) &&
      (fuelType == null || car.fuelType == fuelType) &&
      (transmission == null || car.transmission == transmission);

  /// A copy with a different seats choice; the other two are kept.
  CarFilter withSeats(SeatsFilter seats) =>
      CarFilter(seats: seats, fuelType: fuelType, transmission: transmission);

  /// A copy with a different fuel type (null = Any); the other two are kept.
  CarFilter withFuelType(FuelType? fuelType) =>
      CarFilter(seats: seats, fuelType: fuelType, transmission: transmission);

  /// A copy with a different transmission (null = Any); the other two are
  /// kept.
  CarFilter withTransmission(Transmission? transmission) =>
      CarFilter(seats: seats, fuelType: fuelType, transmission: transmission);

  @override
  bool operator ==(Object other) =>
      other is CarFilter &&
      other.seats == seats &&
      other.fuelType == fuelType &&
      other.transmission == transmission;

  @override
  int get hashCode => Object.hash(seats, fuelType, transmission);
}

/// The cars that match [filter], in their original order.
List<Car> applyCarFilter(List<Car> cars, CarFilter filter) =>
    cars.where(filter.matches).toList();

/// Cheapest first. Cars with the same price are ordered by brand, then model,
/// ignoring letter case. Returns a new list; [cars] is not changed.
List<Car> sortCarsByPrice(List<Car> cars) {
  return [...cars]..sort((a, b) {
    final byPrice = a.pricePerDay.compareTo(b.pricePerDay);
    if (byPrice != 0) return byPrice;
    final byBrand = a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
    if (byBrand != 0) return byBrand;
    return a.model.toLowerCase().compareTo(b.model.toLowerCase());
  });
}
