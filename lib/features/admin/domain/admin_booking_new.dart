/// Creating a booking by hand in the admin area: the draft of the form, its
/// validation, the total and the booking that is stored. Pure Dart; nothing
/// here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_price_preview.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// What is stored as createdBy for a booking made in the admin area. There
/// is one shared admin account, so this is a fixed word: the address of the
/// account adds no information and must not end up in the data.
const adminCreatedByValue = 'admin';

/// The last part of the address of the form, "/admin/bookings/new". It
/// would also pass as a booking ID, so no booking is ever created with it.
const adminNewBookingPathSegment = 'new';

/// What is stored as the e-mail of a customer who has none. The Firestore
/// rules require an e-mail address. The ending ".invalid" is reserved: such
/// an address can never receive mail. Anything that sends mail must skip
/// it; screens show "No e-mail" instead (see [isNoEmailPlaceholder]).
const noEmailPlaceholder = 'none@no-email.invalid';

/// Whether [email] is the placeholder for "the customer has no e-mail".
bool isNoEmailPlaceholder(String email) => email == noEmailPlaceholder;

/// The fields of the "new booking" form as the admin entered them.
class AdminNewBookingDraft {
  const AdminNewBookingDraft({
    required this.fields,
    this.status = BookingStatus.confirmed,
    this.noEmail = false,
  });

  /// The form as it opens: everything empty, the customer's language
  /// English, the status "confirmed". No car and no dates are chosen.
  static const empty = AdminNewBookingDraft(
    fields: AdminBookingDraft(
      input: BookingFormInput(),
      carId: '',
      language: AppLanguage.en,
    ),
  );

  /// The fields a new booking shares with the edit form. The choice of
  /// the total in it is not used: a new booking has no stored total.
  final AdminBookingDraft fields;

  /// The status the booking is created with.
  final BookingStatus status;

  /// True when the switch "The customer has no e-mail" is on. The e-mail
  /// field is then ignored and [noEmailPlaceholder] is stored.
  final bool noEmail;

  AdminNewBookingDraft copyWith({
    AdminBookingDraft? fields,
    BookingStatus? status,
    bool? noEmail,
  }) {
    return AdminNewBookingDraft(
      fields: fields ?? this.fields,
      status: status ?? this.status,
      noEmail: noEmail ?? this.noEmail,
    );
  }
}

/// Whether the admin entered or chose anything in the form: it then has
/// something to lose when it is left.
bool newDraftIsDirty(AdminNewBookingDraft draft) =>
    draftChanges(AdminNewBookingDraft.empty.fields, draft.fields).isNotEmpty ||
    draft.status != AdminNewBookingDraft.empty.status ||
    draft.noEmail != AdminNewBookingDraft.empty.noEmail;

// The fields as they are checked and stored: with the switch "no e-mail"
// on, the e-mail is the placeholder, whatever the field holds.
AdminBookingDraft _effectiveFields(AdminNewBookingDraft draft) => draft.noEmail
    ? draft.fields.copyWith(
        input: draft.fields.input.copyWith(email: noEmailPlaceholder),
      )
    : draft.fields;

/// Every problem with the fields of the "new booking" form. An empty set
/// means they can be saved. The total has its own check, [newTotalErrors].
///
/// The rules are the ones of the edit form ([validateAdminBooking]) for a
/// booking that does not exist yet: a fixed place must be in settings, and
/// nothing is "stored in another format". With the switch "no e-mail" on,
/// the e-mail field is not checked.
///
/// [carIds] are the IDs of all cars, also the hidden ones; null while the
/// cars are not loaded. Then no car can be chosen, and that is reported.
/// [locations] are the fixed places from settings; null while they are not
/// loaded.
Set<AdminBookingError> validateNewBooking(
  AdminNewBookingDraft draft, {
  required Set<String>? carIds,
  required List<PickupLocation>? locations,
}) {
  return validateAdminBooking(
    _effectiveFields(draft),
    carIds: carIds,
    locations: locations,
  );
}

/// How far the total of a new booking can be calculated.
enum AdminNewTotalState {
  /// The car or the dates are not chosen yet, or the dates cannot be
  /// priced (a drop-off before the pickup, more than 365 days).
  incomplete,

  /// The prices of the extras could not be loaded. Nothing can be saved:
  /// a new booking has no stored total to fall back on.
  pricesNotLoaded,

  /// There is a total, and it can be saved.
  ready,

  /// There is a total, but it is above the highest total the rules accept.
  tooHigh,
}

/// The total of a new booking, at today's prices. It is always calculated;
/// the admin cannot type an amount.
class AdminNewTotal {
  const AdminNewTotal(
    this.state, {
    this.price,
    this.carPricePerDay,
    this.extrasPerDay,
  });

  final AdminNewTotalState state;

  /// The days and the total; set for [AdminNewTotalState.ready] and
  /// [AdminNewTotalState.tooHigh].
  final RentalPrice? price;

  /// The price of the car per day; null when no car is chosen.
  final double? carPricePerDay;

  /// The prices of the chosen extras per day, added up; null when the
  /// prices are not loaded.
  final double? extrasPerDay;

  /// The total to store, in US dollars; null unless it is ready.
  double? get totalToSave =>
      state == AdminNewTotalState.ready ? price!.total : null;
}

/// The total of [draft] at the current prices: days x (the car's price per
/// day + the chosen extras per day). [car] is the chosen car, null when
/// none is chosen or the cars are not loaded; [extrasPrices] is null while
/// the prices are not loaded.
AdminNewTotal newBookingTotal({
  required AdminNewBookingDraft draft,
  required Car? car,
  required ExtrasPrices? extrasPrices,
}) {
  if (extrasPrices == null) {
    return AdminNewTotal(
      AdminNewTotalState.pricesNotLoaded,
      carPricePerDay: car?.pricePerDay,
    );
  }
  final input = draft.fields.input;
  var extrasCents = 0;
  for (final extra in input.extras) {
    extrasCents += (extrasPrices.priceOf(extra) * 100).round();
  }
  final extrasPerDay = extrasCents / 100;

  final price = car == null
      ? null
      : previewRentalPrice(input: input, car: car, extrasPrices: extrasPrices);
  if (car == null || price == null) {
    return AdminNewTotal(
      AdminNewTotalState.incomplete,
      carPricePerDay: car?.pricePerDay,
      extrasPerDay: extrasPerDay,
    );
  }
  return AdminNewTotal(
    price.totalCents > bookingMaxTotalPrice * 100
        ? AdminNewTotalState.tooHigh
        : AdminNewTotalState.ready,
    price: price,
    carPricePerDay: car.pricePerDay,
    extrasPerDay: extrasPerDay,
  );
}

/// What about the total stops a save. "Incomplete" is no error of its own:
/// the missing car or date is reported by [validateNewBooking].
Set<AdminBookingError> newTotalErrors(AdminNewTotal total) {
  switch (total.state) {
    case AdminNewTotalState.incomplete:
    case AdminNewTotalState.ready:
      return const {};
    case AdminNewTotalState.pricesNotLoaded:
      return const {AdminBookingError.newTotalUnavailable};
    case AdminNewTotalState.tooHigh:
      return const {AdminBookingError.totalTooHigh};
  }
}

/// The booking to create from a valid form: Tbilisi times become UTC,
/// texts are cleaned, the phone is put into its plain form, the e-mail is
/// [noEmailPlaceholder] when the switch is on, the status is the chosen
/// one and createdBy is [adminCreatedByValue]. [total] is the calculated total
/// in US dollars. The booking has no ID and no createdAt: the data layer
/// gives it both.
///
/// Throws an [ArgumentError] when the form is not valid; call
/// [validateNewBooking] first.
Booking newBookingFromDraft({
  required AdminNewBookingDraft draft,
  required double total,
}) {
  final fields = _effectiveFields(draft);
  final input = fields.input;
  final phone = normalizePhone(input.phone);
  final pickup = input.pickup;
  final dropoff = input.dropoff;
  final pickupLocation = input.pickupLocation;
  final dropoffLocation = input.dropoffLocation;
  if (phone == null ||
      pickup == null ||
      dropoff == null ||
      pickupLocation == null ||
      dropoffLocation == null ||
      fields.carId.trim().isEmpty) {
    throw ArgumentError.value(draft, 'draft', 'the form is not valid');
  }

  return Booking(
    customer: BookingCustomer(
      fullName: input.fullName.trim(),
      phone: phone,
      whatsapp: input.whatsapp,
      telegram: input.telegram,
      email: input.email.trim(),
    ),
    carId: fields.carId,
    pickup: pickup.toUtc(),
    dropoff: dropoff.toUtc(),
    pickupLocation: _cleaned(pickupLocation),
    dropoffLocation: _cleaned(dropoffLocation),
    extras: Set.unmodifiable(input.extras),
    notes: input.notes.trim(),
    totalPrice: total,
    language: fields.language,
    status: draft.status,
    createdBy: adminCreatedByValue,
  );
}

BookingLocation _cleaned(BookingLocation location) =>
    location.isOther ? BookingLocation.other(location.text!.trim()) : location;

/// How a create ended when the server answered.
enum AdminBookingCreateResult {
  /// The booking was created by this call.
  created,

  /// A booking with this ID already exists: an earlier attempt of the same
  /// form, whose answer never arrived, had created it. Nothing was written
  /// now, so there is no second booking.
  alreadyCreated,
}

/// Why a booking was not created.
enum AdminBookingCreateFailure {
  /// The server could not be reached.
  noConnection,

  /// The Firestore rules refused the booking.
  refused,

  /// The chosen car does not exist (any more).
  carMissing,

  /// Anything else.
  unknown,
}

/// The failure for an error [code] of Firestore; the same mapping as for a
/// status change. "not-found" has no meaning for a create and is unknown.
AdminBookingCreateFailure createFailureFromCode(String code) {
  switch (statusChangeFailureFromCode(code)) {
    case AdminStatusChangeFailure.noConnection:
      return AdminBookingCreateFailure.noConnection;
    case AdminStatusChangeFailure.refused:
      return AdminBookingCreateFailure.refused;
    case AdminStatusChangeFailure.bookingMissing:
    case AdminStatusChangeFailure.unknownFields:
    case AdminStatusChangeFailure.noCreatedAt:
    case AdminStatusChangeFailure.storedFormat:
    case AdminStatusChangeFailure.unknown:
      return AdminBookingCreateFailure.unknown;
  }
}

/// Reported when a booking was certainly not created. It carries only the
/// reason, never a Firestore error type and never a value of the booking.
class AdminBookingCreateException implements Exception {
  const AdminBookingCreateException(this.failure);

  final AdminBookingCreateFailure failure;

  @override
  String toString() => 'AdminBookingCreateException(${failure.name})';
}

/// Reported when the server did not answer within the time limit. This
/// does NOT mean "not created": the booking may exist. Only another call
/// with the same ID tells.
class AdminBookingCreateNoAnswer implements Exception {
  const AdminBookingCreateNoAnswer();

  @override
  String toString() => 'AdminBookingCreateNoAnswer';
}

/// What the screen tells the admin after an attempt to create a booking.
enum AdminBookingCreateNotice {
  /// The server confirmed that the booking exists.
  saved,

  /// No answer within the time limit; the booking may or may not exist.
  noAnswer,

  /// "Check again" after a "no answer" could not find out either (no
  /// connection, or another failure): it is still not known whether the
  /// booking exists.
  stillUnknown,

  noConnection,
  refused,
  carMissing,
  unknown,
}

/// The notice for a failure that certainly did not create the booking.
AdminBookingCreateNotice noticeForCreateFailure(
  AdminBookingCreateFailure failure,
) {
  switch (failure) {
    case AdminBookingCreateFailure.noConnection:
      return AdminBookingCreateNotice.noConnection;
    case AdminBookingCreateFailure.refused:
      return AdminBookingCreateNotice.refused;
    case AdminBookingCreateFailure.carMissing:
      return AdminBookingCreateNotice.carMissing;
    case AdminBookingCreateFailure.unknown:
      return AdminBookingCreateNotice.unknown;
  }
}
