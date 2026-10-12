/// What a booking document must look like for the Firestore rules to accept
/// a change of it by an admin. Pure Dart.
///
/// On every update the rules check the WHOLE document, not only the fields
/// that are sent. A document with a field the rules do not know, or without
/// createdAt, is therefore refused whatever is changed. The checks here
/// find that before the write, so the admin reads a clear message instead
/// of a bare "refused".
library;

/// Every top-level field the rules accept in a booking written by an admin.
/// The same list as in isValidAdminBooking (firestore.rules); the test
/// test/rules/booking_rules_limits_test.dart fails when they differ.
const adminBookingKeys = [
  'customer',
  'carId',
  'pickupDateTime',
  'dropoffDateTime',
  'pickupLocation',
  'dropoffLocation',
  'extras',
  'notes',
  'totalPrice',
  'language',
  'status',
  'createdAt',
  'createdBy',
];

/// The fields the rules require. createdBy is optional.
const adminBookingRequiredKeys = [
  'customer',
  'carId',
  'pickupDateTime',
  'dropoffDateTime',
  'pickupLocation',
  'dropoffLocation',
  'extras',
  'notes',
  'totalPrice',
  'language',
  'status',
  'createdAt',
];

/// What is wrong with a stored booking document.
enum AdminDocumentProblemKind {
  /// It has fields the rules do not know.
  unknownFields,

  /// It has no createdAt, or createdAt is not a date.
  noCreatedAt,
}

/// A stored booking document that the rules would refuse on any update.
class AdminDocumentProblem {
  const AdminDocumentProblem(this.kind, [this.fields = const []]);

  final AdminDocumentProblemKind kind;

  /// The names of the unknown fields, sorted; empty for
  /// [AdminDocumentProblemKind.noCreatedAt]. Names only, never values.
  final List<String> fields;
}

/// The fields of a document that the rules do not know, sorted by name.
List<String> unknownBookingKeys(Iterable<String> keys) {
  final unknown = [
    for (final key in keys)
      if (!adminBookingKeys.contains(key)) key,
  ]..sort();
  return List.unmodifiable(unknown);
}

/// Whether [data] has a createdAt that is a date. [data] is a document
/// whose Firestore timestamps were already turned into [DateTime] values.
bool hasCreatedAt(Map<String, dynamic> data) => data['createdAt'] is DateTime;

/// What makes the rules refuse every update of the stored document [data],
/// or null when nothing does. Unknown fields are reported first.
///
/// [data] is a document whose Firestore timestamps were already turned
/// into [DateTime] values.
AdminDocumentProblem? bookingDocumentProblem(Map<String, dynamic> data) {
  final unknown = unknownBookingKeys(data.keys);
  if (unknown.isNotEmpty) {
    return AdminDocumentProblem(
      AdminDocumentProblemKind.unknownFields,
      unknown,
    );
  }
  if (!hasCreatedAt(data)) {
    return const AdminDocumentProblem(AdminDocumentProblemKind.noCreatedAt);
  }
  return null;
}
