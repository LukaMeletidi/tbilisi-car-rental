import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_search.dart';

/// What the catalog screen shows.
class CatalogResult {
  const CatalogResult({required this.cars, required this.totalActive});

  /// The cars to show: filtered, searched, cheapest first.
  final List<Car> cars;

  /// How many active cars exist before filtering and searching. 0 means there
  /// are no cars at all, which is a different message from "no car matches".
  final int totalActive;
}

CatalogResult buildCatalog(
  List<Car> activeCars, {
  CarFilter filter = const CarFilter(),
  String searchQuery = '',
}) {
  final matching = applyCarSearch(
    applyCarFilter(activeCars, filter),
    searchQuery,
  );
  return CatalogResult(
    cars: sortCarsByPrice(matching),
    totalActive: activeCars.length,
  );
}
