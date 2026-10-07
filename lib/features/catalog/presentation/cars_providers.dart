import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/catalog_result.dart';

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

/// What the catalog screen shows: the active cars, cheapest first.
/// Step 1.7 passes the visitor's filter to buildCatalog here.
final catalogCarsProvider = Provider.autoDispose<AsyncValue<CatalogResult>>(
  (ref) => ref.watch(activeCarsProvider).whenData(buildCatalog),
);
