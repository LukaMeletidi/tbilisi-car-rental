import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/data/booking_firestore_mapping.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

/// These tests read firestore.rules as text and compare it with the Dart
/// code. They do not run the rules; tool/check_booking_rules.mjs does that
/// on the emulator.
final rules = File('firestore.rules').readAsStringSync();

/// The number returned by a one-line rules function, for example
/// "function nameMinLength() { return 2; }".
int ruleNumber(String function) {
  final match = RegExp(
    'function $function\\(\\) \\{ return ([0-9]+); \\}',
  ).firstMatch(rules);
  if (match == null) fail('firestore.rules has no number "$function".');
  return int.parse(match.group(1)!);
}

/// The quoted names in the list that follows [start] in the rules.
List<String> ruleList(String start) {
  final from = rules.indexOf(start);
  if (from < 0) fail('firestore.rules does not contain "$start".');
  final to = rules.indexOf(']', from + start.length);
  return [
    for (final match in RegExp(
      "'([A-Za-z]+)'",
    ).allMatches(rules.substring(from + start.length, to)))
      match.group(1)!,
  ];
}

final booking = Booking(
  customer: const BookingCustomer(
    fullName: 'Nino Beridze',
    phone: '+995555123456',
    whatsapp: true,
    telegram: false,
    email: 'nino@example.com',
  ),
  carId: 'car-1',
  pickup: DateTime.utc(2026, 1, 10, 14),
  dropoff: DateTime.utc(2026, 1, 15, 14),
  pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
  dropoffLocation: const BookingLocation.other('Hotel in Batumi'),
  extras: const {Extra.childSeat},
  notes: '',
  totalPrice: 225,
  language: AppLanguage.en,
  status: BookingStatus.newBooking,
);

void main() {
  test('each limit in the rules equals its Dart constant', () {
    expect(ruleNumber('nameMinLength'), bookingNameMinLength);
    expect(ruleNumber('nameMaxLength'), bookingNameMaxLength);
    expect(ruleNumber('emailMaxLength'), bookingEmailMaxLength);
    expect(ruleNumber('otherLocationMaxLength'), bookingOtherLocationMaxLength);
    expect(ruleNumber('notesMaxLength'), bookingNotesMaxLength);
    expect(ruleNumber('maxRentalDays'), bookingMaxRentalDays);
    expect(ruleNumber('maxTotalPrice'), bookingMaxTotalPrice);
  });

  test('the phone pattern in the rules matches the digit limits', () {
    // One digit is the leading [1-9]; the rest are counted in the braces.
    const pattern =
        "'^\\\\+[1-9][0-9]"
        '{${bookingPhoneMinDigits - 1},${bookingPhoneMaxDigits - 1}}'
        "\$'";
    expect(rules, contains(pattern));
  });

  test('the location id pattern in the rules is the Dart pattern', () {
    expect(locationIdPattern.contains(r'\'), false);
    expect(rules, contains("l.id.matches('$locationIdPattern')"));
  });

  test('the reserved location id in the rules is the Dart one', () {
    expect(rules, contains("l.id == '$otherLocationId'"));
  });

  test('the key lists in the rules equal the keys the app sends', () {
    final sent = newBookingDocument(booking).keys.toSet();
    final allowed = ruleList('b.keys().hasOnly([');
    final required = ruleList('b.keys().hasAll([');

    expect(allowed.toSet(), sent);
    expect(allowed.length, sent.length);
    expect(required.toSet(), sent);
    expect(required.length, sent.length);
  });

  test('the customer key lists in the rules equal the customer keys', () {
    final sent = booking.customer.toMap().keys.toSet();
    expect(ruleList('c.keys().hasOnly(').toSet(), sent);
    expect(ruleList('c.keys().hasAll(').toSet(), sent);
  });

  test('the extras, languages and status in the rules are the Dart ones', () {
    expect(ruleList('b.extras.hasOnly(').toSet(), {
      for (final extra in Extra.values) extra.name,
    });
    expect(rules, contains('b.extras.size() <= ${Extra.values.length}'));
    expect(ruleList('b.language in [').toSet(), {
      for (final language in AppLanguage.values) language.code,
    });
    expect(
      rules,
      contains("b.status == '${BookingStatus.newBooking.storedName}'"),
    );
  });

  group('admin bookings (Phase 3)', () {
    test('the admin key lists are the public keys, plus createdBy', () {
      final sent = newBookingDocument(booking).keys.toSet();
      final allowed = ruleList('a.keys().hasOnly([');
      final required = ruleList('a.keys().hasAll([');

      expect(allowed.toSet(), {...sent, 'createdBy'});
      expect(allowed.length, sent.length + 1);
      // createdBy is optional, so it is not in the required list.
      expect(required.toSet(), sent);
      expect(required.length, sent.length);
    });

    test('the admin status list equals the four Dart statuses', () {
      final statuses = ruleList('a.status in [');
      expect(statuses.toSet(), {
        for (final status in BookingStatus.values) status.storedName,
      });
      expect(statuses.length, BookingStatus.values.length);
    });

    test('the admin extras and languages are the public ones', () {
      expect(
        ruleList('a.extras.hasOnly(').toSet(),
        ruleList('b.extras.hasOnly(').toSet(),
      );
      expect(rules, contains('a.extras.size() <= ${Extra.values.length}'));
      expect(
        ruleList('a.language in [').toSet(),
        ruleList('b.language in [').toSet(),
      );
    });
  });
}
