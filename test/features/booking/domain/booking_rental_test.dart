import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_rental.dart';

/// A booking with pickup on 10 January 2026 at 14:00 UTC.
Booking withDropoff(DateTime dropoff) {
  return Booking(
    customer: const BookingCustomer(
      fullName: 'Nino Beridze',
      phone: '+995555123456',
      whatsapp: false,
      telegram: false,
      email: 'nino@example.com',
    ),
    carId: 'car-1',
    pickup: DateTime.utc(2026, 1, 10, 14),
    dropoff: dropoff,
    pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
    dropoffLocation: const BookingLocation.fixed('tbilisiAirport'),
    extras: const {},
    notes: '',
    totalPrice: 225,
    language: AppLanguage.en,
    status: BookingStatus.newBooking,
  );
}

void main() {
  group('Booking, calculated values', () {
    test('rentalDays follows the two dates', () {
      expect(withDropoff(DateTime.utc(2026, 1, 15, 14)).rentalDays, 5);
      expect(withDropoff(DateTime.utc(2026, 1, 10, 15)).rentalDays, 1);
    });

    test('exactly 7 days is not an individual price', () {
      final booking = withDropoff(DateTime.utc(2026, 1, 17, 14));
      expect(booking.rentalDays, 7);
      expect(booking.isIndividualPrice, false);
    });

    test('7 days and 3 hours is an individual price', () {
      final booking = withDropoff(DateTime.utc(2026, 1, 17, 17));
      expect(booking.rentalDays, 8);
      expect(booking.isIndividualPrice, true);
    });

    test('7 days and 2 hours is still within the grace period', () {
      final booking = withDropoff(DateTime.utc(2026, 1, 17, 16));
      expect(booking.rentalDays, 7);
      expect(booking.isIndividualPrice, false);
    });
  });
}
