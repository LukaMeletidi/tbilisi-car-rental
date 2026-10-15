import 'dart:async';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// Stands in for the fleet repository in tests. Nothing here contacts
/// Firebase. The live reads are faked with stream controllers; the writes
/// record their calls and answer as the test says. createCar is not used
/// by the screens yet and fails the test when called.
class FakeFleetRepository implements FleetRepository {
  final _controllers = <StreamController<RawCarsResult>>[];
  final _carControllers = <StreamController<RawCarAnswer>>[];

  /// How many cars queries were started.
  var queries = 0;

  /// How many cars queries are being listened to right now.
  var activeListeners = 0;

  /// The IDs of the single-car reads that were started, in order.
  final carReads = <String>[];

  /// How many single-car reads are being listened to right now.
  var activeCarListeners = 0;

  /// The calls of replaceCar: the car to write and its base.
  final replaced = <({Car car, Car base})>[];

  /// The calls of setCarActive.
  final activeChanges = <({String id, bool active})>[];

  /// What replaceCar does: null returns normally (saved); otherwise it
  /// throws this error (CarWriteNoAnswer or a CarWriteException).
  Object? replaceError;

  /// What setCarActive does, as [replaceError].
  Object? setActiveError;

  /// When set, a write waits for it before it answers.
  Completer<void>? writeGate;

  /// Makes the newest query answer with [documents].
  void emit(List<FleetRawDocument> documents, {bool fromCache = false}) {
    _controllers.last.add(
      RawCarsResult(documents: documents, fromCache: fromCache),
    );
  }

  /// Makes the newest query fail with [error].
  void fail(Object error) => _controllers.last.addError(error);

  /// Makes the newest single-car read answer with [data] (null: no such
  /// document).
  void emitCar(
    String id,
    Map<String, dynamic>? data, {
    bool fromCache = false,
  }) {
    _carControllers.last.add(
      RawCarAnswer(
        document: data == null ? null : (id: id, data: data),
        fromCache: fromCache,
      ),
    );
  }

  /// Makes the newest single-car read fail with [error].
  void failCar(Object error) => _carControllers.last.addError(error);

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
  Stream<RawCarAnswer> watchCar(String id) {
    carReads.add(id);
    final controller = StreamController<RawCarAnswer>(
      onListen: () => activeCarListeners += 1,
      onCancel: () => activeCarListeners -= 1,
    );
    _carControllers.add(controller);
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
  }) async {
    replaced.add((car: car, base: base));
    await writeGate?.future;
    final error = replaceError;
    if (error != null) throw error;
  }

  @override
  Future<void> setCarActive(
    String id, {
    required bool active,
    Duration timeout = carWriteTimeout,
  }) async {
    activeChanges.add((id: id, active: active));
    await writeGate?.future;
    final error = setActiveError;
    if (error != null) throw error;
  }
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
