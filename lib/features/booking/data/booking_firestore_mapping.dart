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

/// The Firestore document for a booking an admin creates by hand.
///
/// The two UTC dates become Firestore timestamps and createdAt is set to
/// the server time, as the rules require. The result has the 13 keys the
/// rules accept from an admin: the 12 of a customer request and createdBy.
///
/// Throws an [ArgumentError] when [booking] already has an ID or a
/// createdAt, or has no createdBy (or one with a space at either end): the
/// rules would refuse such a document.
Map<String, dynamic> adminNewBookingDocument(Booking booking) {
  final createdBy = booking.createdBy;
  if (booking.id != null ||
      booking.createdAt != null ||
      createdBy == null ||
      createdBy.isEmpty ||
      createdBy.trim() != createdBy) {
    throw ArgumentError.value(
      booking,
      'booking',
      'must be a new admin booking (no id, no createdAt, with createdBy)',
    );
  }
  return {
    ...booking.toMap(),
    'pickupDateTime': Timestamp.fromDate(booking.pickup),
    'dropoffDateTime': Timestamp.fromDate(booking.dropoff),
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// The fields an admin's edit sends, ready for Firestore: every UTC
/// [DateTime] becomes a Firestore timestamp, everything else is passed on
/// as it is.
///
/// Throws an [ArgumentError] when [values] holds status, createdAt or
/// createdBy (an edit never writes them; createdAt must stay as stored,
/// or the rules refuse), or a date that is not UTC.
Map<String, dynamic> bookingUpdateToFirestore(Map<String, dynamic> values) {
  for (final key in const ['status', 'createdAt', 'createdBy']) {
    if (values.containsKey(key)) {
      throw ArgumentError.value(key, 'values', 'an edit must not write');
    }
  }
  return {
    for (final entry in values.entries) entry.key: _toFirestore(entry.value),
  };
}

Object? _toFirestore(Object? value) {
  if (value is! DateTime) return value;
  if (!value.isUtc) {
    throw ArgumentError.value(value, 'values', 'a date must be UTC');
  }
  return Timestamp.fromDate(value);
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
