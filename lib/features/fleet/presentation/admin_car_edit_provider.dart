import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/hide_check.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_validation.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// Where the edit of one car stands.
enum AdminCarEditStatus {
  /// Nobody is signed in as an admin: nothing is asked for.
  inactive,

  /// The car has not arrived yet.
  loading,

  /// The form is shown.
  editing,

  /// The server says there is no such car.
  missing,

  /// The document cannot be read as a car.
  unreadable,

  /// The car could not be loaded; see [AdminCarEditState.failure].
  failed,
}

/// What the edit form shows. Everything is plain Dart.
class AdminCarEditState {
  const AdminCarEditState({
    this.status = AdminCarEditStatus.inactive,
    this.base,
    this.baseData,
    this.latest,
    this.latestData,
    this.draft,
    this.validation = const CarValidation(),
    this.needsRepair = false,
    this.showErrors = false,
    this.saving = false,
    this.checking = false,
    this.notice,
    this.attempted,
    this.failure,
    this.formVersion = 0,
  });

  final AdminCarEditStatus status;

  /// The car the edit started from, and its stored fields. Changes are
  /// measured against it, and the save refuses to overwrite a car that no
  /// longer equals it.
  final Car? base;
  final Map<String, dynamic>? baseData;

  /// The car as the live read last delivered it, and its stored fields.
  /// Equal to [base] until it is changed elsewhere while the form keeps
  /// its own fields.
  final Car? latest;
  final Map<String, dynamic>? latestData;

  /// The fields as the admin entered them.
  final CarDraft? draft;

  /// The problems of [draft].
  final CarValidation validation;

  /// True when the stored [base] needs repair (carNeedsRepair).
  final bool needsRepair;

  /// True after the first press of Save, and from the start for a car that
  /// needs repair: the form then shows every error.
  final bool showErrors;

  /// True while a save is running: the form is locked.
  final bool saving;

  /// True while the confirmed bookings of the car are read before the save
  /// hides it ("Checking…"). [saving] is true then too.
  final bool checking;

  /// What to tell the admin about the last attempt to save.
  final CarSaveNotice? notice;

  /// The car the last save tried to write; kept only after "No answer".
  final Car? attempted;

  /// Why loading failed; only for [AdminCarEditStatus.failed].
  final FleetLoadFailure? failure;

  /// Goes up by one whenever the notifier itself replaces the fields of
  /// the form. Typing does not change it. The screen builds new text
  /// controllers for a new version.
  final int formVersion;

  /// True when the form has changes that are not saved.
  bool get isDirty {
    final base = this.base;
    final draft = this.draft;
    return base != null && draft != null && carDraftChanged(base, draft);
  }

  /// After "No answer" the fields are locked: only "Save again" and "Load
  /// the current car" are offered, so the admin never edits on top of a
  /// write whose fate is unknown.
  bool get locked => notice == CarSaveNotice.noAnswer;

  bool get canSave => carEditCanSave(
    editing: status == AdminCarEditStatus.editing,
    saving: saving,
    locked: locked,
    dirty: isDirty,
    needsRepair: needsRepair,
  );

  /// True when the stored car was changed elsewhere while the form keeps
  /// its own fields: a save would be refused.
  bool get changedElsewhere {
    final base = this.base;
    final latest = this.latest;
    return base != null && latest != null && latest != base;
  }

  /// True when pressing Save must first ask "Hide this car?": the car is
  /// visible now, the form hides it, and nothing else stops the save.
  bool get asksHideConfirmation {
    final base = this.base;
    final draft = this.draft;
    if (base == null || draft == null || !canSave) return false;
    return base.active && !draft.active && !validation.hasErrors;
  }

  AdminCarEditState _copy({
    AdminCarEditStatus? status,
    Car? base,
    Map<String, dynamic>? baseData,
    Car? latest,
    Map<String, dynamic>? latestData,
    CarDraft? draft,
    CarValidation? validation,
    bool? needsRepair,
    bool? showErrors,
    bool? saving,
    bool? checking,
    CarSaveNotice? notice,
    bool clearNotice = false,
    Car? attempted,
    int? formVersion,
  }) {
    final nextNotice = clearNotice ? null : (notice ?? this.notice);
    return AdminCarEditState(
      status: status ?? this.status,
      base: base ?? this.base,
      baseData: baseData ?? this.baseData,
      latest: latest ?? this.latest,
      latestData: latestData ?? this.latestData,
      draft: draft ?? this.draft,
      validation: validation ?? this.validation,
      needsRepair: needsRepair ?? this.needsRepair,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      checking: checking ?? this.checking,
      notice: nextNotice,
      // The attempted car belongs to "No answer" and goes with it.
      attempted: nextNotice == CarSaveNotice.noAnswer
          ? (attempted ?? this.attempted)
          : null,
      failure: failure,
      formVersion: formVersion ?? this.formVersion,
    );
  }
}

/// The edit of one car of the admin area: the fields and the save.
///
/// Tied to the admin session: the live read of the car exists only while
/// the session is admin. Auto-dispose: leaving the screen closes it and
/// forgets the fields. An answer that holds no car and did not come from
/// the server says nothing; after serverAnswerWait the form shows "No
/// connection" while the read stays open, so the car appears by itself
/// when the server answers.
///
/// Nothing is logged here except the type of an unexpected error.
class AdminCarEditNotifier extends Notifier<AdminCarEditState> {
  AdminCarEditNotifier(this.carId);

  final String carId;

  StreamSubscription<RawCarAnswer>? _subscription;
  Timer? _giveUpTimer;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  DateTime get _now => ref.read(clockProvider)();

  @override
  AdminCarEditState build() {
    ref.onDispose(_stopListening);
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminCarEditState();
    if (!isPlausibleCarId(carId)) {
      return const AdminCarEditState(status: AdminCarEditStatus.missing);
    }
    _listen();
    return const AdminCarEditState(status: AdminCarEditStatus.loading);
  }

  /// Replaces the fields of the form with [draft]. Ignored while a save
  /// runs and while the fields are locked after "No answer".
  void setDraft(CarDraft draft) {
    if (state.status != AdminCarEditStatus.editing) return;
    if (state.draft == null || state.saving || state.locked) return;
    state = state._copy(
      draft: draft,
      validation: validateCarDraft(draft, now: _now),
    );
  }

  /// Removes the notice about the last attempt. "No answer" stays: it is
  /// left only by "Save again" or "Load the current car".
  void dismissNotice() {
    if (state.notice == null || state.locked) return;
    state = state._copy(clearNotice: true);
  }

  /// Drops the fields of the form and shows the car as it is stored now
  /// ("Load the current car").
  void loadCurrent() {
    final latest = state.latest;
    final latestData = state.latestData;
    if (state.status != AdminCarEditStatus.editing) return;
    if (latest == null || latestData == null || state.saving) return;
    state = _formOf(latest, latestData, formVersion: state.formVersion + 1);
  }

  /// Tries to load the car again after a failure.
  void retry() {
    if (!_isAdmin || !isPlausibleCarId(carId)) return;
    state = const AdminCarEditState(status: AdminCarEditStatus.loading);
    _listen();
  }

  /// Saves the form: replaces the whole stored car.
  ///
  /// Stage 1 checks: there must be a change or a needed repair, and no
  /// error; otherwise nothing is sent and the form shows its errors. When
  /// the save hides a visible car ([AdminCarEditState.asksHideConfirmation]),
  /// the confirmed bookings of the car that are not over yet are read
  /// ([AdminCarEditState.checking]) and [decideHide] (the screen's "Hide
  /// this car?") answers; without a screen the answer is "Cancel". Stage 2
  /// writes and waits for the server. "Save again" after "No answer" comes
  /// here too, with the locked fields and without a new question: if the
  /// first write arrived, the stored car already equals the car to write,
  /// and the save counts as done without a second write.
  Future<void> save({HideDecision decideHide = cancelHide}) async {
    final base = state.base;
    final draft = state.draft;
    if (!_isAdmin || state.saving) return;
    if (state.status != AdminCarEditStatus.editing) return;
    if (base == null || draft == null) return;
    if (!state.isDirty && !state.needsRepair) return;

    final now = _now;
    final validation = validateCarDraft(draft, now: now);
    if (validation.hasErrors) {
      state = state._copy(validation: validation, showErrors: true);
      return;
    }
    final target = carFromDraft(carId, draft, now: now);
    final asksHide = state.asksHideConfirmation;

    state = state._copy(saving: true);
    if (asksHide) {
      final hide = await askBeforeHide(
        ref,
        carId: carId,
        decide: decideHide,
        setChecking: (checking) => state = state._copy(checking: checking),
      );
      if (!ref.mounted || !_isAdmin) return;
      if (!hide) {
        // Cancel: nothing is written and the form is as it was.
        state = state._copy(saving: false, checking: false);
        return;
      }
    }
    state = state._copy(showErrors: true);

    CarSaveNotice notice;
    try {
      await ref.read(fleetRepositoryProvider).replaceCar(target, base: base);
      notice = CarSaveNotice.saved;
    } on CarWriteNoAnswer {
      notice = CarSaveNotice.noAnswer;
    } on CarWriteException catch (error) {
      notice = noticeForCarWriteFailure(error.failure);
    } catch (error) {
      // Not mapped by the repository (for example a refused ID): its
      // diagnosis line, then "unknown".
      debugPrintCarWriteDiagnosis(error);
      notice = CarSaveNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;
    state = state._copy(
      saving: false,
      checking: false,
      notice: notice,
      attempted: target,
    );
  }

  void _listen() {
    _stopListening();
    _subscription = ref
        .read(fleetRepositoryProvider)
        .watchCar(carId)
        .listen(_onAnswer, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;
  }

  /// The form of a stored car, as it opens: errors are shown at once for a
  /// car that needs repair.
  AdminCarEditState _formOf(
    Car car,
    Map<String, dynamic> data, {
    required int formVersion,
  }) {
    final now = _now;
    final draft = CarDraft.fromCar(car);
    final needsRepair = carNeedsRepair(car, data, now: now);
    return AdminCarEditState(
      status: AdminCarEditStatus.editing,
      base: car,
      baseData: data,
      latest: car,
      latestData: data,
      draft: draft,
      validation: validateCarDraft(draft, now: now),
      needsRepair: needsRepair,
      showErrors: needsRepair,
      formVersion: formVersion,
    );
  }

  void _onAnswer(RawCarAnswer answer) {
    final read = readCarAnswer(answer);
    if (read.state == CarReadState.notKnownYet) {
      // Nothing, and not from the server. While loading, the wait gets a
      // limit; a shown form stays as it is.
      if (state.status == AdminCarEditStatus.loading) {
        _giveUpTimer ??= Timer(serverAnswerWait, _onGiveUp);
      }
      return;
    }
    _giveUpTimer?.cancel();
    _giveUpTimer = null;

    switch (read.state) {
      case CarReadState.notKnownYet:
        return;
      case CarReadState.missing:
        state = const AdminCarEditState(status: AdminCarEditStatus.missing);
      case CarReadState.unreadable:
        state = const AdminCarEditState(status: AdminCarEditStatus.unreadable);
      case CarReadState.found:
        final car = read.car!;
        final data = read.data!;
        final attempted = state.attempted;
        if (state.locked &&
            attempted != null &&
            !answer.fromCache &&
            sameCarDocument(data, carDocument(attempted))) {
          // After "No answer", the server shows the car exactly as the
          // save wrote it: the save did arrive.
          state = state._copy(notice: CarSaveNotice.saved);
          return;
        }
        final keepForm =
            state.status == AdminCarEditStatus.editing &&
            (state.isDirty || state.saving || state.locked);
        if (keepForm) {
          state = state._copy(latest: car, latestData: data);
          return;
        }
        final shown = state.draft;
        final next = _formOf(car, data, formVersion: state.formVersion);
        // New text fields only when the fields really differ.
        state = shown == next.draft
            ? next._copy(notice: state.notice)
            : next._copy(
                notice: state.notice,
                formVersion: state.formVersion + 1,
              );
    }
  }

  void _onGiveUp() {
    _giveUpTimer = null;
    if (state.status != AdminCarEditStatus.loading) return;
    // No connection, NOT "no such car". The read stays open: when the
    // server answers, _onAnswer shows the form.
    state = const AdminCarEditState(
      status: AdminCarEditStatus.failed,
      failure: FleetLoadFailure.noConnection,
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out the rules refuse the read; not a failure to show.
    if (!_isAdmin) return;
    _stopListening();
    state = AdminCarEditState(
      status: AdminCarEditStatus.failed,
      failure: error is FleetLoadException
          ? error.failure
          : FleetLoadFailure.other,
    );
  }
}

/// One edit per car ID.
final adminCarEditProvider = NotifierProvider.autoDispose
    .family<AdminCarEditNotifier, AdminCarEditState, String>(
      AdminCarEditNotifier.new,
    );
