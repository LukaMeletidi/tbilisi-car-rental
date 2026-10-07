import 'package:tbilisi_car_rental/core/models/car.dart';

/// "Toyota Prius, 2019".
String carTitle(Car car) => '${car.brand} ${car.model}, ${car.year}';

/// A price without the currency sign. A whole price has no decimals:
/// 45.0 -> "45". A price with a fraction has two: 45.5 -> "45.50".
String formatPrice(double amount) {
  final cents = (amount * 100).round();
  if (cents % 100 == 0) return (cents ~/ 100).toString();
  return (cents / 100).toStringAsFixed(2);
}

/// An engine size in litres with one decimal: 1.8 -> "1.8 L", 2 -> "2.0 L".
String formatEngineSize(double litres) => '${litres.toStringAsFixed(1)} L';

/// The drivetrain is stored in lowercase and always shown in uppercase.
String drivetrainLabel(Drivetrain drivetrain) => drivetrain.name.toUpperCase();
