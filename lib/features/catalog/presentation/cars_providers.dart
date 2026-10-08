import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/catalog_result.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_search_provider.dart';

/// Live list of active cars, as loaded from Firestore (not yet sorted or
/// filtered). Auto-dispose: the Firestore listener closes when no screen
/// watches it.
///
/// Automatic retry is off: the usual failure is "permission denied", which
/// retrying cannot fix. The screen shows an error with a "Try again" button.
final activeCarsProvider = StreamProvider.autoDispose<List<Car>>(
  (ref) => ref.watch(carRepositoryProvider).watchActiveCars(),
  retry: (retryCount, error) => null,
);

/// Live data of one car by its ID, for the detail screen. In the error state
/// the error is a CarNotAvailableException when the car cannot be shown.
final carProvider = StreamProvider.autoDispose.family<Car, String>(
  (ref, carId) => ref.watch(carRepositoryProvider).watchCar(carId),
  retry: (retryCount, error) => null,
);

/// What the catalog screen shows: the active cars that match the visitor's
/// filter and search text, cheapest first.
final catalogCarsProvider = Provider.autoDispose<AsyncValue<CatalogResult>>((
  ref,
) {
  final filter = ref.watch(carFilterProvider);
  final searchQuery = ref.watch(carSearchProvider);
  return ref
      .watch(activeCarsProvider)
      .whenData(
        (cars) => buildCatalog(cars, filter: filter, searchQuery: searchQuery),
      );
});
