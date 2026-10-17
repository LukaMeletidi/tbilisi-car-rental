import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_limits.dart';

/// These tests read firestore.rules as text and compare it with the Dart
/// code. They do not run the rules; tool/check_booking_rules.mjs does that
/// on the emulator.
final rules = File('firestore.rules').readAsStringSync();

/// The number returned by a one-line rules function, for example
/// "function extraMaxPricePerDay() { return 100; }".
int ruleNumber(String function) {
  final match = RegExp(
    'function $function\\(\\) \\{ return ([0-9]+); \\}',
  ).firstMatch(rules);
  if (match == null) fail('firestore.rules has no number "$function".');
  return int.parse(match.group(1)!);
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

/// The text of the match block that starts with [start].
String ruleBlock(String start) {
  final from = rules.indexOf(start);
  if (from < 0) fail('firestore.rules does not contain "$start".');
  return rules.substring(from, rules.indexOf('\n    }', from));
}

/// The quoted names in the list that follows [start] in [text].
List<String> listAfter(String text, String start) {
  final from = text.indexOf(start);
  if (from < 0) fail('The rules text does not contain "$start".');
  final to = text.indexOf(']', from + start.length);
  return [
    for (final match in RegExp(
      "'([A-Za-z0-9]+)'",
    ).allMatches(text.substring(from + start.length, to)))
      match.group(1)!,
  ];
}

/// The single-quoted pattern of the first "[prefix].matches('...')" in
/// [text].
String patternAfter(String text, String prefix) {
  final match = RegExp(
    "${RegExp.escape(prefix)}\\.matches\\('([^']*)'\\)",
  ).firstMatch(text);
  if (match == null) fail('No "$prefix.matches(...)" in the rules text.');
  return match.group(1)!;
}

final extraNames = [for (final extra in Extra.values) extra.name];

void main() {
  test('each limit in the rules equals its Dart constant', () {
    expect(ruleNumber('extraMaxPricePerDay'), extraMaxPricePerDay);
    expect(ruleNumber('companyNameMaxLength'), companyNameMaxLength);
    expect(ruleNumber('companyTextMaxLength'), companyTextMaxLength);
    expect(ruleNumber('companyLinkMaxLength'), companyLinkMaxLength);
  });

  test('settings/extras has exactly the four extras of the app', () {
    final extras = ruleFunction('isValidExtrasSettings');
    expect(listAfter(extras, 's.keys().hasOnly(['), extrasSettingsFields);
    expect(listAfter(extras, 's.keys().hasAll(['), extrasSettingsFields);
    expect(listAfter(extras, 's.pricesPerDay.keys().hasOnly('), extraNames);
    expect(listAfter(extras, 's.pricesPerDay.keys().hasAll('), extraNames);
    for (final name in extraNames) {
      expect(extras, contains('isExtraPrice(s.pricesPerDay.$name)'));
    }
    expect('isExtraPrice('.allMatches(extras), hasLength(extraNames.length));

    final price = ruleFunction('isExtraPrice');
    expect(price, contains('p is number'));
    expect(price, contains('p >= 0'));
    expect(price, contains('p <= extraMaxPricePerDay()'));
  });

  test('settings/company has the fields of the constants, all optional', () {
    final company = ruleFunction('isValidCompanySettings');
    expect(listAfter(company, 'company.keys().hasOnly(['), companyFields);
    expect(company, isNot(contains('hasAll')));
    for (final field in companyFields) {
      expect(company, contains("!('$field' in company)"));
    }
    expect(
      "' in company)".allMatches(company),
      hasLength(companyFields.length),
    );
    expect(
      company,
      contains('isTrimmedText(company.name, 1, companyNameMaxLength())'),
    );
    expect(company, contains('isCompanyPhone(company.phone)'));
    expect(company, contains('isCompanyEmail(company.email)'));
    expect(company, contains('isCompanyText(company.address)'));
    expect(company, contains('isCompanyText(company.workingHours)'));
    expect(company, contains('isCompanyLink(company.mapUrl)'));
    expect(company, contains('isCompanySocial(company.social)'));
  });

  test('the social links are the four of the constants, never empty', () {
    final social = ruleFunction('isCompanySocial');
    expect(listAfter(social, 's.keys().hasOnly(['), companySocialFields);
    for (final field in companySocialFields) {
      expect(social, contains("(!('$field' in s) || isCompanyLink(s.$field))"));
    }
    expect(social, contains('s.size() > 0'));
  });

  test('a translated company text needs every app language', () {
    final text = ruleFunction('isCompanyText');
    expect(listAfter(text, 't.keys().hasOnly(['), companyTextLanguages);
    expect(listAfter(text, 't.keys().hasAll(['), companyTextLanguages);
    expect(
      companyTextLanguages,
      unorderedEquals([
        for (final language in AppLanguage.values) language.code,
      ]),
    );
    for (final language in companyTextLanguages) {
      expect(
        text,
        contains('isTrimmedText(t.$language, 1, companyTextMaxLength())'),
      );
    }
  });

  test('a company link is https only, with the car photo pattern', () {
    final link = ruleFunction('isCompanyLink');
    final pattern = patternAfter(link, 'l');
    expect(pattern, startsWith('^$companyLinkScheme'));
    expect(pattern, patternAfter(ruleFunction('isCarPhoto'), 'p'));
    expect(link, contains('l.size() <= companyLinkMaxLength()'));
    expect(companyLinkScheme, carPhotoScheme);
  });

  test('the company phone and e-mail are checked as in a booking', () {
    final customer = ruleFunction('isValidCustomer');

    final phone = patternAfter(ruleFunction('isCompanyPhone'), 'p');
    expect(phone, patternAfter(customer, 'c.phone'));
    expect(
      phone,
      "^\\\\+[1-9][0-9]"
      '{${bookingPhoneMinDigits - 1},${bookingPhoneMaxDigits - 1}}\$',
    );

    final email = ruleFunction('isCompanyEmail');
    expect(patternAfter(email, 'e'), patternAfter(customer, 'c.email'));
    expect(email, contains('e.size() <= emailMaxLength()'));
    expect(customer, contains('c.email.size() <= emailMaxLength()'));
  });

  test('only an admin writes extras and company, nobody deletes', () {
    for (final document in ['extras', 'company']) {
      final block = ruleBlock('match /settings/$document {');
      expect(block, contains('allow create, update: if isAdmin()'));
      expect(block, contains('allow delete: if false;'));
      expect(block, isNot(contains('allow write')));
      expect(block, isNot(contains('allow read')));
    }
    expect(
      ruleBlock('match /settings/extras {'),
      contains('isValidExtrasSettings(request.resource.data)'),
    );
    expect(
      ruleBlock('match /settings/company {'),
      contains('isValidCompanySettings(request.resource.data)'),
    );

    final generic = ruleBlock('match /settings/{settingId} {');
    expect(generic, contains('allow read: if true;'));
    expect(generic, contains('allow write: if false;'));
    expect('allow '.allMatches(generic), hasLength(2));

    // settings/locations stays closed: it has no block of its own.
    expect(rules, isNot(contains('match /settings/locations')));
    expect(RegExp(r'match /settings/[a-z]').allMatches(rules), hasLength(2));
  });

  test('no allowed extras price can make a total the booking rules refuse', () {
    final highestPerDay =
        carMaxPricePerDay + Extra.values.length * extraMaxPricePerDay;
    expect(
      bookingMaxRentalDays * highestPerDay,
      lessThanOrEqualTo(bookingMaxTotalPrice),
    );
  });

  test('the emulator seeds settings/extras in the shape of the rules', () {
    final script = File('tool/check_booking_rules.mjs').readAsStringSync();
    final from = script.indexOf("await seed('settings/extras', {");
    expect(from, greaterThanOrEqualTo(0));
    final seed = script.substring(from, script.indexOf('});', from));
    expect(seed, contains('pricesPerDay: {'));
    expect([
      for (final match in RegExp(r'(\w+): \d').allMatches(seed))
        match.group(1)!,
    ], extraNames);
  });
}
