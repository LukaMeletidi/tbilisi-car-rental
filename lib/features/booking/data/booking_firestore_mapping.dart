import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';

/// The Firestore document for a new customer request.
///
/// The two UTC dates become Firestore timestamps and createdAt is set to the
/// server time. The result has exactly the keys that the Firestore rules for
/// bookings accept.
///
/// Throws an [ArgumentError] when [booking] is not a new customer request:
/// it already has an ID, a createdAt or a createdBy, or its status is not
/// "new". The rules would refuse such a document.
Map<String, dynamic> newBookingDocument(Booking booking) {
  if (booking.id != null ||
      booking.createdAt != null ||
      booking.createdBy != null ||
      booking.status != BookingStatus.newBooking) {
    throw ArgumentError.value(
      booking,
      'booking',
      'must be a new customer request (no id, createdAt or createdBy, '
          'status "new")',
    );
  }
  return {
    ...booking.toMap(),
    'pickupDateTime': Timestamp.fromDate(booking.pickup),
    'dropoffDateTime': Timestamp.fromDate(booking.dropoff),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// The fields of a stored booking with their Firestore timestamps turned
/// into UTC [DateTime] values, ready for Booking.fromMap.
///
/// Only the three date fields are touched, and only when they really are
/// timestamps. A field of another type is left as it is, so that
/// Booking.fromMap reports it as wrong instead of this function failing.
Map<String, dynamic> bookingMapFromFirestore(Map<String, dynamic> data) {
  final result = Map<String, dynamic>.of(data);
  for (final field in const [
    'pickupDateTime',
    'dropoffDateTime',
    'createdAt',
  ]) {
    final value = result[field];
    if (value is Timestamp) result[field] = value.toDate().toUtc();
  }
  return result;
}
