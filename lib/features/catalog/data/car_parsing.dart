import 'package:tbilisi_car_rental/core/models/car.dart';

/// A Firestore document reduced to plain Dart: its ID and its fields.
typedef RawCarDocument = ({String id, Map<String, dynamic> data});

/// Turns raw documents into cars, keeping their order. A document that cannot
/// be read as a car is left out and reported to [onSkipped]; it never stops
/// the other cars from loading.
List<Car> parseCars(
  List<RawCarDocument> documents, {
  void Function(String id, Object error, StackTrace stackTrace)? onSkipped,
}) {
  final cars = <Car>[];
  for (final document in documents) {
    try {
      cars.add(Car.fromMap(document.id, document.data));
    } catch (error, stackTrace) {
      onSkipped?.call(document.id, error, stackTrace);
    }
  }
  return cars;
}
