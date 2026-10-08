import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';

/// A booking the server has just confirmed, for the thank-you screen.
class SentBooking {
  const SentBooking({
    required this.id,
    required this.booking,
    required this.car,
  });

  /// The ID of the new Firestore document.
  final String id;

  /// What was sent. Its own id and createdAt are null: the public app
  /// cannot read a booking back.
  final Booking booking;

  /// The car as it was shown when the request was sent.
  final Car car;
}

/// The last sent booking, or null.
///
/// It contains personal data (name, phone, e-mail). It is kept in memory
/// only, never written to the device, and must be removed with [clear] when
/// the user leaves the thank-you screen.
class SentBookingNotifier extends Notifier<SentBooking?> {
  @override
  SentBooking? build() => null;

  void set(SentBooking sent) => state = sent;

  /// Forgets the sent booking.
  void clear() => state = null;
}

final sentBookingProvider = NotifierProvider<SentBookingNotifier, SentBooking?>(
  SentBookingNotifier.new,
);
