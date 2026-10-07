import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';

/// What the catalog screen shows.
class CatalogResult {
  const CatalogResult({required this.cars, required this.totalActive});

  /// The cars to show: filtered, cheapest first.
  final List<Car> cars;

  /// How many active cars exist before filtering. 0 means there are no cars
  /// at all, which is a different message from "no car matches the filters".
  final int totalActive;
}

CatalogResult buildCatalog(
  List<Car> activeCars, {
  CarFilter filter = const CarFilter(),
}) {
  return CatalogResult(
    cars: sortCarsByPrice(applyCarFilter(activeCars, filter)),
    totalActive: activeCars.length,
  );
}
