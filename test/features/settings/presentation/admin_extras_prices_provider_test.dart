import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_auth_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/admin_extras_prices_provider.dart';

import '../../../support/fake_admin_auth_repository.dart';
import '../../../support/fake_settings_repository.dart';

/// Made-up sample prices; not the real ones.
ExtrasPrices prices({num snowChains = 7, num childSeat = 4.5}) =>
    ExtrasPrices.fromMap({
      'pricesPerDay': {
        'snowChains': snowChains,
        'childSeat': childSeat,
        'infantSeat': 0,
        'boosterSeat': 3,
      },
    });

/// These tests build no widgets. They use testWidgets only for its clock.
class Harness {
  Harness(this.tester, this.container, this.settings, this.auth);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeSettingsRepository settings;
  final FakeAdminAuthRepository auth;

  AdminExtrasPricesState get state => container.read(adminExtrasPricesProvider);

  AdminExtrasPricesNotifier get notifier =>
      container.read(adminExtrasPricesProvider.notifier);

  Future<void> flush() => tester.pump(Duration.zero);

  Future<void> emit(ExtrasPrices prices) async {
    settings.emitExtras(prices);
    await flush();
  }

  void type(Extra extra, String text) =>
      notifier.setDraft({...state.draft!, extra: text});
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
  final subscription = container.listen(adminExtrasPricesProvider, (_, _) {});
  addTearDown(subscription.close);
  await harness.flush();
  return harness;
}

Future<Harness> editing(WidgetTester tester, {ExtrasPrices? stored}) async {
  final h = await start(tester);
  await h.emit(stored ?? prices());
  expect(h.state.status, AdminExtrasPricesStatus.editing);
  return h;
}

void main() {
  group('loading', () {
    testWidgets('not an admin: inactive, nothing is read', (tester) async {
      final h = await start(tester, session: AdminSession.signedOut);
      expect(h.state.status, AdminExtrasPricesStatus.inactive);
      expect(h.settings.activeExtrasListeners, 0);
    });

    testWidgets('an admin: loading until the prices come', (tester) async {
      final h = await start(tester);
      expect(h.state.status, AdminExtrasPricesStatus.loading);
      expect(h.settings.activeExtrasListeners, 1);
    });

    testWidgets('the prices open the form', (tester) async {
      final h = await editing(tester);
      expect(h.state.base, prices());
      expect(h.state.latest, prices());
      expect(h.state.draft, extrasDraftOf(prices()));
      expect(h.state.problems, isEmpty);
      expect(h.state.showErrors, false);
      expect(h.state.isDirty, false);
      expect(h.state.canSave, false);
    });

    testWidgets('no answer of the server: "No connection", and the form '
        'comes by itself later', (tester) async {
      final h = await start(tester);
      h.settings.failExtras(const NoServerAnswerException());
      await h.flush();
      expect(h.state.status, AdminExtrasPricesStatus.failed);
      expect(h.state.failure, ExtrasLoadFailure.noConnection);
      expect(h.settings.activeExtrasListeners, 1);

      await h.emit(prices());
      expect(h.state.status, AdminExtrasPricesStatus.editing);
    });

    testWidgets('a missing or broken document: unreadable', (tester) async {
      final h = await start(tester);
      h.settings.failExtras(const FormatException('broken'));
      await h.flush();
      expect(h.state.status, AdminExtrasPricesStatus.unreadable);
    });

    testWidgets('any other error: failed, the read stops; Try again reads '
        'again', (tester) async {
      final h = await start(tester);
      h.settings.failExtras(StateError('other'));
      await h.flush();
      expect(h.state.status, AdminExtrasPricesStatus.failed);
      expect(h.state.failure, ExtrasLoadFailure.other);
      expect(h.settings.activeExtrasListeners, 0);

      h.notifier.retry();
      await h.flush();
      expect(h.state.status, AdminExtrasPricesStatus.loading);
      expect(h.settings.activeExtrasListeners, 1);
    });

    testWidgets('an error after a sign-out is not shown', (tester) async {
      final h = await editing(tester);
      h.auth.report(AdminSession.signedOut);
      await h.flush();
      expect(h.state.status, AdminExtrasPricesStatus.inactive);
      expect(h.settings.activeExtrasListeners, 0);
    });

    testWidgets('a stored price a console edit made invalid opens with its '
        'error shown', (tester) async {
      final h = await editing(tester, stored: prices(childSeat: 4.555));
      expect(h.state.showErrors, true);
      expect(h.state.problems, {Extra.childSeat: ExtraPriceProblem.invalid});
      expect(h.state.canSave, false);
    });

    testWidgets('leaving closes the read (auto-dispose)', (tester) async {
      final h = await start(tester);
      expect(h.settings.activeExtrasListeners, 1);
      h.container.invalidate(adminExtrasPricesProvider);
      await h.flush();
      // Still listened to by the test: a new read replaces the old one.
      expect(h.settings.activeExtrasListeners, 1);
    });
  });

  group('typing', () {
    testWidgets('a change makes the form dirty and Save possible', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      expect(h.state.isDirty, true);
      expect(h.state.canSave, true);
    });

    testWidgets('the same value written differently is no change', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '7.00');
      expect(h.state.isDirty, false);
    });

    testWidgets('a problem is known at once but shown only after Save', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, 'abc');
      expect(h.state.problems, {Extra.snowChains: ExtraPriceProblem.invalid});
      expect(h.state.showErrors, false);
    });
  });

  group('save', () {
    testWidgets('with a problem: the errors show, nothing is sent', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '100.01');
      await h.notifier.save();
      expect(h.state.showErrors, true);
      expect(h.settings.extrasSaves, isEmpty);
    });

    testWidgets('without a change: nothing is sent', (tester) async {
      final h = await editing(tester);
      await h.notifier.save();
      expect(h.settings.extrasSaves, isEmpty);
    });

    testWidgets('saved: the repository got the new prices and the base', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8,5');
      await h.notifier.save();
      expect(h.settings.extrasSaves.single.prices, prices(snowChains: 8.5));
      expect(h.settings.extrasSaves.single.base, prices());
      expect(h.state.notice, ExtrasSaveNotice.saved);
      expect(h.state.saving, false);
    });

    testWidgets('a second press while saving sends nothing more', (
      tester,
    ) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      final gate = h.settings.writeGate = Completer<void>();
      final first = h.notifier.save();
      await h.flush();
      expect(h.state.saving, true);
      expect(h.state.canSave, false);
      await h.notifier.save();
      gate.complete();
      await first;
      expect(h.settings.extrasSaves, hasLength(1));
    });

    testWidgets('no answer: the fields are locked; "Save again" calls '
        'again', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      h.settings.saveError = const SettingsWriteNoAnswer();
      await h.notifier.save();
      expect(h.state.notice, ExtrasSaveNotice.noAnswer);
      expect(h.state.locked, true);
      expect(h.state.canSave, false);

      h.type(Extra.snowChains, '9');
      expect(h.state.draft![Extra.snowChains], '8');
      h.notifier.dismissNotice();
      expect(h.state.notice, ExtrasSaveNotice.noAnswer);

      h.settings.saveError = null;
      await h.notifier.save();
      expect(h.settings.extrasSaves, hasLength(2));
      expect(h.state.notice, ExtrasSaveNotice.saved);
    });

    testWidgets('no answer, then the stored prices equal the attempt: '
        'saved', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      h.settings.saveError = const SettingsWriteNoAnswer();
      await h.notifier.save();
      await h.emit(prices(snowChains: 8));
      expect(h.state.notice, ExtrasSaveNotice.saved);
    });

    testWidgets('no answer, then other prices: still locked', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      h.settings.saveError = const SettingsWriteNoAnswer();
      await h.notifier.save();
      await h.emit(prices(snowChains: 9));
      expect(h.state.notice, ExtrasSaveNotice.noAnswer);
      expect(h.state.latest, prices(snowChains: 9));
    });

    for (final failure in SettingsWriteFailure.values) {
      testWidgets('${failure.name}: its notice, the form stays', (
        tester,
      ) async {
        final h = await editing(tester);
        h.type(Extra.snowChains, '8');
        h.settings.saveError = SettingsWriteException(failure);
        await h.notifier.save();
        expect(h.state.notice, noticeForSettingsWriteFailure(failure));
        expect(h.state.draft![Extra.snowChains], '8');
        h.notifier.dismissNotice();
        expect(h.state.notice, isNull);
      });
    }

    testWidgets('any other error: unknown', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      h.settings.saveError = StateError('raw');
      await h.notifier.save();
      expect(h.state.notice, ExtrasSaveNotice.unknown);
    });
  });

  group('changed elsewhere', () {
    testWidgets('new prices while the form has changes: the form stays, '
        'the banner flag is set', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      await h.emit(prices(childSeat: 6));
      expect(h.state.changedElsewhere, true);
      expect(h.state.draft![Extra.snowChains], '8');
      expect(h.state.base, prices());
    });

    testWidgets('"Load the current prices" shows them', (tester) async {
      final h = await editing(tester);
      h.type(Extra.snowChains, '8');
      await h.emit(prices(childSeat: 6));
      final version = h.state.formVersion;
      h.notifier.loadCurrent();
      expect(h.state.base, prices(childSeat: 6));
      expect(h.state.draft, extrasDraftOf(prices(childSeat: 6)));
      expect(h.state.changedElsewhere, false);
      expect(h.state.formVersion, version + 1);
    });

    testWidgets('new prices while the form has no changes: it follows', (
      tester,
    ) async {
      final h = await editing(tester);
      await h.emit(prices(childSeat: 6));
      expect(h.state.base, prices(childSeat: 6));
      expect(h.state.draft![Extra.childSeat], '6');
      expect(h.state.changedElsewhere, false);
    });
  });
}
