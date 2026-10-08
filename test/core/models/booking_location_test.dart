import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking_location.dart';

void main() {
  test('a fixed location round-trips through toMap and fromMap', () {
    const location = BookingLocation.fixed('tbilisiAirport');
    expect(BookingLocation.fromMap(location.toMap()), location);
    expect(location.isOther, false);
    expect(location.text, isNull);
  });

  test('an "other" location round-trips with its text', () {
    const location = BookingLocation.other('Hotel in Batumi');
    expect(location.id, 'other');
    expect(location.isOther, true);
    expect(BookingLocation.fromMap(location.toMap()), location);
    expect(location.toMap(), {'id': 'other', 'text': 'Hotel in Batumi'});
  });

  test('a fixed location writes no text field', () {
    const location = BookingLocation.fixed('tbilisiOffice');
    expect(location.toMap(), {'id': 'tbilisiOffice'});
  });

  test('throws when the id is missing, empty or not a text', () {
    expect(() => BookingLocation.fromMap({}), throwsFormatException);
    expect(() => BookingLocation.fromMap({'id': '  '}), throwsFormatException);
    expect(() => BookingLocation.fromMap({'id': 7}), throwsFormatException);
  });

  test('throws when "other" has no text', () {
    expect(
      () => BookingLocation.fromMap({'id': 'other'}),
      throwsFormatException,
    );
    expect(
      () => BookingLocation.fromMap({'id': 'other', 'text': '   '}),
      throwsFormatException,
    );
    expect(
      () => BookingLocation.fromMap({'id': 'other', 'text': 5}),
      throwsFormatException,
    );
  });

  test('throws when a fixed location has a text', () {
    expect(
      () => BookingLocation.fromMap({'id': 'tbilisiAirport', 'text': 'x'}),
      throwsFormatException,
    );
  });

  test('locations with the same values are equal', () {
    expect(const BookingLocation.fixed('a'), const BookingLocation.fixed('a'));
    expect(
      const BookingLocation.other('x') == const BookingLocation.other('y'),
      false,
    );
  });
}
