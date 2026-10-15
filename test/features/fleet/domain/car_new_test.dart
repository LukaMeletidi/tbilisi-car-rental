import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

void main() {
  test('a new form is empty and hidden', () {
    expect(newCarDraft.brand, '');
    expect(newCarDraft.photos, isEmpty);
    expect(newCarDraft.active, false);
  });

  test('both confirmed results mean "saved"', () {
    expect(createNoticeOf(CarCreateResult.created), CarCreateNotice.saved);
    expect(
      createNoticeOf(CarCreateResult.alreadyCreated),
      CarCreateNotice.saved,
    );
  });

  test('the failures of a create', () {
    expect(
      createNoticeForFailure(CarWriteFailure.noConnection),
      CarCreateNotice.noConnection,
    );
    expect(
      createNoticeForFailure(CarWriteFailure.refused),
      CarCreateNotice.refused,
    );
    for (final failure in [
      CarWriteFailure.carMissing,
      CarWriteFailure.changedElsewhere,
      CarWriteFailure.unknown,
    ]) {
      expect(
        createNoticeForFailure(failure),
        CarCreateNotice.unknown,
        reason: failure.name,
      );
    }
  });

  test('"No answer" and an unknown error may have created the car; '
      'noConnection and refused certainly did not', () {
    expect(createMayHaveArrived(CarCreateNotice.noAnswer), true);
    expect(createMayHaveArrived(CarCreateNotice.unknown), true);
    expect(createMayHaveArrived(CarCreateNotice.noConnection), false);
    expect(createMayHaveArrived(CarCreateNotice.refused), false);
    expect(createMayHaveArrived(CarCreateNotice.saved), false);
  });

  group('something to lose', () {
    bool lose(
      Object draft, {
      bool mayAlreadyExist = false,
      bool created = false,
    }) => newCarHasSomethingToLose(
      draft == 'empty' ? newCarDraft : newCarDraft.copyWith(brand: 'Kia'),
      mayAlreadyExist: mayAlreadyExist,
      created: created,
    );

    test('an empty form: nothing', () {
      expect(lose('empty'), false);
    });

    test('one typed field: yes', () {
      expect(lose('typed'), true);
    });

    test('a save whose fate is unknown: yes, also with empty fields', () {
      expect(lose('empty', mayAlreadyExist: true), true);
    });

    test('once created: nothing', () {
      expect(lose('typed', created: true), false);
    });
  });

  test('Save can be pressed unless a save runs or the car may exist', () {
    expect(newCarCanSave(saving: false, mayAlreadyExist: false), true);
    expect(newCarCanSave(saving: true, mayAlreadyExist: false), false);
    expect(newCarCanSave(saving: false, mayAlreadyExist: true), false);
  });
}
