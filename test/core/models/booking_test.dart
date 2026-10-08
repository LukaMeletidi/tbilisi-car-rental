import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';

Map<String, dynamic> validMap() => {
  'customer': {
    'fullName': 'Nino Beridze',
    'phone': '+995555123456',
    'whatsapp': true,
    'telegram': false,
    'email': 'nino@example.com',
  },
  'carId': 'car-1',
  'pickupDateTime': DateTime.utc(2026, 1, 10, 14),
  'dropoffDateTime': DateTime.utc(2026, 1, 15, 14),
  'pickupLocation': {'id': 'tbilisiAirport'},
  'dropoffLocation': {'id': 'other', 'text': 'Hotel in Batumi'},
  'extras': ['childSeat', 'snowChains'],
  'notes': 'Late arrival',
  'totalPrice': 272.5,
  'language': 'ru',
  'status': 'new',
  'createdAt': DateTime.utc(2026, 1, 1, 9, 30),
};

Map<String, dynamic> mapWith(String field, Object? value) =>
    validMap()..[field] = value;

Map<String, dynamic> mapWithout(String field) => validMap()..remove(field);

Map<String, dynamic> mapWithCustomer(String field, Object? value) {
  final map = validMap();
  final customer = Map<String, dynamic>.from(map['customer'] as Map);
  if (value == null) {
    customer.remove(field);
  } else {
    customer[field] = value;
  }
  return map..['customer'] = customer;
}

void main() {
  group('Booking.fromMap', () {
    test('reads a complete stored booking', () {
      final booking = Booking.fromMap('booking-1', validMap());

      expect(booking.id, 'booking-1');
      expect(booking.customer.fullName, 'Nino Beridze');
      expect(booking.customer.phone, '+995555123456');
      expect(booking.customer.whatsapp, true);
      expect(booking.customer.telegram, false);
      expect(booking.customer.email, 'nino@example.com');
      expect(booking.carId, 'car-1');
      expect(booking.pickup, DateTime.utc(2026, 1, 10, 14));
      expect(booking.dropoff, DateTime.utc(2026, 1, 15, 14));
      expect(
        booking.pickupLocation,
        const BookingLocation.fixed('tbilisiAirport'),
      );
      expect(
        booking.dropoffLocation,
        const BookingLocation.other('Hotel in Batumi'),
      );
      expect(booking.extras, {Extra.childSeat, Extra.snowChains});
      expect(booking.notes, 'Late arrival');
      expect(booking.totalPrice, 272.5);
      expect(booking.totalPriceCents, 27250);
      expect(booking.language, AppLanguage.ru);
      expect(booking.status, BookingStatus.newBooking);
      expect(booking.createdAt, DateTime.utc(2026, 1, 1, 9, 30));
      expect(booking.createdBy, isNull);
    });

    test('accepts a booking without createdAt and with empty notes', () {
      final map = mapWithout('createdAt')..['notes'] = '';
      final booking = Booking.fromMap('id', map);
      expect(booking.createdAt, isNull);
      expect(booking.notes, '');
    });

    test('reads createdBy for a booking created by an admin', () {
      final booking = Booking.fromMap('id', mapWith('createdBy', 'Giorgi'));
      expect(booking.createdBy, 'Giorgi');
    });

    test('accepts an empty list of extras', () {
      expect(Booking.fromMap('id', mapWith('extras', [])).extras, isEmpty);
    });

    test('totalPrice may be a whole number or a decimal', () {
      final whole = Booking.fromMap('id', mapWith('totalPrice', 90));
      expect(whole.totalPrice, 90.0);
      expect(whole.totalPriceCents, 9000);

      final decimal = Booking.fromMap('id', mapWith('totalPrice', 90.5));
      expect(decimal.totalPrice, 90.5);
      expect(decimal.totalPriceCents, 9050);

      final cents = Booking.fromMap('id', mapWith('totalPrice', 59.97));
      expect(cents.totalPriceCents, 5997);

      expect(Booking.fromMap('id', mapWith('totalPrice', 0)).totalPrice, 0.0);
    });

    test('throws when totalPrice is not a valid amount', () {
      for (final value in <Object>[
        '90',
        -1,
        -0.01,
        double.nan,
        double.infinity,
        45.123,
        0.001,
      ]) {
        expect(
          () => Booking.fromMap('id', mapWith('totalPrice', value)),
          throwsFormatException,
          reason: 'totalPrice $value',
        );
      }
    });

    test('throws when a required field is missing', () {
      const requiredFields = [
        'customer',
        'carId',
        'pickupDateTime',
        'dropoffDateTime',
        'pickupLocation',
        'dropoffLocation',
        'extras',
        'notes',
        'totalPrice',
        'language',
        'status',
      ];
      for (final field in requiredFields) {
        expect(
          () => Booking.fromMap('id', mapWithout(field)),
          throwsFormatException,
          reason: 'missing $field',
        );
      }
    });

    test('throws when a customer field is missing', () {
      for (final field in [
        'fullName',
        'phone',
        'whatsapp',
        'telegram',
        'email',
      ]) {
        expect(
          () => Booking.fromMap('id', mapWithCustomer(field, null)),
          throwsFormatException,
          reason: 'missing customer.$field',
        );
      }
    });

    test('throws when a field has the wrong type', () {
      expect(
        () => Booking.fromMap('id', mapWith('carId', 7)),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('customer', 'Nino')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWithCustomer('whatsapp', 'yes')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWithCustomer('fullName', '   ')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('pickupDateTime', '2026-01-10')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('extras', 'childSeat')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('notes', 5)),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('createdBy', 5)),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('pickupLocation', 'airport')),
        throwsFormatException,
      );
    });

    test('throws for an unknown status, extra or language', () {
      expect(
        () => Booking.fromMap('id', mapWith('status', 'completed')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('extras', ['roofBox'])),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap('id', mapWith('language', 'de')),
        throwsFormatException,
      );
    });

    test('throws when a date is not UTC', () {
      expect(
        () => Booking.fromMap(
          'id',
          mapWith('pickupDateTime', DateTime(2026, 1, 10, 14)),
        ),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap(
          'id',
          mapWith('dropoffDateTime', DateTime(2026, 1, 15, 14)),
        ),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap(
          'id',
          mapWith('createdAt', DateTime(2026, 1, 1, 9, 30)),
        ),
        throwsFormatException,
      );
    });

    test('throws when dropoff is not after pickup', () {
      expect(
        () => Booking.fromMap(
          'id',
          mapWith('dropoffDateTime', DateTime.utc(2026, 1, 10, 14)),
        ),
        throwsFormatException,
      );
      expect(
        () => Booking.fromMap(
          'id',
          mapWith('dropoffDateTime', DateTime.utc(2026, 1, 9)),
        ),
        throwsFormatException,
      );
    });
  });

  group('Booking.toMap', () {
    test('toMap then fromMap gives the same booking', () {
      final booking = Booking.fromMap('booking-1', validMap());
      final copy = Booking.fromMap(
        'booking-1',
        booking.toMap()..['createdAt'] = booking.createdAt,
      );
      expect(copy, booking);
      expect(copy.hashCode, booking.hashCode);
    });

    test('contains neither the id nor createdAt', () {
      final map = Booking.fromMap('booking-1', validMap()).toMap();
      expect(map.containsKey('id'), false);
      expect(map.containsKey('createdAt'), false);
    });

    test('writes createdBy only when it is set', () {
      final customer = Booking.fromMap('id', validMap()).toMap();
      expect(customer.containsKey('createdBy'), false);

      final admin = Booking.fromMap('id', mapWith('createdBy', 'Giorgi'));
      expect(admin.toMap()['createdBy'], 'Giorgi');
    });

    test('writes extras, status and language as their stored names', () {
      final map = Booking.fromMap('id', validMap()).toMap();
      expect(map['extras'], ['snowChains', 'childSeat']);
      expect(map['status'], 'new');
      expect(map['language'], 'ru');
      expect(map['pickupLocation'], {'id': 'tbilisiAirport'});
      expect(map['dropoffLocation'], {
        'id': 'other',
        'text': 'Hotel in Batumi',
      });
    });

    test('keeps the dates as UTC DateTime values', () {
      final map = Booking.fromMap('id', validMap()).toMap();
      expect(map['pickupDateTime'], DateTime.utc(2026, 1, 10, 14));
      expect((map['dropoffDateTime'] as DateTime).isUtc, true);
    });
  });

  test('bookings with different values are not equal', () {
    final booking = Booking.fromMap('id', validMap());
    expect(booking == Booking.fromMap('other-id', validMap()), false);
    expect(booking == Booking.fromMap('id', mapWith('notes', 'x')), false);
    expect(
      booking == Booking.fromMap('id', mapWith('extras', ['childSeat'])),
      false,
    );
  });
}
