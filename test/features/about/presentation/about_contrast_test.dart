import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/section_title.dart';
import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/contacts_card.dart';

import '../about_samples.dart';
import 'about_harness.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colour behind [element]: the nearest painted Material above it (a
/// button inside the card has its own).
Color backgroundOf(Element element) {
  Color? found;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Material &&
        widget.type != MaterialType.transparency &&
        widget.color != null &&
        widget.color!.a > 0) {
      found = widget.color;
      return false;
    }
    return true;
  });
  return found!;
}

/// Every text and icon (RichText) and every selectable value (EditableText)
/// on every card has a contrast of at least 4.5 with what is behind it: the
/// white card, or a button on it.
void expectReadableCards(WidgetTester tester, String reason) {
  final cards = find.byType(Card);
  expect(cards, findsWidgets);
  for (final card in cards.evaluate()) {
    final of = find.byWidget(card.widget);
    final background = tester
        .widget<Material>(
          find.descendant(of: of, matching: find.byType(Material)).first,
        )
        .color!;
    expect(background, Colors.white);
    final colors = <(String, Color, Color)>[
      for (final element
          in find
              .descendant(of: of, matching: find.byType(RichText))
              .evaluate())
        (
          (element.renderObject! as RenderParagraph).text.toPlainText(),
          (element.renderObject! as RenderParagraph).text.style!.color!,
          backgroundOf(element),
        ),
      for (final element
          in find
              .descendant(of: of, matching: find.byType(EditableText))
              .evaluate())
        (
          (element.widget as EditableText).controller.text,
          (element.widget as EditableText).style.color!,
          backgroundOf(element),
        ),
    ];
    expect(colors, isNotEmpty);
    for (final (text, color, behind) in colors) {
      expect(
        contrast(color, behind),
        greaterThanOrEqualTo(4.5),
        reason: '$reason "$text" is $color on $behind',
      );
    }
  }
}

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language: every field, the headings on purple, the links '
        'purple and underlined', (tester) async {
      await pumpAbout(
        tester,
        answer: CompanyData(fullCompany()),
        size: const Size(400, 2000),
        language: language,
      );
      expectReadableCards(tester, language);

      for (final heading in tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(SectionTitle),
          matching: find.byType(RichText),
        ),
      )) {
        expect(
          contrast(heading.text.style!.color!, appBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      }

      final link = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(contactRowKey(ContactKind.phone)),
          matching: find.byType(EditableText),
        ),
      );
      expect(link.style.color, appBackgroundColor);
      expect(link.style.decoration, TextDecoration.underline);
      expect(
        contrast(appBackgroundColor, Colors.white),
        greaterThanOrEqualTo(7),
      );
    });

    testWidgets('$language: the error card is readable', (tester) async {
      await pumpAbout(tester, answer: const CompanyError(), language: language);
      expectReadableCards(tester, '$language error');
    });
  }
}
