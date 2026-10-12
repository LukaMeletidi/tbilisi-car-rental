import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings_filter.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// The fixed "now" of these tests: 1 March 2026, 12:00 UTC.
final now = DateTime.utc(2026, 3, 1, 12);

/// A booking with made-up values, built through the real parser.
Booking booking(
  String id, {
  String fullName = 'Test Person',
  String phone = '+995555000000',
  String status = 'new',
  DateTime? pickup,
  DateTime? createdAt,
  bool withoutCreatedAt = false,
}) {
  final start = pickup ?? DateTime.utc(2026, 3, 10, 14);
  final document = rawBooking(
    id,
    fullName: fullName,
    phone: phone,
    status: status,
    pickup: start,
    dropoff: start.add(const Duration(days: 3)),
    createdAt: createdAt,
  );
  if (withoutCreatedAt) document.data.remove('createdAt');
  return parseBookings([document]).bookings.single;
}

List<String> idsOf(List<Booking> bookings) => [
  for (final booking in bookings) booking.id!,
];

List<String> visibleIds(List<Booking> bookings, AdminBookingsFilter filter) =>
    idsOf(visibleBookings(bookings, filter: filter, now: now));

void main() {
  final people = [
    booking('nino', fullName: 'Nino Beridze', phone: '+995555123456'),
    booking(
      'giorgi',
      fullName: 'Giorgi Maisuradze',
      phone: '+995555000111',
      status: 'confirmed',
    ),
    booking(
      'anna',
      fullName: 'Anna NINOSHVILI',
      phone: '+9955554440022',
      status: 'pending',
    ),
    booking(
      'pavle',
      fullName: 'Pavle Beridze',
      phone: '+995555222333',
      status: 'cancelled',
    ),
    booking(
      'nika',
      fullName: 'Nika Test',
      phone: '+995555999888',
      status: 'confirmed',
    ),
  ];

  group('the search words', () {
    test('lower case, split at spaces, no empty ones', () {
      expect(searchWords('  Nino   BER '), ['nino', 'ber']);
      expect(searchWords('nino\tber\nidze'), ['nino', 'ber', 'idze']);
    });

    test('an empty text and only spaces give no words', () {
      expect(searchWords(''), isEmpty);
      expect(searchWords('   '), isEmpty);
    });
  });

  group('phone matching', () {
    test('digitsOf keeps only the digits', () {
      expect(digitsOf('+995 555 12-34-56'), '995555123456');
      expect(digitsOf('(555) 12.34'), '5551234');
      expect(digitsOf('nino'), '');
    });

    test('isPhoneSearch: digits and phone signs, with at least one digit', () {
      for (final text in ['555', '+995 555', '555 12-34', '(555) 12.34']) {
        expect(isPhoneSearch(text), true, reason: text);
      }
      for (final text in ['', '   ', '+', '- -', 'nino', 'nino 555', '55a']) {
        expect(isPhoneSearch(text), false, reason: '"$text"');
      }
    });

    test('spaces and signs are ignored on both sides', () {
      final nino = people[0]; // +995555123456
      for (final search in [
        '555 12',
        '55512',
        '+995 555',
        '555-12-34',
        '(555) 123.456',
        '3456',
      ]) {
        expect(matchesSearch(nino, search), true, reason: search);
      }
    });

    test('the digits must appear in one piece', () {
      final nino = people[0]; // +995555123456
      expect(matchesSearch(nino, '555 99'), false);
      expect(matchesSearch(nino, '12 99'), false);
      expect(matchesSearch(nino, '654321'), false);
    });
  });

  group('matchesSearch', () {
    test('an empty search matches everything', () {
      for (final person in people) {
        expect(matchesSearch(person, ''), true);
        expect(matchesSearch(person, '   '), true);
      }
    });

    test('a word of the name, upper and lower case ignored', () {
      expect(matchesSearch(people[0], 'nino'), true);
      expect(matchesSearch(people[0], 'BERIDZE'), true);
      expect(matchesSearch(people[2], 'ninoshvili'), true);
      expect(matchesSearch(people[1], 'nino'), false);
    });

    test('a part of a word is enough', () {
      expect(matchesSearch(people[0], 'ber'), true);
      expect(matchesSearch(people[2], 'nino'), true); // NINOSHVILI
    });

    test('several words must all be found, in any order', () {
      expect(matchesSearch(people[0], 'beridze nino'), true);
      expect(matchesSearch(people[0], 'nino maisuradze'), false);
      expect(matchesSearch(people[3], 'pav ber'), true);
    });

    test('a name and digits together: name in the name, digits in the '
        'phone', () {
      expect(matchesSearch(people[0], 'nino 3456'), true);
      expect(matchesSearch(people[0], 'nino 0111'), false);
      expect(matchesSearch(people[1], 'giorgi 0111'), true);
    });

    test('Georgian and Russian names are found as typed', () {
      final georgian = booking('ka', fullName: 'ნინო ბერიძე');
      final russian = booking('ru', fullName: 'Нино Беридзе');
      expect(matchesSearch(georgian, 'ნინო'), true);
      expect(matchesSearch(georgian, 'ბერ'), true);
      expect(matchesSearch(russian, 'нино'), true);
      expect(matchesSearch(russian, 'БЕРИДЗЕ'), true);
      expect(matchesSearch(georgian, 'nino'), false);
    });

    test('only the name and the phone are searched', () {
      // The e-mail of every test booking is person@example.com.
      expect(matchesSearch(people[0], 'example'), false);
      expect(matchesSearch(people[0], 'person@'), false);
      expect(matchesSearch(people[0], 'tbilisiAirport'), false);
    });
  });

  group('countByStatus', () {
    test('every status is counted, also with 0', () {
      expect(countByStatus(const []), {
        for (final status in BookingStatus.values) status: 0,
      });
    });

    test('counts the loaded bookings per status', () {
      final counts = countByStatus(people);
      expect(counts[BookingStatus.newBooking], 1);
      expect(counts[BookingStatus.pending], 1);
      expect(counts[BookingStatus.confirmed], 2);
      expect(counts[BookingStatus.cancelled], 1);
      expect(counts.values.reduce((a, b) => a + b), people.length);
    });

    test('with a search only the matching bookings are counted', () {
      final counts = countByStatus(people, search: 'beridze');
      expect(counts[BookingStatus.newBooking], 1);
      expect(counts[BookingStatus.cancelled], 1);
      expect(counts[BookingStatus.confirmed], 0);
      expect(counts[BookingStatus.pending], 0);
    });
  });

  group('visibleBookings: filtering', () {
    test('the default shows everything', () {
      expect(visibleIds(people, const AdminBookingsFilter()), idsOf(people));
    });

    test('each status shows only its bookings', () {
      const expected = {
        BookingStatus.newBooking: ['nino'],
        BookingStatus.pending: ['anna'],
        BookingStatus.confirmed: ['giorgi', 'nika'],
        BookingStatus.cancelled: ['pavle'],
      };
      for (final status in BookingStatus.values) {
        expect(
          visibleIds(people, AdminBookingsFilter(status: status)),
          expected[status],
          reason: status.name,
        );
      }
    });

    test('status and search together', () {
      expect(
        visibleIds(
          people,
          const AdminBookingsFilter(
            status: BookingStatus.cancelled,
            search: 'beridze',
          ),
        ),
        ['pavle'],
      );
      expect(
        visibleIds(
          people,
          const AdminBookingsFilter(
            status: BookingStatus.pending,
            search: 'beridze',
          ),
        ),
        isEmpty,
      );
    });

    test('nothing loaded: nothing shown', () {
      expect(visibleIds(const [], const AdminBookingsFilter()), isEmpty);
    });

    test('the given list is not changed', () {
      final before = idsOf(people);
      visibleBookings(
        people,
        filter: const AdminBookingsFilter(sort: AdminBookingsSort.oldestFirst),
        now: now,
      );
      expect(idsOf(people), before);
    });
  });

  group('sortBookings', () {
    final received = [
      booking('second', createdAt: DateTime.utc(2026, 2, 2)),
      booking('third', createdAt: DateTime.utc(2026, 2, 3)),
      booking('first', createdAt: DateTime.utc(2026, 2, 1)),
    ];

    List<String> sorted(List<Booking> bookings, AdminBookingsSort sort) =>
        idsOf(sortBookings(bookings, sort: sort, now: now));

    test('newest first', () {
      expect(sorted(received, AdminBookingsSort.newestFirst), [
        'third',
        'second',
        'first',
      ]);
    });

    test('oldest first', () {
      expect(sorted(received, AdminBookingsSort.oldestFirst), [
        'first',
        'second',
        'third',
      ]);
    });

    test('a booking without a received time counts as the newest', () {
      final withFresh = [...received, booking('fresh', withoutCreatedAt: true)];
      expect(sorted(withFresh, AdminBookingsSort.newestFirst).first, 'fresh');
      expect(sorted(withFresh, AdminBookingsSort.oldestFirst).last, 'fresh');
    });

    test('pickup date: coming pickups first, the soonest on top; past '
        'pickups after them, the most recent on top', () {
      final byPickup = [
        booking('past-old', pickup: DateTime.utc(2026, 1, 5)),
        booking('coming-late', pickup: DateTime.utc(2026, 4, 1)),
        booking('past-recent', pickup: DateTime.utc(2026, 2, 27)),
        booking('coming-soon', pickup: DateTime.utc(2026, 3, 2)),
      ];
      expect(sorted(byPickup, AdminBookingsSort.pickupDate), [
        'coming-soon',
        'coming-late',
        'past-recent',
        'past-old',
      ]);
    });

    test('a pickup exactly at "now" still counts as coming', () {
      final edge = [
        booking('just-past', pickup: now.subtract(const Duration(minutes: 1))),
        booking('exactly-now', pickup: now),
      ];
      expect(sorted(edge, AdminBookingsSort.pickupDate), [
        'exactly-now',
        'just-past',
      ]);
    });

    test('the pickup order depends on the "now" that is passed in', () {
      final two = [
        booking('march', pickup: DateTime.utc(2026, 3, 10)),
        booking('may', pickup: DateTime.utc(2026, 5, 10)),
      ];
      List<String> at(DateTime moment) => idsOf(
        sortBookings(two, sort: AdminBookingsSort.pickupDate, now: moment),
      );
      expect(at(DateTime.utc(2026, 3, 1)), ['march', 'may']);
      // In April the March pickup is past and goes to the end.
      expect(at(DateTime.utc(2026, 4, 1)), ['may', 'march']);
    });

    test('stable: equal values keep the order they were loaded in', () {
      final same = DateTime.utc(2026, 2, 1);
      final samePickup = DateTime.utc(2026, 3, 10);
      final equal = [
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
          booking(id, createdAt: same, pickup: samePickup),
      ];
      for (final sort in AdminBookingsSort.values) {
        expect(sorted(equal, sort), idsOf(equal), reason: sort.name);
      }
    });

    test('the given list is not changed', () {
      final before = idsOf(received);
      sortBookings(received, sort: AdminBookingsSort.oldestFirst, now: now);
      expect(idsOf(received), before);
    });
  });

  group('AdminBookingsFilter', () {
    test('the default is all statuses, no search, newest first', () {
      const filter = AdminBookingsFilter();
      expect(filter.status, isNull);
      expect(filter.search, '');
      expect(filter.sort, AdminBookingsSort.newestFirst);
      expect(filter.isFiltering, false);
    });

    test('isFiltering: a status or a real search, not the order', () {
      const base = AdminBookingsFilter();
      expect(base.withStatus(BookingStatus.pending).isFiltering, true);
      expect(base.withSearch('nino').isFiltering, true);
      expect(base.withSearch('   ').isFiltering, false);
      expect(base.withSort(AdminBookingsSort.pickupDate).isFiltering, false);
    });

    test('each change keeps the other two values', () {
      const filter = AdminBookingsFilter(
        status: BookingStatus.confirmed,
        search: 'nino',
        sort: AdminBookingsSort.pickupDate,
      );
      expect(
        filter.withStatus(null),
        const AdminBookingsFilter(
          search: 'nino',
          sort: AdminBookingsSort.pickupDate,
        ),
      );
      expect(filter.withSearch('').status, BookingStatus.confirmed);
      expect(filter.withSort(AdminBookingsSort.oldestFirst).search, 'nino');
    });

    test('cleared() drops the status and the search and keeps the order', () {
      const filter = AdminBookingsFilter(
        status: BookingStatus.confirmed,
        search: 'nino',
        sort: AdminBookingsSort.pickupDate,
      );
      expect(
        filter.cleared(),
        const AdminBookingsFilter(sort: AdminBookingsSort.pickupDate),
      );
    });

    test('toString never contains the search text', () {
      const filter = AdminBookingsFilter(
        status: BookingStatus.pending,
        search: 'Very Secret Name 555123',
      );
      final text = '$filter';
      expect(text.contains('Very'), false);
      expect(text.contains('Secret'), false);
      expect(text.contains('555123'), false);
      expect(text, contains('23 characters'));
      expect(text, contains('pending'));
    });
  });

  test('the filter code does not log or print anything', () {
    // The search text can be a name or a phone number. These files must
    // have no way of writing it anywhere.
    for (final path in [
      'lib/features/admin/domain/admin_bookings_filter.dart',
      'lib/features/admin/presentation/admin_bookings_filter_provider.dart',
      'lib/features/admin/presentation/widgets/admin_bookings_controls.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final call in ['log(', 'print(', 'debugPrint(', 'dart:developer']) {
        expect(source.contains(call), false, reason: '$path has "$call"');
      }
    }
  });
}
