import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/contacts_card.dart';

import '../about_samples.dart';
import 'about_harness.dart';

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language at 360 px and text size 1.3: no overflow, every '
        'row inside its card', (tester) async {
      // A layout overflow is reported as an error and fails the test.
      await pumpAbout(
        tester,
        answer: CompanyData(fullCompany()),
        size: const Size(360, 780),
        textScale: 1.3,
        language: language,
      );
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      final contacts = tester.getRect(cards.last);
      for (final kind in ContactKind.values) {
        final row = find.byKey(contactRowKey(kind));
        if (row.evaluate().isEmpty) continue;
        await tester.ensureVisible(row);
        await tester.pump();
        final rect = tester.getRect(row);
        final card = tester.getRect(cards.last);
        expect(
          rect.left >= card.left &&
              rect.right <= card.right &&
              rect.top >= card.top &&
              rect.bottom <= card.bottom,
          isTrue,
          reason: '$language $kind: $rect in $card',
        );
      }
      expect(contacts.width, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a wide window: in the middle, at most 720 wide', (tester) async {
    await pumpAbout(
      tester,
      answer: CompanyData(fullCompany()),
      size: const Size(1400, 1200),
    );
    final card = tester.getRect(find.byType(Card).first);
    expect(card.width, lessThanOrEqualTo(aboutMaxWidth));
    expect(card.center.dx, closeTo(700, 0.01));
  });
}
