import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

import '../../../support/fake_fleet_repository.dart';

final now = DateTime.utc(2026, 10, 14, 12);

/// A stored car document (made-up values) with [popular] set as given;
/// [absent] leaves the key out.
Map<String, dynamic> stored({Object? popular, bool absent = false}) => rawCar(
  change: (d) {
    if (!absent) d['popular'] = popular;
  },
);

Car carOf(Map<String, dynamic> data, {String id = 'car-1'}) =>
    Car.fromMap(id, data);

void main() {
  group('Car.fromMap and toMap (step 6b.5)', () {
    test('a missing key: not popular', () {
      expect(carOf(stored(absent: true)).popular, false);
    });

    test('true: popular', () {
      expect(carOf(stored(popular: true)).popular, true);
    });

    test('false: not popular', () {
      expect(carOf(stored(popular: false)).popular, false);
    });

    test('a value that is not a bool reads as false; the car stays '
        'readable', () {
      for (final value in <Object?>[
        'true',
        1,
        null,
        <bool>[true],
      ]) {
        expect(carOf(stored(popular: value)).popular, false, reason: '$value');
      }
    });

    test('toMap writes the key only when the car is popular', () {
      expect(carOf(stored(popular: true)).toMap()['popular'], true);
      expect(
        carOf(stored(popular: false)).toMap().containsKey('popular'),
        false,
      );
      expect(carOf(stored(absent: true)).toMap().containsKey('popular'), false);
    });

    test('== and hashCode include popular', () {
      final a = carOf(stored(popular: true));
      final b = carOf(stored(popular: true));
      final c = carOf(stored(absent: true));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, false);
    });
  });

  group('the draft', () {
    test('fromCar, copyWith and carFromDraft carry the mark', () {
      final draft = CarDraft.fromCar(carOf(stored(popular: true)));
      expect(draft.popular, true);
      expect(draft.copyWith(popular: false).popular, false);
      expect(draft.copyWith(brand: 'Kia').popular, true);
      expect(carFromDraft('car-1', draft, now: now).popular, true);
    });

    test('a new draft is not popular', () {
      expect(const CarDraft().popular, false);
    });

    test('carDocument: the key only when marked', () {
      final draft = CarDraft.fromCar(carOf(stored(absent: true)));
      final marked = carFromDraft(
        'car-1',
        draft.copyWith(popular: true),
        now: now,
      );
      expect(carDocument(marked)['popular'], true);
      final unmarked = carFromDraft('car-1', draft, now: now);
      expect(carDocument(unmarked).containsKey('popular'), false);
    });

    test('a tick is a change; a tick and an untick are none', () {
      final base = carOf(stored(absent: true));
      final draft = CarDraft.fromCar(base);
      expect(carDraftChanged(base, draft.copyWith(popular: true)), true);
      expect(
        carDraftChanged(
          base,
          draft.copyWith(popular: true).copyWith(popular: false),
        ),
        false,
      );
    });
  });

  group('the save decision', () {
    test('popular changed elsewhere: nothing is written', () {
      final base = carOf(stored(absent: true));
      final target = carFromDraft(
        'car-1',
        CarDraft.fromCar(base).copyWith(brand: 'Kia'),
        now: now,
      );
      expect(
        decideReplace(
          storedData: stored(popular: true),
          base: base,
          target: target,
        ),
        CarReplaceDecision.changedElsewhere,
      );
    });

    test('a retry after a lost answer: already saved', () {
      final base = carOf(stored(absent: true));
      final target = carFromDraft(
        'car-1',
        CarDraft.fromCar(base).copyWith(popular: true),
        now: now,
      );
      expect(
        decideReplace(
          storedData: carDocument(target),
          base: base,
          target: target,
        ),
        CarReplaceDecision.alreadySaved,
      );
    });

    test('a stored false and a draft without the key are the same car, but '
        'a save is a real replacement (it drops the key)', () {
      final storedFalse = stored(popular: false);
      final base = carOf(storedFalse);
      final target = carFromDraft(
        'car-1',
        CarDraft.fromCar(base).copyWith(brand: 'Kia'),
        now: now,
      );
      expect(base, carOf(stored(absent: true)));
      expect(
        decideReplace(storedData: storedFalse, base: base, target: target),
        CarReplaceDecision.write,
      );
      expect(carDocument(target).containsKey('popular'), false);
    });
  });

  group('Needs repair', () {
    test('a stored true: no reason', () {
      final data = stored(popular: true);
      expect(carRepairReasons(carOf(data), data, now: now), isEmpty);
    });

    test('a stored false is valid: no reason', () {
      final data = stored(popular: false);
      expect(carRepairReasons(carOf(data), data, now: now), isEmpty);
    });

    test('a value that is not a bool is a reason', () {
      for (final value in <Object?>['true', 1]) {
        final data = stored(popular: value);
        expect(carRepairReasons(carOf(data), data, now: now), [
          'popular is not true or false',
        ], reason: '$value');
      }
    });
  });

  group('otherVisiblePopularCount', () {
    FleetEntry entry(String id, {bool active = true, bool popular = true}) =>
        FleetCarEntry(
          carOf(
            rawCar(
              active: active,
              change: (d) {
                if (popular) d['popular'] = true;
              },
            ),
            id: id,
          ),
          needsRepair: false,
        );

    test('counts visible marked cars other than the one in the form', () {
      final entries = [
        entry('a'),
        entry('b'),
        entry('c', active: false),
        entry('d', popular: false),
        const FleetUnreadableEntry('e'),
        entry('f'),
      ];
      expect(otherVisiblePopularCount(entries), 3);
      expect(otherVisiblePopularCount(entries, carId: 'a'), 2);
      expect(otherVisiblePopularCount(entries, carId: 'c'), 3);
    });

    test('an empty list: none', () {
      expect(otherVisiblePopularCount(const []), 0);
    });
  });
}
