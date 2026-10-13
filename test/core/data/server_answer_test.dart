import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';

/// A made-up answer of a read: some rows, and where it came from.
typedef _Answer = ({List<int> rows, bool fromCache});

/// What a listener of [waitForServerAnswer] received, in order.
class _Log {
  final values = <int>[];
  final errors = <Object>[];
  var done = false;
}

void main() {
  group('answerMeaning', () {
    test('something from the server is data', () {
      expect(
        answerMeaning(isEmpty: false, fromCache: false),
        AnswerMeaning.data,
      );
    });

    test('something from memory is data too', () {
      expect(
        answerMeaning(isEmpty: false, fromCache: true),
        AnswerMeaning.data,
      );
    });

    test('nothing, said by the server: confirmed empty (or missing)', () {
      expect(
        answerMeaning(isEmpty: true, fromCache: false),
        AnswerMeaning.confirmedEmpty,
      );
    });

    test('nothing, and not from the server: not known yet', () {
      expect(
        answerMeaning(isEmpty: true, fromCache: true),
        AnswerMeaning.notKnownYet,
      );
    });
  });

  test('the wait for the server is 3 seconds', () {
    expect(serverAnswerWait, const Duration(seconds: 3));
  });

  test('the exception names no data', () {
    expect('${const NoServerAnswerException()}', 'NoServerAnswerException');
  });

  // testWidgets only for its clock: time passes when the test says so, and
  // a timer that is still running at the end fails the test.
  group('waitForServerAnswer', () {
    late StreamController<_Answer> source;
    late _Log log;
    late StreamSubscription<int> subscription;

    /// Listens to the sum of the rows of each answer.
    void listen({int Function(_Answer answer)? read}) {
      source = StreamController<_Answer>();
      log = _Log();
      subscription =
          waitForServerAnswer<_Answer, int>(
            source.stream,
            isEmpty: (answer) => answer.rows.isEmpty,
            fromCache: (answer) => answer.fromCache,
            read: read ?? (answer) => answer.rows.fold(0, (a, b) => a + b),
          ).listen(
            log.values.add,
            onError: (Object error) => log.errors.add(error),
            onDone: () => log.done = true,
          );
      // Clean-up runs last-added first: the listener leaves, then the source
      // is closed. Neither is awaited: on the test clock they may
      // never report that it is finished.
      addTearDown(() => unawaited(source.close()));
      addTearDown(() => unawaited(subscription.cancel()));
    }

    Future<void> send(
      WidgetTester tester,
      List<int> rows, {
      required bool fromCache,
    }) async {
      source.add((rows: rows, fromCache: fromCache));
      await tester.pump(Duration.zero);
    }

    testWidgets('an answer of the server is passed on at once', (tester) async {
      listen();
      await send(tester, [1, 2], fromCache: false);

      expect(log.values, [3]);
      expect(log.errors, isEmpty);
    });

    testWidgets('data held in memory is passed on at once', (tester) async {
      listen();
      await send(tester, [4], fromCache: true);

      expect(log.values, [4]);
      expect(log.errors, isEmpty);
    });

    testWidgets('an empty answer of the server is passed on as empty', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: false);

      expect(log.values, [0]);
      expect(log.errors, isEmpty);
    });

    testWidgets('an empty answer that is not from the server is held back, '
        'and reported as "no answer" after the wait, not before', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);

      expect(log.values, isEmpty);
      expect(log.errors, isEmpty);

      await tester.pump(serverAnswerWait - const Duration(milliseconds: 1));
      expect(log.errors, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(log.values, isEmpty);
      expect(log.errors.single, isA<NoServerAnswerException>());
    });

    testWidgets('the server answers within the wait: no error at all', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);
      await tester.pump(const Duration(seconds: 2));
      await send(tester, [5], fromCache: false);
      await tester.pump(const Duration(seconds: 10));

      expect(log.values, [5]);
      expect(log.errors, isEmpty);
    });

    testWidgets('the server answers after the error: the value still comes', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);
      await tester.pump(serverAnswerWait);
      expect(log.errors, hasLength(1));

      await send(tester, [7], fromCache: false);

      expect(log.values, [7]);
      expect(log.errors, hasLength(1));
      expect(log.done, false);
    });

    testWidgets('the server confirms "empty" after the error: empty comes', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, [], fromCache: false);

      expect(log.values, [0]);
      expect(log.errors, hasLength(1));
    });

    testWidgets('more empty answers from memory: still one error, and the '
        'wait is not started again', (tester) async {
      listen();
      await send(tester, [], fromCache: true);
      await tester.pump(const Duration(seconds: 2));
      await send(tester, [], fromCache: true);
      await tester.pump(const Duration(seconds: 1));
      expect(log.errors, hasLength(1));

      await send(tester, [], fromCache: true);
      await tester.pump(const Duration(seconds: 10));
      expect(log.errors, hasLength(1));
    });

    testWidgets('after a real answer a new wait can start', (tester) async {
      listen();
      await send(tester, [], fromCache: true);
      await tester.pump(serverAnswerWait);
      await send(tester, [], fromCache: false);
      await send(tester, [], fromCache: true);
      await tester.pump(serverAnswerWait);

      expect(log.values, [0]);
      expect(log.errors, hasLength(2));
    });

    testWidgets('its own wait can be given', (tester) async {
      source = StreamController<_Answer>();
      final errors = <Object>[];
      final subscription = waitForServerAnswer<_Answer, int>(
        source.stream,
        isEmpty: (answer) => answer.rows.isEmpty,
        fromCache: (answer) => answer.fromCache,
        read: (answer) => 0,
        wait: const Duration(seconds: 1),
      ).listen((_) {}, onError: (Object error) => errors.add(error));
      addTearDown(() => unawaited(source.close()));
      addTearDown(() => unawaited(subscription.cancel()));

      source.add((rows: const [], fromCache: true));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 1));

      expect(errors, hasLength(1));
    });

    testWidgets('what "read" throws is passed on, and the stream goes on', (
      tester,
    ) async {
      listen(
        read: (answer) => answer.rows.first == 0
            ? throw const FormatException('bad')
            : answer.rows.first,
      );
      await send(tester, [0], fromCache: false);
      await send(tester, [9], fromCache: false);

      expect(log.errors.single, isA<FormatException>());
      expect(log.values, [9]);
    });

    testWidgets('an error of the source is passed on unchanged and ends the '
        'wait', (tester) async {
      listen();
      await send(tester, [], fromCache: true);
      final error = StateError('refused');
      source.addError(error);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 10));

      expect(log.errors, [same(error)]);
    });

    testWidgets('the end of the source ends the stream and the wait', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);
      // Not awaited: on the test clock it finishes only while pumping.
      unawaited(source.close());
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 10));

      expect(log.done, true);
      expect(log.errors, isEmpty);
    });

    testWidgets('a listener that leaves stops the wait and the source', (
      tester,
    ) async {
      listen();
      await send(tester, [], fromCache: true);
      expect(source.hasListener, true);

      unawaited(subscription.cancel());
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 10));

      expect(source.hasListener, false);
      expect(log.errors, isEmpty);
    });

    testWidgets('nothing is asked for before somebody listens', (tester) async {
      // Not closed at the end: closing a stream nobody listened to never
      // finishes.
      final source = StreamController<_Answer>();
      waitForServerAnswer<_Answer, int>(
        source.stream,
        isEmpty: (answer) => answer.rows.isEmpty,
        fromCache: (answer) => answer.fromCache,
        read: (answer) => 0,
      );

      expect(source.hasListener, false);
    });
  });
}
