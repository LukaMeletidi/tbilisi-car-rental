import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/about/presentation/about_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, screen) in const <(String, Widget)>[
    ('Home', HomeScreen()),
    ('About', AboutScreen()),
    ('FAQ', FaqScreen()),
  ]) {
    for (final language in ['en', 'ka', 'ru']) {
      testWidgets('$name ($language): the text on the card is readable', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildAppTheme(),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: screen,
            ),
          ),
        );
        await tester.pump();

        final card = find.byType(Card);
        expect(card, findsOneWidget);
        final background = tester
            .widget<Material>(
              find.descendant(of: card, matching: find.byType(Material)).first,
            )
            .color!;
        final paragraphs = find.descendant(
          of: card,
          matching: find.byType(RichText),
        );
        expect(paragraphs, findsWidgets);
        for (final element in paragraphs.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final color = paragraph.text.style!.color!;
          expect(
            contrast(color, background),
            greaterThanOrEqualTo(4.5),
            reason: '"${paragraph.text.toPlainText()}" on $background',
          );
        }
      });
    }
  }
}
