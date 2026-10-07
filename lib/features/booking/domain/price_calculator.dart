import 'package:tbilisi_car_rental/core/models/extra.dart';

/// Free time at the end of a rental before another day is charged.
const rentalGracePeriod = Duration(hours: 2);

/// Rentals of up to this many days get the normal calculated price. Longer
/// rentals are flagged: their price is agreed individually.
const standardRentalMaxDays = 7;

const _minutesPerDay = 24 * 60;

/// The result of a price calculation.
class RentalPrice {
  const RentalPrice({required this.days, required this.totalCents});

  /// Charged rental days, at least 1.
  final int days;

  /// The total in whole US cents. Exact; use this for storing and comparing.
  final int totalCents;

  /// The total in US dollars, with at most two decimals.
  double get total => totalCents / 100;

  /// True for rentals longer than [standardRentalMaxDays]: the total is only
  /// an estimate and the final price is agreed individually.
  bool get isIndividualPrice => days > standardRentalMaxDays;

  @override
  bool operator ==(Object other) =>
      other is RentalPrice &&
      other.days == days &&
      other.totalCents == totalCents;

  @override
  int get hashCode => Object.hash(days, totalCents);
}

/// Charged days: max(1, ceil((dropoff - pickup - 2 hours) / 24 hours)).
///
/// Works in whole minutes; seconds are ignored. Both dates must be UTC and
/// [dropoff] must be after [pickup], otherwise an [ArgumentError] is thrown.
int rentalDays({required DateTime pickup, required DateTime dropoff}) {
  if (!pickup.isUtc) {
    throw ArgumentError.value(pickup, 'pickup', 'must be a UTC date');
  }
  if (!dropoff.isUtc) {
    throw ArgumentError.value(dropoff, 'dropoff', 'must be a UTC date');
  }
  if (!dropoff.isAfter(pickup)) {
    throw ArgumentError.value(dropoff, 'dropoff', 'must be after pickup');
  }

  final chargedMinutes =
      dropoff.difference(pickup).inMinutes - rentalGracePeriod.inMinutes;
  if (chargedMinutes <= 0) return 1;

  // Whole-number "round up": 1440 minutes is 1 day, 1441 minutes is 2 days.
  return (chargedMinutes + _minutesPerDay - 1) ~/ _minutesPerDay;
}

/// Total = days * (car price per day + the selected extras' prices per day).
///
/// Prices are in US dollars. The calculation is done in whole cents, so the
/// result has no rounding noise. Throws an [ArgumentError] when a date is
/// invalid (see [rentalDays]), when a price is negative or not a number, or
/// when a selected extra has no price in [extraPricesPerDay].
RentalPrice calculateRentalPrice({
  required DateTime pickup,
  required DateTime dropoff,
  required double carPricePerDay,
  Set<Extra> selectedExtras = const {},
  Map<Extra, double> extraPricesPerDay = const {},
}) {
  final days = rentalDays(pickup: pickup, dropoff: dropoff);

  var centsPerDay = _toCents(carPricePerDay, 'carPricePerDay');
  for (final extra in selectedExtras) {
    final price = extraPricesPerDay[extra];
    if (price == null) {
      throw ArgumentError.value(
        extra,
        'selectedExtras',
        'has no price in extraPricesPerDay',
      );
    }
    centsPerDay += _toCents(price, 'extraPricesPerDay[${extra.name}]');
  }

  return RentalPrice(days: days, totalCents: days * centsPerDay);
}

int _toCents(double price, String name) {
  if (!price.isFinite || price < 0) {
    throw ArgumentError.value(price, name, 'must be a number, 0 or more');
  }
  return (price * 100).round();
}
