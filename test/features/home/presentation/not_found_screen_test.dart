import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/home/presentation/not_found_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colour behind [element]: the nearest painted Material above it (the
/// page, or the button).
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
  return found ?? appBackgroundColor;
}

AppLocalizations texts(String language) =>
    lookupAppLocalizations(Locale(language));

/// The page alone (the router is tested in not_found_routes_test.dart).
Future<void> pumpPage(
  WidgetTester tester, {
  String language = 'en',
  Size size = const Size(400, 900),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NotFoundScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    group(language, () {
      testWidgets('the heading, the text and the button; no back arrow', (
        tester,
      ) async {
        await pumpPage(tester, language: language);
        final l10n = texts(language);
        expect(find.text(l10n.notFoundTitle), findsOneWidget);
        expect(find.text(l10n.notFoundText), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, l10n.notFoundGoHome),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
      });

      testWidgets('360 px at text size 1.3: no overflow', (tester) async {
        // A layout overflow is reported as an error and fails the test.
        await pumpPage(
          tester,
          language: language,
          size: const Size(360, 640),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final l10n = texts(language);
        for (final text in [l10n.notFoundTitle, l10n.notFoundText]) {
          final rect = tester.getRect(find.text(text));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
      });

      testWidgets('readable: every text and icon has a contrast of at least '
          '4.5 with what is behind it', (tester) async {
        await pumpPage(tester, language: language);
        final body = find.descendant(
          of: find.byType(NotFoundScreen),
          matching: find.byType(SafeArea),
        );
        final paragraphs = find.descendant(
          of: body,
          matching: find.byType(RichText),
        );
        expect(paragraphs, findsWidgets);
        for (final element in paragraphs.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final color = paragraph.text.style!.color!;
          final behind = backgroundOf(element);
          expect(
            contrast(color, behind),
            greaterThanOrEqualTo(4.5),
            reason: '"${paragraph.text.toPlainText()}" $color on $behind',
          );
        }
      });
    });
  }

  testWidgets('a wide window: in the middle, at most 720 wide', (tester) async {
    await pumpPage(tester, size: const Size(1400, 900));
    final text = tester.getRect(find.text(texts('en').notFoundText));
    expect(text.width, lessThanOrEqualTo(notFoundMaxWidth));
    expect(text.center.dx, closeTo(700, 0.5));
  });

  testWidgets('the heading is a header for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);
    expect(
      tester.getSemantics(find.text(texts('en').notFoundTitle)),
      isSemantics(isHeader: true),
    );
    semantics.dispose();
  });

  test('the 3 texts are filled in ka, ru and en, without outer spaces, and '
      'differ between the languages', () {
    List<String> of(String language) {
      final l10n = texts(language);
      return [l10n.notFoundTitle, l10n.notFoundText, l10n.notFoundGoHome];
    }

    final all = {
      for (final l in ['ka', 'ru', 'en']) l: of(l),
    };
    for (final MapEntry(key: language, value: values) in all.entries) {
      for (final value in values) {
        expect(value, isNotEmpty, reason: language);
        expect(value.trim(), value, reason: language);
      }
    }
    for (var i = 0; i < 3; i++) {
      expect({all['ka']![i], all['ru']![i], all['en']![i]}, hasLength(3));
    }
  });
}
