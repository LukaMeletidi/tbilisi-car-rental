/// Deleting a booking in the admin area. Pure Dart; nothing here talks to
/// Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';

/// Whether the question "Delete this booking?" gets one more line of
/// warning: for a confirmed booking the customer expects the car.
bool deleteNeedsStrongWarning(BookingStatus status) =>
    status == BookingStatus.confirmed;

/// Whether the status of the stored booking is no longer the one the admin
/// saw when they confirmed the delete. [storedStatus] is the raw value of
/// the document's "status" field; anything that is not exactly the stored
/// name of [shown] counts as changed.
///
/// Only the status is compared. Somebody else confirming (or cancelling)
/// the booking meanwhile changes what a delete means; other changes (the
/// notes, a date) do not stop it.
bool statusChangedElsewhere({
  required BookingStatus shown,
  required Object? storedStatus,
}) => storedStatus != shown.storedName;

/// How a delete ended when the server answered and the booking is gone.
enum AdminBookingDeleteResult {
  /// The booking was deleted by this call.
  deleted,

  /// There was no such booking any more: it had been deleted before
  /// (elsewhere, or by an earlier attempt whose answer never arrived).
  alreadyDeleted,
}

/// Why a booking was certainly not deleted.
enum AdminBookingDeleteFailure {
  /// The server could not be reached.
  noConnection,

  /// The Firestore rules refused the delete.
  refused,

  /// The status of the booking was changed elsewhere since the admin
  /// confirmed the delete; nothing was deleted.
  statusChanged,

  /// Anything else.
  unknown,
}

/// The failure for an error [code] of Firestore; the same mapping as for a
/// status change. "not-found" has no meaning here (the transaction reads
/// the booking first) and is unknown.
AdminBookingDeleteFailure deleteFailureFromCode(String code) {
  switch (statusChangeFailureFromCode(code)) {
    case AdminStatusChangeFailure.noConnection:
      return AdminBookingDeleteFailure.noConnection;
    case AdminStatusChangeFailure.refused:
      return AdminBookingDeleteFailure.refused;
    case AdminStatusChangeFailure.bookingMissing:
    case AdminStatusChangeFailure.unknownFields:
    case AdminStatusChangeFailure.noCreatedAt:
    case AdminStatusChangeFailure.storedFormat:
    case AdminStatusChangeFailure.unknown:
      return AdminBookingDeleteFailure.unknown;
  }
}

/// Reported when a booking was certainly not deleted. It carries only the
/// reason, never a Firestore error type and never a value of the booking.
class AdminBookingDeleteException implements Exception {
  const AdminBookingDeleteException(this.failure);

  final AdminBookingDeleteFailure failure;

  @override
  String toString() => 'AdminBookingDeleteException(${failure.name})';
}

/// Reported when the server did not answer within the time limit. This
/// does NOT mean "not deleted": the booking may be gone. Only the live read
/// of the booking tells.
class AdminBookingDeleteNoAnswer implements Exception {
  const AdminBookingDeleteNoAnswer();

  @override
  String toString() => 'AdminBookingDeleteNoAnswer';
}

/// What the detail tells the admin after an attempt to delete that left
/// the booking on screen.
enum AdminBookingDeleteNotice {
  /// No answer within the time limit; the booking may or may not be gone.
  /// While it is still shown, it was not deleted.
  noAnswer,

  noConnection,
  refused,
  statusChanged,
  unknown,
}

/// The notice for a failure that certainly did not delete.
AdminBookingDeleteNotice noticeForDeleteFailure(
  AdminBookingDeleteFailure failure,
) {
  switch (failure) {
    case AdminBookingDeleteFailure.noConnection:
      return AdminBookingDeleteNotice.noConnection;
    case AdminBookingDeleteFailure.refused:
      return AdminBookingDeleteNotice.refused;
    case AdminBookingDeleteFailure.statusChanged:
      return AdminBookingDeleteNotice.statusChanged;
    case AdminBookingDeleteFailure.unknown:
      return AdminBookingDeleteNotice.unknown;
  }
}

/// What the bookings list says once, after the detail of a booking was
/// closed because the booking is gone.
enum AdminDeletedNotice {
  /// "Booking deleted."
  deleted,

  /// "This booking was already deleted."
  alreadyDeleted,
}

/// How an attempt to delete ends for the detail screen.
///
/// [result] is the answer of the transaction when the booking is gone;
/// [notice] is why it may still be there (no answer, or a failure); exactly
/// one of the two is set. [goneInLiveRead] says whether the live read of
/// the booking reported "missing" while the delete was running.
///
/// Returns what the list says when the detail must be closed, or null when
/// the booking stays on screen with [notice].
///
/// The live read can be faster than the answer of the transaction. When it
/// already said "missing", the booking is gone whatever the transaction
/// then reports: a missing answer or a failure does not bring it back.
AdminDeletedNotice? deletedOutcome({
  required AdminBookingDeleteResult? result,
  required AdminBookingDeleteNotice? notice,
  required bool goneInLiveRead,
}) {
  assert((result == null) != (notice == null));
  switch (result) {
    case AdminBookingDeleteResult.deleted:
      return AdminDeletedNotice.deleted;
    case AdminBookingDeleteResult.alreadyDeleted:
      return AdminDeletedNotice.alreadyDeleted;
    case null:
      return goneInLiveRead ? AdminDeletedNotice.deleted : null;
  }
}
