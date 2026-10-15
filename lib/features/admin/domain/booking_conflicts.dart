/// The conflict rules of Phase 5 (Sections 3.4 and 7): when two bookings of
/// one car are too close, when a save must be checked, and which confirmed
/// bookings lie ahead when a car is hidden. Pure Dart; only UTC moments, never
/// the device time zone. Nothing here talks to Firestore and nothing is
/// logged.
library;

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';

/// The time a car needs between two rentals: a car returned at 10:00 can be
/// picked up again from 15:00. The single named constant of Section 7.
const conflictBuffer = Duration(hours: 5);

void _requireUtc(Booking booking) {
  if (!booking.pickup.isUtc || !booking.dropoff.isUtc) {
    throw ArgumentError('A booking time must be UTC.');
  }
}

/// Whether [a] and [b] are too close: the same car, and
/// a.pickup < b.dropoff + buffer AND a.dropoff + buffer > b.pickup.
///
/// Only the car and the times are compared, never the statuses: which
/// bookings count is decided by [findConflicts]. Symmetric: the order of
/// [a] and [b] does not matter. A gap of exactly [conflictBuffer] is no
/// conflict. Throws an ArgumentError for a time that is not UTC.
bool bookingsConflict(Booking a, Booking b) {
  _requireUtc(a);
  _requireUtc(b);
  if (a.carId != b.carId) return false;
  return a.pickup.isBefore(b.dropoff.add(conflictBuffer)) &&
      a.dropoff.add(conflictBuffer).isAfter(b.pickup);
}

/// The confirmed bookings among [others] that conflict with [candidate],
/// sorted by pickup (then by document ID).
///
/// The booking being saved is never its own conflict: [selfId] is its
/// document ID (the edit and the new form know it even before the first
/// save), and an entry of [others] with that ID is skipped. new, pending and
/// cancelled bookings never conflict. The status of [candidate] is not
/// looked at: whether a check is needed at all is [needsConflictCheck].
List<Booking> findConflicts(
  Booking candidate,
  Iterable<Booking> others, {
  required String? selfId,
}) {
  final conflicts = [
    for (final other in others)
      if (other.status == BookingStatus.confirmed &&
          (selfId == null || other.id != selfId) &&
          bookingsConflict(candidate, other))
        other,
  ];
  conflicts.sort(_byPickupThenId);
  return List.unmodifiable(conflicts);
}

/// Whether saving [edited] must check for conflicts first.
///
/// [base] is the booking as stored before this save, or null for a new
/// booking. A check is needed when the saved booking is confirmed AND
/// - it is new, or
/// - it was not confirmed before (any status to confirmed), or
/// - its car, pickup or dropoff changed.
/// A change of notes, customer, extras, places or total alone needs no
/// check; neither does any save of a new, pending or cancelled booking.
bool needsConflictCheck({required Booking? base, required Booking edited}) {
  if (edited.status != BookingStatus.confirmed) return false;
  if (base == null) return true;
  if (base.status != BookingStatus.confirmed) return true;
  return base.carId != edited.carId ||
      base.pickup != edited.pickup ||
      base.dropoff != edited.dropoff;
}

/// The confirmed bookings of the car [carId] that are not over at [now]:
/// the dropoff is after [now], so a rental in progress counts. A dropoff
/// exactly at [now] is over. Sorted by pickup (then by document ID). Used
/// by the "Hide this car?" dialog. Throws an ArgumentError when [now] or a
/// booking time is not UTC.
List<Booking> futureConfirmed(
  Iterable<Booking> bookings, {
  required String carId,
  required DateTime now,
}) {
  if (!now.isUtc) throw ArgumentError('now must be UTC.');
  final ahead = [
    for (final booking in bookings)
      if (booking.status == BookingStatus.confirmed &&
          booking.carId == carId &&
          _dropoffAfter(booking, now))
        booking,
  ];
  ahead.sort(_byPickupThenId);
  return List.unmodifiable(ahead);
}

bool _dropoffAfter(Booking booking, DateTime now) {
  _requireUtc(booking);
  return booking.dropoff.isAfter(now);
}

int _byPickupThenId(Booking a, Booking b) {
  final byPickup = a.pickup.compareTo(b.pickup);
  if (byPickup != 0) return byPickup;
  return (a.id ?? '').compareTo(b.id ?? '');
}
