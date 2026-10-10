import 'dart:async';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';

/// Stands in for Firestore in tests of the admin bookings list. Nothing
/// here contacts Firebase, and every value in the tests is made up.
class FakeAdminBookingsRepository implements AdminBookingsRepository {
  /// Every query that was started, with the limit it asked for.
  final limits = <int>[];

  final _controllers = <StreamController<RawBookingsResult>>[];

  /// How many queries are being listened to right now.
  var activeListeners = 0;

  /// How often the cars were read.
  var carReads = 0;

  /// What readAllCars answers.
  List<Car> cars = const [];

  /// When set, readAllCars fails with it.
  Object? carsError;

  /// When set, readAllCars waits for it.
  Completer<void>? carsPending;

  /// Makes the newest query answer with [documents].
  void emit(List<RawBookingDocument> documents, {bool fromCache = false}) {
    _controllers.last.add(
      RawBookingsResult(documents: documents, fromCache: fromCache),
    );
  }

  /// Makes the newest query fail with [error].
  void fail(Object error) => _controllers.last.addError(error);

  @override
  Stream<RawBookingsResult> watchNewestBookings({required int limit}) {
    limits.add(limit);
    final controller = StreamController<RawBookingsResult>(
      onListen: () => activeListeners += 1,
      onCancel: () => activeListeners -= 1,
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<List<Car>> readAllCars() async {
    carReads += 1;
    if (carsPending != null) await carsPending!.future;
    if (carsError != null) throw carsError!;
    return cars;
  }
}

/// A raw booking document as the repository hands it on: the dates are
/// already UTC DateTime values. Every value is made up.
RawBookingDocument rawBooking(
  String id, {
  String fullName = 'Test Person',
  String phone = '+995555000000',
  String carId = 'car-1',
  DateTime? pickup,
  DateTime? dropoff,
  String status = 'new',
  num totalPrice = 225,
  DateTime? createdAt,
  Map<String, dynamic> changes = const {},
}) {
  return (
    id: id,
    data: {
      'customer': {
        'fullName': fullName,
        'phone': phone,
        'whatsapp': false,
        'telegram': false,
        'email': 'person@example.com',
      },
      'carId': carId,
      // 18:00 and 20:00 in Tbilisi.
      'pickupDateTime': pickup ?? DateTime.utc(2026, 1, 10, 14),
      'dropoffDateTime': dropoff ?? DateTime.utc(2026, 1, 15, 16),
      'pickupLocation': {'id': 'tbilisiAirport'},
      'dropoffLocation': {'id': 'tbilisiOffice'},
      'extras': <String>[],
      'notes': '',
      'totalPrice': totalPrice,
      'language': 'en',
      'status': status,
      // 17:34 in Tbilisi.
      'createdAt': createdAt ?? DateTime.utc(2026, 10, 9, 13, 34),
      ...changes,
    },
  );
}

/// A made-up car for the tests.
Car testCar({String id = 'car-1', bool active = true}) {
  return Car(
    id: id,
    brand: 'Toyota',
    model: 'Prius',
    year: 2019,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: FuelType.hybrid,
    seats: 5,
    engineSize: 1.8,
    pricePerDay: 45,
    description: const LocalizedText(),
    photos: const [],
    active: active,
  );
}
