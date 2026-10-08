import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// Values of a booking that follow from its two dates. They are calculated
/// with the pricing rules and never stored.
extension BookingRental on Booking {
  /// Charged days: one day is 24 hours, with a 2 hour grace period.
  int get rentalDays => _chargedDays(pickup, dropoff);

  /// True for rentals longer than 7 days: the stored total is only an
  /// estimate and the final price is agreed individually.
  bool get isIndividualPrice => rentalDays > standardRentalMaxDays;
}

/// The calculator's rentalDays function. Inside the extension that name means
/// the getter, so the function is called from here.
int _chargedDays(DateTime pickup, DateTime dropoff) =>
    rentalDays(pickup: pickup, dropoff: dropoff);
