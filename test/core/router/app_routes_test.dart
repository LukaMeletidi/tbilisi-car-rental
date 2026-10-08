import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';

void main() {
  group('AppRoutes.car', () {
    test('builds the address of a car', () {
      expect(AppRoutes.car('abc123'), '/cars/abc123');
    });

    test('encodes characters that are not safe in an address', () {
      expect(AppRoutes.car('a b'), '/cars/a%20b');
      expect(AppRoutes.car('a/b'), '/cars/a%2Fb');
    });
  });
}
