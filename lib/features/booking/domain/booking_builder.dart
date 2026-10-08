import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// Builds the booking to create from a valid form: Tbilisi times become UTC,
/// texts are cleaned, and the total is calculated once and stored.
///
/// For rentals longer than 7 days the total is an estimate; the booking's
/// isIndividualPrice (see booking_rental.dart) is then true.
///
/// Throws an [ArgumentError] when the form is not valid. Call
/// [validateBookingForm] first and show its errors to the user.
Booking buildBooking({
  required BookingFormInput input,
  required Car car,
  required ExtrasPrices extrasPrices,
  required List<PickupLocation> locations,
  required AppLanguage language,
  required DateTime now,
}) {
  final errors = validateBookingForm(
    input,
    car: car,
    locations: locations,
    now: now,
  );
  if (errors.isNotEmpty) {
    throw ArgumentError.value(errors, 'input', 'the booking form is not valid');
  }

  final pickup = input.pickup!.toUtc();
  final dropoff = input.dropoff!.toUtc();
  final price = calculateRentalPrice(
    pickup: pickup,
    dropoff: dropoff,
    carPricePerDay: car.pricePerDay,
    selectedExtras: input.extras,
    extraPricesPerDay: extrasPrices.pricesPerDay,
  );

  return Booking(
    customer: BookingCustomer(
      fullName: input.fullName.trim(),
      phone: normalizePhone(input.phone)!,
      whatsapp: input.whatsapp,
      telegram: input.telegram,
      email: input.email.trim(),
    ),
    carId: car.id,
    pickup: pickup,
    dropoff: dropoff,
    pickupLocation: _cleaned(input.pickupLocation!),
    dropoffLocation: _cleaned(input.dropoffLocation!),
    extras: Set.unmodifiable(input.extras),
    notes: input.notes.trim(),
    // From the calculator's exact cents, so there is no rounding noise.
    totalPrice: price.totalCents / 100,
    language: language,
    status: BookingStatus.newBooking,
  );
}

BookingLocation _cleaned(BookingLocation location) =>
    location.isOther ? BookingLocation.other(location.text!.trim()) : location;
