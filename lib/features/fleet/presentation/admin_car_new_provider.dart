import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// What the "new car" form shows. Everything is plain Dart.
class AdminCarNewState {
  const AdminCarNewState({
    this.carId,
    this.draft = newCarDraft,
    this.validation = const CarValidation(),
    this.showErrors = false,
    this.saving = false,
    this.notice,
    this.pending,
    this.created = false,
  });

  /// The ID of the new car, made on the device once when the form opens
  /// and used for every attempt. Null while nobody is signed in as an
  /// admin: then there is no form.
  final String? carId;

  /// The fields as the admin entered them. A new car starts hidden.
  final CarDraft draft;

  /// The problems of [draft].
  final CarValidation validation;

  /// True after the first press of Save: the form then shows every error.
  final bool showErrors;

  /// True while a create runs: the form is locked.
  final bool saving;

  /// What to tell the admin about the last attempt.
  final CarCreateNotice? notice;

  /// The car of an attempt whose fate is unknown ("No answer" or an
  /// unknown error). While it is set, the fields are locked and only
  /// "Check again" sends it again, with the same ID.
  final Car? pending;

  /// True once the server confirmed that the car exists.
  final bool created;

  bool get mayAlreadyExist => pending != null;

  bool get hasSomethingToLose => newCarHasSomethingToLose(
    draft,
    mayAlreadyExist: mayAlreadyExist,
    created: created,
  );

  bool get canSave =>
      carId != null &&
      !created &&
      newCarCanSave(saving: saving, mayAlreadyExist: mayAlreadyExist);

  bool get canCheckAgain => mayAlreadyExist && !saving && !created;

  AdminCarNewState _copy({
    CarDraft? draft,
    CarValidation? validation,
    bool? showErrors,
    bool? saving,
    CarCreateNotice? notice,
    bool clearNotice = false,
    Car? pending,
    bool clearPending = false,
    bool? created,
  }) {
    return AdminCarNewState(
      carId: carId,
      draft: draft ?? this.draft,
      validation: validation ?? this.validation,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      notice: clearNotice ? null : (notice ?? this.notice),
      pending: clearPending ? null : (pending ?? this.pending),
      created: created ?? this.created,
    );
  }
}

/// The "new car" form of the admin area: the fields and the create.
///
/// Tied to the admin session; auto-dispose, so leaving the screen forgets
/// the fields and the ID. A retry after an uncertain attempt sends the same
/// car with the same ID; createCar finds it when the first attempt did
/// arrive, so a car is never created twice.
///
/// Nothing is logged here except the type of an unexpected error.
class AdminCarNewNotifier extends Notifier<AdminCarNewState> {
  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  DateTime get _now => ref.read(clockProvider)();

  @override
  AdminCarNewState build() {
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminCarNewState();
    return AdminCarNewState(
      carId: ref.read(fleetRepositoryProvider).newCarId(),
      validation: validateCarDraft(newCarDraft, now: _now),
    );
  }

  /// Replaces the fields with [draft]. Ignored while a create runs, after
  /// an uncertain attempt and after the car was created.
  void setDraft(CarDraft draft) {
    if (state.carId == null || state.saving) return;
    if (state.mayAlreadyExist || state.created) return;
    state = state._copy(
      draft: draft,
      validation: validateCarDraft(draft, now: _now),
    );
  }

  /// Removes the notice about the last attempt. The note of an uncertain
  /// attempt stays: only "Check again" or leaving ends it.
  void dismissNotice() {
    if (state.notice == null || state.mayAlreadyExist) return;
    state = state._copy(clearNotice: true);
  }

  /// Saves the form: creates the car with the form's ID. With errors,
  /// nothing is sent and the form shows them.
  Future<void> save() async {
    final carId = state.carId;
    if (!_isAdmin || carId == null || !state.canSave) return;
    final now = _now;
    final validation = validateCarDraft(state.draft, now: now);
    if (validation.hasErrors) {
      state = state._copy(validation: validation, showErrors: true);
      return;
    }
    await _create(carFromDraft(carId, state.draft, now: now));
  }

  /// After an uncertain attempt: sends the same car with the same ID again.
  /// If the first attempt arrived, the car is found and not created twice.
  Future<void> checkAgain() async {
    final pending = state.pending;
    if (!_isAdmin || pending == null || !state.canCheckAgain) return;
    await _create(pending);
  }

  Future<void> _create(Car car) async {
    final wasPending = state.mayAlreadyExist;
    state = state._copy(saving: true, showErrors: true);
    CarCreateNotice notice;
    try {
      final result = await ref.read(fleetRepositoryProvider).createCar(car);
      notice = createNoticeOf(result);
    } on CarWriteNoAnswer {
      notice = CarCreateNotice.noAnswer;
    } on CarWriteException catch (error) {
      notice = createNoticeForFailure(error.failure);
    } catch (error) {
      // Not mapped by the repository (for example a refused ID): its
      // diagnosis line, then "unknown".
      debugPrintCarWriteDiagnosis(error);
      notice = CarCreateNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;

    final created = notice == CarCreateNotice.saved;
    // An earlier uncertain attempt stays uncertain after a retry that
    // certainly did not create the car now: the first one may have.
    final keepPending =
        !created && (createMayHaveArrived(notice) || wasPending);
    state = state._copy(
      saving: false,
      notice: notice,
      created: created,
      pending: keepPending ? car : null,
      clearPending: !keepPending,
    );
  }
}

final adminCarNewProvider =
    NotifierProvider.autoDispose<AdminCarNewNotifier, AdminCarNewState>(
      AdminCarNewNotifier.new,
    );
