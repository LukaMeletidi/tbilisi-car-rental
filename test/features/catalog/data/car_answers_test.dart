import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_parsing.dart';
import 'package:tbilisi_car_rental/features/catalog/data/car_repository.dart';
import 'package:tbilisi_car_rental/features/catalog/domain/car_not_available_exception.dart';

Map<String, dynamic> carData({bool active = true}) => {
  'brand': 'Toyota',
  'model': 'Prius',
  'year': 2019,
  'drivetrain': 'fwd',
  'transmission': 'automatic',
  'fuelType': 'hybrid',
  'seats': 5,
  'pricePerDay': 45,
  'active': active,
};

/// What a stream delivered, in order: values and errors.
class _Log<T> {
  _Log(WidgetTester tester, Stream<T> stream) {
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
  group('activeCarsFrom', () {
    late StreamController<CarsAnswer> answers;

    setUp(() {
      answers = StreamController<CarsAnswer>();
      addTearDown(answers.close);
    });

    Future<void> send(
      WidgetTester tester,
      List<RawCarDocument> documents, {
      required bool fromCache,
    }) async {
      answers.add((documents: documents, fromCache: fromCache));
      await tester.pump(Duration.zero);
    }

    testWidgets('no connection at the start: never "no cars", but "no '
        'answer" after the wait', (tester) async {
      final log = _Log(tester, activeCarsFrom(answers.stream));
      await send(tester, [], fromCache: true);

      expect(log.values, isEmpty);
      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait);
      expect(log.values, isEmpty);
      expect(log.errors.single, isA<NoServerAnswerException>());
    });

    testWidgets('the server says there are no cars: an empty list', (
      tester,
    ) async {
      final log = _Log(tester, activeCarsFrom(answers.stream));
      await send(tester, [], fromCache: false);
      await tester.pump(serverAnswerWait);

      expect(log.values.single, isEmpty);
      expect(log.errors, isEmpty);
    });

    testWidgets('the cars come later by themselves', (tester) async {
      final log = _Log(tester, activeCarsFrom(answers.stream));
      await send(tester, [], fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, [(id: 'a', data: carData())], fromCache: false);

      expect(log.errors, hasLength(1));
      expect(log.values.single.single.id, 'a');
    });

    testWidgets('cars held in memory are shown without the server', (
      tester,
    ) async {
      final log = _Log(tester, activeCarsFrom(answers.stream));
      await send(tester, [(id: 'a', data: carData())], fromCache: true);
      await tester.pump(serverAnswerWait);

      expect(log.values.single.single.id, 'a');
      expect(log.errors, isEmpty);
    });

    testWidgets('a car that cannot be read is skipped, as before', (
      tester,
    ) async {
      final log = _Log(tester, activeCarsFrom(answers.stream));
      await send(tester, [
        (id: 'bad', data: carData()..['seats'] = 'five'),
        (id: 'good', data: carData()),
      ], fromCache: false);

      expect(log.values.single.map((car) => car.id), ['good']);
    });
  });

  group('carFrom', () {
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

    testWidgets('the server says there is no such car: not available', (
      tester,
    ) async {
      final log = _Log<Car>(tester, carFrom('a', answers.stream));
      await send(tester, null, fromCache: false);

      expect(log.errors.single, isA<CarNotAvailableException>());
    });

    testWidgets('missing only without the server: NOT "not available", but '
        '"no answer" after the wait', (tester) async {
      final log = _Log<Car>(tester, carFrom('a', answers.stream));
      await send(tester, null, fromCache: true);

      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait);
      expect(log.errors.single, isA<NoServerAnswerException>());
    });

    testWidgets('the car comes later by itself', (tester) async {
      final log = _Log<Car>(tester, carFrom('a', answers.stream));
      await send(tester, null, fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, carData(), fromCache: false);

      expect(log.values.single.id, 'a');
    });

    testWidgets('a car held in memory is shown without the server', (
      tester,
    ) async {
      final log = _Log<Car>(tester, carFrom('a', answers.stream));
      await send(tester, carData(), fromCache: true);

      expect(log.values.single.id, 'a');
      expect(log.errors, isEmpty);
    });

    testWidgets('a hidden car and an unreadable car: not available', (
      tester,
    ) async {
      final log = _Log<Car>(tester, carFrom('a', answers.stream));
      await send(tester, carData(active: false), fromCache: false);
      await send(tester, carData()..['seats'] = 'five', fromCache: false);

      expect(log.values, isEmpty);
      expect(log.errors, hasLength(2));
      expect(log.errors, everyElement(isA<CarNotAvailableException>()));
    });
  });

  test('"no answer" is not turned into "car not available"', () {
    const error = NoServerAnswerException();
    expect(mapCarReadError(error), same(error));
  });
}
