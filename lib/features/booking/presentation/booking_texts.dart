/// The texts of the booking form that depend on a value: which error, which
/// extra, which failure. Every number in a text comes from a constant in
/// booking_limits.dart or price_calculator.dart.
library;

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_create_exception.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_display.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The text shown for [error].
String bookingErrorText(AppLocalizations l10n, BookingFormError error) {
  switch (error) {
    case BookingFormError.carNotAvailable:
      return l10n.carNotAvailable;
    case BookingFormError.nameRequired:
      return l10n.bookingErrorNameRequired;
    case BookingFormError.nameTooShort:
      return l10n.bookingErrorNameTooShort;
    case BookingFormError.nameTooLong:
      return l10n.bookingErrorTooLong(bookingNameMaxLength);
    case BookingFormError.phoneRequired:
      return l10n.bookingErrorPhoneRequired;
    case BookingFormError.phoneInvalid:
      return l10n.bookingErrorPhoneInvalid(bookingPhoneExample);
    case BookingFormError.emailRequired:
      return l10n.bookingErrorEmailRequired;
    case BookingFormError.emailInvalid:
      return l10n.bookingErrorEmailInvalid;
    case BookingFormError.emailTooLong:
      return l10n.bookingErrorTooLong(bookingEmailMaxLength);
    case BookingFormError.pickupRequired:
      return l10n.bookingErrorPickupRequired;
    case BookingFormError.pickupNotInFuture:
      return l10n.bookingErrorPickupNotInFuture;
    case BookingFormError.dropoffRequired:
      return l10n.bookingErrorDropoffRequired;
    case BookingFormError.dropoffNotAfterPickup:
      return l10n.bookingErrorDropoffNotAfterPickup;
    case BookingFormError.rentalTooLong:
      return l10n.bookingErrorRentalTooLong(bookingMaxRentalDays);
    case BookingFormError.pickupLocationRequired:
    case BookingFormError.dropoffLocationRequired:
      return l10n.bookingErrorLocationRequired;
    case BookingFormError.pickupLocationUnknown:
    case BookingFormError.dropoffLocationUnknown:
      return l10n.bookingErrorLocationUnknown;
    case BookingFormError.pickupLocationTextRequired:
    case BookingFormError.dropoffLocationTextRequired:
      return l10n.bookingErrorLocationTextRequired;
    case BookingFormError.pickupLocationTextTooLong:
    case BookingFormError.dropoffLocationTextTooLong:
      return l10n.bookingErrorTooLong(bookingOtherLocationMaxLength);
    case BookingFormError.notesTooLong:
      return l10n.bookingErrorTooLong(bookingNotesMaxLength);
  }
}

/// A phone number in the expected format: the hint of the phone field and
/// the example in its error text. The same in every language.
const bookingPhoneExample = '+995 555 12 34 56';

/// The name of [extra].
String extraName(AppLocalizations l10n, Extra extra) {
  switch (extra) {
    case Extra.snowChains:
      return l10n.extraSnowChains;
    case Extra.childSeat:
      return l10n.extraChildSeat;
    case Extra.infantSeat:
      return l10n.extraInfantSeat;
    case Extra.boosterSeat:
      return l10n.extraBoosterSeat;
  }
}

/// The age a seat is meant for, or null for an extra without an age.
String? extraAgeText(AppLocalizations l10n, Extra extra) {
  switch (extra) {
    case Extra.snowChains:
      return null;
    case Extra.childSeat:
      return l10n.extraChildSeatAge;
    case Extra.infantSeat:
      return l10n.extraInfantSeatAge;
    case Extra.boosterSeat:
      return l10n.extraBoosterSeatAge;
  }
}

/// The price of an extra per day: "$5 / day", or "Free" for a price of 0.
String extraPriceText(AppLocalizations l10n, double pricePerDay) {
  if (pricePerDay == 0) return l10n.extraFree;
  return l10n.pricePerDay(formatPrice(pricePerDay));
}

/// The note shown with the estimated total of a long rental.
String individualPriceNote(AppLocalizations l10n) =>
    l10n.bookingIndividualPriceNote(standardRentalMaxDays);

/// The notes counter, for example "430 / 500". The same in every language.
String notesCounterText(int length) => '$length / $bookingNotesMaxLength';

/// Whether the notes field shows its counter for a text of [length]
/// characters.
bool showsNotesCounter(int length) => length >= bookingNotesCounterFrom;

/// The text shown when a booking could not be sent.
String bookingFailureText(AppLocalizations l10n, BookingCreateFailure failure) {
  switch (failure) {
    case BookingCreateFailure.rejected:
      return l10n.bookingFailedRejected;
    case BookingCreateFailure.noConnection:
      return l10n.bookingFailedNoConnection;
    case BookingCreateFailure.unknown:
      return l10n.bookingFailedUnknown;
  }
}
