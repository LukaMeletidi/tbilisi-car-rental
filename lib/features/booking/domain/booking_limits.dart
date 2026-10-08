/// The limits of the booking form.
///
/// The Firestore rules for bookings (firestore.rules) repeat these numbers,
/// except where a comment says otherwise. Change both files together; the
/// test test/rules/booking_rules_limits_test.dart fails when they differ.
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

/// From this many characters the notes field shows its counter
/// ("430 / 500").
///
/// Only used by the app; it is NOT mirrored in the rules.
const bookingNotesCounterFrom = 400;

/// How long before pickup a booking must be made. Zero means any future
/// moment is accepted (there is no minimum lead time).
///
/// Not a number in the rules: they only require a pickup after the server
/// time.
const bookingMinimumNotice = Duration.zero;

/// The dropoff may be at most this many days after the pickup. Exactly this
/// many days is still allowed.
const bookingMaxRentalDays = 365;

/// The highest total in USD that the rules accept. The rules do not check
/// that the total matches the prices; this is only an upper bound.
const bookingMaxTotalPrice = 1000000;

/// How long the app waits for the server to confirm a new booking.
///
/// Only used by the app; it is NOT mirrored in the rules.
const bookingCreateTimeout = Duration(seconds: 20);
