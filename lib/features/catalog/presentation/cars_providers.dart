import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/catalog_result.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';

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

/// What the catalog screen shows: the active cars that match the visitor's
/// filter, cheapest first.
final catalogCarsProvider = Provider.autoDispose<AsyncValue<CatalogResult>>((
  ref,
) {
  final filter = ref.watch(carFilterProvider);
  return ref
      .watch(activeCarsProvider)
      .whenData((cars) => buildCatalog(cars, filter: filter));
});
