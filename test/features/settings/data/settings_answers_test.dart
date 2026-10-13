import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';

const _extras = <String, dynamic>{
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 4.5,
    'boosterSeat': 3,
  },
};

const _locations = <String, dynamic>{
  'items': [
    {
      'id': 'tbilisiAirport',
      'name': {'en': 'Tbilisi Airport'},
    },
  ],
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

  group('extrasPricesFrom', () {
    testWidgets('missing only without the server: no FormatException; "no '
        'answer" after the wait', (tester) async {
      final log = _Log(extrasPricesFrom(answers.stream));
      await send(tester, null, fromCache: true);

      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait);
      expect(log.errors.single, isA<NoServerAnswerException>());
      expect(log.values, isEmpty);
    });

    testWidgets('the server says the document does not exist: the '
        'FormatException as before', (tester) async {
      final log = _Log(extrasPricesFrom(answers.stream));
      await send(tester, null, fromCache: false);

      expect(log.errors.single, isA<FormatException>());
    });

    testWidgets('an invalid document: the FormatException as before', (
      tester,
    ) async {
      final log = _Log(extrasPricesFrom(answers.stream));
      await send(tester, {'pricesPerDay': 5}, fromCache: false);

      expect(log.errors.single, isA<FormatException>());
    });

    testWidgets('the prices come later by themselves', (tester) async {
      final log = _Log(extrasPricesFrom(answers.stream));
      await send(tester, null, fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, _extras, fromCache: false);

      expect(log.values.single.priceOf(Extra.snowChains), 5.0);
    });

    testWidgets('prices held in memory are used without the server', (
      tester,
    ) async {
      final log = _Log(extrasPricesFrom(answers.stream));
      await send(tester, _extras, fromCache: true);
      await tester.pump(serverAnswerWait);

      expect(log.values, hasLength(1));
      expect(log.errors, isEmpty);
    });
  });

  group('pickupLocationsFrom', () {
    testWidgets('missing only without the server: no FormatException; "no '
        'answer" after the wait', (tester) async {
      final log = _Log(pickupLocationsFrom(answers.stream));
      await send(tester, null, fromCache: true);

      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait);
      expect(log.errors.single, isA<NoServerAnswerException>());
    });

    testWidgets('the server says the document does not exist: the '
        'FormatException as before', (tester) async {
      final log = _Log(pickupLocationsFrom(answers.stream));
      await send(tester, null, fromCache: false);

      expect(log.errors.single, isA<FormatException>());
    });

    testWidgets('the places come later by themselves', (tester) async {
      final log = _Log(pickupLocationsFrom(answers.stream));
      await send(tester, null, fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, _locations, fromCache: false);

      expect(log.values.single.single.id, 'tbilisiAirport');
    });
  });
}
