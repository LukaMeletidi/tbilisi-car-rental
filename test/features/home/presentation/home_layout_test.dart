import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_hero.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_page_view.dart';

import 'home_harness.dart';

/// The page views of Home and their number of pages.
const pageViews = {'process': 4, 'benefits': 3, 'conditions': 3, 'traffic': 3};

/// Every text of the shown page lies fully inside the swiped area.
void expectShownPageFits(WidgetTester tester, String name, int page) {
  final view = find.descendant(
    of: find.ancestor(
      of: find.byKey(homePageDotKey(name, 0)),
      matching: find.byType(HomePageView),
    ),
    matching: find.byType(PageView),
  );
  final area = tester.getRect(view);
  final texts = find.descendant(of: view, matching: find.byType(RichText));
  expect(texts, findsWidgets);
  for (final text in texts.evaluate()) {
    final rect = tester.getRect(find.byWidget(text.widget));
    if (rect.right <= area.left || rect.left >= area.right) continue;
    expect(
      rect.top >= area.top - 0.5 && rect.bottom <= area.bottom + 0.5,
      isTrue,
      reason: '$name page $page: a text is cut off ($rect in $area)',
    );
  }
}

void main() {
  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language at 360 px and text size 1.3: no overflow, and '
        'every page shows its whole text', (tester) async {
      // A layout overflow is reported as an error and fails the test.
      await pumpHome(
        tester,
        size: const Size(360, 780),
        textScale: 1.3,
        language: language,
      );
      final texts = homeTexts(language);
      expect(find.text(texts.homeHeroTitle), findsOneWidget);

      for (final MapEntry(key: name, value: count) in pageViews.entries) {
        for (var page = 0; page < count; page++) {
          final dot = find.byKey(homePageDotKey(name, page));
          await tester.ensureVisible(dot);
          await tester.pumpAndSettle();
          await tester.tap(dot);
          await tester.pumpAndSettle();
          expectShownPageFits(tester, name, page);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final language in ['ka', 'ru', 'en']) {
    testWidgets('$language: the block titles are centered over the width', (
      tester,
    ) async {
      await pumpHome(tester, size: const Size(360, 780), language: language);
      final l10n = homeTexts(language);
      final titles = [
        l10n.homeTopCarsTitle,
        l10n.homeProcessTitle,
        l10n.homeBenefitsTitle,
        l10n.homeTermsTitle,
        l10n.homeTrafficTitle,
      ];
      for (final title in titles) {
        final text = find.text(title);
        expect(text, findsOneWidget, reason: title);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)),
        );
        expect(paragraph.textAlign, TextAlign.center, reason: title);
        // The box of the title spans the content, so its middle is the
        // middle of the screen, also for a title of several lines.
        expect(
          tester.getRect(text).center.dx,
          closeTo(180, 0.01),
          reason: title,
        );
      }
      // The hero title stays at the bottom left.
      final hero = tester.getRect(find.text(l10n.homeHeroTitle));
      expect(hero.left, closeTo(16 + 16, 0.01));
    });
  }

  testWidgets('the hero keeps the shape of its photo on a phone', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(360, 780));
    final hero = tester.getSize(find.byKey(homeHeroKey));
    // 360 minus two gutters of 16, at 1600 by 675.
    expect(hero.height, closeTo(328 * 675 / 1600, 1));
  });

  testWidgets('a wide window: Home stands in the middle, at most 720 wide', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(1400, 900));
    final hero = tester.getRect(find.byKey(homeHeroKey));
    expect(hero.width, 720);
    expect(hero.center.dx, closeTo(700, 1));
  });
}
