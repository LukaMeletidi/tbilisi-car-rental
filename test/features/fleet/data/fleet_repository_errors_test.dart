import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// Only what can be tested without a database: the mapping of errors, and
/// the guard that refuses a bad ID before anything is sent. The
/// transactions themselves run against Firestore; the rules side is proven
/// by tool/check_booking_rules.mjs.
void main() {
  group('mapCarWriteError', () {
    test('no answer in time: CarWriteNoAnswer, which is not "not saved"', () {
      expect(
        mapCarWriteError(TimeoutException('late')),
        isA<CarWriteNoAnswer>(),
      );
    });

    test('each Firestore code: its reason', () {
      final expected = {
        'unavailable': CarWriteFailure.noConnection,
        'deadline-exceeded': CarWriteFailure.noConnection,
        'permission-denied': CarWriteFailure.refused,
        'not-found': CarWriteFailure.carMissing,
        'aborted': CarWriteFailure.unknown,
        'internal': CarWriteFailure.unknown,
      };
      for (final entry in expected.entries) {
        final error = FirebaseException(
          plugin: 'cloud_firestore',
          code: entry.key,
        );
        expect(
          mapCarWriteError(error),
          CarWriteException(entry.value),
          reason: entry.key,
        );
      }
    });

    test('a car exception and a no-answer stay what they are', () {
      const missing = CarWriteException(CarWriteFailure.changedElsewhere);
      const late = CarWriteNoAnswer();
      expect(mapCarWriteError(missing), same(missing));
      expect(mapCarWriteError(late), same(late));
    });

    test('a code with the web prefix "firestore/": the same reason', () {
      for (final code in [
        'firestore/unavailable',
        'firestore/deadline-exceeded',
      ]) {
        expect(
          mapCarWriteError(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          const CarWriteException(CarWriteFailure.noConnection),
          reason: code,
        );
      }
    });

    test('an unrecognised type stays unknown; only its type is logged', () {
      expect(
        mapCarWriteError(const FormatException('Secret value')),
        const CarWriteException(CarWriteFailure.unknown),
      );
    });

    test('anything else: an unknown failure', () {
      expect(
        mapCarWriteError(StateError('broken')),
        const CarWriteException(CarWriteFailure.unknown),
      );
    });
  });

  group('carWriteDiagnosis: every route to "unknown" has a line', () {
    test('no line for an error with a known reason', () {
      for (final error in <Object>[
        TimeoutException('late'),
        const CarWriteNoAnswer(),
        const CarWriteException(CarWriteFailure.noConnection),
        const CarWriteException(CarWriteFailure.refused),
        const CarWriteException(CarWriteFailure.carMissing),
        const CarWriteException(CarWriteFailure.changedElsewhere),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'firestore/unavailable',
        ),
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      ]) {
        expect(carWriteDiagnosis(error), isNull, reason: '$error');
      }
    });

    test('a car exception that is already unknown: its own line', () {
      expect(
        carWriteDiagnosis(const CarWriteException(CarWriteFailure.unknown)),
        'CarWriteException(unknown)',
      );
    });

    test('a Firestore code without a reason: the code only', () {
      expect(
        carWriteDiagnosis(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'aborted',
            message: 'Secret message',
          ),
        ),
        'CarWriteException(unknown) from FirebaseException(code: aborted)',
      );
    });

    test('any other type: the type only, never the message', () {
      final text = carWriteDiagnosis(StateError('Secret value'));
      expect(text, 'CarWriteException(unknown) from StateError');
      expect(text, isNot(contains('Secret')));
      expect(
        carWriteDiagnosis(ArgumentError('Secret id')),
        'CarWriteException(unknown) from ArgumentError',
      );
    });

    test('the line agrees with the mapping: a line exactly when the result '
        'is unknown', () {
      for (final error in <Object>[
        TimeoutException('late'),
        const CarWriteNoAnswer(),
        const CarWriteException(CarWriteFailure.unknown),
        const CarWriteException(CarWriteFailure.refused),
        FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        StateError('broken'),
      ]) {
        final unknown =
            mapCarWriteError(error) ==
            const CarWriteException(CarWriteFailure.unknown);
        expect(carWriteDiagnosis(error) != null, unknown, reason: '$error');
      }
    });
  });

  group('a bad car ID is refused before anything is sent', () {
    // A repository without a usable Firestore instance: the guard must
    // throw before Firestore is touched at all.
    final repository = FleetRepository(_NoFirestore());
    final badCar = Car(
      id: 'bad.id',
      brand: 'Honda',
      model: 'Civic',
      year: 2019,
      drivetrain: Drivetrain.fwd,
      transmission: Transmission.automatic,
      fuelType: FuelType.petrol,
      seats: 5,
      engineSize: null,
      pricePerDay: 45,
      description: const LocalizedText(ka: 'a', ru: 'b', en: 'c'),
      photos: const [],
      active: false,
    );

    test('create', () {
      expect(() => repository.createCar(badCar), throwsArgumentError);
    });

    test('replace', () {
      expect(
        () => repository.replaceCar(badCar, base: badCar),
        throwsArgumentError,
      );
    });

    test('hide or show', () {
      expect(
        () => repository.setCarActive('cars/other', active: false),
        throwsArgumentError,
      );
    });
  });
}

/// Fails the test if any of its members is used.
class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('Firestore was used: ${invocation.memberName}');
}
