import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_status.dart';

void main() {
  test('parses the four stored names', () {
    expect(BookingStatus.parse('new'), BookingStatus.newBooking);
    expect(BookingStatus.parse('pending'), BookingStatus.pending);
    expect(BookingStatus.parse('confirmed'), BookingStatus.confirmed);
    expect(BookingStatus.parse('cancelled'), BookingStatus.cancelled);
  });

  test('the stored name of newBooking is "new"', () {
    expect(BookingStatus.newBooking.storedName, 'new');
  });

  test('every status parses back from its stored name', () {
    for (final status in BookingStatus.values) {
      expect(BookingStatus.parse(status.storedName), status);
    }
  });

  test('throws for an unknown name', () {
    expect(() => BookingStatus.parse('contacted'), throwsFormatException);
    expect(() => BookingStatus.parse('completed'), throwsFormatException);
    expect(() => BookingStatus.parse('newBooking'), throwsFormatException);
    expect(() => BookingStatus.parse(''), throwsFormatException);
  });

  test('is case-sensitive', () {
    expect(() => BookingStatus.parse('New'), throwsFormatException);
    expect(() => BookingStatus.parse('CONFIRMED'), throwsFormatException);
  });
}
