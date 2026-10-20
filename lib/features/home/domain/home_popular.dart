import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';

/// The cars of the "popular" block on Home: the visible cars that the admin
/// marked, in the catalog order (cheapest first, then brand and model,
/// ignoring letter case), at most [homePopularMax].
///
/// The ID is the last tie-break, so two cars with the same price, brand and
/// model never swap places between two loads.
List<Car> selectHomePopularCars(List<Car> cars) {
  final popular = [
    for (final car in cars)
      if (car.active && car.popular) car,
  ];
  popular.sort((a, b) {
    final byPrice = a.pricePerDay.compareTo(b.pricePerDay);
    if (byPrice != 0) return byPrice;
    final byBrand = a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
    if (byBrand != 0) return byBrand;
    final byModel = a.model.toLowerCase().compareTo(b.model.toLowerCase());
    if (byModel != 0) return byModel;
    return a.id.compareTo(b.id);
  });
  return List.unmodifiable(popular.take(homePopularMax));
}
