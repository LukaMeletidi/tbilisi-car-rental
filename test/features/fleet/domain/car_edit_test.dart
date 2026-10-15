import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

import '../../../support/fake_fleet_repository.dart';

void main() {
  group('readCarAnswer', () {
    test('a readable car is found, with its stored fields', () {
      final data = rawCar();
      final read = readCarAnswer(
        RawCarAnswer(document: (id: 'a', data: data), fromCache: false),
      );
      expect(read.state, CarReadState.found);
      expect(read.car!.id, 'a');
      expect(read.data, same(data));
    });

    test('no document from the server: missing', () {
      final read = readCarAnswer(
        const RawCarAnswer(document: null, fromCache: false),
      );
      expect(read.state, CarReadState.missing);
    });

    test('no document, not from the server: not known yet, NOT missing', () {
      final read = readCarAnswer(
        const RawCarAnswer(document: null, fromCache: true),
      );
      expect(read.state, CarReadState.notKnownYet);
    });

    test('a document Car.fromMap cannot read: unreadable, nothing kept', () {
      final read = readCarAnswer(
        const RawCarAnswer(
          document: (id: 'a', data: {'brand': 5}),
          fromCache: false,
        ),
      );
      expect(read.state, CarReadState.unreadable);
      expect(read.car, isNull);
      expect(read.data, isNull);
    });
  });

  test('the dirty check compares with the form of the base car', () {
    final base = Car.fromMap('a', rawCar());
    final draft = CarDraft.fromCar(base);
    expect(carDraftChanged(base, draft), false);
    expect(carDraftChanged(base, draft.copyWith(seats: '4')), true);
    expect(carDraftChanged(base, draft.copyWith(active: false)), true);
    expect(carDraftChanged(base, draft.copyWith(photos: [''])), true);
  });

  group('carEditCanSave', () {
    bool canSave({
      bool editing = true,
      bool saving = false,
      bool locked = false,
      bool dirty = false,
      bool needsRepair = false,
    }) => carEditCanSave(
      editing: editing,
      saving: saving,
      locked: locked,
      dirty: dirty,
      needsRepair: needsRepair,
    );

    test('a complete car without a change: no', () {
      expect(canSave(), false);
    });

    test('a change: yes', () {
      expect(canSave(dirty: true), true);
    });

    test('a car that needs repair, without a change: yes, a save repairs '
        'it', () {
      expect(canSave(needsRepair: true), true);
    });

    test('never while saving, while locked after "No answer", or without '
        'a form', () {
      expect(canSave(dirty: true, saving: true), false);
      expect(canSave(dirty: true, locked: true), false);
      expect(canSave(dirty: true, editing: false), false);
    });
  });

  group('the photo list', () {
    test('add: one empty row at the end, never more than the maximum', () {
      expect(addPhotoRow(const []), ['']);
      expect(addPhotoRow(const ['https://a.example/1']), [
        'https://a.example/1',
        '',
      ]);
      final full = List.filled(carMaxPhotos, 'x');
      expect(addPhotoRow(full), same(full));
    });

    test('remove and set', () {
      expect(removePhotoAt(const ['a', 'b', 'c'], 1), ['a', 'c']);
      expect(setPhotoAt(const ['a', 'b'], 1, 'z'), ['a', 'z']);
    });

    test('move up and down; nothing at the ends', () {
      const photos = ['a', 'b', 'c'];
      expect(movePhoto(photos, 1, up: true), ['b', 'a', 'c']);
      expect(movePhoto(photos, 1, up: false), ['a', 'c', 'b']);
      expect(movePhoto(photos, 0, up: true), same(photos));
      expect(movePhoto(photos, 2, up: false), same(photos));
    });
  });

  test('the notices of a failed save', () {
    expect(
      noticeForCarWriteFailure(CarWriteFailure.noConnection),
      CarSaveNotice.noConnection,
    );
    expect(
      noticeForCarWriteFailure(CarWriteFailure.refused),
      CarSaveNotice.refused,
    );
    expect(
      noticeForCarWriteFailure(CarWriteFailure.carMissing),
      CarSaveNotice.carMissing,
    );
    expect(
      noticeForCarWriteFailure(CarWriteFailure.changedElsewhere),
      CarSaveNotice.changedElsewhere,
    );
    expect(
      noticeForCarWriteFailure(CarWriteFailure.unknown),
      CarSaveNotice.unknown,
    );
  });

  test('the notices of a failed hide or show', () {
    expect(
      activeNoticeForFailure(CarWriteFailure.noConnection),
      CarActiveNotice.noConnection,
    );
    expect(
      activeNoticeForFailure(CarWriteFailure.refused),
      CarActiveNotice.refused,
    );
    expect(
      activeNoticeForFailure(CarWriteFailure.carMissing),
      CarActiveNotice.carMissing,
    );
    expect(
      activeNoticeForFailure(CarWriteFailure.unknown),
      CarActiveNotice.unknown,
    );
  });
}
