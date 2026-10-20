import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/faq/presentation/widgets/faq_item.dart';

import 'faq_harness.dart';

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language at 360 px and text size 1.3, all ten answers '
        'open: no overflow, every answer fully inside its card', (
      tester,
    ) async {
      // A layout overflow is reported as an error and fails the test.
      await pumpFaq(
        tester,
        size: const Size(360, 780),
        textScale: 1.3,
        language: language,
      );
      final entries = faqOf(language);
      for (final (index, entry) in entries.indexed) {
        await tapQuestion(tester, index + 1, entry.question);
      }
      for (final (index, entry) in entries.indexed) {
        final answer = find.text(entry.answer);
        expect(answer, findsOneWidget, reason: '$language ${index + 1}');
        await tester.ensureVisible(answer);
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byKey(faqItemKey(index + 1)));
        final text = tester.getRect(answer);
        expect(
          text.left >= card.left &&
              text.right <= card.right &&
              text.bottom <= card.bottom,
          isTrue,
          reason: '$language answer ${index + 1}: $text in $card',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
