// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tbilisi Car Rental';

  @override
  String get languageLabel => 'Language';

  @override
  String get catalogEmpty => 'No cars available yet';

  @override
  String get catalogError => 'Could not load the cars. Please try again later.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noPhoto => 'No photo';

  @override
  String pricePerDay(String price) {
    return '\$$price / day';
  }

  @override
  String seatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get transmissionAutomatic => 'Automatic';

  @override
  String get transmissionManual => 'Manual';

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelElectric => 'Electric';

  @override
  String get filters => 'Filters';

  @override
  String filtersWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get filterSeats => 'Seats';

  @override
  String get filterFuelType => 'Fuel type';

  @override
  String get filterTransmission => 'Transmission';

  @override
  String get filterAny => 'Any';

  @override
  String get filterReset => 'Reset';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get catalogNoMatch => 'No cars match your filters';

  @override
  String showCars(int count) {
    return 'Show cars ($count)';
  }

  @override
  String get searchHint => 'Brand or model';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get catalogNoSearchMatch => 'No cars match your search';

  @override
  String get makeBooking => 'Make a booking';

  @override
  String get bookingComingSoon => 'Online booking is coming soon';

  @override
  String get carNotAvailable => 'This car is not available';

  @override
  String get backToCars => 'Back to the cars';

  @override
  String get carError => 'Could not load the car. Please try again later.';

  @override
  String get descriptionTitle => 'Description';

  @override
  String photoPosition(int current, int total) {
    return 'Photo $current of $total';
  }

  @override
  String get bookingTitle => 'Booking request';

  @override
  String get bookingSectionContact => 'Your details';

  @override
  String get bookingFullName => 'Full name and surname';

  @override
  String get bookingFullNameHelper => 'As in your passport';

  @override
  String get bookingPhone => 'Phone number';

  @override
  String get bookingWhatsapp => 'I use WhatsApp on this number';

  @override
  String get bookingTelegram => 'I use Telegram on this number';

  @override
  String get bookingEmail => 'E-mail';

  @override
  String get bookingSectionDates => 'Dates';

  @override
  String get bookingPickupDateTime => 'Pickup date and time';

  @override
  String get bookingDropoffDateTime => 'Dropoff date and time';

  @override
  String get tbilisiTimeLabel => 'Tbilisi time (GMT+4)';

  @override
  String get bookingSectionLocations => 'Places';

  @override
  String get bookingPickupLocation => 'Pickup place';

  @override
  String get bookingDropoffLocation => 'Dropoff place';

  @override
  String get bookingLocationOther => 'Other place';

  @override
  String get bookingLocationOtherText => 'Address or place in Georgia';

  @override
  String get bookingSectionExtras => 'Extras';

  @override
  String get extraSnowChains => 'Snow chains';

  @override
  String get extraChildSeat => 'Child seat';

  @override
  String get extraChildSeatAge => '1–4 years';

  @override
  String get extraInfantSeat => 'Infant seat';

  @override
  String get extraInfantSeatAge => '0–12 months';

  @override
  String get extraBoosterSeat => 'Booster seat';

  @override
  String get extraBoosterSeatAge => '3–16 years';

  @override
  String get extraFree => 'Free';

  @override
  String get bookingSectionNotes => 'Special requests';

  @override
  String get bookingNotesHint => 'Optional. For example: two child seats';

  @override
  String get bookingSectionPrice => 'Price';

  @override
  String get bookingChooseDates => 'Choose the dates to see the price';

  @override
  String get bookingRentalDays => 'Rental days';

  @override
  String get bookingTotal => 'Total';

  @override
  String get bookingEstimatedTotal => 'Estimated total';

  @override
  String bookingIndividualPriceNote(int days) {
    return 'For rentals longer than $days days, the price is individual — our team will contact you to confirm the final price.';
  }

  @override
  String get bookingSubmit => 'Send request';

  @override
  String get bookingSending => 'Sending…';

  @override
  String get bookingCheckFields => 'Please check the marked fields';

  @override
  String get bookingFormLoadError =>
      'Could not load the booking form. Please try again later.';

  @override
  String get bookingErrorNameRequired => 'Enter your full name';

  @override
  String get bookingErrorNameTooShort => 'The name is too short';

  @override
  String bookingErrorTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String get bookingErrorPhoneRequired => 'Enter your phone number';

  @override
  String bookingErrorPhoneInvalid(String example) {
    return 'Use the international format, for example $example';
  }

  @override
  String get bookingErrorEmailRequired => 'Enter your e-mail';

  @override
  String get bookingErrorEmailInvalid => 'Enter a valid e-mail address';

  @override
  String get bookingErrorPickupRequired => 'Choose the pickup date and time';

  @override
  String get bookingErrorPickupNotInFuture =>
      'The pickup time must be in the future';

  @override
  String get bookingErrorDropoffRequired => 'Choose the dropoff date and time';

  @override
  String get bookingErrorDropoffNotAfterPickup =>
      'The dropoff must be later than the pickup';

  @override
  String bookingErrorRentalTooLong(int days) {
    return 'A rental can be at most $days days';
  }

  @override
  String get bookingErrorLocationRequired => 'Choose a place';

  @override
  String get bookingErrorLocationUnknown =>
      'This place is no longer available. Choose another one.';

  @override
  String get bookingErrorLocationTextRequired => 'Enter the address or place';

  @override
  String get bookingFailedRejected =>
      'The request was not accepted. Check your details and the dates, or choose another car.';

  @override
  String get bookingFailedNoConnection =>
      'Could not send the request. Check your internet connection and try again.';

  @override
  String get bookingFailedUnknown => 'Something went wrong. Please try again.';

  @override
  String get bookingSentThanks =>
      'Thank you for your trust — our representative will contact you shortly to confirm the details.';
}
