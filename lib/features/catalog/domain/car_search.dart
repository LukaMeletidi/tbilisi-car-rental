import 'package:tbilisi_car_rental/core/models/car.dart';

final _whitespace = RegExp(r'\s+');

/// Whether [car] matches the search text [query].
///
/// The query is split into words. Every word must be contained in
/// "brand model", ignoring letter case. An empty query matches every car.
bool matchesCarSearch(Car car, String query) {
  final words = query
      .toLowerCase()
      .split(_whitespace)
      .where((word) => word.isNotEmpty);
  final text = '${car.brand} ${car.model}'.toLowerCase();
  return words.every(text.contains);
}

/// The cars that match [query], in their original order.
List<Car> applyCarSearch(List<Car> cars, String query) =>
    cars.where((car) => matchesCarSearch(car, query)).toList();
