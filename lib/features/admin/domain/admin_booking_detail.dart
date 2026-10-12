/// One booking in the admin area: reading it and changing its status.
/// Pure Dart; nothing here talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';

/// How long the app waits for the server to confirm a status change.
const adminStatusChangeTimeout = Duration(seconds: 20);

final _bookingId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Whether [id] can be the ID of a booking document: letters, digits, "_"
/// and "-" only. An address typed by hand can hold anything; an ID of
/// another shape is treated as "does not exist" without asking Firestore.
bool isPlausibleBookingId(String id) => _bookingId.hasMatch(id);

/// One answer of the live read of a single booking, before it is read as a
/// booking.
class RawBookingAnswer {
  const RawBookingAnswer({required this.document, required this.fromCache});

  /// The document, or null when there is none with that ID.
  final RawBookingDocument? document;

  /// True when this answer came from the copy saved on the device and not
  /// from the server.
  final bool fromCache;
}

/// What an answer of the live read means.
enum AdminBookingReadState {
  /// The booking was read.
  found,

  /// The server says there is no such booking (never existed, or deleted).
  missing,

  /// There is a document, but it cannot be read as a booking.
  unreadable,

  /// Nothing can be said yet: the saved copy has no such document, and the
  /// server has not answered. This is NOT "missing": the device may simply
  /// be offline.
  notKnownYet,
}

/// The result of [readBookingAnswer].
class AdminBookingRead {
  const AdminBookingRead(this.state, {this.booking, this.reason});

  final AdminBookingReadState state;

  /// Set only for [AdminBookingReadState.found].
  final Booking? booking;

  /// Set only for [AdminBookingReadState.unreadable]: which field is wrong.
  /// It never holds the document.
  final String? reason;
}

/// Reads one answer of the live read.
///
/// A missing document counts as "missing" only when the server said so. The
/// saved copy not having it proves nothing.
AdminBookingRead readBookingAnswer(RawBookingAnswer answer) {
  final document = answer.document;
  if (document == null) {
    return AdminBookingRead(
      answer.fromCache
          ? AdminBookingReadState.notKnownYet
          : AdminBookingReadState.missing,
    );
  }
  final parsed = parseBookings([document]);
  if (parsed.bookings.isEmpty) {
    return AdminBookingRead(
      AdminBookingReadState.unreadable,
      reason: parsed.unreadable.single.reason,
    );
  }
  return AdminBookingRead(
    AdminBookingReadState.found,
    booking: parsed.bookings.single,
  );
}

/// The statuses an admin can change a booking to: every status except the
/// one it has. Any status can follow any other.
List<BookingStatus> selectableStatuses(BookingStatus current) => [
  for (final status in BookingStatus.values)
    if (status != current) status,
];

/// Whether the admin is asked "are you sure?" before the change.
///
/// Asked for the two changes that are hard on a customer: cancelling a
/// booking, and taking a confirmed booking out of "confirmed".
bool statusChangeNeedsConfirmation({
  required BookingStatus from,
  required BookingStatus to,
}) {
  if (from == to) return false;
  return to == BookingStatus.cancelled || from == BookingStatus.confirmed;
}

/// Why a status change was not saved.
enum AdminStatusChangeFailure {
  /// The server could not be reached.
  noConnection,

  /// The Firestore rules refused the change.
  refused,

  /// The booking does not exist any more.
  bookingMissing,

  /// Anything else.
  unknown,
}

/// The failure for an error [code] of Firestore.
AdminStatusChangeFailure statusChangeFailureFromCode(String code) {
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
      return AdminStatusChangeFailure.noConnection;
    case 'permission-denied':
      return AdminStatusChangeFailure.refused;
    case 'not-found':
      return AdminStatusChangeFailure.bookingMissing;
    default:
      return AdminStatusChangeFailure.unknown;
  }
}

/// Reported when a status change was certainly not saved. It carries only
/// the reason, never a Firestore error type.
class AdminStatusChangeException implements Exception {
  const AdminStatusChangeException(this.failure);

  final AdminStatusChangeFailure failure;

  @override
  String toString() => 'AdminStatusChangeException(${failure.name})';
}

/// Reported when the server did not answer within the time limit. Unlike an
/// [AdminStatusChangeException] this does NOT mean "not saved": the change
/// may still have arrived. Only the live read tells which status is stored.
class AdminStatusChangeNoAnswer implements Exception {
  const AdminStatusChangeNoAnswer();

  @override
  String toString() => 'AdminStatusChangeNoAnswer';
}

/// What the screen tells the admin after an attempt to change the status.
enum AdminStatusChangeNotice {
  /// The server confirmed the change.
  saved,

  /// No answer within the time limit; the change may or may not have
  /// arrived.
  noAnswer,

  noConnection,
  refused,
  bookingMissing,
  unknown,
}

/// The notice for a failure that certainly did not save.
AdminStatusChangeNotice noticeForFailure(AdminStatusChangeFailure failure) {
  switch (failure) {
    case AdminStatusChangeFailure.noConnection:
      return AdminStatusChangeNotice.noConnection;
    case AdminStatusChangeFailure.refused:
      return AdminStatusChangeNotice.refused;
    case AdminStatusChangeFailure.bookingMissing:
      return AdminStatusChangeNotice.bookingMissing;
    case AdminStatusChangeFailure.unknown:
      return AdminStatusChangeNotice.unknown;
  }
}
