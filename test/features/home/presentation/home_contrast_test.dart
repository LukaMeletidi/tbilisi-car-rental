import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_photo_backdrop.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_section_title.dart';

import 'home_harness.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The dark layer over the worst photo: one that is pure white there.
final scrimOnWhite = Color.alphaBlend(homeScrimColor, Colors.white);

Color colorOf(Element text) =>
    (text.renderObject! as RenderParagraph).text.style!.color!;

String plain(Element text) =>
    (text.renderObject! as RenderParagraph).text.toPlainText();

void main() {
  test('white on the dark layer is readable even over pure white', () {
    expect(contrast(Colors.white, scrimOnWhite), greaterThanOrEqualTo(4.5));
  });

  for (final language in ['ka', 'ru', 'en']) {
    group(language, () {
      testWidgets('the cards: purple or dark titles, dark text, on white', (
        tester,
      ) async {
        await pumpHome(tester, language: language);
        final cards = find.byType(Card);
        expect(cards, findsWidgets);
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
          for (final text
              in find
                  .descendant(
                    of: find.byWidget(card.widget),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            expect(
              contrast(colorOf(text), background),
              greaterThanOrEqualTo(4.5),
              reason: '"${plain(text)}" is ${colorOf(text)}',
            );
          }
        }
        // The benefits and conditions titles are purple, the traffic
        // titles dark.
        final l10n = homeTexts(language);
        Color titleColor(String title) =>
            colorOf(find.text(title).evaluate().first);
        expect(titleColor(l10n.homeBenefit1Title), appBackgroundColor);
        expect(titleColor(l10n.homeTerms1Title), appBackgroundColor);
        expect(
          contrast(titleColor(l10n.homeTraffic1Title), Colors.white),
          greaterThanOrEqualTo(7),
        );
      });

      testWidgets('white text on the photos lies on the dark layer', (
        tester,
      ) async {
        await pumpHome(tester, language: language);
        final backdrops = find.byType(HomePhotoBackdrop);
        expect(backdrops, findsNWidgets(3));
        var checked = 0;
        for (final backdrop in backdrops.evaluate()) {
          final widget = backdrop.widget as HomePhotoBackdrop;
          final texts = find.descendant(
            of: find.byWidget(widget),
            matching: find.byType(RichText),
          );
          for (final text in texts.evaluate()) {
            final onCard = find
                .ancestor(
                  of: find.byWidget(text.widget),
                  matching: find.byType(Card),
                )
                .evaluate()
                .isNotEmpty;
            if (onCard) continue;
            expect(colorOf(text), Colors.white, reason: plain(text));
            final onBand = find
                .ancestor(
                  of: find.byWidget(text.widget),
                  matching: find.byWidgetPredicate(
                    (w) => w is ColoredBox && w.color == homeScrimColor,
                  ),
                )
                .evaluate()
                .isNotEmpty;
            expect(
              widget.scrim || onBand,
              isTrue,
              reason: '"${plain(text)}" is not on the dark layer',
            );
            checked++;
          }
        }
        // The hero title and subtitle, the four steps (with their copies
        // and numbers) and the traffic title.
        expect(checked, greaterThanOrEqualTo(3));
      });

      testWidgets('the section titles and the step numbers on purple', (
        tester,
      ) async {
        await pumpHome(tester, language: language);
        final titles = find.descendant(
          of: find.byType(HomeSectionTitle),
          matching: find.byType(RichText),
        );
        expect(titles, findsWidgets);
        for (final text in titles.evaluate()) {
          expect(
            contrast(colorOf(text), appBackgroundColor),
            greaterThanOrEqualTo(4.5),
            reason: plain(text),
          );
        }
        final number = find.text('1').evaluate().first;
        expect(
          contrast(colorOf(number), appBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
