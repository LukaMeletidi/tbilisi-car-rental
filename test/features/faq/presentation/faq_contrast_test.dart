import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/section_title.dart';

import 'faq_harness.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every text and icon on every card has a contrast of at least 4.5 with
/// the card; the questions are the app purple.
void expectReadableCards(WidgetTester tester, String language) {
  final cards = find.byType(Card);
  expect(cards, findsNWidgets(10));
  for (final card in cards.evaluate()) {
    final background = tester
        .widget<Material>(
          find
              .descendant(
                of: find.byWidget(card.widget),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    expect(background, Colors.white);
    // Icons are drawn as text too, so the arrow is checked here as well.
    for (final element
        in find
            .descendant(
              of: find.byWidget(card.widget),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final color = paragraph.text.style!.color!;
      expect(
        contrast(color, background),
        greaterThanOrEqualTo(4.5),
        reason: '$language "${paragraph.text.toPlainText()}" is $color',
      );
    }
  }
  for (final entry in faqOf(language)) {
    final question = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text(entry.question),
        matching: find.byType(RichText),
      ),
    );
    expect(question.text.style!.color, appBackgroundColor);
  }
}

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language: the heading on purple, the cards closed and '
        'open', (tester) async {
      await pumpFaq(tester, size: const Size(400, 6000), language: language);
      final heading = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(SectionTitle),
          matching: find.byType(RichText),
        ),
      );
      expect(
        contrast(heading.text.style!.color!, appBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
      expectReadableCards(tester, language);

      for (final (index, entry) in faqOf(language).indexed) {
        await tapQuestion(tester, index + 1, entry.question);
      }
      expectReadableCards(tester, language);
    });
  }
}
