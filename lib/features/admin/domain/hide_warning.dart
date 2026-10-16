/// What the "Hide this car?" dialog says about the confirmed bookings of the
/// car that are not over yet (Section 3.4, step 5.4). Pure Dart; nothing
/// here talks to Firestore, nothing is logged, and no text is built here.
library;

import 'dart:math' as math;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';

/// What the check before hiding found. Hiding is never blocked: every
/// outcome only changes what the dialog says.
sealed class HideCheckOutcome {
  const HideCheckOutcome();
}

/// No confirmed booking ahead, and every document could be read: the
/// dialog as it was before Phase 5.
final class HideCheckClear extends HideCheckOutcome {
  const HideCheckClear();
}

/// Confirmed bookings ahead, or documents that could not be read.
final class HideCheckBookings extends HideCheckOutcome {
  const HideCheckBookings({required this.ahead, required this.unreadable});

  /// The confirmed bookings whose dropoff is after now, sorted by pickup.
  final List<Booking> ahead;

  /// Documents of the car that could not be read and are not listed.
  final int unreadable;
}

/// The bookings could not be read: the dialog says that future bookings
/// cannot be ruled out.
final class HideCheckFailed extends HideCheckOutcome {
  const HideCheckFailed(this.failure);

  final ConflictCheckFailure failure;
}

/// The outcome for hiding the car [carId] at [now] (UTC), from the [read]
/// of its confirmed bookings. "Ahead" means: the dropoff is after [now], so
/// a rental in progress counts and a dropoff exactly at [now] does not
/// (futureConfirmed). A failure of the comparison itself (a time that is
/// not UTC) is "could not be checked": never a crash, never a silent pass.
HideCheckOutcome hideCheckOutcome({
  required ConfirmedBookingsRead read,
  required String carId,
  required DateTime now,
}) {
  switch (read) {
    case ConfirmedBookingsUnchecked(:final failure):
      return HideCheckFailed(failure);
    case ConfirmedBookingsChecked(:final bookings, :final unreadable):
      final List<Booking> ahead;
      try {
        ahead = futureConfirmed(bookings, carId: carId, now: now);
      } on ArgumentError {
        return const HideCheckFailed(ConflictCheckFailure.other);
      }
      if (ahead.isEmpty && unreadable == 0) return const HideCheckClear();
      return HideCheckBookings(ahead: ahead, unreadable: unreadable);
  }
}

/// The lines of the dialog for [outcome]: at most conflictWarningMaxListed
/// periods (the same limit and the same shape as the conflict dialog), how
/// many more there are, and the unreadable count. No customer data.
ConflictWarningLines hideWarningLines(HideCheckBookings outcome) {
  final listed = math.min(outcome.ahead.length, conflictWarningMaxListed);
  return ConflictWarningLines(
    periods: List.unmodifiable([
      for (final booking in outcome.ahead.take(listed))
        (pickup: booking.pickup, dropoff: booking.dropoff),
    ]),
    more: outcome.ahead.length - listed,
    unreadable: outcome.unreadable,
  );
}
