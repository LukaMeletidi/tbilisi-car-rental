import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));
  final ka = lookupAppLocalizations(const Locale('ka'));

  test('price per day keeps the dollar sign and the amount', () {
    expect(en.pricePerDay('45'), '\$45 / day');
    expect(en.pricePerDay('45.50'), '\$45.50 / day');
    expect(ru.pricePerDay('45'), '\$45 / день');
    expect(ka.pricePerDay('45'), _georgianPrice45);
  });

  test('English seats: singular and plural', () {
    expect(en.seatsCount(1), '1 seat');
    expect(en.seatsCount(2), '2 seats');
    expect(en.seatsCount(7), '7 seats');
  });

  test('Russian seats: the three plural forms', () {
    expect(ru.seatsCount(1), '1 место');
    expect(ru.seatsCount(2), '2 места');
    expect(ru.seatsCount(4), '4 места');
    expect(ru.seatsCount(5), '5 мест');
    expect(ru.seatsCount(7), '7 мест');
    expect(ru.seatsCount(21), '21 место');
  });

  test('Georgian seats: one form for every number', () {
    expect(ka.seatsCount(1), '1 $_georgianSeat');
    expect(ka.seatsCount(5), '5 $_georgianSeat');
  });
}

const _georgianPrice45 = '\$45 / დღე';
const _georgianSeat = 'ადგილი';
