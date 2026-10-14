/// The number fields of the car form (price per day, engine size): from the
/// typed text to a number and back. Pure Dart.
library;

final _decimalInput = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');

/// "45", "45.5", "45.50": digits, then at most two decimals. A comma is
/// taken as the decimal point, because Georgian and Russian keyboards offer
/// it. Spaces at either end are ignored. Null when empty or not a number of
/// that shape.
double? parseDecimalInput(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!_decimalInput.hasMatch(value)) return null;
  return double.parse(value);
}

/// A stored number for a text field: "45" for 45.0, "45.5" for 45.5, "1.75"
/// for 1.75; never a trailing zero.
///
/// A value with MORE than two decimals (possible only in a car typed by hand
/// in the console, for example 45.555) is shown in full, not rounded: the
/// validation then reports it, instead of a save changing the price without
/// anybody noticing.
String formatDecimalInput(double value) {
  final fixed = value.toStringAsFixed(2);
  if (double.parse(fixed) != value) return value.toString();
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}
