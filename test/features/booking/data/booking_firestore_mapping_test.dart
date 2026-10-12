import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_firestore_mapping.dart';

Booking booking({
  String? id,
  BookingStatus status = BookingStatus.newBooking,
  DateTime? createdAt,
  String? createdBy,
}) {
  return Booking(
    id: id,
    customer: const BookingCustomer(
      fullName: 'Nino Beridze',
      phone: '+995555123456',
      whatsapp: true,
      telegram: false,
      email: 'nino@example.com',
    ),
    carId: 'car-1',
    pickup: DateTime.utc(2026, 1, 10, 14),
    dropoff: DateTime.utc(2026, 1, 15, 16, 30),
    pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
    dropoffLocation: const BookingLocation.other('Hotel in Batumi'),
    extras: const {Extra.childSeat, Extra.snowChains},
    notes: 'Late arrival',
    totalPrice: 272.5,
    language: AppLanguage.ru,
    status: status,
    createdAt: createdAt,
    createdBy: createdBy,
  );
}

void main() {
  test('turns the two dates into Timestamps of the same moment', () {
    final document = newBookingDocument(booking());

    final pickup = document['pickupDateTime'];
    final dropoff = document['dropoffDateTime'];
    expect(pickup, isA<Timestamp>());
    expect(dropoff, isA<Timestamp>());
    expect(
      (pickup as Timestamp).toDate().toUtc(),
      DateTime.utc(2026, 1, 10, 14),
    );
    expect(
      (dropoff as Timestamp).toDate().toUtc(),
      DateTime.utc(2026, 1, 15, 16, 30),
    );
  });

  test('adds createdAt as the server-time marker', () {
    final document = newBookingDocument(booking());
    expect(document['createdAt'], FieldValue.serverTimestamp());
  });

  test('contains exactly the 12 keys the rules expect', () {
    final document = newBookingDocument(booking());
    expect(document.keys.toSet(), {
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
      'createdAt',
    });
  });

  test('does not contain an id, createdBy or expireAt', () {
    final document = newBookingDocument(booking());
    expect(document.containsKey('id'), false);
    expect(document.containsKey('createdBy'), false);
    expect(document.containsKey('expireAt'), false);
  });

  test('keeps the other values as the model stores them', () {
    final document = newBookingDocument(booking());

    expect(document['customer'], {
      'fullName': 'Nino Beridze',
      'phone': '+995555123456',
      'whatsapp': true,
      'telegram': false,
      'email': 'nino@example.com',
    });
    expect(document['carId'], 'car-1');
    expect(document['pickupLocation'], {'id': 'tbilisiAirport'});
    expect(document['dropoffLocation'], {
      'id': 'other',
      'text': 'Hotel in Batumi',
    });
    expect(document['extras'], ['snowChains', 'childSeat']);
    expect(document['notes'], 'Late arrival');
    expect(document['totalPrice'], 272.5);
    expect(document['language'], 'ru');
    expect(document['status'], 'new');
  });

  test('throws for a booking that is not a new customer request', () {
    expect(() => newBookingDocument(booking(id: 'saved')), throwsArgumentError);
    expect(
      () => newBookingDocument(booking(createdBy: 'Giorgi')),
      throwsArgumentError,
    );
    expect(
      () => newBookingDocument(booking(createdAt: DateTime.utc(2026))),
      throwsArgumentError,
    );
    expect(
      () => newBookingDocument(booking(status: BookingStatus.confirmed)),
      throwsArgumentError,
    );
  });

  group('bookingMapFromFirestore', () {
    Map<String, dynamic> stored() => {
      ...newBookingDocument(booking()),
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 9, 13, 34)),
    };

    test('turns the three timestamps into UTC dates of the same moment', () {
      final map = bookingMapFromFirestore(stored());

      for (final field in ['pickupDateTime', 'dropoffDateTime', 'createdAt']) {
        expect(map[field], isA<DateTime>(), reason: field);
        expect((map[field] as DateTime).isUtc, true, reason: field);
      }
      expect(map['pickupDateTime'], DateTime.utc(2026, 1, 10, 14));
      expect(map['dropoffDateTime'], DateTime.utc(2026, 1, 15, 16, 30));
      expect(map['createdAt'], DateTime.utc(2026, 10, 9, 13, 34));
    });

    test('the result can be read as the booking that was stored', () {
      final read = Booking.fromMap(
        'stored-id',
        bookingMapFromFirestore(stored()),
      );
      final original = booking();

      expect(read.id, 'stored-id');
      expect(read.customer, original.customer);
      expect(read.pickup, original.pickup);
      expect(read.dropoff, original.dropoff);
      expect(read.extras, original.extras);
      expect(read.totalPrice, original.totalPrice);
      expect(read.createdAt, DateTime.utc(2026, 10, 9, 13, 34));
    });

    test('leaves the other fields and the given map unchanged', () {
      final source = stored();
      final map = bookingMapFromFirestore(source);

      expect(map['carId'], 'car-1');
      expect(map['customer'], source['customer']);
      expect(map.keys.toSet(), source.keys.toSet());
      expect(source['pickupDateTime'], isA<Timestamp>());
    });

    test('a date field of another type is left as it is', () {
      final source = stored()
        ..['pickupDateTime'] = '2026-01-10'
        ..remove('createdAt');
      final map = bookingMapFromFirestore(source);

      expect(map['pickupDateTime'], '2026-01-10');
      expect(map.containsKey('createdAt'), false);
      // Reading it as a booking then reports the wrong field.
      expect(() => Booking.fromMap('id', map), throwsFormatException);
    });
  });

  group('adminNewBookingDocument', () {
    final adminBooking = booking(
      status: BookingStatus.confirmed,
      createdBy: 'admin',
    );

    test('has the 13 keys an admin may write: the 12 of a request and '
        'createdBy', () {
      final document = adminNewBookingDocument(adminBooking);

      expect(document.keys.toSet(), {
        ...newBookingDocument(booking()).keys,
        'createdBy',
      });
      expect(document, hasLength(13));
      expect(document['createdBy'], 'admin');
      expect(document['status'], 'confirmed');
    });

    test('the dates are timestamps and createdAt is the server time', () {
      final document = adminNewBookingDocument(adminBooking);

      expect(
        document['pickupDateTime'],
        Timestamp.fromDate(DateTime.utc(2026, 1, 10, 14)),
      );
      expect(
        document['dropoffDateTime'],
        Timestamp.fromDate(DateTime.utc(2026, 1, 15, 16, 30)),
      );
      expect(document['createdAt'], isA<FieldValue>());
      expect(document['createdAt'], FieldValue.serverTimestamp());
    });

    test('every status can be written', () {
      for (final status in BookingStatus.values) {
        final document = adminNewBookingDocument(
          booking(status: status, createdBy: 'admin'),
        );
        expect(document['status'], status.storedName);
      }
    });

    test('a booking with an ID, with a createdAt, or without a usable '
        'createdBy is refused', () {
      for (final wrong in [
        booking(id: 'b1', status: BookingStatus.confirmed, createdBy: 'admin'),
        booking(
          status: BookingStatus.confirmed,
          createdBy: 'admin',
          createdAt: DateTime.utc(2026),
        ),
        booking(status: BookingStatus.confirmed),
        booking(status: BookingStatus.confirmed, createdBy: ''),
        booking(status: BookingStatus.confirmed, createdBy: ' admin'),
        booking(status: BookingStatus.confirmed, createdBy: 'admin '),
      ]) {
        expect(() => adminNewBookingDocument(wrong), throwsArgumentError);
      }
    });
  });

  group('bookingUpdateToFirestore', () {
    test('dates become timestamps; everything else is passed on', () {
      final map = bookingUpdateToFirestore({
        'pickupDateTime': DateTime.utc(2026, 1, 10, 14),
        'dropoffDateTime': DateTime.utc(2026, 1, 15, 16, 30),
        'customer': {'fullName': 'Nino Beridze'},
        'pickupLocation': {'id': 'other', 'text': 'Hotel in Batumi'},
        'extras': ['childSeat'],
        'carId': 'car-2',
        'notes': '',
        'totalPrice': 272.5,
        'language': 'ka',
      });

      expect(
        map['pickupDateTime'],
        Timestamp.fromDate(DateTime.utc(2026, 1, 10, 14)),
      );
      expect(
        map['dropoffDateTime'],
        Timestamp.fromDate(DateTime.utc(2026, 1, 15, 16, 30)),
      );
      expect(map['customer'], {'fullName': 'Nino Beridze'});
      expect(map['pickupLocation'], {'id': 'other', 'text': 'Hotel in Batumi'});
      expect(map['extras'], ['childSeat']);
      expect(map['carId'], 'car-2');
      expect(map['notes'], '');
      expect(map['totalPrice'], 272.5);
      expect(map['language'], 'ka');
      expect(map, hasLength(9));
    });

    test('only the given keys are in the result', () {
      expect(bookingUpdateToFirestore({'notes': 'Late arrival'}), {
        'notes': 'Late arrival',
      });
      expect(bookingUpdateToFirestore(const {}), isEmpty);
    });

    test('status, createdAt and createdBy are refused', () {
      for (final key in ['status', 'createdAt', 'createdBy']) {
        expect(
          () => bookingUpdateToFirestore({'notes': '', key: 'x'}),
          throwsArgumentError,
          reason: key,
        );
      }
    });

    test('a date that is not UTC is refused', () {
      expect(
        () => bookingUpdateToFirestore({'pickupDateTime': DateTime(2026)}),
        throwsArgumentError,
      );
    });

    test('a timestamp read back is the same moment', () {
      final moment = DateTime.utc(2026, 1, 10, 14, 0, 30);
      final sent = bookingUpdateToFirestore({'pickupDateTime': moment});
      final back = bookingMapFromFirestore(sent);

      expect(back['pickupDateTime'], moment);
    });
  });
}
