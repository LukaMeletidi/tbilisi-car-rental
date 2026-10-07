import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';

void main() {
  group('catalogColumnCount', () {
    test('a phone has one column', () {
      expect(catalogColumnCount(320), 1);
      expect(catalogColumnCount(411), 1);
      expect(catalogColumnCount(799), 1);
    });

    test('800 to 1199 has two columns', () {
      expect(catalogColumnCount(800), 2);
      expect(catalogColumnCount(1199), 2);
    });

    test('1200 and wider has three columns, never more', () {
      expect(catalogColumnCount(1200), 3);
      expect(catalogColumnCount(1600), 3);
      expect(catalogColumnCount(4000), 3);
    });

    test('a zero width still gives one column', () {
      expect(catalogColumnCount(0), 1);
    });
  });
}
