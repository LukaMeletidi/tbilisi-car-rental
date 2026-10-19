import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_screen.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// A made-up company.
final company = CompanyInfo(
  name: 'Example Car Rental',
  phone: '+995555000000',
  email: 'info@example.com',
  workingHours: const LocalizedText(
    ka: 'ყოველდღე 09:00–20:00',
    ru: 'Ежедневно 09:00–20:00',
    en: 'Every day 09:00–20:00',
  ),
  social: const {CompanySocialLink.telegram: 'https://www.example.com/t'},
);

late FakeSettingsRepository settings;

const settingsPage = 'the settings page';

/// Pumps the screen; [stored] is emitted as the server's answer when
/// [answer] is true (null: no document).
Future<void> pumpScreen(
  WidgetTester tester, {
  Size size = const Size(1200, 1600),
  bool answer = true,
  CompanyInfo? stored,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAdminAuthRepository(initial: AdminSession.admin);
  addTearDown(auth.close);
  settings = FakeSettingsRepository();
  final router = GoRouter(
    initialLocation: AppRoutes.adminSettingsCompany,
    routes: [
      GoRoute(
        path: AppRoutes.adminSettings,
        builder: (context, state) => const Scaffold(body: Text(settingsPage)),
        routes: [
          GoRoute(
            path: AppRoutes.adminSettingsCompanyPattern,
            builder: (context, state) => const AdminCompanyInfoScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (answer) {
    settings.emitCompany(stored);
    await tester.pump();
    await tester.pump();
  }
}

Finder field(CompanyFormField f) => find.byKey(adminCompanyFieldKey(f));

TextField textField(WidgetTester tester, CompanyFormField f) =>
    tester.widget<TextField>(field(f));

Finder get saveButton => find.widgetWithText(FilledButton, adminCompanySave);

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(saveButton).onPressed != null;

Future<void> type(WidgetTester tester, CompanyFormField f, String text) async {
  await tester.enterText(field(f), text);
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(saveButton);
  await tester.pump();
  await tester.tap(saveButton);
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a spinner until the server answers', (tester) async {
    await pumpScreen(tester, answer: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(saveButton, findsNothing);
  });

  testWidgets('no document: the six cards and 14 empty fields; Save is '
      'disabled', (tester) async {
    await pumpScreen(tester);
    for (final title in [
      adminCompanyCardCompany,
      adminCompanyCardContacts,
      adminCompanyCardAddress,
      adminCompanyCardHours,
      adminCompanyCardMap,
      adminCompanyCardSocial,
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text(adminCompanyNote), findsOneWidget);
    for (final f in CompanyFormField.values) {
      expect(textField(tester, f).controller!.text, '', reason: f.name);
    }
    expect(
      textField(tester, CompanyFormField.addressKa).decoration!.labelText,
      adminCompanyLabelKa,
    );
    expect(saveEnabled(tester), false);
  });

  testWidgets('a stored company fills its fields', (tester) async {
    await pumpScreen(tester, stored: company);
    expect(
      textField(tester, CompanyFormField.name).controller!.text,
      'Example Car Rental',
    );
    expect(
      textField(tester, CompanyFormField.phone).controller!.text,
      '+995555000000',
    );
    expect(
      textField(tester, CompanyFormField.hoursRu).controller!.text,
      'Ежедневно 09:00–20:00',
    );
    expect(
      textField(tester, CompanyFormField.telegram).controller!.text,
      'https://www.example.com/t',
    );
    expect(textField(tester, CompanyFormField.instagram).controller!.text, '');
  });

  testWidgets('the keyboards and the multi-line working hours', (tester) async {
    await pumpScreen(tester);
    expect(
      textField(tester, CompanyFormField.phone).keyboardType,
      TextInputType.phone,
    );
    expect(
      textField(tester, CompanyFormField.email).keyboardType,
      TextInputType.emailAddress,
    );
    expect(
      textField(tester, CompanyFormField.mapUrl).keyboardType,
      TextInputType.url,
    );
    expect(textField(tester, CompanyFormField.hoursEn).maxLines, 6);
  });

  testWidgets('each error appears under its field after Save; the '
      'translated text is marked in all three fields', (tester) async {
    await pumpScreen(tester);
    await type(tester, CompanyFormField.phone, 'x');
    await type(tester, CompanyFormField.email, 'info@');
    await type(tester, CompanyFormField.addressEn, 'Tbilisi, 1 Example Street');
    await type(tester, CompanyFormField.mapUrl, 'http://www.example.com/map');
    await type(tester, CompanyFormField.facebook, 'https://localhost');
    expect(
      textField(tester, CompanyFormField.phone).decoration!.errorText,
      isNull,
    );

    await tapSave(tester);
    String? error(CompanyFormField f) =>
        textField(tester, f).decoration!.errorText;
    expect(
      error(CompanyFormField.phone),
      adminCompanyProblemText(CompanyField.phone, CompanyProblem.invalid),
    );
    expect(
      error(CompanyFormField.email),
      adminCompanyProblemText(CompanyField.email, CompanyProblem.invalid),
    );
    expect(
      error(CompanyFormField.addressEn),
      adminCompanyProblemText(CompanyField.address, CompanyProblem.incomplete),
    );
    expect(error(CompanyFormField.addressKa), '');
    expect(error(CompanyFormField.addressRu), '');
    expect(
      error(CompanyFormField.mapUrl),
      adminCompanyProblemText(CompanyField.mapUrl, CompanyProblem.notHttps),
    );
    expect(
      error(CompanyFormField.facebook),
      adminCompanyProblemText(CompanyField.facebook, CompanyProblem.invalid),
    );
    expect(error(CompanyFormField.name), isNull);
    expect(find.text(adminCorrectFields), findsOneWidget);
    expect(settings.companySaves, isEmpty);
  });

  testWidgets('the first save: "Saved" and back to Settings', (tester) async {
    await pumpScreen(tester);
    await type(tester, CompanyFormField.name, 'Example Car Rental');
    expect(saveEnabled(tester), true);
    await tapSave(tester);
    await settle(tester);

    expect(settings.companySaves.single.base, isNull);
    expect(settings.companySaves.single.company.toMap(), {
      'name': 'Example Car Rental',
    });
    expect(find.text(adminCompanySaved), findsOneWidget);
    expect(find.text(settingsPage), findsOneWidget);
  });

  testWidgets('while saving: locked, a spinner line, no Save', (tester) async {
    await pumpScreen(tester, stored: company);
    await type(tester, CompanyFormField.name, 'Other Name');
    final gate = settings.writeGate = Completer<void>();
    await tapSave(tester);
    expect(find.text(adminSaving), findsOneWidget);
    expect(textField(tester, CompanyFormField.name).enabled, false);
    expect(saveEnabled(tester), false);
    gate.complete();
    await settle(tester);
  });

  testWidgets('back with changes asks first; Discard leaves', (tester) async {
    await pumpScreen(tester, stored: company);
    await type(tester, CompanyFormField.name, 'Other Name');
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text(adminDiscardTitle), findsOneWidget);
    await tester.tap(find.text(adminKeepEditing));
    await settle(tester);
    expect(find.byType(AdminCompanyInfoScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text(adminDiscard));
    await settle(tester);
    expect(find.text(settingsPage), findsOneWidget);
    expect(settings.companySaves, isEmpty);
  });

  testWidgets('back without changes leaves without asking', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text(adminDiscardTitle), findsNothing);
    expect(find.text(settingsPage), findsOneWidget);
  });

  testWidgets('no answer: the text, "Save again" and "Load the current '
      'info"; the fields are locked', (tester) async {
    await pumpScreen(tester, stored: company);
    await type(tester, CompanyFormField.name, 'Other Name');
    settings.saveError = const SettingsWriteNoAnswer();
    await tapSave(tester);
    await settle(tester);
    expect(
      find.text(adminCompanySaveNoticeText(CompanySaveNotice.noAnswer)),
      findsOneWidget,
    );
    expect(find.text(adminSaveAgain), findsOneWidget);
    expect(find.text(adminLoadCurrentInfo), findsOneWidget);
    expect(saveButton, findsNothing);
    expect(textField(tester, CompanyFormField.name).enabled, false);
  });

  testWidgets('a failed save shows its text and can be dismissed', (
    tester,
  ) async {
    await pumpScreen(tester, stored: company);
    await type(tester, CompanyFormField.name, 'Other Name');
    settings.saveError = const SettingsWriteException(
      SettingsWriteFailure.unknown,
    );
    await tapSave(tester);
    await settle(tester);
    final text = adminCompanySaveNoticeText(CompanySaveNotice.unknown);
    expect(find.text(text), findsOneWidget);
    await tester.ensureVisible(find.byTooltip(adminDismissNotice));
    await tester.tap(find.byTooltip(adminDismissNotice));
    await tester.pump();
    expect(find.text(text), findsNothing);
  });

  testWidgets('changed elsewhere while editing: the banner and its button', (
    tester,
  ) async {
    await pumpScreen(tester, stored: company);
    await type(tester, CompanyFormField.email, 'other@example.com');
    settings.emitCompany(CompanyInfo(name: 'Changed Elsewhere'));
    await tester.pump();
    expect(find.text(adminCompanyChangedElsewhereBanner), findsOneWidget);

    await tester.tap(find.text(adminLoadCurrentInfo));
    await tester.pump();
    expect(find.text(adminCompanyChangedElsewhereBanner), findsNothing);
    expect(
      textField(tester, CompanyFormField.name).controller!.text,
      'Changed Elsewhere',
    );
    expect(textField(tester, CompanyFormField.email).controller!.text, '');
  });

  testWidgets('no connection: the text with Try again and Back to Settings; '
      'the form comes later', (tester) async {
    await pumpScreen(tester, answer: false);
    settings.failCompany(const NoServerAnswerException());
    await tester.pump();
    expect(
      find.text(adminCompanyFailureText(CompanyLoadFailure.noConnection)),
      findsOneWidget,
    );
    expect(find.text(adminTryAgain), findsOneWidget);
    expect(find.text(adminBackToSettings), findsOneWidget);

    settings.emitCompany(null);
    await tester.pump();
    expect(field(CompanyFormField.name), findsOneWidget);
  });

  testWidgets('a broken stored document: the unreadable text', (tester) async {
    await pumpScreen(tester, answer: false);
    settings.failCompany(const FormatException('broken'));
    await tester.pump();
    expect(find.text(adminCompanyUnreadable), findsOneWidget);
    expect(find.text(adminBackToSettings), findsOneWidget);
  });

  testWidgets('320 px wide: nothing overflows, also with every error', (
    tester,
  ) async {
    await pumpScreen(tester, size: const Size(320, 640));
    await type(tester, CompanyFormField.name, 'a' * 101);
    await type(tester, CompanyFormField.phone, 'x');
    await type(tester, CompanyFormField.email, 'x');
    await type(tester, CompanyFormField.addressKa, 'x');
    await type(tester, CompanyFormField.hoursRu, 'x');
    await type(tester, CompanyFormField.mapUrl, 'x');
    await type(tester, CompanyFormField.facebook, 'x');
    await type(tester, CompanyFormField.instagram, 'x');
    await type(tester, CompanyFormField.whatsapp, 'x');
    await type(tester, CompanyFormField.telegram, 'x');
    await tapSave(tester);
    expect(find.text(adminCorrectFields), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
