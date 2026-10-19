import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// Where the edit of the extras prices stands.
enum AdminExtrasPricesStatus {
  /// Nobody is signed in as an admin: nothing is asked for.
  inactive,

  /// The prices have not arrived yet.
  loading,

  /// The form is shown.
  editing,

  /// settings/extras is missing or cannot be read as prices; it is
  /// corrected in the Firebase console.
  unreadable,

  /// The prices could not be loaded; see [AdminExtrasPricesState.failure].
  failed,
}

/// What the Extras & Prices form shows. Everything is plain Dart.
class AdminExtrasPricesState {
  const AdminExtrasPricesState({
    this.status = AdminExtrasPricesStatus.inactive,
    this.base,
    this.latest,
    this.draft,
    this.problems = const {},
    this.showErrors = false,
    this.saving = false,
    this.notice,
    this.attempted,
    this.failure,
    this.formVersion = 0,
  });

  final AdminExtrasPricesStatus status;

  /// The prices the edit started from. Changes are measured against them,
  /// and the save refuses to overwrite prices that no longer equal them.
  final ExtrasPrices? base;

  /// The prices as the live read last delivered them. Equal to [base]
  /// until they are changed elsewhere while the form keeps its own fields.
  final ExtrasPrices? latest;

  /// The four prices as the admin typed them.
  final ExtrasDraft? draft;

  /// The problems of [draft].
  final Map<Extra, ExtraPriceProblem> problems;

  /// True after the first press of Save, and from the start when a stored
  /// price has a problem: the form then shows every error.
  final bool showErrors;

  /// True while a save is running: the form is locked.
  final bool saving;

  /// What to tell the admin about the last attempt to save.
  final ExtrasSaveNotice? notice;

  /// The prices the last save tried to write; kept only after "No answer".
  final ExtrasPrices? attempted;

  /// Why loading failed; only for [AdminExtrasPricesStatus.failed].
  final ExtrasLoadFailure? failure;

  /// Goes up by one whenever the notifier itself replaces the fields of
  /// the form. Typing does not change it. The screen builds new text
  /// controllers for a new version.
  final int formVersion;

  /// True when the form has changes that are not saved.
  bool get isDirty {
    final base = this.base;
    final draft = this.draft;
    return base != null && draft != null && extrasDraftChanged(base, draft);
  }

  /// After "No answer" the fields are locked: only "Save again" and "Load
  /// the current prices" are offered, so the admin never edits on top of a
  /// write whose fate is unknown.
  bool get locked => notice == ExtrasSaveNotice.noAnswer;

  /// Whether Save can be pressed. Problems do not disable it: the press
  /// shows them.
  bool get canSave =>
      status == AdminExtrasPricesStatus.editing &&
      !saving &&
      !locked &&
      isDirty;

  /// True when the stored prices were changed elsewhere while the form
  /// keeps its own fields: a save would be refused.
  bool get changedElsewhere {
    final base = this.base;
    final latest = this.latest;
    return base != null && latest != null && latest != base;
  }

  AdminExtrasPricesState _copy({
    AdminExtrasPricesStatus? status,
    ExtrasPrices? base,
    ExtrasPrices? latest,
    ExtrasDraft? draft,
    Map<Extra, ExtraPriceProblem>? problems,
    bool? showErrors,
    bool? saving,
    ExtrasSaveNotice? notice,
    bool clearNotice = false,
    ExtrasPrices? attempted,
    int? formVersion,
  }) {
    final nextNotice = clearNotice ? null : (notice ?? this.notice);
    return AdminExtrasPricesState(
      status: status ?? this.status,
      base: base ?? this.base,
      latest: latest ?? this.latest,
      draft: draft ?? this.draft,
      problems: problems ?? this.problems,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      notice: nextNotice,
      // The attempted prices belong to "No answer" and go with it.
      attempted: nextNotice == ExtrasSaveNotice.noAnswer
          ? (attempted ?? this.attempted)
          : null,
      failure: failure,
      formVersion: formVersion ?? this.formVersion,
    );
  }
}

/// The edit of the extras prices: the four fields and the save. It behaves
/// as the edit form of a car.
///
/// Tied to the admin session: the live read exists only while the session
/// is admin. Auto-dispose: leaving the screen closes it and forgets the
/// fields. The read waits for the server as every settings read does
/// (watchExtrasPrices): an answer from memory without the document says
/// nothing, and after serverAnswerWait the form shows "No connection"
/// while the read stays open, so the form appears by itself when the
/// server answers.
///
/// Nothing is logged here except, in debug builds, the type of an
/// unexpected error.
class AdminExtrasPricesNotifier extends Notifier<AdminExtrasPricesState> {
  StreamSubscription<ExtrasPrices>? _subscription;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminExtrasPricesState build() {
    ref.onDispose(_stopListening);
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminExtrasPricesState();
    _listen();
    return const AdminExtrasPricesState(
      status: AdminExtrasPricesStatus.loading,
    );
  }

  /// Replaces the fields of the form with [draft]. Ignored while a save
  /// runs and while the fields are locked after "No answer".
  void setDraft(ExtrasDraft draft) {
    if (state.status != AdminExtrasPricesStatus.editing) return;
    if (state.draft == null || state.saving || state.locked) return;
    state = state._copy(
      draft: Map.unmodifiable(draft),
      problems: extrasDraftProblems(draft),
    );
  }

  /// Removes the notice about the last attempt. "No answer" stays: it is
  /// left only by "Save again" or "Load the current prices".
  void dismissNotice() {
    if (state.notice == null || state.locked) return;
    state = state._copy(clearNotice: true);
  }

  /// Drops the fields of the form and shows the prices as they are stored
  /// now ("Load the current prices").
  void loadCurrent() {
    final latest = state.latest;
    if (state.status != AdminExtrasPricesStatus.editing) return;
    if (latest == null || state.saving) return;
    state = _formOf(latest, formVersion: state.formVersion + 1);
  }

  /// Tries to load the prices again after a failure.
  void retry() {
    if (!_isAdmin) return;
    state = const AdminExtrasPricesState(
      status: AdminExtrasPricesStatus.loading,
    );
    _listen();
  }

  /// Saves the form: replaces the whole settings/extras document.
  ///
  /// There must be a change and no problem; otherwise nothing is sent and
  /// the form shows its problems. "Save again" after "No answer" comes here
  /// too, with the locked fields: if the first write arrived, the stored
  /// prices already equal the prices to write, and the save counts as done
  /// without a second write.
  Future<void> save() async {
    final base = state.base;
    final draft = state.draft;
    if (!_isAdmin || state.saving) return;
    if (state.status != AdminExtrasPricesStatus.editing) return;
    if (base == null || draft == null || !state.isDirty) return;

    final problems = extrasDraftProblems(draft);
    if (problems.isNotEmpty) {
      state = state._copy(problems: problems, showErrors: true);
      return;
    }
    final target = extrasPricesFromInput(draft);

    state = state._copy(saving: true, showErrors: true);
    ExtrasSaveNotice notice;
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveExtrasPrices(target, base: base);
      notice = ExtrasSaveNotice.saved;
    } on SettingsWriteNoAnswer {
      notice = ExtrasSaveNotice.noAnswer;
    } on SettingsWriteException catch (error) {
      notice = noticeForSettingsWriteFailure(error.failure);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'An unexpected error in a settings save: ${error.runtimeType}',
        );
      }
      notice = ExtrasSaveNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;
    state = state._copy(saving: false, notice: notice, attempted: target);
  }

  void _listen() {
    _stopListening();
    _subscription = ref
        .read(settingsRepositoryProvider)
        .watchExtrasPrices()
        .listen(_onPrices, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// The form of the stored [prices], as it opens: errors are shown at
  /// once when a stored price has a problem (only possible by a console
  /// edit).
  AdminExtrasPricesState _formOf(
    ExtrasPrices prices, {
    required int formVersion,
  }) {
    final draft = extrasDraftOf(prices);
    final problems = extrasDraftProblems(draft);
    return AdminExtrasPricesState(
      status: AdminExtrasPricesStatus.editing,
      base: prices,
      latest: prices,
      draft: draft,
      problems: problems,
      showErrors: problems.isNotEmpty,
      formVersion: formVersion,
    );
  }

  void _onPrices(ExtrasPrices prices) {
    final attempted = state.attempted;
    if (state.locked && attempted != null && prices == attempted) {
      // After "No answer", the stored prices are exactly what the save
      // wrote: the save did arrive.
      state = state._copy(latest: prices, notice: ExtrasSaveNotice.saved);
      return;
    }
    final keepForm =
        state.status == AdminExtrasPricesStatus.editing &&
        (state.isDirty || state.saving || state.locked);
    if (keepForm) {
      state = state._copy(latest: prices);
      return;
    }
    final shown = state.draft;
    final next = _formOf(prices, formVersion: state.formVersion);
    // New text fields only when the fields really differ.
    state = mapEquals(shown, next.draft)
        ? next._copy(notice: state.notice)
        : next._copy(notice: state.notice, formVersion: state.formVersion + 1);
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out nothing is shown; the session change puts this
    // provider to rest.
    if (!_isAdmin) return;
    if (error is NoServerAnswerException) {
      // No connection, NOT "no prices". The read stays open: when the
      // server answers, _onPrices shows the form.
      if (state.status != AdminExtrasPricesStatus.loading) return;
      state = const AdminExtrasPricesState(
        status: AdminExtrasPricesStatus.failed,
        failure: ExtrasLoadFailure.noConnection,
      );
      return;
    }
    if (error is FormatException) {
      // The document is missing or broken; the read stays open, so the
      // form opens once it is corrected in the console.
      state = const AdminExtrasPricesState(
        status: AdminExtrasPricesStatus.unreadable,
      );
      return;
    }
    _stopListening();
    state = const AdminExtrasPricesState(
      status: AdminExtrasPricesStatus.failed,
      failure: ExtrasLoadFailure.other,
    );
  }
}

final adminExtrasPricesProvider =
    NotifierProvider.autoDispose<
      AdminExtrasPricesNotifier,
      AdminExtrasPricesState
    >(AdminExtrasPricesNotifier.new);
