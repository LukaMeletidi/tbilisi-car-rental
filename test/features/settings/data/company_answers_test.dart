import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

import '../../../support/fake_settings_repository.dart';

const _company = <String, dynamic>{
  'name': 'Example Car Rental',
  'phone': '+995555000000',
  'email': 'info@example.com',
};

/// What a stream delivered, in order: values and errors.
class _Log<T> {
  _Log(Stream<T> stream) {
    final subscription = stream.listen(
      values.add,
      onError: (Object error) => errors.add(error),
    );
    addTearDown(subscription.cancel);
  }

  final values = <T>[];
  final errors = <Object>[];
}

// testWidgets only for its clock; see server_answer_test.dart.
void main() {
  group('companyInfoFrom', () {
    late StreamController<DocumentAnswer> answers;

    setUp(() {
      answers = StreamController<DocumentAnswer>();
      addTearDown(answers.close);
    });

    Future<void> send(
      WidgetTester tester,
      Map<String, dynamic>? data, {
      required bool fromCache,
    }) async {
      answers.add((data: data, fromCache: fromCache));
      await tester.pump(Duration.zero);
    }

    testWidgets('the server says it does not exist: null, not an error', (
      tester,
    ) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, null, fromCache: false);

      expect(log.values, [null]);
      expect(log.errors, isEmpty);
    });

    testWidgets('missing only without the server: nothing, then "no '
        'answer" after the wait', (tester) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, null, fromCache: true);

      expect(log.values, isEmpty);
      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait);
      expect(log.errors.single, isA<NoServerAnswerException>());
      expect(log.values, isEmpty);
    });

    testWidgets('a valid document gives the company', (tester) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, _company, fromCache: false);

      expect(log.values.single, CompanyInfo.fromMap(_company));
    });

    testWidgets('an empty document gives an empty company, not null', (
      tester,
    ) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, {}, fromCache: false);

      expect(log.values.single, CompanyInfo.empty);
    });

    testWidgets('an invalid document: a FormatException', (tester) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, {'phone': '+0555000000'}, fromCache: false);

      expect(log.errors.single, isA<FormatException>());
    });

    testWidgets('the company comes later by itself', (tester) async {
      final log = _Log(companyInfoFrom(answers.stream));
      await send(tester, null, fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, _company, fromCache: false);

      expect(log.errors.single, isA<NoServerAnswerException>());
      expect(log.values.single?.name, 'Example Car Rental');
    });
  });

  group('companyInfoProvider', () {
    late FakeSettingsRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeSettingsRepository();
      container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('loading until the repository answers', () {
      final subscription = container.listen(companyInfoProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(container.read(companyInfoProvider).isLoading, true);
      expect(repository.companyReads, 1);
    });

    test('null when the company is not filled in yet', () async {
      final subscription = container.listen(companyInfoProvider, (_, _) {});
      addTearDown(subscription.close);
      repository.emitCompany(null);
      await pumpEventQueue();

      final state = container.read(companyInfoProvider);
      expect(state.hasValue, true);
      expect(state.value, isNull);
    });

    test('the company when it is stored', () async {
      final subscription = container.listen(companyInfoProvider, (_, _) {});
      addTearDown(subscription.close);
      repository.emitCompany(CompanyInfo.fromMap(_company));
      await pumpEventQueue();

      expect(
        container.read(companyInfoProvider).value?.email,
        'info@example.com',
      );
    });

    test('an error stays an error: no automatic retry', () async {
      final subscription = container.listen(companyInfoProvider, (_, _) {});
      addTearDown(subscription.close);
      repository.failCompany(const NoServerAnswerException());
      await pumpEventQueue();

      expect(
        container.read(companyInfoProvider).error,
        isA<NoServerAnswerException>(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.companyReads, 1);
    });

    test('nobody listening: the read is closed (auto-dispose)', () async {
      final subscription = container.listen(companyInfoProvider, (_, _) {});
      await pumpEventQueue();
      expect(repository.activeCompanyListeners, 1);

      subscription.close();
      await pumpEventQueue();
      expect(repository.activeCompanyListeners, 0);
    });
  });
}
