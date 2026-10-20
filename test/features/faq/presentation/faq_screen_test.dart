import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/faq/presentation/faq_screen.dart';
import 'package:tbilisi_car_rental/features/faq/presentation/widgets/faq_item.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import 'faq_harness.dart';

final en = lookupAppLocalizations(const Locale('en'));
final entries = faqOf('en');

void main() {
  testWidgets('the heading and the ten questions in order, all closed', (
    tester,
  ) async {
    await pumpFaq(tester, size: const Size(400, 3000));
    expect(find.text(en.faqPageHeading), findsOneWidget);
    expect(entries, hasLength(10));
    var lastTop = tester.getTopLeft(find.text(en.faqPageHeading)).dy;
    for (final (index, entry) in entries.indexed) {
      final question = find.descendant(
        of: find.byKey(faqItemKey(index + 1)),
        matching: find.text(entry.question),
      );
      expect(question, findsOneWidget, reason: entry.question);
      final top = tester.getTopLeft(question).dy;
      expect(top, greaterThan(lastTop));
      lastTop = top;
      expect(find.text(entry.answer), findsNothing);
    }
  });

  testWidgets('the heading is centered and a header', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpFaq(tester);
    final heading = find.text(en.faqPageHeading);
    expect(tester.getRect(heading).center.dx, closeTo(200, 0.01));
    expect(tester.getSemantics(heading), isSemantics(isHeader: true));
    semantics.dispose();
  });

  testWidgets('a tap opens the answer, another tap closes it', (tester) async {
    await pumpFaq(tester);
    final first = entries.first;
    await tapQuestion(tester, 1, first.question);
    expect(find.text(first.answer), findsOneWidget);
    await tapQuestion(tester, 1, first.question);
    expect(find.text(first.answer), findsNothing);
  });

  testWidgets('several answers can be open at once', (tester) async {
    await pumpFaq(tester, size: const Size(400, 3000));
    await tapQuestion(tester, 1, entries[0].question);
    await tapQuestion(tester, 3, entries[2].question);
    expect(find.text(entries[0].answer), findsOneWidget);
    expect(find.text(entries[2].answer), findsOneWidget);
    expect(find.text(entries[1].answer), findsNothing);
  });

  testWidgets('screen readers hear the hint "Collapsed", then "Expanded"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFaq(tester);
    final question = find.text(entries.first.question);
    expect(tester.getSemantics(question), isSemantics(hint: 'Collapsed'));
    await tapQuestion(tester, 1, entries.first.question);
    expect(tester.getSemantics(question), isSemantics(hint: 'Expanded'));
    semantics.dispose();
  });

  testWidgets('a wide window: the list stands in the middle, at most 720', (
    tester,
  ) async {
    await pumpFaq(tester, size: const Size(1400, 900));
    final card = tester.getRect(find.byKey(faqItemKey(1)));
    expect(card.width, lessThanOrEqualTo(faqMaxWidth));
    expect(card.center.dx, closeTo(700, 0.01));
  });
}
