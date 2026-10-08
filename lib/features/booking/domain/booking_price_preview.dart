import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// The days and the total to show while the form is being filled in.
///
/// Null while there is nothing to calculate: a date is missing, the dropoff
/// is not after the pickup, or the rental is longer than
/// [bookingMaxRentalDays]. Other problems of the form (for example an empty
/// name or a pickup in the past) do not hide the price.
RentalPrice? previewRentalPrice({
  required BookingFormInput input,
  required Car car,
  required ExtrasPrices extrasPrices,
}) {
  final pickup = input.pickup?.toUtc();
  final dropoff = input.dropoff?.toUtc();
  if (pickup == null || dropoff == null) return null;
  if (!dropoff.isAfter(pickup)) return null;
  if (dropoff.difference(pickup) > const Duration(days: bookingMaxRentalDays)) {
    return null;
  }
  return calculateRentalPrice(
    pickup: pickup,
    dropoff: dropoff,
    carPricePerDay: car.pricePerDay,
    selectedExtras: input.extras,
    extraPricesPerDay: extrasPrices.pricesPerDay,
  );
}
