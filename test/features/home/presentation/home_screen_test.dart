import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_screen.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_hero.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_popular_cars.dart';

import 'home_harness.dart';

final en = homeTexts('en');

Finder get popularCards => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('home-popular-'),
);

/// The IDs of the popular cards, from left to right.
List<String> popularIds(WidgetTester tester) {
  final cards = popularCards.evaluate().toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a.widget))
          .dx
          .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dx),
    );
  return [
    for (final card in cards)
      (card.widget.key! as ValueKey<String>).value.substring(
        'home-popular-'.length,
      ),
  ];
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settleHome(tester);
}

void main() {
  testWidgets('Home is the first tab and shows every block', (tester) async {
    await pumpHome(tester);
    expect(browserAddress(tester), '/');
    expect(selectedTab(tester), 0);
    expect(find.byType(HomeScreen), findsOneWidget);
    for (final title in [
      en.homeHeroTitle,
      en.homeHeroSubtitle,
      en.homeTopCarsTitle,
      en.homeProcessTitle,
      en.homeBenefitsTitle,
      en.homeTermsTitle,
      en.homeTrafficTitle,
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  group('the hero', () {
    testWidgets('a tap opens the catalog on the Cars tab', (tester) async {
      await pumpHome(tester);
      await tapVisible(tester, find.byKey(homeHeroKey));
      expect(browserAddress(tester), '/cars');
      expect(selectedTab(tester), 1);
      expect(find.byType(CatalogScreen), findsOneWidget);
    });

    testWidgets('one button for screen readers, named by the title', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester);
      expect(
        tester.getSemantics(find.byKey(homeHeroKey)),
        matchesSemantics(
          label: en.homeHeroTitle,
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('the popular cars', () {
    testWidgets('the marked cars, in catalog order, photo only', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(popularIds(tester), ['car-a', 'car-b', 'car-c']);
      // Photo only: no brand or model is written on Home.
      expect(find.textContaining('Brand'), findsNothing);
    });

    testWidgets('a tap opens the car page above Home; Back returns to Home', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapVisible(tester, find.byKey(homePopularCarKey('car-b')));
      // A push that the browser address shows too
      // (optionURLReflectsImperativeAPIs).
      expect(routerOf(tester).state.uri.toString(), '/cars/car-b');
      expect(browserAddress(tester), '/cars/car-b');
      expect(find.byType(CarDetailScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.pageBack();
      await settleHome(tester);
      expect(browserAddress(tester), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
    });

    testWidgets('card -> Book -> Back (the car) -> Back (the catalog)', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapVisible(tester, find.byKey(homePopularCarKey('car-a')));
      expect(find.byType(CarDetailScreen), findsOneWidget);

      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Make a booking'),
      );
      expect(find.byType(BookingFormScreen), findsOneWidget);
      expect(browserAddress(tester), '/cars/car-a/book');

      await tester.pageBack();
      await settleHome(tester);
      expect(find.byType(CarDetailScreen), findsOneWidget);
      expect(browserAddress(tester), '/cars/car-a');

      // The existing behaviour of the car page: "Make a booking" uses
      // context.go, which builds the stack Cars -> car -> form anew. The
      // way back after a booking form therefore ends on the catalog, not
      // on Home (decided in step 6b.6; the button is unchanged).
      await tester.pageBack();
      await settleHome(tester);
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(browserAddress(tester), '/cars');
      expect(selectedTab(tester), 1);
    });

    // At 400 px: a row of 400 - 2 * 16, three thirds with two gaps of 8.
    const third = (400 - 32 - 16) / 3;
    for (final count in [1, 2, 3]) {
      testWidgets('$count marked: cards of a third, the row in the middle', (
        tester,
      ) async {
        final ids = [for (var i = 0; i < count; i++) 'car-$i'];
        await pumpHome(tester, cars: [for (final id in ids) homeCar(id)]);
        expect(popularIds(tester), ids);
        final rects = [
          for (final id in ids)
            tester.getRect(find.byKey(homePopularCarKey(id))),
        ];
        for (final rect in rects) {
          expect(rect.width, closeTo(third, 0.01));
        }
        final row = rects.reduce((a, b) => a.expandToInclude(b));
        expect(row.center.dx, closeTo(200, 0.01));
        if (count == 3) {
          // Three fill the row from gutter to gutter.
          expect(row.left, closeTo(16, 0.01));
          expect(row.right, closeTo(384, 0.01));
        }
      });
    }

    testWidgets('a car without a photo shows the catalog placeholder', (
      tester,
    ) async {
      await pumpHome(tester, cars: [homeCar('only')]);
      expect(
        find.descendant(
          of: find.byKey(homePopularCarKey('only')),
          matching: find.byIcon(Icons.directions_car),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no car marked: the block is hidden', (tester) async {
      await pumpHome(tester, cars: [homeCar('plain', popular: false)]);
      expect(find.text(en.homeTopCarsTitle), findsNothing);
      expect(popularCards, findsNothing);
      expect(find.text(en.homeHeroTitle), findsOneWidget);
    });

    testWidgets('while the cars load: hidden, the rest is shown', (
      tester,
    ) async {
      await pumpHome(tester, carsPending: true);
      expect(find.text(en.homeTopCarsTitle), findsNothing);
      expect(find.text(en.homeProcessTitle), findsOneWidget);
    });

    testWidgets('when the cars cannot be loaded: hidden, no error on Home', (
      tester,
    ) async {
      await pumpHome(tester, carsError: Exception('made-up failure'));
      expect(find.text(en.homeTopCarsTitle), findsNothing);
      expect(find.text(en.homeProcessTitle), findsOneWidget);
    });
  });
}
