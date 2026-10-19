/// The Extras & Prices form (step 6.6): a typed price per extra, its
/// problem, and the prices to save. Pure Dart. The same rule as the car
/// price: digits, at most two decimals, a comma counts as the point.
library;

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

/// What is wrong with a typed price.
enum ExtraPriceProblem {
  /// Nothing typed: every extra needs a price (0 is "Free").
  required,

  /// Not a number of the allowed shape (a letter, a minus sign, more than
  /// two decimals).
  invalid,

  /// Above extraMaxPricePerDay.
  tooHigh,
}

/// The problem of the typed price [text], or null when it is valid.
ExtraPriceProblem? extraPriceProblem(String text) {
  if (text.trim().isEmpty) return ExtraPriceProblem.required;
  final price = parseDecimalInput(text);
  if (price == null) return ExtraPriceProblem.invalid;
  if (price > extraMaxPricePerDay) return ExtraPriceProblem.tooHigh;
  return null;
}

/// The text of a stored price in the form: "5", "4.5"; a stored price with
/// more decimals is shown in full, so that its problem is reported instead
/// of the price being changed silently (formatDecimalInput).
String extraPriceText(double price) => formatDecimalInput(price);

/// The prices to save from the typed [input], one text per extra. Throws an
/// [ArgumentError] when an extra is missing or a text has a problem.
ExtrasPrices extrasPricesFromInput(Map<Extra, String> input) {
  for (final extra in Extra.values) {
    final text = input[extra];
    if (text == null || extraPriceProblem(text) != null) {
      throw ArgumentError('The price of ${extra.name} has a problem.');
    }
  }
  return ExtrasPrices.fromMap({
    'pricesPerDay': {
      for (final extra in Extra.values)
        extra.name: parseDecimalInput(input[extra]!)!,
    },
  });
}
