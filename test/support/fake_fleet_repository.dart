import 'dart:async';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// Stands in for the fleet repository in tests. Nothing here contacts
/// Firebase. Only the live list is faked; the writes are not used by the
/// screens yet and fail the test when called.
class FakeFleetRepository implements FleetRepository {
  final _controllers = <StreamController<RawCarsResult>>[];

  /// How many cars queries were started.
  var queries = 0;

  /// How many cars queries are being listened to right now.
  var activeListeners = 0;

  /// Makes the newest query answer with [documents].
  void emit(List<FleetRawDocument> documents, {bool fromCache = false}) {
    _controllers.last.add(
      RawCarsResult(documents: documents, fromCache: fromCache),
    );
  }

  /// Makes the newest query fail with [error].
  void fail(Object error) => _controllers.last.addError(error);

  @override
  Stream<RawCarsResult> watchAllCars() {
    queries += 1;
    final controller = StreamController<RawCarsResult>(
      onListen: () => activeListeners += 1,
      onCancel: () => activeListeners -= 1,
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  String newCarId() => throw UnimplementedError('not used yet');

  @override
  Future<CarCreateResult> createCar(
    Car car, {
    Duration timeout = carWriteTimeout,
  }) => throw UnimplementedError('not used yet');

  @override
  Future<void> replaceCar(
    Car car, {
    required Car base,
    Duration timeout = carWriteTimeout,
  }) => throw UnimplementedError('not used yet');

  @override
  Future<void> setCarActive(
    String id, {
    required bool active,
    Duration timeout = carWriteTimeout,
  }) => throw UnimplementedError('not used yet');
}

/// The stored fields of a complete car, as an admin save writes them. All
/// values are made up. [change] edits a copy.
Map<String, dynamic> rawCar({
  String brand = 'Honda',
  String model = 'Civic',
  bool active = true,
  void Function(Map<String, dynamic> data)? change,
}) {
  final data = <String, dynamic>{
    'brand': brand,
    'model': model,
    'year': 2019,
    'drivetrain': 'fwd',
    'transmission': 'automatic',
    'fuelType': 'petrol',
    'seats': 5,
    'engineSize': 1.8,
    'pricePerDay': 45.0,
    'description': {'ka': 'ქართული', 'ru': 'Русский', 'en': 'English'},
    'photos': <String>[],
    'active': active,
  };
  change?.call(data);
  return data;
}
