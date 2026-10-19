import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  test('no answer in time: SettingsWriteNoAnswer, not "not saved"', () {
    expect(
      mapSettingsWriteError(TimeoutException('late')),
      isA<SettingsWriteNoAnswer>(),
    );
  });

  test('a Firestore error becomes its reason', () {
    expect(
      mapSettingsWriteError(firestoreError('unavailable')),
      const SettingsWriteException(SettingsWriteFailure.noConnection),
    );
    expect(
      mapSettingsWriteError(firestoreError('permission-denied')),
      const SettingsWriteException(SettingsWriteFailure.refused),
    );
  });

  test('a Firestore error without a reason is unknown', () {
    expect(
      mapSettingsWriteError(firestoreError('aborted')),
      const SettingsWriteException(SettingsWriteFailure.unknown),
    );
  });

  test('our own errors stay as they are', () {
    const changed = SettingsWriteException(
      SettingsWriteFailure.changedElsewhere,
    );
    expect(mapSettingsWriteError(changed), same(changed));
    const noAnswer = SettingsWriteNoAnswer();
    expect(mapSettingsWriteError(noAnswer), same(noAnswer));
  });

  test('any other error is unknown (also the raw offline error of Chrome)', () {
    expect(
      mapSettingsWriteError(StateError('raw')),
      const SettingsWriteException(SettingsWriteFailure.unknown),
    );
    expect(
      mapSettingsWriteError(Exception('NativeError')),
      const SettingsWriteException(SettingsWriteFailure.unknown),
    );
  });

  test('no Firestore type reaches the caller', () {
    for (final error in <Object>[
      firestoreError('unavailable'),
      firestoreError('internal'),
      TimeoutException('late'),
      StateError('raw'),
    ]) {
      final mapped = mapSettingsWriteError(error);
      expect(mapped, isNot(isA<FirebaseException>()));
      expect(
        mapped is SettingsWriteException || mapped is SettingsWriteNoAnswer,
        true,
      );
    }
  });
}
