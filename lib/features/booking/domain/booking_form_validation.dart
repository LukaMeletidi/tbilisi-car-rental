import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

/// The raw values of the booking form, exactly as the user entered them.
/// Dates and times are Tbilisi time.
class BookingFormInput {
  const BookingFormInput({
    this.fullName = '',
    this.phone = '',
    this.whatsapp = false,
    this.telegram = false,
    this.email = '',
    this.pickup,
    this.dropoff,
    this.pickupLocation,
    this.dropoffLocation,
    this.extras = const {},
    this.notes = '',
  });

  final String fullName;
  final String phone;
  final bool whatsapp;
  final bool telegram;
  final String email;

  /// Null while no date and time is chosen.
  final TbilisiDateTime? pickup;
  final TbilisiDateTime? dropoff;

  /// Null while no location is chosen.
  final BookingLocation? pickupLocation;
  final BookingLocation? dropoffLocation;

  final Set<Extra> extras;
  final String notes;
}

/// What can be wrong with a booking form. The texts shown to the user come
/// from the translations, not from here.
enum BookingFormError {
  carNotAvailable,
  nameRequired,
  nameTooShort,
  nameTooLong,
  phoneRequired,
  phoneInvalid,
  emailRequired,
  emailInvalid,
  emailTooLong,
  pickupRequired,
  pickupNotInFuture,
  dropoffRequired,
  dropoffNotAfterPickup,
  rentalTooLong,
  pickupLocationRequired,
  pickupLocationUnknown,
  pickupLocationTextRequired,
  pickupLocationTextTooLong,
  dropoffLocationRequired,
  dropoffLocationUnknown,
  dropoffLocationTextRequired,
  dropoffLocationTextTooLong,
  notesTooLong,
}

final _phoneNoise = RegExp(r'[\s\-.()]');

// "+", a first digit from 1 to 9, then the remaining digits.
final _phonePattern = RegExp(
  '^\\+[1-9][0-9]{${bookingPhoneMinDigits - 1},${bookingPhoneMaxDigits - 1}}\$',
);

final _whitespace = RegExp(r'\s');

/// The phone number in its stored form: "+" and digits only. Spaces,
/// hyphens, dots and brackets are removed, so "+995 555 12-34-56" becomes
/// "+995555123456". Returns null when the rest is not a number in
/// international format.
///
/// This does not prove that the number exists or belongs to a real country
/// code.
String? normalizePhone(String raw) {
  final cleaned = raw.replaceAll(_phoneNoise, '');
  return _phonePattern.hasMatch(cleaned) ? cleaned : null;
}

/// A simple shape check: no spaces, exactly one "@", something before it,
/// and after it a domain with at least one dot and no empty part.
///
/// This does not catch a mistyped address or a mailbox that does not exist.
bool isValidEmail(String raw) {
  final email = raw.trim();
  if (email.isEmpty || email.length > bookingEmailMaxLength) return false;
  if (email.contains(_whitespace)) return false;

  final parts = email.split('@');
  if (parts.length != 2 || parts[0].isEmpty) return false;

  final labels = parts[1].split('.');
  return labels.length >= 2 && labels.every((label) => label.isNotEmpty);
}

/// Every problem with the form. An empty set means the form is valid.
///
/// [locations] are the fixed places from settings. [now] is the current
/// moment in UTC; it is passed in so that the rule can be tested. Throws an
/// [ArgumentError] when [now] is not a UTC date.
Set<BookingFormError> validateBookingForm(
  BookingFormInput input, {
  required Car car,
  required List<PickupLocation> locations,
  required DateTime now,
}) {
  if (!now.isUtc) {
    throw ArgumentError.value(now, 'now', 'must be a UTC date');
  }
  final errors = <BookingFormError>{};

  if (!car.active) errors.add(BookingFormError.carNotAvailable);

  final name = input.fullName.trim();
  if (name.isEmpty) {
    errors.add(BookingFormError.nameRequired);
  } else if (name.length < bookingNameMinLength) {
    errors.add(BookingFormError.nameTooShort);
  } else if (name.length > bookingNameMaxLength) {
    errors.add(BookingFormError.nameTooLong);
  }

  if (input.phone.trim().isEmpty) {
    errors.add(BookingFormError.phoneRequired);
  } else if (normalizePhone(input.phone) == null) {
    errors.add(BookingFormError.phoneInvalid);
  }

  final email = input.email.trim();
  if (email.isEmpty) {
    errors.add(BookingFormError.emailRequired);
  } else if (email.length > bookingEmailMaxLength) {
    errors.add(BookingFormError.emailTooLong);
  } else if (!isValidEmail(email)) {
    errors.add(BookingFormError.emailInvalid);
  }

  // Tbilisi times are compared as UTC moments.
  final pickup = input.pickup?.toUtc();
  final dropoff = input.dropoff?.toUtc();

  if (pickup == null) {
    errors.add(BookingFormError.pickupRequired);
  } else if (!pickup.isAfter(now.add(bookingMinimumNotice))) {
    errors.add(BookingFormError.pickupNotInFuture);
  }

  if (dropoff == null) {
    errors.add(BookingFormError.dropoffRequired);
  } else if (pickup != null) {
    if (!dropoff.isAfter(pickup)) {
      errors.add(BookingFormError.dropoffNotAfterPickup);
    } else if (dropoff.difference(pickup) >
        const Duration(days: bookingMaxRentalDays)) {
      errors.add(BookingFormError.rentalTooLong);
    }
  }

  final knownIds = {for (final location in locations) location.id};
  final pickupLocationError = _locationError(
    input.pickupLocation,
    knownIds,
    required: BookingFormError.pickupLocationRequired,
    unknown: BookingFormError.pickupLocationUnknown,
    textRequired: BookingFormError.pickupLocationTextRequired,
    textTooLong: BookingFormError.pickupLocationTextTooLong,
  );
  if (pickupLocationError != null) errors.add(pickupLocationError);

  final dropoffLocationError = _locationError(
    input.dropoffLocation,
    knownIds,
    required: BookingFormError.dropoffLocationRequired,
    unknown: BookingFormError.dropoffLocationUnknown,
    textRequired: BookingFormError.dropoffLocationTextRequired,
    textTooLong: BookingFormError.dropoffLocationTextTooLong,
  );
  if (dropoffLocationError != null) errors.add(dropoffLocationError);

  if (input.notes.trim().length > bookingNotesMaxLength) {
    errors.add(BookingFormError.notesTooLong);
  }

  return errors;
}

BookingFormError? _locationError(
  BookingLocation? location,
  Set<String> knownIds, {
  required BookingFormError required,
  required BookingFormError unknown,
  required BookingFormError textRequired,
  required BookingFormError textTooLong,
}) {
  if (location == null) return required;
  if (!location.isOther) {
    return knownIds.contains(location.id) ? null : unknown;
  }
  final text = (location.text ?? '').trim();
  if (text.isEmpty) return textRequired;
  if (text.length > bookingOtherLocationMaxLength) return textTooLong;
  return null;
}
