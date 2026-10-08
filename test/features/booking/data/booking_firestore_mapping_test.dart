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
}
