import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_filter.dart';

/// The visitor's current filter choices.
///
/// Not auto-dispose on purpose: the choices are kept while the app runs, also
/// when the visitor leaves the catalog and comes back. They are not saved, so
/// a restart of the app starts without filters.
class CarFilterNotifier extends Notifier<CarFilter> {
  @override
  CarFilter build() => const CarFilter();

  void setSeats(SeatsFilter seats) => state = state.withSeats(seats);

  /// null = Any.
  void setFuelType(FuelType? fuelType) => state = state.withFuelType(fuelType);

  /// null = Any.
  void setTransmission(Transmission? transmission) =>
      state = state.withTransmission(transmission);

  void reset() => state = const CarFilter();
}

final carFilterProvider = NotifierProvider<CarFilterNotifier, CarFilter>(
  CarFilterNotifier.new,
);
