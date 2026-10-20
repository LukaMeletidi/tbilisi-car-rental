import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/about/domain/contact_rows.dart';
import 'package:tbilisi_car_rental/features/about/presentation/widgets/contacts_card.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

import '../about_samples.dart';
import 'about_harness.dart';

final en = aboutTexts('en');

/// The value of the row of [kind] (a SelectableText).
Finder valueOf(ContactKind kind) => find.descendant(
  of: find.byKey(contactRowKey(kind)),
  matching: find.byType(SelectableText),
);

Future<void> tapRow(WidgetTester tester, ContactKind kind) async {
  await tester.ensureVisible(valueOf(kind));
  await tester.pump();
  await tester.tap(valueOf(kind));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('the heading and the about text', (tester) async {
    await pumpAbout(tester);
    expect(find.text(en.aboutTitle), findsOneWidget);
    expect(find.text(en.aboutText), findsOneWidget);
  });

  testWidgets('every field: the Contacts card with the name and all rows', (
    tester,
  ) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    expect(find.text(en.aboutContactsTitle), findsOneWidget);
    expect(find.text(sampleName), findsOneWidget);
    for (final kind in [
      ContactKind.phone,
      ContactKind.email,
      ContactKind.address,
      ContactKind.workingHours,
      ContactKind.facebook,
      ContactKind.instagram,
      ContactKind.whatsapp,
      ContactKind.telegram,
    ]) {
      expect(find.byKey(contactRowKey(kind)), findsOneWidget, reason: '$kind');
    }
    expect(find.byKey(contactRowKey(ContactKind.map)), findsNothing);
    expect(find.text(en.aboutPhoneLabel), findsOneWidget);
    expect(find.text(en.aboutWorkingHoursLabel), findsOneWidget);
  });

  testWidgets('some fields: only their rows', (tester) async {
    await pumpAbout(
      tester,
      answer: CompanyData(CompanyInfo(phone: samplePhone)),
    );
    expect(find.byKey(contactRowKey(ContactKind.phone)), findsOneWidget);
    expect(find.byKey(contactRowKey(ContactKind.email)), findsNothing);
    expect(find.text(sampleName), findsNothing);
  });

  for (final (name, answer) in [
    ('no document', const CompanyData(null)),
    ('nothing filled in', CompanyData(CompanyInfo.empty)),
  ]) {
    testWidgets('$name: only the about card, no Contacts', (tester) async {
      await pumpAbout(tester, answer: answer);
      expect(find.text(en.aboutText), findsOneWidget);
      expect(find.text(en.aboutContactsTitle), findsNothing);
      expect(find.byType(Card), findsOneWidget);
    });
  }

  testWidgets('while loading: the about text and a spinner card', (
    tester,
  ) async {
    await pumpAbout(tester, answer: const CompanyPending());
    expect(find.text(en.aboutText), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an error: the message and Try again, which reads again', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      answer: const CompanyError(),
      then: CompanyData(fullCompany()),
    );
    expect(find.text(en.aboutContactsError), findsOneWidget);
    expect(companyReads, 1);
    await tester.tap(find.widgetWithText(FilledButton, en.tryAgain));
    await tester.pump();
    await tester.pump();
    expect(companyReads, 2);
    expect(find.text(en.aboutContactsError), findsNothing);
    expect(find.text(sampleName), findsOneWidget);
  });

  testWidgets('a tap opens the link of the row', (tester) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    await tapRow(tester, ContactKind.phone);
    await tapRow(tester, ContactKind.email);
    await tapRow(tester, ContactKind.address);
    await tapRow(tester, ContactKind.facebook);
    expect(opener.opened, [
      Uri.parse('tel:$samplePhone'),
      Uri.parse('mailto:$sampleEmail'),
      Uri.parse(sampleMap),
      Uri.parse('https://www.example.com/facebook'),
    ]);
  });

  testWidgets('the working hours are plain text: a tap opens nothing', (
    tester,
  ) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    await tapRow(tester, ContactKind.workingHours);
    expect(opener.opened, isEmpty);
  });

  testWidgets('a map link without an address: "Show on the map"', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      answer: CompanyData(CompanyInfo(mapUrl: sampleMap)),
    );
    expect(find.text(en.aboutShowOnMap), findsOneWidget);
    await tapRow(tester, ContactKind.map);
    expect(opener.opened, [Uri.parse(sampleMap)]);
  });

  testWidgets('a link that cannot be opened: copied, with a message', (
    tester,
  ) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    opener.opens = false;
    await tapRow(tester, ContactKind.phone);
    expect(copied, [samplePhone]);
    expect(find.text(en.aboutOpenFailed), findsOneWidget);
  });

  testWidgets('the copy button copies the value and says "Copied"', (
    tester,
  ) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    for (final kind in [ContactKind.phone, ContactKind.email]) {
      expect(find.byKey(contactCopyKey(kind)), findsOneWidget);
    }
    expect(find.byKey(contactCopyKey(ContactKind.workingHours)), findsNothing);
    final copy = find.byKey(contactCopyKey(ContactKind.email));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(copied, [sampleEmail]);
    expect(find.text(en.aboutCopied), findsOneWidget);
    expect(opener.opened, isEmpty);
  });

  testWidgets('the values can be selected', (tester) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()));
    expect(
      tester.widget<SelectableText>(valueOf(ContactKind.phone)).data,
      samplePhone,
    );
  });

  testWidgets('the address follows the language', (tester) async {
    await pumpAbout(tester, answer: CompanyData(fullCompany()), language: 'ka');
    expect(
      tester.widget<SelectableText>(valueOf(ContactKind.address)).data,
      sampleAddress.ka,
    );
    expect(find.text(aboutTexts('ka').aboutText), findsOneWidget);
  });
}
