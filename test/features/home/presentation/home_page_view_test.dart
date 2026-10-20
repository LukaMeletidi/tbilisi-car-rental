import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_page_view.dart';

const pageHeights = [80.0, 240.0, 120.0];

Future<void> pumpPages(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListView(
          children: [
            HomePageView(
              name: 'test',
              pages: [
                for (final (index, height) in pageHeights.indexed)
                  SizedBox(height: height, child: Text('Page $index')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page that is shown: its text lies inside the swiped area.
int shownPage(WidgetTester tester) {
  final view = tester.getRect(find.byType(PageView));
  for (var i = 0; i < pageHeights.length; i++) {
    final text = find.descendant(
      of: find.byType(PageView),
      matching: find.text('Page $i'),
    );
    if (text.evaluate().isNotEmpty &&
        view.contains(tester.getCenter(text.first))) {
      return i;
    }
  }
  return -1;
}

Color dotColor(WidgetTester tester, int index) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(homePageDotKey('test', index)),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('the view is as tall as the tallest page', (tester) async {
    await pumpPages(tester);
    expect(tester.getSize(find.byType(PageView)).height, 240);
  });

  testWidgets('a tap on a dot opens its page; the dot is filled', (
    tester,
  ) async {
    await pumpPages(tester);
    expect(shownPage(tester), 0);
    expect(dotColor(tester, 0), Colors.white);
    expect(dotColor(tester, 2), isNot(Colors.white));

    await tester.tap(find.byKey(homePageDotKey('test', 2)));
    await tester.pumpAndSettle();
    expect(shownPage(tester), 2);
    expect(dotColor(tester, 2), Colors.white);
    expect(dotColor(tester, 0), isNot(Colors.white));
  });

  testWidgets('a swipe by touch moves one page', (tester) async {
    await pumpPages(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shownPage(tester), 1);
    expect(dotColor(tester, 1), Colors.white);
  });

  testWidgets('a mouse drag also moves the pages (Chrome)', (tester) async {
    await pumpPages(tester);
    await tester.drag(
      find.byType(PageView),
      const Offset(-300, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(shownPage(tester), 1);
  });

  testWidgets('the dots are hidden from screen readers', (tester) async {
    await pumpPages(tester);
    expect(
      find.ancestor(
        of: find.byKey(homePageDotKey('test', 0)),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });

  testWidgets('the invisible copies take no taps', (tester) async {
    await pumpPages(tester);
    // Each page is built twice: the invisible copy for the height and the
    // page in the view. Only the page in the view can be hit.
    expect(find.text('Page 0'), findsNWidgets(2));
    expect(find.text('Page 0').hitTestable(), findsOneWidget);
  });
}
