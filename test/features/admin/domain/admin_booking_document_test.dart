import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_document.dart';

import '../../../support/fake_admin_bookings_repository.dart';

void main() {
  test('the required keys are the allowed keys without createdBy', () {
    expect(adminBookingKeys.toSet(), hasLength(adminBookingKeys.length));
    expect(adminBookingRequiredKeys, [
      for (final key in adminBookingKeys)
        if (key != 'createdBy') key,
    ]);
  });

  group('unknownBookingKeys', () {
    test('none for a booking as the app writes it', () {
      expect(unknownBookingKeys(rawBooking('b1').data.keys), isEmpty);
      expect(unknownBookingKeys(adminBookingKeys), isEmpty);
    });

    test('names every other key, sorted', () {
      expect(
        unknownBookingKeys([
          ...adminBookingKeys,
          'zzTest',
          'updatedAt',
          'expireAt',
        ]),
        ['expireAt', 'updatedAt', 'zzTest'],
      );
    });

    test('a key is compared exactly', () {
      expect(unknownBookingKeys(['Status', 'notes ', 'createdby']), [
        'Status',
        'createdby',
        'notes ',
      ]);
    });
  });

  group('bookingDocumentProblem', () {
    test('none for a booking as the app writes it', () {
      expect(bookingDocumentProblem(rawBooking('b1').data), isNull);
      expect(
        bookingDocumentProblem(
          rawBooking('b1', changes: {'createdBy': 'Made-up Staff'}).data,
        ),
        isNull,
      );
    });

    test('unknown fields are reported by name, never by value', () {
      final problem = bookingDocumentProblem(
        rawBooking(
          'b1',
          changes: {'zzTest': 'a secret value', 'updatedAt': 1},
        ).data,
      )!;

      expect(problem.kind, AdminDocumentProblemKind.unknownFields);
      expect(problem.fields, ['updatedAt', 'zzTest']);
    });

    test('no createdAt is reported', () {
      final data = rawBooking('b1').data..remove('createdAt');

      final problem = bookingDocumentProblem(data)!;

      expect(problem.kind, AdminDocumentProblemKind.noCreatedAt);
      expect(problem.fields, isEmpty);
    });

    test('a createdAt that is not a date counts as none', () {
      for (final value in [null, '2026-10-09', 1760000000]) {
        final data = rawBooking('b1', changes: {'createdAt': value}).data;
        expect(
          bookingDocumentProblem(data)!.kind,
          AdminDocumentProblemKind.noCreatedAt,
          reason: '$value',
        );
        expect(hasCreatedAt(data), false);
      }
    });

    test('unknown fields are reported before a missing createdAt', () {
      final data = rawBooking('b1', changes: {'zzTest': true}).data
        ..remove('createdAt');

      expect(
        bookingDocumentProblem(data)!.kind,
        AdminDocumentProblemKind.unknownFields,
      );
    });
  });
}
