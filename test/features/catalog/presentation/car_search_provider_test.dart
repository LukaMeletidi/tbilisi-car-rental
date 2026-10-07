import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/catalog/presentation/car_search_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts empty', () {
    expect(container.read(carSearchProvider), '');
  });

  test('setQuery keeps the text exactly as typed', () {
    container.read(carSearchProvider.notifier).setQuery('  Toyota pri');
    expect(container.read(carSearchProvider), '  Toyota pri');
  });

  test('clear empties the text', () {
    container.read(carSearchProvider.notifier).setQuery('toyota');
    container.read(carSearchProvider.notifier).clear();
    expect(container.read(carSearchProvider), '');
  });
}
