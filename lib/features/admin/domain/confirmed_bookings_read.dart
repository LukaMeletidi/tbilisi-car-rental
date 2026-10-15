/// The confirmed bookings of one car, read for a conflict check or a hide
/// check, and what happens when they cannot be read. Pure Dart; nothing here
/// talks to Firestore and nothing is logged.
library;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';

/// How long a conflict or hide check waits for the server.
const conflictCheckTimeout = Duration(seconds: 10);

/// Why the confirmed bookings could not be read. Every kind means the same
/// for the admin: "could not be checked"; the kind is only for the
/// diagnosis line of debug builds.
enum ConflictCheckFailure {
  /// No connection, or only an answer from memory.
  noConnection,

  /// No answer within [conflictCheckTimeout].
  timeout,

  /// The rules refused (not, or no longer, an admin).
  refused,

  /// Anything else, also an error of the app itself.
  other,
}

/// The result of reading the confirmed bookings of one car. A read never
/// throws; every failure is [ConfirmedBookingsUnchecked].
sealed class ConfirmedBookingsRead {
  const ConfirmedBookingsRead();
}

/// The server answered: the readable confirmed bookings of the car, in no
/// particular order (findConflicts and futureConfirmed sort them), and how
/// many documents of the answer could not be read as bookings.
final class ConfirmedBookingsChecked extends ConfirmedBookingsRead {
  const ConfirmedBookingsChecked({
    required this.bookings,
    required this.unreadable,
  });

  final List<Booking> bookings;

  /// Documents that were skipped. They could not be compared, so the
  /// dialogs of 5.3 and 5.4 name their number instead of passing in silence.
  final int unreadable;
}

/// The bookings could not be read: the check is "could not be checked".
final class ConfirmedBookingsUnchecked extends ConfirmedBookingsRead {
  const ConfirmedBookingsUnchecked(this.failure);

  final ConflictCheckFailure failure;
}

/// Reads one answer of the query "bookings where carId == [carId] and status
/// == confirmed".
///
/// An answer that did not come from the server is never trusted, empty or
/// not: it is [ConflictCheckFailure.noConnection]. Of a server answer, only
/// the readable bookings that really are confirmed bookings of [carId] are
/// kept (a document changed between the query and the read could differ);
/// a document that cannot be read is counted in
/// [ConfirmedBookingsChecked.unreadable].
ConfirmedBookingsRead readConfirmedBookings(
  List<RawBookingDocument> documents, {
  required bool fromCache,
  required String carId,
}) {
  if (fromCache) {
    return const ConfirmedBookingsUnchecked(ConflictCheckFailure.noConnection);
  }
  final parsed = parseBookings(documents);
  return ConfirmedBookingsChecked(
    bookings: List.unmodifiable([
      for (final booking in parsed.bookings)
        if (booking.carId == carId && booking.status == BookingStatus.confirmed)
          booking,
    ]),
    unreadable: parsed.unreadable.length,
  );
}
