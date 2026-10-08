/// The limits of the booking form. The Firestore rules for bookings must use
/// the same numbers.
library;

const bookingNameMinLength = 2;
const bookingNameMaxLength = 100;

/// Digits of a phone number in international format, without the "+".
const bookingPhoneMinDigits = 8;
const bookingPhoneMaxDigits = 15;

const bookingEmailMaxLength = 254;

/// The free text of an "other" pickup or dropoff location.
const bookingOtherLocationMaxLength = 200;

const bookingNotesMaxLength = 500;

/// How long before pickup a booking must be made. Zero means any future
/// moment is accepted (there is no minimum lead time).
const bookingMinimumNotice = Duration.zero;

/// The dropoff may be at most this many days after the pickup. Exactly this
/// many days is still allowed.
const bookingMaxRentalDays = 365;
