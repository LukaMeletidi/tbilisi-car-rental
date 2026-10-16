/// What a conflict check before a write found, and what the conflict
/// dialog lists. Pure Dart; nothing here talks to Firestore, nothing is
/// logged, and no text is built here (the English texts are in
/// admin_texts.dart).
library;

import 'dart:math' as math;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';

/// The dialog lists at most this many conflicting bookings.
const conflictWarningMaxListed = 3;

/// The result of the conflict check before a write.
sealed class ConflictCheckOutcome {
  const ConflictCheckOutcome();
}

/// Nothing to say: no conflict, and every document could be read. The write
/// goes ahead without a dialog.
final class ConflictCheckClear extends ConflictCheckOutcome {
  const ConflictCheckClear();
}

/// Conflicts were found, or some documents could not be read: the dialog
/// with "Continue anyway" and "Cancel".
final class ConflictCheckWarning extends ConflictCheckOutcome {
  const ConflictCheckWarning({
    required this.conflicts,
    required this.unreadable,
  });

  /// The conflicting confirmed bookings, sorted by pickup.
  final List<Booking> conflicts;

  /// Documents of the car that could not be read and were not compared.
  final int unreadable;
}

/// The check could not be done: the dialog "Conflicts could not be
/// checked", with the same two buttons.
final class ConflictCheckFailed extends ConflictCheckOutcome {
  const ConflictCheckFailed(this.failure);

  final ConflictCheckFailure failure;
}

/// The outcome for [candidate], the booking about to be written, from the
/// [read] of the confirmed bookings of its car. [selfId] is the ID of the
/// booking being written, so it is never its own conflict.
///
/// A failure of the comparison itself (a time that is not UTC) is "could
/// not be checked": never a crash, never a silent pass.
ConflictCheckOutcome conflictCheckOutcome({
  required ConfirmedBookingsRead read,
  required Booking candidate,
  required String? selfId,
}) {
  switch (read) {
    case ConfirmedBookingsUnchecked(:final failure):
      return ConflictCheckFailed(failure);
    case ConfirmedBookingsChecked(:final bookings, :final unreadable):
      final List<Booking> conflicts;
      try {
        conflicts = findConflicts(candidate, bookings, selfId: selfId);
      } on ArgumentError {
        return const ConflictCheckFailed(ConflictCheckFailure.other);
      }
      if (conflicts.isEmpty && unreadable == 0) {
        return const ConflictCheckClear();
      }
      return ConflictCheckWarning(conflicts: conflicts, unreadable: unreadable);
  }
}

/// One period of the dialog, as stored (UTC). admin_texts.dart shows it in
/// Tbilisi time.
typedef ConflictPeriod = ({DateTime pickup, DateTime dropoff});

/// What the conflict dialog lists: no customer data, only times and counts.
class ConflictWarningLines {
  const ConflictWarningLines({
    required this.periods,
    required this.more,
    required this.unreadable,
  });

  /// At most [conflictWarningMaxListed] periods, sorted by pickup.
  final List<ConflictPeriod> periods;

  /// How many conflicts are not listed ("and N more"); 0 for none.
  final int more;

  /// How many documents could not be read (a line of its own when > 0).
  final int unreadable;
}

/// The lines of the dialog for [warning].
ConflictWarningLines conflictWarningLines(ConflictCheckWarning warning) {
  final listed = math.min(warning.conflicts.length, conflictWarningMaxListed);
  return ConflictWarningLines(
    periods: List.unmodifiable([
      for (final booking in warning.conflicts.take(listed))
        (pickup: booking.pickup, dropoff: booking.dropoff),
    ]),
    more: warning.conflicts.length - listed,
    unreadable: warning.unreadable,
  );
}

/// [booking] with another [status]; every other field, the ID included,
/// unchanged. The status change uses it as the "edited" booking of
/// needsConflictCheck and of the check.
Booking bookingWithStatus(Booking booking, BookingStatus status) => Booking(
  id: booking.id,
  customer: booking.customer,
  carId: booking.carId,
  pickup: booking.pickup,
  dropoff: booking.dropoff,
  pickupLocation: booking.pickupLocation,
  dropoffLocation: booking.dropoffLocation,
  extras: booking.extras,
  notes: booking.notes,
  totalPrice: booking.totalPrice,
  language: booking.language,
  status: status,
  createdAt: booking.createdAt,
  createdBy: booking.createdBy,
);
