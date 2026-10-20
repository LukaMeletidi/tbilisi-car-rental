import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/home/domain/home_popular.dart';

/// The popular cars that Home shows, from the live list of active cars that
/// the catalog uses too: no query of its own and no index.
///
/// Empty while the first list loads and when it fails before any list came:
/// the block is a bonus, so Home then simply hides it (the catalog shows the
/// error and "Try again"). After a later failure the last list stays.
final homePopularCarsProvider = Provider.autoDispose<List<Car>>((ref) {
  final cars = ref.watch(activeCarsProvider).value;
  return cars == null ? const [] : selectHomePopularCars(cars);
});
