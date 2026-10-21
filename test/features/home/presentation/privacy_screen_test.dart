import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/core/widgets/privacy_link.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/widgets/submit_area.dart';
import 'package:tbilisi_car_rental/features/home/presentation/privacy_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

const languages = ['ka', 'ru', 'en'];

AppLocalizations texts(String language) =>
    lookupAppLocalizations(Locale(language));

/// The 15 texts of the Privacy Policy in one language, by name.
Map<String, String> privacyTexts(AppLocalizations l) => {
  'privacyTitle': l.privacyTitle,
  'privacy1Title': l.privacy1Title,
  'privacy1Text': l.privacy1Text,
  'privacy2Title': l.privacy2Title,
  'privacy2Text': l.privacy2Text,
  'privacy3Title': l.privacy3Title,
  'privacy3Text': l.privacy3Text,
  'privacy4Title': l.privacy4Title,
  'privacy4Text': l.privacy4Text,
  'privacy5Title': l.privacy5Title,
  'privacy5Text': l.privacy5Text,
  'privacy6Title': l.privacy6Title,
  'privacy6Text': l.privacy6Text,
  'privacyGoToContact': l.privacyGoToContact,
  'privacyConsent': l.privacyConsent,
};

/// The contrast ratio of two colours (WCAG): 1 for the same colour, 21 for
/// black on white.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colour behind [element]: the nearest painted Material above it.
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

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String language = 'en',
  Size size = const Size(400, 2400),
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
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

/// The Send area alone, as at the end of the booking form.
Widget submitArea({bool sending = false}) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: SubmitArea(
      showCheckFields: false,
      failureText: null,
      sending: sending,
      onSend: () {},
    ),
  ),
);

void main() {
  group('the page', () {
    for (final language in languages) {
      testWidgets('$language: the title, six sections and the Contact '
          'button; no phone and no e-mail address', (tester) async {
        await pumpScreen(tester, const PrivacyScreen(), language: language);
        final l = texts(language);
        expect(find.text(l.privacyTitle), findsOneWidget);
        for (final text in [
          l.privacy1Title,
          l.privacy1Text,
          l.privacy2Title,
          l.privacy2Text,
          l.privacy3Title,
          l.privacy3Text,
          l.privacy4Title,
          l.privacy4Text,
          l.privacy5Title,
          l.privacy5Text,
          l.privacy6Title,
          l.privacy6Text,
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.byType(Card), findsNWidgets(6));
        expect(find.byKey(privacyGoToContactKey), findsOneWidget);
        expect(find.textContaining('@'), findsNothing);
        expect(find.textContaining('+995'), findsNothing);
      });

      testWidgets('$language at 360 px and text size 1.3: no overflow, '
          'nothing cut', (tester) async {
        // A layout overflow is reported as an error and fails the test.
        await pumpScreen(
          tester,
          const PrivacyScreen(),
          language: language,
          size: const Size(360, 3200),
          textScale: 1.3,
        );
        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: paragraph.text.toPlainText(),
          );
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('$language: every text has a contrast of at least 4.5', (
        tester,
      ) async {
        await pumpScreen(tester, const PrivacyScreen(), language: language);
        final body = find.descendant(
          of: find.byType(PrivacyScreen),
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
    }

    testWidgets('a wide window: in the middle, at most 720 wide', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const PrivacyScreen(),
        size: const Size(1400, 2400),
      );
      final card = tester.getRect(find.byType(Card).first);
      expect(card.width, lessThanOrEqualTo(privacyMaxWidth));
      expect(card.center.dx, closeTo(700, 0.5));
    });
  });

  group('under Send', () {
    for (final language in languages) {
      testWidgets('$language: the consent line and the link below the '
          'button', (tester) async {
        await pumpScreen(
          tester,
          submitArea(),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        final l = texts(language);
        final send = tester.getRect(
          find.widgetWithText(FilledButton, l.bookingSubmit),
        );
        final consent = tester.getRect(find.byKey(privacyConsentKey));
        final link = tester.getRect(find.byKey(privacyLinkKey));
        expect(find.text(l.privacyConsent), findsOneWidget);
        expect(consent.top, greaterThanOrEqualTo(send.bottom));
        expect(link.top, greaterThanOrEqualTo(consent.bottom));
        expect(
          find.descendant(
            of: find.byKey(privacyLinkKey),
            matching: find.text(l.privacyTitle),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the link is off while the request is being sent', (
      tester,
    ) async {
      await pumpScreen(tester, submitArea(sending: true));
      final link = tester.widget<TextButton>(find.byKey(privacyLinkKey));
      expect(link.onPressed, isNull);
    });
  });

  group('the texts', () {
    test('15 texts, filled in ka, ru and en, without outer spaces; the '
        'languages differ', () {
      final all = {for (final l in languages) l: privacyTexts(texts(l))};
      for (final MapEntry(key: language, value: values) in all.entries) {
        expect(values, hasLength(15));
        values.forEach((name, text) {
          expect(text, isNotEmpty, reason: '$language $name');
          expect(text.trim(), text, reason: '$language $name');
        });
      }
      for (final name in all['en']!.keys) {
        expect(
          {all['ka']![name], all['ru']![name], all['en']![name]},
          hasLength(3),
          reason: name,
        );
      }
    });

    test('reCAPTCHA only in section 5 (step 7.6); no "აღებისა", no "not '
        'yet" about deletion', () {
      for (final language in languages) {
        final all = privacyTexts(texts(language));
        expect(all['privacy5Text'], contains('Google reCAPTCHA'));
        all.forEach((name, text) {
          if (name != 'privacy5Text') {
            expect(text.toLowerCase(), isNot(contains('recaptcha')));
          }
          expect(text, isNot(contains('აღებისა')));
        });
      }
      expect(texts('en').privacy4Text, isNot(contains('yet')));
      expect(texts('ka').privacy4Text, isNot(contains('ჯერ')));
      expect(texts('ru').privacy4Text, isNot(contains('пока нет')));
    });

    test('section 2 lists the e-mail in each language', () {
      expect(texts('en').privacy2Text, contains('e-mail'));
      expect(texts('ka').privacy2Text, contains('ელფოსტ'));
      expect(texts('ru').privacy2Text, contains('эл. почта'));
      expect(texts('en').privacy2Text, isNot(contains('if you give one')));
    });
  });
}
