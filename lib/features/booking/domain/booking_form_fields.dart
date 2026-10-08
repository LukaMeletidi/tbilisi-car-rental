import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

/// The parts of the booking form that can show an error, in the order they
/// appear on the screen.
enum BookingFormField {
  fullName,
  phone,
  email,
  pickup,
  dropoff,
  pickupLocation,
  dropoffLocation,
  notes,
}

/// The field under which [error] is shown. Null for
/// [BookingFormError.carNotAvailable]: that error concerns the whole form,
/// not one field.
BookingFormField? fieldOfError(BookingFormError error) {
  switch (error) {
    case BookingFormError.carNotAvailable:
      return null;
    case BookingFormError.nameRequired:
    case BookingFormError.nameTooShort:
    case BookingFormError.nameTooLong:
      return BookingFormField.fullName;
    case BookingFormError.phoneRequired:
    case BookingFormError.phoneInvalid:
      return BookingFormField.phone;
    case BookingFormError.emailRequired:
    case BookingFormError.emailInvalid:
    case BookingFormError.emailTooLong:
      return BookingFormField.email;
    case BookingFormError.pickupRequired:
    case BookingFormError.pickupNotInFuture:
      return BookingFormField.pickup;
    case BookingFormError.dropoffRequired:
    case BookingFormError.dropoffNotAfterPickup:
    case BookingFormError.rentalTooLong:
      return BookingFormField.dropoff;
    case BookingFormError.pickupLocationRequired:
    case BookingFormError.pickupLocationUnknown:
    case BookingFormError.pickupLocationTextRequired:
    case BookingFormError.pickupLocationTextTooLong:
      return BookingFormField.pickupLocation;
    case BookingFormError.dropoffLocationRequired:
    case BookingFormError.dropoffLocationUnknown:
    case BookingFormError.dropoffLocationTextRequired:
    case BookingFormError.dropoffLocationTextTooLong:
      return BookingFormField.dropoffLocation;
    case BookingFormError.notesTooLong:
      return BookingFormField.notes;
  }
}

/// The error of each field that has one. The validation reports at most one
/// error per field.
Map<BookingFormField, BookingFormError> errorsByField(
  Set<BookingFormError> errors,
) {
  final result = <BookingFormField, BookingFormError>{};
  for (final error in errors) {
    final field = fieldOfError(error);
    if (field != null) result.putIfAbsent(field, () => error);
  }
  return result;
}

/// The errors the screen shows now. Before the first press of Send only the
/// fields in [touched] show their error; after it ([submitAttempted]) every
/// field does.
Map<BookingFormField, BookingFormError> visibleErrors(
  Set<BookingFormError> errors, {
  required Set<BookingFormField> touched,
  required bool submitAttempted,
}) {
  final all = errorsByField(errors);
  if (submitAttempted) return all;
  return {
    for (final entry in all.entries)
      if (touched.contains(entry.key)) entry.key: entry.value,
  };
}

/// The first field on the screen that has an error, or null. The screen
/// scrolls to it after a failed Send.
BookingFormField? firstFieldWithError(Set<BookingFormError> errors) {
  final withError = errorsByField(errors).keys.toSet();
  for (final field in BookingFormField.values) {
    if (withError.contains(field)) return field;
  }
  return null;
}
