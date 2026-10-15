import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

import '../../../support/fake_fleet_repository.dart';

final now = DateTime.utc(2026, 10, 14, 12);

/// The repair reasons of one stored document that can be read.
List<String> reasons(Map<String, dynamic> data) =>
    carRepairReasons(Car.fromMap('car-1', data), data, now: now);

FleetEntry entry(Map<String, dynamic> data, {String id = 'car-1'}) =>
    fleetEntryOf((id: id, data: data), now: now);

void main() {
  group('needs repair: the reasons, named without values', () {
    test('a car as a save writes it: no reason', () {
      expect(reasons(rawCar()), isEmpty);
      expect((entry(rawCar()) as FleetCarEntry).needsRepair, false);
    });

    test('a complete car typed by hand in the console: no reason. The '
        'console stores a whole price as a whole number and leaves the '
        'engine size out; both are fine', () {
      final typedByHand = rawCar(
        change: (d) {
          d['pricePerDay'] = 45;
          d.remove('engineSize');
          d['photos'] = ['https://photos.example.com/car.jpg'];
        },
      );
      expect(reasons(typedByHand), isEmpty);
    });

    test('no description (the old demo cars): each language is missing', () {
      expect(reasons(rawCar(change: (d) => d.remove('description'))), {
        'error: descriptionKaRequired',
        'error: descriptionRuRequired',
        'error: descriptionEnRequired',
      });
    });

    test('no photos (an empty list) alone is not a repair case', () {
      final data = rawCar(change: (d) => d['photos'] = <String>[]);
      expect(reasons(data), isEmpty);
      expect((entry(data) as FleetCarEntry).needsRepair, false);
    });

    test('why a car that looks complete can still need repair: the form '
        'made from it has no error and the screen shows the same values, '
        'but a stored field differs from what a save would write', () {
      // Car.fromMap reads 2019.0 as the year 2019 and the screen shows
      // "Year 2019"; a save would write the whole number 2019, which the
      // "already saved" check of a replace does not count as the same.
      final data = rawCar(change: (d) => d['year'] = 2019.0);
      final car = Car.fromMap('car-1', data);
      expect(car.year, 2019);
      expect(carNeedsRepair(car, data, now: now), true);
      expect(reasons(data), ['differs: year']);
    });

    test('no photos field at all: the form is fine, but the stored document '
        'lacks the field a save writes', () {
      expect(reasons(rawCar(change: (d) => d.remove('photos'))), [
        'missing field: photos',
      ]);
    });

    test('an http photo address', () {
      expect(
        reasons(rawCar(change: (d) => d['photos'] = ['http://a.example/1'])),
        ['photo 0: notHttps'],
      );
    });

    test('an unknown field', () {
      expect(reasons(rawCar(change: (d) => d['note'] = 'old')), [
        'unknown field: note',
      ]);
    });

    test('a year stored as the decimal 2019.0', () {
      expect(reasons(rawCar(change: (d) => d['year'] = 2019.0)), [
        'differs: year',
      ]);
    });

    test('seats stored as the decimal 5.0', () {
      expect(reasons(rawCar(change: (d) => d['seats'] = 5.0)), [
        'differs: seats',
      ]);
    });

    test('a brand with a space at the end', () {
      expect(reasons(rawCar(brand: 'Honda ')), ['differs: brand']);
    });

    test('a description with a space at the end', () {
      final data = rawCar(
        change: (d) => d['description'] = {
          'ka': 'ქართული',
          'ru': 'Русский ',
          'en': 'English',
        },
      );
      expect(reasons(data), ['differs: description']);
    });

    test('10 seats', () {
      expect(reasons(rawCar(change: (d) => d['seats'] = 10)), [
        'error: seatsOutOfRange',
      ]);
    });

    test('a price with three decimals, typed by hand', () {
      expect(reasons(rawCar(change: (d) => d['pricePerDay'] = 45.555)), [
        'error: priceInvalid',
      ]);
    });

    test('the reasons never contain a stored value', () {
      final data = rawCar(
        brand: 'Secretbrand ',
        change: (d) => d['note'] = 'Secretnote',
      );
      final text = reasons(data).join(' ');
      expect(text, isNot(contains('Secretbrand')));
      expect(text, isNot(contains('Secretnote')));
    });
  });

  group('rows', () {
    test('a readable car keeps its car', () {
      final row = entry(rawCar(), id: 'abc') as FleetCarEntry;
      expect(row.id, 'abc');
      expect(row.car.brand, 'Honda');
    });

    test('a document Car.fromMap cannot read is unreadable, only its ID', () {
      expect(
        entry(rawCar(change: (d) => d['seats'] = 'five')),
        isA<FleetUnreadableEntry>(),
      );
      expect(
        entry(rawCar(change: (d) => d.remove('brand'))),
        isA<FleetUnreadableEntry>(),
      );
      expect(entry({'active': true}, id: 'x1').id, 'x1');
    });
  });

  test('sorting: visible, then hidden, by brand, model and year ignoring '
      'case; unreadable last by ID', () {
    final rows = fleetEntries([
      (id: 'u2', data: {'brand': 5}),
      (id: 'h1', data: rawCar(brand: 'Audi', active: false)),
      (id: 'v3', data: rawCar(brand: 'kia', model: 'Rio')),
      (id: 'v2', data: rawCar(brand: 'Kia', model: 'Ceed')),
      (id: 'v1', data: rawCar(brand: 'BMW')),
      (id: 'u1', data: {'brand': 5}),
      (id: 'v4', data: rawCar(brand: 'BMW', change: (d) => d['year'] = 2018)),
    ], now: now);
    expect(rows.map((row) => row.id), [
      'v4',
      'v1',
      'v2',
      'v3',
      'h1',
      'u1',
      'u2',
    ]);
  });

  test('counts', () {
    final rows = fleetEntries([
      (id: 'a', data: rawCar()),
      (id: 'b', data: rawCar(change: (d) => d.remove('description'))),
      (id: 'c', data: rawCar(active: false, change: (d) => d['note'] = 'x')),
      (id: 'd', data: {'active': true}),
    ], now: now);
    final counts = fleetCounts(rows);
    expect(
      counts,
      const FleetCounts(visible: 2, hidden: 1, needRepair: 2, unreadable: 1),
    );
    expect(counts.total, 4);
  });

  test('shortCarId: up to 8 characters as they are, longer with "…"', () {
    expect(shortCarId('abcdefgh'), 'abcdefgh');
    expect(shortCarId('abcdefghi'), 'abcdefgh…');
    expect(shortCarId('a'), 'a');
  });

  test('the read failures', () {
    expect(
      fleetLoadFailureFromCode('permission-denied'),
      FleetLoadFailure.permissionDenied,
    );
    expect(fleetLoadFailureFromCode('unavailable'), FleetLoadFailure.other);
    expect(
      '${const FleetLoadException(FleetLoadFailure.other)}',
      'FleetLoadException(other)',
    );
  });
}
