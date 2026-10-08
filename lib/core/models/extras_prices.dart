import 'package:tbilisi_car_rental/core/models/extra.dart';

/// The per-day prices of the extras, from the document settings/extras.
/// A value of this type always has a valid price for every extra.
class ExtrasPrices {
  ExtrasPrices._(Map<Extra, double> pricesPerDay)
    : pricesPerDay = Map.unmodifiable(pricesPerDay);

  /// Reads the document settings/extras. [data] is null when the document
  /// does not exist. Throws a [FormatException] unless every extra has a
  /// price that is a number of 0 or more. There are no default prices.
  factory ExtrasPrices.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      throw const FormatException('settings/extras does not exist.');
    }
    final raw = data['pricesPerDay'];
    if (raw is! Map) {
      throw FormatException(
        'settings/extras: "pricesPerDay" must be a map, '
        'got ${raw.runtimeType}.',
      );
    }

    final knownNames = {for (final extra in Extra.values) extra.name};
    for (final key in raw.keys) {
      if (!knownNames.contains(key)) {
        throw FormatException(
          'settings/extras: unknown extra "$key" '
          '(allowed: ${knownNames.join(', ')}).',
        );
      }
    }

    final prices = <Extra, double>{};
    for (final extra in Extra.values) {
      final value = raw[extra.name];
      if (value is! num) {
        throw FormatException(
          'settings/extras: the price of "${extra.name}" is missing or '
          'not a number.',
        );
      }
      final price = value.toDouble();
      if (!price.isFinite || price < 0) {
        throw FormatException(
          'settings/extras: the price of "${extra.name}" must be 0 or '
          'more, got $value.',
        );
      }
      prices[extra] = price;
    }
    return ExtrasPrices._(prices);
  }

  /// Price per day in USD for every extra. Cannot be changed.
  final Map<Extra, double> pricesPerDay;

  double priceOf(Extra extra) => pricesPerDay[extra]!;

  @override
  bool operator ==(Object other) =>
      other is ExtrasPrices &&
      Extra.values.every((extra) => other.priceOf(extra) == priceOf(extra));

  @override
  int get hashCode =>
      Object.hashAll([for (final extra in Extra.values) priceOf(extra)]);
}
