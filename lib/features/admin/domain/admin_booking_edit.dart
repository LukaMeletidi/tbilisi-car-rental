/// Editing a booking in the admin area: the draft of the form, its
/// validation, what changed, the conflict check and the total. Pure Dart;
/// nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_price_preview.dart';
import 'package:tbilisi_car_rental/features/booking/domain/price_calculator.dart';

/// The parts of a booking the edit form can change, each with the name of
/// its top-level field in Firestore. Status, createdAt and createdBy are
/// not here: the edit form never writes them.
enum AdminBookingField {
  customer('customer'),
  car('carId'),
  pickup('pickupDateTime'),
  dropoff('dropoffDateTime'),
  pickupLocation('pickupLocation'),
  dropoffLocation('dropoffLocation'),
  extras('extras'),
  notes('notes'),
  total('totalPrice'),
  language('language');

  const AdminBookingField(this.storedKey);

  /// The name of the top-level field in the Firestore document.
  final String storedKey;
}

/// What the admin wants saved as the total after the car, the dates or the
/// extras changed.
enum AdminTotalChoice {
  /// Keep the total that is stored.
  keepStored,

  /// Store the total calculated from the current prices.
  useNew,
}

/// The fields of the edit form as the admin entered them. Dates and times
/// are Tbilisi time.
class AdminBookingDraft {
  const AdminBookingDraft({
    required this.input,
    required this.carId,
    required this.language,
    this.totalChoice,
  });

  /// The draft that shows [booking] unchanged.
  factory AdminBookingDraft.fromBooking(Booking booking) {
    final customer = booking.customer;
    return AdminBookingDraft(
      input: BookingFormInput(
        fullName: customer.fullName,
        phone: customer.phone,
        whatsapp: customer.whatsapp,
        telegram: customer.telegram,
        email: customer.email,
        pickup: TbilisiDateTime.fromUtc(booking.pickup),
        dropoff: TbilisiDateTime.fromUtc(booking.dropoff),
        pickupLocation: booking.pickupLocation,
        dropoffLocation: booking.dropoffLocation,
        extras: booking.extras,
        notes: booking.notes,
      ),
      carId: booking.carId,
      language: booking.language,
    );
  }

  /// The same fields as in the public booking form.
  final BookingFormInput input;

  final String carId;

  /// The language the customer uses.
  final AppLanguage language;

  /// Null while the admin has not chosen.
  final AdminTotalChoice? totalChoice;

  /// A copy with the given values changed; a value that is left out stays
  /// as it is. With [keepTotalChoice] false the choice of the total is
  /// removed (unless a new one is given).
  AdminBookingDraft copyWith({
    BookingFormInput? input,
    String? carId,
    AppLanguage? language,
    AdminTotalChoice? totalChoice,
    bool keepTotalChoice = true,
  }) {
    return AdminBookingDraft(
      input: input ?? this.input,
      carId: carId ?? this.carId,
      language: language ?? this.language,
      totalChoice: totalChoice ?? (keepTotalChoice ? this.totalChoice : null),
    );
  }
}

bool _sameExtras(Set<Extra> a, Set<Extra> b) =>
    a.length == b.length && a.containsAll(b);

/// Whether the two drafts differ in what the price depends on: the car,
/// the two dates or the extras.
bool priceFieldsDiffer(AdminBookingDraft a, AdminBookingDraft b) =>
    a.carId != b.carId ||
    a.input.pickup != b.input.pickup ||
    a.input.dropoff != b.input.dropoff ||
    !_sameExtras(a.input.extras, b.input.extras);

/// The parts in which the draft [now] differs from the draft [initial], as
/// the admin entered them (nothing is cleaned or checked here). It tells
/// whether the form has unsaved changes, also while it is not valid. The
/// total is not a field of the form and is never in the result.
Set<AdminBookingField> draftChanges(
  AdminBookingDraft initial,
  AdminBookingDraft now,
) {
  final a = initial.input;
  final b = now.input;
  return {
    if (a.fullName != b.fullName ||
        a.phone != b.phone ||
        a.whatsapp != b.whatsapp ||
        a.telegram != b.telegram ||
        a.email != b.email)
      AdminBookingField.customer,
    if (initial.carId != now.carId) AdminBookingField.car,
    if (a.pickup != b.pickup) AdminBookingField.pickup,
    if (a.dropoff != b.dropoff) AdminBookingField.dropoff,
    if (a.pickupLocation != b.pickupLocation) AdminBookingField.pickupLocation,
    if (a.dropoffLocation != b.dropoffLocation)
      AdminBookingField.dropoffLocation,
    if (!_sameExtras(a.extras, b.extras)) AdminBookingField.extras,
    if (a.notes != b.notes) AdminBookingField.notes,
    if (initial.language != now.language) AdminBookingField.language,
  };
}

/// What can be wrong with the edit form. The English texts are in
/// admin_texts.dart.
enum AdminBookingError {
  nameRequired,
  nameTooShort,
  nameTooLong,
  phoneRequired,
  phoneInvalid,
  emailRequired,
  emailInvalid,
  emailTooLong,
  carRequired,
  carMissing,
  pickupRequired,
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
  nameStoredFormat,
  phoneStoredFormat,
  emailStoredFormat,
  pickupLocationStoredFormat,
  dropoffLocationStoredFormat,
  totalChoiceRequired,
  newTotalUnavailable,
  totalTooHigh,
}

/// Every problem with the fields of the edit form. An empty set means they
/// can be saved. The total has its own check, [totalErrors].
///
/// The limits are the ones of the public booking form, and of the
/// Firestore rules. Two things differ, as the rules allow them for an
/// admin: the pickup may be in the past, and the car may be hidden.
///
/// [carIds] are the IDs of all cars, also the hidden ones; null while the
/// cars are not loaded (then the car is not checked here; the save itself
/// still checks that it exists). [locations] are the fixed places from
/// settings; null while they are not loaded. A fixed place is accepted
/// when it is in [locations], or when it is the place [base] already has
/// (a place that was removed from settings stays possible).
Set<AdminBookingError> validateAdminBooking(
  AdminBookingDraft draft, {
  required Booking base,
  required Set<String>? carIds,
  required List<PickupLocation>? locations,
}) {
  final errors = <AdminBookingError>{};
  final input = draft.input;

  final name = input.fullName.trim();
  if (name.isEmpty) {
    errors.add(AdminBookingError.nameRequired);
  } else if (name.length < bookingNameMinLength) {
    errors.add(AdminBookingError.nameTooShort);
  } else if (name.length > bookingNameMaxLength) {
    errors.add(AdminBookingError.nameTooLong);
  }

  if (input.phone.trim().isEmpty) {
    errors.add(AdminBookingError.phoneRequired);
  } else if (normalizePhone(input.phone) == null) {
    errors.add(AdminBookingError.phoneInvalid);
  }

  final email = input.email.trim();
  if (email.isEmpty) {
    errors.add(AdminBookingError.emailRequired);
  } else if (email.length > bookingEmailMaxLength) {
    errors.add(AdminBookingError.emailTooLong);
  } else if (!isValidEmail(email)) {
    errors.add(AdminBookingError.emailInvalid);
  }

  if (draft.carId.trim().isEmpty) {
    errors.add(AdminBookingError.carRequired);
  } else if (carIds != null && !carIds.contains(draft.carId)) {
    errors.add(AdminBookingError.carMissing);
  }

  // Tbilisi times are compared as UTC moments. A pickup in the past is
  // allowed: an old booking can be corrected.
  final pickup = input.pickup?.toUtc();
  final dropoff = input.dropoff?.toUtc();
  if (pickup == null) errors.add(AdminBookingError.pickupRequired);
  if (dropoff == null) {
    errors.add(AdminBookingError.dropoffRequired);
  } else if (pickup != null) {
    if (!dropoff.isAfter(pickup)) {
      errors.add(AdminBookingError.dropoffNotAfterPickup);
    } else if (dropoff.difference(pickup) >
        const Duration(days: bookingMaxRentalDays)) {
      errors.add(AdminBookingError.rentalTooLong);
    }
  }

  final knownIds = {
    if (locations != null)
      for (final location in locations) location.id,
  };
  final pickupLocationError = _locationError(
    input.pickupLocation,
    {...knownIds, base.pickupLocation.id},
    required: AdminBookingError.pickupLocationRequired,
    unknown: AdminBookingError.pickupLocationUnknown,
    textRequired: AdminBookingError.pickupLocationTextRequired,
    textTooLong: AdminBookingError.pickupLocationTextTooLong,
  );
  if (pickupLocationError != null) errors.add(pickupLocationError);

  final dropoffLocationError = _locationError(
    input.dropoffLocation,
    {...knownIds, base.dropoffLocation.id},
    required: AdminBookingError.dropoffLocationRequired,
    unknown: AdminBookingError.dropoffLocationUnknown,
    textRequired: AdminBookingError.dropoffLocationTextRequired,
    textTooLong: AdminBookingError.dropoffLocationTextTooLong,
  );
  if (dropoffLocationError != null) errors.add(dropoffLocationError);

  if (input.notes.trim().length > bookingNotesMaxLength) {
    errors.add(AdminBookingError.notesTooLong);
  }

  errors.addAll(storedFormatErrors(base, draft));
  return errors;
}

/// The parts the admin did not touch whose STORED value is not in the form
/// the Firestore rules accept, although the checks above find nothing
/// wrong with it: a name, an e-mail or the text of a place with a space at
/// either end, or a phone that is not "+" and digits only.
///
/// The app never stores such a value, but one can be written by hand in
/// the console. An untouched part is not sent and not cleaned (see
/// [editedBooking]), and the rules check the whole document on every
/// update, so every save would end with a bare "refused". This names the
/// part instead. Touching the part removes the error: a touched part is
/// cleaned and sent.
///
/// The notes are not here: the rules accept notes with spaces at the ends.
Set<AdminBookingError> storedFormatErrors(
  Booking base,
  AdminBookingDraft draft,
) {
  final touched = draftChanges(AdminBookingDraft.fromBooking(base), draft);
  final errors = <AdminBookingError>{};

  if (!touched.contains(AdminBookingField.customer)) {
    final stored = base.customer;
    final name = stored.fullName.trim();
    if (name != stored.fullName &&
        name.length >= bookingNameMinLength &&
        name.length <= bookingNameMaxLength) {
      errors.add(AdminBookingError.nameStoredFormat);
    }
    final phone = normalizePhone(stored.phone);
    if (phone != null && phone != stored.phone) {
      errors.add(AdminBookingError.phoneStoredFormat);
    }
    if (stored.email.trim() != stored.email && isValidEmail(stored.email)) {
      errors.add(AdminBookingError.emailStoredFormat);
    }
  }
  if (!touched.contains(AdminBookingField.pickupLocation) &&
      _hasUncleanText(base.pickupLocation)) {
    errors.add(AdminBookingError.pickupLocationStoredFormat);
  }
  if (!touched.contains(AdminBookingField.dropoffLocation) &&
      _hasUncleanText(base.dropoffLocation)) {
    errors.add(AdminBookingError.dropoffLocationStoredFormat);
  }
  return errors;
}

/// The five errors of [storedFormatErrors]. The edit form shows them at
/// once, not only after the first press of Save: nothing can be saved
/// until the part is corrected.
const storedFormatErrorKinds = {
  AdminBookingError.nameStoredFormat,
  AdminBookingError.phoneStoredFormat,
  AdminBookingError.emailStoredFormat,
  AdminBookingError.pickupLocationStoredFormat,
  AdminBookingError.dropoffLocationStoredFormat,
};

/// [storedFormatErrors] for a stored document in which nothing is touched:
/// what makes the rules refuse every update of it although the app can
/// read it. The status change uses this, as it sends none of these parts.
///
/// [data] is a document whose Firestore timestamps were already turned
/// into [DateTime] values. A document that cannot be read as a booking
/// gives no error here; the rules then decide.
Set<AdminBookingError> storedFormatErrorsOfDocument(
  String id,
  Map<String, dynamic> data,
) {
  final Booking booking;
  try {
    booking = Booking.fromMap(id, data);
  } on FormatException {
    return const {};
  }
  return storedFormatErrors(booking, AdminBookingDraft.fromBooking(booking));
}

/// How many calendar years before and after the current one the date
/// pickers of the edit form offer. An old booking can be corrected.
const adminPickerYearsBack = 5;
const adminPickerYearsAhead = 2;

/// The first and the last day the date pickers of the edit form offer:
/// from 1 January [adminPickerYearsBack] years before [today] to 31
/// December [adminPickerYearsAhead] years after it (Tbilisi days).
({TbilisiDateTime first, TbilisiDateTime last}) adminPickerRange(
  TbilisiDateTime today,
) => (
  first: TbilisiDateTime(today.year - adminPickerYearsBack, 1, 1, 0, 0),
  last: TbilisiDateTime(today.year + adminPickerYearsAhead, 12, 31, 23, 59),
);

// A free text that is usable once trimmed, but is not stored trimmed.
bool _hasUncleanText(BookingLocation location) {
  final text = location.text;
  if (!location.isOther || text == null) return false;
  final trimmed = text.trim();
  return trimmed != text &&
      trimmed.isNotEmpty &&
      trimmed.length <= bookingOtherLocationMaxLength;
}

AdminBookingError? _locationError(
  BookingLocation? location,
  Set<String> acceptedIds, {
  required AdminBookingError required,
  required AdminBookingError unknown,
  required AdminBookingError textRequired,
  required AdminBookingError textTooLong,
}) {
  if (location == null) return required;
  if (!location.isOther) {
    // The rules check the shape of the ID; a stored ID of another shape
    // would be refused, so it is not accepted here either.
    final accepted =
        acceptedIds.contains(location.id) && isValidLocationId(location.id);
    return accepted ? null : unknown;
  }
  final text = (location.text ?? '').trim();
  if (text.isEmpty) return textRequired;
  if (text.length > bookingOtherLocationMaxLength) return textTooLong;
  return null;
}

/// Whether the pickup of [draft] is before [now] (UTC). Allowed for an
/// admin; the form only shows a note.
bool isPickupInPast(AdminBookingDraft draft, {required DateTime now}) {
  if (!now.isUtc) {
    throw ArgumentError.value(now, 'now', 'must be a UTC date');
  }
  final pickup = draft.input.pickup?.toUtc();
  return pickup != null && pickup.isBefore(now);
}

/// The stored total next to the total calculated from the current prices.
class AdminTotalComparison {
  const AdminTotalComparison({
    required this.storedCents,
    required this.storedDays,
    required this.priceFieldsChanged,
    this.newPrice,
    this.carPricePerDay,
    this.extrasPerDay,
  });

  /// The stored total in whole US cents.
  final int storedCents;

  /// The charged days of the stored dates.
  final int storedDays;

  /// True when the car, a date or the extras differ from the stored ones.
  final bool priceFieldsChanged;

  /// The days and the total of the draft at the CURRENT prices of the car
  /// and the extras. Null when it cannot be calculated: the car or the
  /// prices are not loaded, or the dates of the draft are not usable.
  final RentalPrice? newPrice;

  /// The current price of the draft's car per day; null when not loaded.
  final double? carPricePerDay;

  /// The current prices of the draft's extras per day, added up; null when
  /// not loaded.
  final double? extrasPerDay;

  /// True when there is a new total and it is not the stored one.
  bool get differs => newPrice != null && newPrice!.totalCents != storedCents;

  /// True when the admin must choose which total is saved: something the
  /// price depends on changed, and the new total is not known to be the
  /// stored one.
  bool get choiceNeeded => priceFieldsChanged && (newPrice == null || differs);

  /// True when "use the new total" is possible: there is one, and it is
  /// not above the highest total the rules accept.
  bool get canUseNew =>
      newPrice != null && newPrice!.totalCents <= bookingMaxTotalPrice * 100;
}

/// Compares the stored total of [base] with the total of [draft] at the
/// current prices. [car] is the car of the draft and [extrasPrices] the
/// current prices of the extras; either is null while it is not loaded.
///
/// Nothing is decided here; see [totalErrors] and [totalToSave].
AdminTotalComparison compareTotals({
  required Booking base,
  required AdminBookingDraft draft,
  required Car? car,
  required ExtrasPrices? extrasPrices,
}) {
  final changed = priceFieldsDiffer(AdminBookingDraft.fromBooking(base), draft);

  RentalPrice? newPrice;
  double? extrasPerDay;
  if (extrasPrices != null) {
    var cents = 0;
    for (final extra in draft.input.extras) {
      cents += (extrasPrices.priceOf(extra) * 100).round();
    }
    extrasPerDay = cents / 100;
    if (car != null) {
      newPrice = previewRentalPrice(
        input: draft.input,
        car: car,
        extrasPrices: extrasPrices,
      );
    }
  }

  return AdminTotalComparison(
    storedCents: base.totalPriceCents,
    storedDays: rentalDays(pickup: base.pickup, dropoff: base.dropoff),
    priceFieldsChanged: changed,
    newPrice: newPrice,
    carPricePerDay: car?.pricePerDay,
    extrasPerDay: extrasPerDay,
  );
}

/// What is wrong with the choice of the total. The rule:
/// - nothing the price depends on changed, or the new total equals the
///   stored one: no choice is needed and the stored total stays;
/// - otherwise the admin must choose; nothing is chosen for them;
/// - "use the new total" needs a new total that the rules accept.
Set<AdminBookingError> totalErrors(
  AdminTotalComparison comparison,
  AdminTotalChoice? choice,
) {
  if (!comparison.choiceNeeded) return const {};
  switch (choice) {
    case null:
      return const {AdminBookingError.totalChoiceRequired};
    case AdminTotalChoice.keepStored:
      return const {};
    case AdminTotalChoice.useNew:
      if (comparison.newPrice == null) {
        return const {AdminBookingError.newTotalUnavailable};
      }
      if (!comparison.canUseNew) return const {AdminBookingError.totalTooHigh};
      return const {};
  }
}

/// The total to write, in US dollars, or null when the stored total stays.
/// A new total is written only when the admin chose it and it is needed
/// and possible. The stored total is never changed any other way.
double? totalToSave(AdminTotalComparison comparison, AdminTotalChoice? choice) {
  if (!comparison.choiceNeeded) return null;
  if (choice != AdminTotalChoice.useNew || !comparison.canUseNew) return null;
  return comparison.newPrice!.total;
}

/// The booking as it is after the edit. [newTotal] is the total to store;
/// null keeps the stored one.
///
/// Each part of [draft] is compared with the draft the form started from
/// (AdminBookingDraft.fromBooking of [base]). A part the admin did not
/// touch keeps the stored value of [base] EXACTLY: nothing is trimmed and
/// the phone is not put into its plain form. Only a touched part is
/// cleaned. So an edit never rewrites what the admin did not change. The
/// parts are: the customer (its five inputs together), the notes, each
/// place and each date (the form only knows minutes; an untouched date
/// keeps its stored seconds). ID, status, createdAt and createdBy are
/// always the ones of [base].
///
/// Throws an [ArgumentError] when a touched part is not valid; call
/// [validateAdminBooking] first.
Booking editedBooking({
  required Booking base,
  required AdminBookingDraft draft,
  required double? newTotal,
}) {
  final input = draft.input;
  final touched = draftChanges(AdminBookingDraft.fromBooking(base), draft);
  Never invalid() =>
      throw ArgumentError.value(draft, 'draft', 'the edit form is not valid');

  var customer = base.customer;
  if (touched.contains(AdminBookingField.customer)) {
    customer = BookingCustomer(
      fullName: input.fullName.trim(),
      phone: normalizePhone(input.phone) ?? invalid(),
      whatsapp: input.whatsapp,
      telegram: input.telegram,
      email: input.email.trim(),
    );
  }

  return Booking(
    id: base.id,
    customer: customer,
    carId: draft.carId,
    pickup: touched.contains(AdminBookingField.pickup)
        ? (input.pickup ?? invalid()).toUtc()
        : base.pickup,
    dropoff: touched.contains(AdminBookingField.dropoff)
        ? (input.dropoff ?? invalid()).toUtc()
        : base.dropoff,
    pickupLocation: touched.contains(AdminBookingField.pickupLocation)
        ? _cleaned(input.pickupLocation ?? invalid())
        : base.pickupLocation,
    dropoffLocation: touched.contains(AdminBookingField.dropoffLocation)
        ? _cleaned(input.dropoffLocation ?? invalid())
        : base.dropoffLocation,
    extras: Set.unmodifiable(input.extras),
    notes: touched.contains(AdminBookingField.notes)
        ? input.notes.trim()
        : base.notes,
    totalPrice: newTotal ?? base.totalPrice,
    language: draft.language,
    status: base.status,
    createdAt: base.createdAt,
    createdBy: base.createdBy,
  );
}

BookingLocation _cleaned(BookingLocation location) =>
    location.isOther ? BookingLocation.other(location.text!.trim()) : location;

/// Which parts of [edited] differ from [base].
Set<AdminBookingField> bookingChanges(Booking base, Booking edited) {
  return {
    if (edited.customer != base.customer) AdminBookingField.customer,
    if (edited.carId != base.carId) AdminBookingField.car,
    if (edited.pickup != base.pickup) AdminBookingField.pickup,
    if (edited.dropoff != base.dropoff) AdminBookingField.dropoff,
    if (edited.pickupLocation != base.pickupLocation)
      AdminBookingField.pickupLocation,
    if (edited.dropoffLocation != base.dropoffLocation)
      AdminBookingField.dropoffLocation,
    if (!_sameExtras(edited.extras, base.extras)) AdminBookingField.extras,
    if (edited.notes != base.notes) AdminBookingField.notes,
    if (edited.totalPriceCents != base.totalPriceCents) AdminBookingField.total,
    if (edited.language != base.language) AdminBookingField.language,
  };
}

/// What an update of the document sends for [fields]: the top-level fields
/// only, each with its whole new value. A nested map (the customer, a
/// place) and the list of extras are always sent whole. The dates are UTC
/// [DateTime] values; the data layer turns them into Firestore timestamps.
///
/// status, createdAt and createdBy can never be in it: no
/// [AdminBookingField] names them.
Map<String, dynamic> bookingUpdateMap(
  Booking edited,
  Set<AdminBookingField> fields,
) {
  final all = edited.toMap();
  return {
    for (final field in AdminBookingField.values)
      if (fields.contains(field)) field.storedKey: all[field.storedKey],
  };
}

/// The changes of one edit: which parts changed, and what is sent.
class AdminBookingChanges {
  const AdminBookingChanges({required this.fields, required this.values});

  /// The changes that turn [base] into [edited].
  factory AdminBookingChanges.between(Booking base, Booking edited) {
    final fields = bookingChanges(base, edited);
    return AdminBookingChanges(
      fields: Set.unmodifiable(fields),
      values: Map.unmodifiable(bookingUpdateMap(edited, fields)),
    );
  }

  final Set<AdminBookingField> fields;

  /// See [bookingUpdateMap].
  final Map<String, dynamic> values;

  bool get isEmpty => fields.isEmpty;
}

/// A stored value in a form that can be compared: a date becomes its
/// milliseconds since the epoch in UTC (Firestore keeps microseconds, a
/// browser only milliseconds; without this the same moment could look
/// different), a number becomes a double (225 equals 225.0), and maps and
/// lists are normalised all the way down.
Object? normalizedBookingValue(Object? value) {
  if (value is DateTime) {
    return (date: value.toUtc().millisecondsSinceEpoch);
  }
  if (value is num) return value.toDouble();
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': normalizedBookingValue(entry.value),
    };
  }
  if (value is Iterable) {
    return [for (final item in value) normalizedBookingValue(item)];
  }
  return value;
}

/// Whether two normalised values are equal, maps and lists deeply.
bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

// The extras are a set: their stored order has no meaning.
Object? _normalizedField(AdminBookingField field, Object? value) {
  final normalized = normalizedBookingValue(value);
  if (field == AdminBookingField.extras && normalized is List) {
    return [...normalized]..sort((a, b) => '$a'.compareTo('$b'));
  }
  return normalized;
}

/// What the total depends on: the car, the two dates and the extras.
const priceFields = {
  AdminBookingField.car,
  AdminBookingField.pickup,
  AdminBookingField.dropoff,
  AdminBookingField.extras,
};

/// The parts whose stored value must still be the one the edit started
/// from, for a write of the parts [edited]: the edited parts themselves
/// and, when the total is written, also everything the total depends on
/// ([priceFields]), whether the admin edited it or not. The new total was
/// calculated from those values; were one of them changed elsewhere, the
/// total would be wrong. When the total is not written, nothing is added.
Set<AdminBookingField> fieldsToCompare(Set<AdminBookingField> edited) => {
  ...edited,
  if (edited.contains(AdminBookingField.total)) ...priceFields,
};

/// The parts that were changed elsewhere since the edit started and that a
/// write of the parts [edited] must not overwrite or rely on.
///
/// [base] is the booking the edit started from and [current] the document
/// as it is stored now (its Firestore timestamps already turned into
/// [DateTime] values). For each part in [fieldsToCompare] of [edited] the
/// value the edit started from is compared with the current one, both
/// after the same normalisation ([normalizedBookingValue]). No other part
/// is looked at: a status change made elsewhere is no conflict, and
/// neither is a changed car while only the notes are written.
Set<AdminBookingField> conflictingFields({
  required Booking base,
  required Map<String, dynamic> current,
  required Set<AdminBookingField> edited,
}) {
  final started = base.toMap();
  final compared = fieldsToCompare(edited);
  return {
    for (final field in AdminBookingField.values)
      if (compared.contains(field) &&
          !_deepEquals(
            _normalizedField(field, started[field.storedKey]),
            _normalizedField(field, current[field.storedKey]),
          ))
        field,
  };
}

/// Why an edit was not saved.
enum AdminBookingSaveFailure {
  /// The server could not be reached.
  noConnection,

  /// The Firestore rules refused the change.
  refused,

  /// The booking does not exist any more.
  bookingMissing,

  /// The chosen car does not exist (any more).
  carMissing,

  /// The stored document has fields the rules do not know.
  unknownFields,

  /// The stored document has no createdAt.
  noCreatedAt,

  /// An edited part was changed elsewhere meanwhile.
  conflict,

  /// A part that is not written is stored in a form the rules refuse.
  storedFormat,

  /// Anything else.
  unknown,
}

/// The failure for an error [code] of Firestore; the same mapping as for a
/// status change.
AdminBookingSaveFailure saveFailureFromCode(String code) {
  switch (statusChangeFailureFromCode(code)) {
    case AdminStatusChangeFailure.noConnection:
      return AdminBookingSaveFailure.noConnection;
    case AdminStatusChangeFailure.refused:
      return AdminBookingSaveFailure.refused;
    case AdminStatusChangeFailure.bookingMissing:
      return AdminBookingSaveFailure.bookingMissing;
    case AdminStatusChangeFailure.unknownFields:
    case AdminStatusChangeFailure.noCreatedAt:
    case AdminStatusChangeFailure.storedFormat:
    case AdminStatusChangeFailure.unknown:
      return AdminBookingSaveFailure.unknown;
  }
}

/// Reported when an edit was certainly not saved. It carries the reason
/// and, for unknown fields or a conflict, the names of the fields; never a
/// value and never a Firestore error type.
class AdminBookingSaveException implements Exception {
  const AdminBookingSaveException(this.failure, {this.fields = const []});

  final AdminBookingSaveFailure failure;

  /// For [AdminBookingSaveFailure.unknownFields] the unknown field names;
  /// for [AdminBookingSaveFailure.conflict] the stored names of the parts
  /// that were changed elsewhere; for
  /// [AdminBookingSaveFailure.storedFormat] the names of the
  /// [AdminBookingError] values. Otherwise empty.
  final List<String> fields;

  @override
  String toString() => 'AdminBookingSaveException(${failure.name})';
}

/// Reported when the server did not answer within the time limit. This
/// does NOT mean "not saved": the change may still have arrived.
class AdminBookingSaveNoAnswer implements Exception {
  const AdminBookingSaveNoAnswer();

  @override
  String toString() => 'AdminBookingSaveNoAnswer';
}

/// What the screen tells the admin after an attempt to save an edit.
enum AdminBookingSaveNotice {
  /// The server confirmed the change.
  saved,

  /// No answer within the time limit; the change may or may not have
  /// arrived.
  noAnswer,

  noConnection,
  refused,
  bookingMissing,
  carMissing,
  unknownFields,
  noCreatedAt,
  conflict,
  storedFormat,
  unknown,
}

/// The notice for a failure that certainly did not save.
AdminBookingSaveNotice noticeForSaveFailure(AdminBookingSaveFailure failure) {
  switch (failure) {
    case AdminBookingSaveFailure.noConnection:
      return AdminBookingSaveNotice.noConnection;
    case AdminBookingSaveFailure.refused:
      return AdminBookingSaveNotice.refused;
    case AdminBookingSaveFailure.bookingMissing:
      return AdminBookingSaveNotice.bookingMissing;
    case AdminBookingSaveFailure.carMissing:
      return AdminBookingSaveNotice.carMissing;
    case AdminBookingSaveFailure.unknownFields:
      return AdminBookingSaveNotice.unknownFields;
    case AdminBookingSaveFailure.noCreatedAt:
      return AdminBookingSaveNotice.noCreatedAt;
    case AdminBookingSaveFailure.conflict:
      return AdminBookingSaveNotice.conflict;
    case AdminBookingSaveFailure.storedFormat:
      return AdminBookingSaveNotice.storedFormat;
    case AdminBookingSaveFailure.unknown:
      return AdminBookingSaveNotice.unknown;
  }
}
