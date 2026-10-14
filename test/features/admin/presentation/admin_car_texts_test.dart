import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';

void main() {
  test('every car error has its own English sentence', () {
    final texts = {
      for (final error in CarError.values) adminCarErrorText(error),
    };
    expect(texts, hasLength(CarError.values.length));
    for (final text in texts) {
      expect(text.trim(), isNotEmpty);
      expect(text, endsWith('.'));
    }
  });

  test('every photo error has its own English sentence', () {
    final texts = {
      for (final error in CarPhotoError.values) adminCarPhotoErrorText(error),
    };
    expect(texts, hasLength(CarPhotoError.values.length));
  });

  test('the numbers in the texts are the limits', () {
    expect(
      adminCarErrorText(CarError.brandTooLong),
      contains('$carNameMaxLength'),
    );
    expect(adminCarErrorText(CarError.yearTooOld), contains('$carMinYear'));
    expect(
      adminCarErrorText(CarError.seatsOutOfRange),
      'A car has $carMinSeats to $carMaxSeats seats.',
    );
    expect(
      adminCarErrorText(CarError.engineSizeOutOfRange),
      contains('$carMaxEngineSize litres'),
    );
    expect(
      adminCarErrorText(CarError.priceOutOfRange),
      contains('$carMaxPricePerDay USD'),
    );
    expect(
      adminCarErrorText(CarError.descriptionKaTooLong),
      contains('$carDescriptionMaxLength'),
    );
    expect(
      adminCarErrorText(CarError.tooManyPhotos),
      contains('$carMaxPhotos'),
    );
    expect(
      adminCarPhotoErrorText(CarPhotoError.tooLong),
      contains('$carPhotoMaxLength'),
    );
    expect(
      adminCarPhotoErrorText(CarPhotoError.notHttps),
      'The address must start with https://.',
    );
  });

  test('the approved wording of a few texts', () {
    expect(
      adminCarErrorText(CarError.priceInvalid),
      'Enter the price as a number with at most two decimals, for example '
      '45.50.',
    );
    expect(
      adminCarErrorText(CarError.descriptionRuRequired),
      'Enter the description in Russian.',
    );
    expect(
      adminCarPhotoErrorText(CarPhotoError.notWebAddress),
      'This is not a web address.',
    );
  });
}
