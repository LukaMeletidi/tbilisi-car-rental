/// What an answer of Firestore means when it holds nothing, and how long
/// the app waits for the server. Pure Dart; nothing here talks to
/// Firestore and nothing is logged.
library;

import 'dart:async';

/// How long a screen waits for the first answer of the server before it
/// says that there is no connection. Also the delay of the admin area's
/// "Offline" note.
const serverAnswerWait = Duration(seconds: 3);

/// What one answer of a read means.
enum AnswerMeaning {
  /// There is something to show (from the server, or from what the app
  /// holds in memory).
  data,

  /// The SERVER said there is nothing: the list is empty, or the document
  /// does not exist.
  confirmedEmpty,

  /// Nothing can be said yet: the answer holds nothing, and it did not
  /// come from the server. This is NOT "empty" and NOT "missing": the app
  /// keeps no copy of the data on the device, so without a connection
  /// every first answer looks like this.
  notKnownYet,
}

/// The meaning of an answer. [isEmpty] is true for a list without rows and
/// for a document that is not there; [fromCache] is true when the answer
/// did not come from the server.
AnswerMeaning answerMeaning({required bool isEmpty, required bool fromCache}) {
  if (!isEmpty) return AnswerMeaning.data;
  return fromCache ? AnswerMeaning.notKnownYet : AnswerMeaning.confirmedEmpty;
}

/// Reported when the server gave no answer within [serverAnswerWait] and
/// the app has nothing of its own to show. It is a connection problem; it
/// never means that the data does not exist.
class NoServerAnswerException implements Exception {
  const NoServerAnswerException();

  @override
  String toString() => 'NoServerAnswerException';
}

/// One answer of a live read of a single document, reduced to plain Dart.
/// [data] is null when the answer has no such document.
typedef DocumentAnswer = ({Map<String, dynamic>? data, bool fromCache});

/// Turns the answers of a live read into values, and never takes "nothing
/// yet" for "nothing".
///
/// - An answer that means [AnswerMeaning.data] or
///   [AnswerMeaning.confirmedEmpty] is given to [read] and its result is
///   passed on. What [read] throws is passed on as an error.
/// - An answer that means [AnswerMeaning.notKnownYet] is not passed on at
///   all. If no better answer follows within [wait], the stream reports a
///   [NoServerAnswerException], once.
/// - The stream stays open after that error. When the server answers
///   later, the value is passed on, so a screen recovers by itself.
/// - An error of [answers] is passed on unchanged.
Stream<T> waitForServerAnswer<S, T>(
  Stream<S> answers, {
  required bool Function(S answer) isEmpty,
  required bool Function(S answer) fromCache,
  required T Function(S answer) read,
  Duration wait = serverAnswerWait,
}) {
  late final StreamController<T> controller;
  StreamSubscription<S>? subscription;
  Timer? timer;

  void stopWaiting() {
    timer?.cancel();
    timer = null;
  }

  void onAnswer(S answer) {
    final meaning = answerMeaning(
      isEmpty: isEmpty(answer),
      fromCache: fromCache(answer),
    );
    if (meaning == AnswerMeaning.notKnownYet) {
      // One timer per wait: a second "nothing yet" does not start it again.
      timer ??= Timer(wait, () {
        if (!controller.isClosed) {
          controller.addError(const NoServerAnswerException());
        }
      });
      return;
    }
    stopWaiting();
    final T value;
    try {
      value = read(answer);
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      return;
    }
    controller.add(value);
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = answers.listen(
        onAnswer,
        onError: (Object error, StackTrace stackTrace) {
          stopWaiting();
          controller.addError(error, stackTrace);
        },
        onDone: () {
          stopWaiting();
          // Already over: nothing is left to cancel when the listener of
          // this stream is told so.
          subscription = null;
          controller.close();
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      stopWaiting();
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
