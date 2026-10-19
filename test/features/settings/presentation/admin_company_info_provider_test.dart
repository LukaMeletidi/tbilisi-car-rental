import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/localized_text.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_company_info_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// A made-up company.
CompanyInfo company({String name = 'Example Car Rental'}) => CompanyInfo(
  name: name,
  phone: '+995555000000',
  email: 'info@example.com',
  social: const {CompanySocialLink.telegram: 'https://www.example.com/t'},
);

CompanyInput withName(CompanyInput input, String name) => CompanyInput(
  name: name,
  phone: input.phone,
  email: input.email,
  address: input.address,
  workingHours: input.workingHours,
  mapUrl: input.mapUrl,
  social: input.social,
);

/// These tests build no widgets. They use testWidgets only for its clock.
class Harness {
  Harness(this.tester, this.container, this.settings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeSettingsRepository settings;
  final FakeAdminAuthRepository auth;

  AdminCompanyInfoState get state => container.read(adminCompanyInfoProvider);

  AdminCompanyInfoNotifier get notifier =>
      container.read(adminCompanyInfoProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> emit(CompanyInfo? info) async {
    settings.emitCompany(info);
    await flush();
  }

  void name(String name) => notifier.setDraft(withName(state.draft!, name));
}

Future<Harness> start(
  WidgetTester tester, {
  AdminSession session = AdminSession.admin,
}) async {
  final auth = FakeAdminAuthRepository(initial: session);
  final settings = FakeSettingsRepository();
  final container = ProviderContainer(
    overrides: [
      adminAuthRepositoryProvider.overrideWithValue(auth),
      settingsRepositoryProvider.overrideWithValue(settings),
    ],
  );
  final harness = Harness(tester, container, settings, auth);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  container.read(adminSessionProvider);
  await harness.flush();
  final subscription = container.listen(adminCompanyInfoProvider, (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

/// A started harness with [stored] in the form (null: no document).
Future<Harness> editing(
  WidgetTester tester, {
  CompanyInfo? stored,
  bool noDocument = false,
}) async {
  final h = await start(tester);
  await h.emit(noDocument ? null : (stored ?? company()));
  expect(h.state.status, AdminCompanyInfoStatus.editing);
  return h;
}

void main() {
  group('loading', () {
    testWidgets('not an admin: inactive, nothing is read', (tester) async {
      final h = await start(tester, session: AdminSession.signedOut);
      expect(h.state.status, AdminCompanyInfoStatus.inactive);
      expect(h.settings.companyReads, 0);
    });

    testWidgets('an admin: loading until the server answers', (tester) async {
      final h = await start(tester);
      expect(h.state.status, AdminCompanyInfoStatus.loading);
      expect(h.settings.activeCompanyListeners, 1);
    });

    testWidgets('the server says there is no document: an empty form', (
      tester,
    ) async {
      final h = await editing(tester, noDocument: true);
      expect(h.state.base, isNull);
      expect(h.state.latest, isNull);
      expect(h.state.draft!.name, '');
      expect(h.state.problems, isEmpty);
      expect(h.state.isDirty, false);
      expect(h.state.canSave, false);
      expect(h.state.changedElsewhere, false);
    });

    testWidgets('a stored company opens the filled form', (tester) async {
      final h = await editing(tester);
      expect(h.state.base, company());
      expect(h.state.draft!.phone, '+995555000000');
      expect(h.state.isDirty, false);
    });

    testWidgets('no answer of the server: "No connection", and the form '
        'comes by itself later', (tester) async {
      final h = await start(tester);
      h.settings.failCompany(const NoServerAnswerException());
      await h.flush();
      expect(h.state.status, AdminCompanyInfoStatus.failed);
      expect(h.state.failure, CompanyLoadFailure.noConnection);
      expect(h.settings.activeCompanyListeners, 1);

      await h.emit(null);
      expect(h.state.status, AdminCompanyInfoStatus.editing);
    });

    testWidgets('a broken stored document: unreadable', (tester) async {
      final h = await start(tester);
      h.settings.failCompany(const FormatException('broken'));
      await h.flush();
      expect(h.state.status, AdminCompanyInfoStatus.unreadable);
    });

    testWidgets('any other error: failed, the read stops; Try again reads '
        'again', (tester) async {
      final h = await start(tester);
      h.settings.failCompany(StateError('other'));
      await h.flush();
      expect(h.state.status, AdminCompanyInfoStatus.failed);
      expect(h.state.failure, CompanyLoadFailure.other);
      expect(h.settings.activeCompanyListeners, 0);

      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminCompanyInfoStatus.loading);
      expect(h.settings.activeCompanyListeners, 1);
    });

    testWidgets('after a sign-out nothing is shown and nothing is read', (
      tester,
    ) async {
      final h = await editing(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminCompanyInfoStatus.inactive);
      expect(h.settings.activeCompanyListeners, 0);
    });
  });

  group('typing', () {
    testWidgets('a change makes the form dirty and Save possible', (
      tester,
    ) async {
      final h = await editing(tester);
      h.name('Other Name');
      expect(h.state.isDirty, true);
      expect(h.state.canSave, true);
    });

    testWidgets('a problem is known at once but shown only after Save', (
      tester,
    ) async {
      final h = await editing(tester, noDocument: true);
      h.notifier.setDraft(const CompanyInput(phone: 'x'));
      expect(h.state.problems, {CompanyField.phone: CompanyProblem.invalid});
      expect(h.state.showErrors, false);
    });
  });

  group('save', () {
    testWidgets('with a problem: the errors show, nothing is sent', (
      tester,
    ) async {
      final h = await editing(tester, noDocument: true);
      h.notifier.setDraft(
        const CompanyInput(
          address: LocalizedText(en: 'Tbilisi, 1 Example Street'),
        ),
      );
      await h.notifier.save();
      expect(h.state.showErrors, true);
      expect(h.state.problems, {
        CompanyField.address: CompanyProblem.incomplete,
      });
      expect(h.settings.companySaves, isEmpty);
    });

    testWidgets('without a change: nothing is sent', (tester) async {
      final h = await editing(tester);
      await h.notifier.save();
      expect(h.settings.companySaves, isEmpty);
    });

    testWidgets('the first save, without a document, sends base null', (
      tester,
    ) async {
      final h = await editing(tester, noDocument: true);
      h.notifier.setDraft(
        const CompanyInput(
          name: ' Example Car Rental ',
          phone: '+995 555 0000',
        ),
      );
      await h.notifier.save();
      final saved = h.settings.companySaves.single;
      expect(saved.base, isNull);
      expect(saved.company.toMap(), {
        'name': 'Example Car Rental',
        'phone': '+9955550000',
      });
      expect(h.state.notice, CompanySaveNotice.saved);
    });

    testWidgets('a save of a stored company sends it as the base; a cleared '
        'field leaves its key out', (tester) async {
      final h = await editing(tester);
      h.name('');
      await h.notifier.save();
      final saved = h.settings.companySaves.single;
      expect(saved.base, company());
      expect(saved.company.toMap().containsKey('name'), false);
      expect(saved.company.phone, '+995555000000');
    });

    testWidgets('a second press while saving sends nothing more', (
      tester,
    ) async {
      final h = await editing(tester);
      h.name('Other Name');
      final gate = h.settings.writeGate = Completer<void>();
      final first = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      await h.notifier.save();
      gate.complete();
      await first;
      expect(h.settings.companySaves, hasLength(1));
    });

    testWidgets('no answer: locked; "Save again" calls again', (tester) async {
      final h = await editing(tester);
      h.name('Other Name');
      h.settings.saveError = const SettingsWriteNoAnswer();
      await h.notifier.save();
      expect(h.state.notice, CompanySaveNotice.noAnswer);
      expect(h.state.locked, true);
      h.name('Third');
      expect(h.state.draft!.name, 'Other Name');

      h.settings.saveError = null;
      await h.notifier.save();
      expect(h.settings.companySaves, hasLength(2));
      expect(h.state.notice, CompanySaveNotice.saved);
    });

    testWidgets('no answer, then the stored company equals the attempt: '
        'saved', (tester) async {
      final h = await editing(tester);
      h.name('Other Name');
      h.settings.saveError = const SettingsWriteNoAnswer();
      await h.notifier.save();
      await h.emit(company(name: 'Other Name'));
      expect(h.state.notice, CompanySaveNotice.saved);
    });

    for (final failure in SettingsWriteFailure.values) {
      testWidgets('${failure.name}: its notice, the form stays', (
        tester,
      ) async {
        final h = await editing(tester);
        h.name('Other Name');
        h.settings.saveError = SettingsWriteException(failure);
        await h.notifier.save();
        expect(h.state.notice, noticeForCompanyWriteFailure(failure));
        expect(h.state.draft!.name, 'Other Name');
        h.notifier.dismissNotice();
        expect(h.state.notice, isNull);
      });
    }
  });

  group('changed elsewhere', () {
    testWidgets('new information while the form has changes: the form '
        'stays, the banner flag is set', (tester) async {
      final h = await editing(tester);
      h.name('Other Name');
      await h.emit(company(name: 'Changed Elsewhere'));
      expect(h.state.changedElsewhere, true);
      expect(h.state.draft!.name, 'Other Name');
    });

    testWidgets('created elsewhere while the first form has changes', (
      tester,
    ) async {
      final h = await editing(tester, noDocument: true);
      h.notifier.setDraft(const CompanyInput(name: 'Mine'));
      await h.emit(company());
      expect(h.state.changedElsewhere, true);
      expect(h.state.base, isNull);
    });

    testWidgets('"Load the current info" shows it', (tester) async {
      final h = await editing(tester);
      h.name('Other Name');
      await h.emit(company(name: 'Changed Elsewhere'));
      final version = h.state.formVersion;
      h.notifier.loadCurrent();
      expect(h.state.base, company(name: 'Changed Elsewhere'));
      expect(h.state.draft!.name, 'Changed Elsewhere');
      expect(h.state.changedElsewhere, false);
      expect(h.state.formVersion, version + 1);
    });

    testWidgets('new information while the form has no changes: it follows', (
      tester,
    ) async {
      final h = await editing(tester);
      await h.emit(company(name: 'Changed Elsewhere'));
      expect(h.state.base, company(name: 'Changed Elsewhere'));
      expect(h.state.changedElsewhere, false);
    });
  });
}
