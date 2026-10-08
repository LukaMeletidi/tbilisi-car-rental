import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';

void main() {
  group('mapCarReadError', () {
    test('"permission denied" becomes "car not available"', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(mapCarReadError(error), isA<CarNotAvailableException>());
    });

    test('another Firestore error is returned unchanged', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(mapCarReadError(error), same(error));
    });

    test('an error that is not from Firestore is returned unchanged', () {
      final error = Exception('no connection');
      expect(mapCarReadError(error), same(error));
    });

    test('"car not available" stays what it is', () {
      const error = CarNotAvailableException();
      expect(mapCarReadError(error), isA<CarNotAvailableException>());
    });
  });
}
