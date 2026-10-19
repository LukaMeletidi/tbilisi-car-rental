import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// Where the edit of the company information stands.
enum AdminCompanyInfoStatus {
  /// Nobody is signed in as an admin: nothing is asked for.
  inactive,

  /// The information has not arrived yet.
  loading,

  /// The form is shown (empty when settings/company does not exist yet).
  editing,

  /// settings/company exists but cannot be read; it is corrected in the
  /// Firebase console.
  unreadable,

  /// The information could not be loaded; see
  /// [AdminCompanyInfoState.failure].
  failed,
}

/// What the Company Info form shows. Everything is plain Dart.
class AdminCompanyInfoState {
  const AdminCompanyInfoState({
    this.status = AdminCompanyInfoStatus.inactive,
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

  final AdminCompanyInfoStatus status;

  /// The information the edit started from; null while editing means that
  /// settings/company did not exist (the server said so). Changes are
  /// measured against it, and the save refuses to overwrite information
  /// that no longer equals it.
  final CompanyInfo? base;

  /// The information as the live read last delivered it (null: no
  /// document). Equal to [base] until it is changed elsewhere while the
  /// form keeps its own fields.
  final CompanyInfo? latest;

  /// The fields as the admin typed them.
  final CompanyInput? draft;

  /// The problems of [draft].
  final Map<CompanyField, CompanyProblem> problems;

  /// True after the first press of Save: the form then shows every error.
  final bool showErrors;

  /// True while a save is running: the form is locked.
  final bool saving;

  /// What to tell the admin about the last attempt to save.
  final CompanySaveNotice? notice;

  /// The information the last save tried to write; kept only after "No
  /// answer".
  final CompanyInfo? attempted;

  /// Why loading failed; only for [AdminCompanyInfoStatus.failed].
  final CompanyLoadFailure? failure;

  /// Goes up by one whenever the notifier itself replaces the fields of
  /// the form. Typing does not change it. The screen builds new text
  /// controllers for a new version.
  final int formVersion;

  /// True when the form has changes that are not saved.
  bool get isDirty {
    final draft = this.draft;
    return status == AdminCompanyInfoStatus.editing &&
        draft != null &&
        companyDraftChanged(base, draft);
  }

  /// After "No answer" the fields are locked: only "Save again" and "Load
  /// the current info" are offered.
  bool get locked => notice == CompanySaveNotice.noAnswer;

  /// Whether Save can be pressed. Problems do not disable it: the press
  /// shows them.
  bool get canSave =>
      status == AdminCompanyInfoStatus.editing && !saving && !locked && isDirty;

  /// True when the stored information was changed (or created) elsewhere
  /// while the form keeps its own fields: a save would be refused.
  bool get changedElsewhere =>
      status == AdminCompanyInfoStatus.editing && latest != base;

  AdminCompanyInfoState _copy({
    CompanyInfo? latest,
    bool setLatest = false,
    CompanyInput? draft,
    Map<CompanyField, CompanyProblem>? problems,
    bool? showErrors,
    bool? saving,
    CompanySaveNotice? notice,
    bool clearNotice = false,
    CompanyInfo? attempted,
    int? formVersion,
  }) {
    final nextNotice = clearNotice ? null : (notice ?? this.notice);
    return AdminCompanyInfoState(
      status: status,
      base: base,
      latest: setLatest ? latest : this.latest,
      draft: draft ?? this.draft,
      problems: problems ?? this.problems,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      notice: nextNotice,
      // The attempted information belongs to "No answer" and goes with it.
      attempted: nextNotice == CompanySaveNotice.noAnswer
          ? (attempted ?? this.attempted)
          : null,
      failure: failure,
      formVersion: formVersion ?? this.formVersion,
    );
  }
}

/// The edit of the company information: the fields and the save. It
/// behaves as the Extras & Prices form and the edit form of a car.
///
/// Tied to the admin session: the live read exists only while the session
/// is admin. Auto-dispose: leaving the screen closes it and forgets the
/// fields. The read waits for the server as every settings read does
/// (watchCompany): the empty first-time form opens only when the SERVER
/// says that settings/company does not exist; an answer from memory
/// without the document says nothing, and after serverAnswerWait the form
/// shows "No connection" while the read stays open.
///
/// Nothing is logged here except, in debug builds, the type of an
/// unexpected error.
class AdminCompanyInfoNotifier extends Notifier<AdminCompanyInfoState> {
  StreamSubscription<CompanyInfo?>? _subscription;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminCompanyInfoState build() {
    ref.onDispose(_stopListening);
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminCompanyInfoState();
    _listen();
    return const AdminCompanyInfoState(status: AdminCompanyInfoStatus.loading);
  }

  /// Replaces the fields of the form with [draft]. Ignored while a save
  /// runs and while the fields are locked after "No answer".
  void setDraft(CompanyInput draft) {
    if (state.status != AdminCompanyInfoStatus.editing) return;
    if (state.draft == null || state.saving || state.locked) return;
    state = state._copy(draft: draft, problems: validateCompanyInput(draft));
  }

  /// Removes the notice about the last attempt. "No answer" stays: it is
  /// left only by "Save again" or "Load the current info".
  void dismissNotice() {
    if (state.notice == null || state.locked) return;
    state = state._copy(clearNotice: true);
  }

  /// Drops the fields of the form and shows the information as it is
  /// stored now ("Load the current info").
  void loadCurrent() {
    if (state.status != AdminCompanyInfoStatus.editing || state.saving) {
      return;
    }
    state = _formOf(state.latest, formVersion: state.formVersion + 1);
  }

  /// Tries to load the information again after a failure.
  void retry() {
    if (!_isAdmin) return;
    state = const AdminCompanyInfoState(status: AdminCompanyInfoStatus.loading);
    _listen();
  }

  /// Saves the form: replaces the whole settings/company document. When
  /// the form started from "does not exist", the save expects no document.
  ///
  /// There must be a change and no problem; otherwise nothing is sent and
  /// the form shows its problems. "Save again" after "No answer" comes here
  /// too, with the locked fields: if the first write arrived, the stored
  /// information already equals what is written, and the save counts as
  /// done without a second write.
  Future<void> save() async {
    final draft = state.draft;
    if (!_isAdmin || state.saving) return;
    if (state.status != AdminCompanyInfoStatus.editing) return;
    if (draft == null || !state.isDirty) return;

    final problems = validateCompanyInput(draft);
    if (problems.isNotEmpty) {
      state = state._copy(problems: problems, showErrors: true);
      return;
    }
    final target = companyFromInput(draft);
    final base = state.base;

    state = state._copy(saving: true, showErrors: true);
    CompanySaveNotice notice;
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveCompany(target, base: base);
      notice = CompanySaveNotice.saved;
    } on SettingsWriteNoAnswer {
      notice = CompanySaveNotice.noAnswer;
    } on SettingsWriteException catch (error) {
      notice = noticeForCompanyWriteFailure(error.failure);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'An unexpected error in a settings save: ${error.runtimeType}',
        );
      }
      notice = CompanySaveNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;
    state = state._copy(saving: false, notice: notice, attempted: target);
  }

  void _listen() {
    _stopListening();
    _subscription = ref
        .read(settingsRepositoryProvider)
        .watchCompany()
        .listen(_onCompany, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// The form of the stored [company] (null: no document), as it opens.
  AdminCompanyInfoState _formOf(
    CompanyInfo? company, {
    required int formVersion,
  }) {
    final draft = CompanyInput.fromCompany(company);
    return AdminCompanyInfoState(
      status: AdminCompanyInfoStatus.editing,
      base: company,
      latest: company,
      draft: draft,
      problems: validateCompanyInput(draft),
      formVersion: formVersion,
    );
  }

  void _onCompany(CompanyInfo? company) {
    final attempted = state.attempted;
    if (state.locked && attempted != null && company == attempted) {
      // After "No answer", the stored information is exactly what the save
      // wrote: the save did arrive.
      state = state._copy(
        latest: company,
        setLatest: true,
        notice: CompanySaveNotice.saved,
      );
      return;
    }
    final keepForm =
        state.status == AdminCompanyInfoStatus.editing &&
        (state.isDirty || state.saving || state.locked);
    if (keepForm) {
      state = state._copy(latest: company, setLatest: true);
      return;
    }
    final shown = state.draft;
    final next = _formOf(company, formVersion: state.formVersion);
    // New text fields only when the fields really differ.
    state = shown != null && sameCompanyInput(shown, next.draft!)
        ? next._copy(notice: state.notice)
        : next._copy(notice: state.notice, formVersion: state.formVersion + 1);
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out nothing is shown; the session change puts this
    // provider to rest.
    if (!_isAdmin) return;
    if (error is NoServerAnswerException) {
      // No connection, NOT "no information". The read stays open: when the
      // server answers, _onCompany shows the form.
      if (state.status != AdminCompanyInfoStatus.loading) return;
      state = const AdminCompanyInfoState(
        status: AdminCompanyInfoStatus.failed,
        failure: CompanyLoadFailure.noConnection,
      );
      return;
    }
    if (error is FormatException) {
      // The stored document is broken; the read stays open, so the form
      // opens once it is corrected in the console.
      state = const AdminCompanyInfoState(
        status: AdminCompanyInfoStatus.unreadable,
      );
      return;
    }
    _stopListening();
    state = const AdminCompanyInfoState(
      status: AdminCompanyInfoStatus.failed,
      failure: CompanyLoadFailure.other,
    );
  }
}

final adminCompanyInfoProvider =
    NotifierProvider.autoDispose<
      AdminCompanyInfoNotifier,
      AdminCompanyInfoState
    >(AdminCompanyInfoNotifier.new);
