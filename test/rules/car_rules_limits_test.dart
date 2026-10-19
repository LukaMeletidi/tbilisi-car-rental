import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';

/// These tests read firestore.rules as text and compare it with the Dart
/// code. They do not run the rules; tool/check_booking_rules.mjs does that
/// on the emulator.
final rules = File('firestore.rules').readAsStringSync();

/// The number returned by a one-line rules function, for example
/// "function carMaxSeats() { return 9; }".
int ruleNumber(String function) {
  final match = RegExp(
    'function $function\\(\\) \\{ return ([0-9]+); \\}',
  ).firstMatch(rules);
  if (match == null) fail('firestore.rules has no number "$function".');
  return int.parse(match.group(1)!);
}

/// The quoted names in the list that follows [start] in the rules.
List<String> ruleList(String start) {
  final from = rules.indexOf(start);
  if (from < 0) fail('firestore.rules does not contain "$start".');
  final to = rules.indexOf(']', from + start.length);
  return [
    for (final match in RegExp(
      "'([A-Za-z0-9]+)'",
    ).allMatches(rules.substring(from + start.length, to)))
      match.group(1)!,
  ];
}

/// The text of the rules function [name], up to the next function or match.
String ruleFunction(String name) {
  final from = rules.indexOf('function $name(');
  if (from < 0) fail('firestore.rules has no function "$name".');
  final next = RegExp(
    r'\n    (function |match |// )',
  ).firstMatch(rules.substring(from + 1));
  return next == null
      ? rules.substring(from)
      : rules.substring(from, from + 1 + next.start);
}

final car = Car(
  id: 'car-1',
  brand: 'Honda',
  model: 'Civic',
  year: 2019,
  drivetrain: Drivetrain.fwd,
  transmission: Transmission.automatic,
  fuelType: FuelType.hybrid,
  seats: 5,
  engineSize: 1.8,
  pricePerDay: 45,
  description: const LocalizedText(ka: 'ქართული', ru: 'Русский', en: 'English'),
  photos: const ['https://photos.example.com/car-1.jpg'],
  active: true,
  popular: true,
);

void main() {
  test('each limit in the rules equals its Dart constant', () {
    expect(ruleNumber('carNameMaxLength'), carNameMaxLength);
    expect(ruleNumber('carMinYear'), carMinYear);
    expect(ruleNumber('carMaxSeats'), carMaxSeats);
    expect(ruleNumber('carMaxPricePerDay'), carMaxPricePerDay);
    expect(ruleNumber('carMaxEngineSize'), carMaxEngineSize);
    expect(ruleNumber('carDescriptionMaxLength'), carDescriptionMaxLength);
    expect(ruleNumber('carMaxPhotos'), carMaxPhotos);
    expect(ruleNumber('carPhotoMaxLength'), carPhotoMaxLength);
  });

  test('the limits that the rules write out in words', () {
    final valid = ruleFunction('isValidCar');
    expect(valid, contains('car.year <= request.time.year() + $carYearsAhead'));
    expect(valid, contains('car.seats >= $carMinSeats'));
    expect(valid, contains('car.pricePerDay > 0'));
    expect(valid, contains('car.engineSize > 0'));
    expect(valid, contains('isTrimmedText(car.brand, 1, carNameMaxLength())'));
    expect(valid, contains('isTrimmedText(car.model, 1, carNameMaxLength())'));
    expect(ruleFunction('isCarPhoto'), contains("p.matches('^$carPhotoScheme"));
  });

  test('the fields the rules allow are the fields of the constants', () {
    expect(ruleList('return car.keys().hasOnly(['), carFields);
    expect(ruleList('&& car.keys().hasAll(['), [
      for (final field in carFields)
        if (!carOptionalFields.contains(field)) field,
    ]);
  });

  test('a car written by the app has exactly the allowed fields', () {
    expect(car.toMap().keys, unorderedEquals(carFields));
    // Without the two optional fields: no engine size, not popular.
    final withoutOptional = Car.fromMap(
      'car-2',
      car.toMap()
        ..remove('engineSize')
        ..remove('popular'),
    );
    expect(
      withoutOptional.toMap().keys,
      unorderedEquals([
        for (final field in carFields)
          if (!carOptionalFields.contains(field)) field,
      ]),
    );
  });

  test('the fixed lists of the rules are the values of the app', () {
    final valid = ruleFunction('isValidCar');
    List<String> listAfter(String start) {
      final from = valid.indexOf(start);
      if (from < 0) fail('isValidCar does not contain "$start".');
      final to = valid.indexOf(']', from);
      return [
        for (final match in RegExp(
          "'([A-Za-z0-9]+)'",
        ).allMatches(valid.substring(from, to)))
          match.group(1)!,
      ];
    }

    expect(listAfter('car.drivetrain in ['), [
      for (final value in Drivetrain.values) value.name,
    ]);
    expect(listAfter('car.transmission in ['), [
      for (final value in Transmission.values) value.name,
    ]);
    expect(listAfter('car.fuelType in ['), [
      for (final value in FuelType.values) value.name,
    ]);
  });

  test('the description languages of the rules are the app languages', () {
    final description = ruleFunction('isValidCarDescription');
    final only = RegExp(r"hasOnly\(\[([^\]]*)\]").firstMatch(description);
    final all = RegExp(r"hasAll\(\[([^\]]*)\]").firstMatch(description);
    List<String> names(RegExpMatch? match) => [
      for (final name in RegExp("'([a-z]+)'").allMatches(match!.group(1)!))
        name.group(1)!,
    ];

    expect(names(only), carDescriptionLanguages);
    expect(names(all), carDescriptionLanguages);
    // The same languages as the app has, in whatever order.
    expect(
      carDescriptionLanguages,
      unorderedEquals([
        for (final language in AppLanguage.values) language.code,
      ]),
    );
    expect(car.description.toMap().keys, carDescriptionLanguages);
    for (final language in carDescriptionLanguages) {
      expect(
        description,
        contains('isTrimmedText(d.$language, 1, carDescriptionMaxLength())'),
      );
    }
  });

  test('the photo list has one check per allowed photo, no more', () {
    final photos = ruleFunction('isValidCarPhotos');
    for (var i = 0; i < carMaxPhotos; i++) {
      expect(photos, contains('(p.size() < ${i + 1} || isCarPhoto(p[$i]))'));
    }
    expect('isCarPhoto(p['.allMatches(photos), hasLength(carMaxPhotos));
    expect(photos, contains('p.size() <= carMaxPhotos()'));
    expect(photos, contains('p.toSet().size() == p.size()'));
  });

  test('a car is never deleted, and only an admin writes one', () {
    final from = rules.indexOf('match /cars/{carId} {');
    final block = rules.substring(from, rules.indexOf('\n    }', from));

    expect(block, contains('allow delete: if false;'));
    expect(block, contains('allow create: if isAdmin()'));
    expect(block, contains('allow update: if isAdmin()'));
    expect(
      block,
      contains('allow read: if resource.data.active == true || isAdmin();'),
    );
    expect(block, isNot(contains('allow write')));
  });

  test('hiding and showing touches only "active"', () {
    final only = ruleFunction('isOnlyActiveChange');
    expect(only, contains(".hasOnly(['active'])"));
    expect(only, contains('request.resource.data.active is bool'));
  });
}
