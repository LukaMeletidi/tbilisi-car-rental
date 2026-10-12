import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

/// Where the edit of one booking stands.
enum AdminBookingEditStatus {
  /// Nobody is signed in as an admin: nothing is asked for.
  inactive,

  /// The booking has not arrived yet.
  loading,

  /// The form is shown.
  editing,

  /// The server says there is no such booking (also: deleted meanwhile).
  missing,

  /// The document cannot be read as a booking.
  unreadable,

  /// The booking could not be loaded; see [AdminBookingEditState.failure].
  failed,
}

/// What the edit form shows. Everything is plain Dart.
class AdminBookingEditState {
  const AdminBookingEditState({
    this.status = AdminBookingEditStatus.inactive,
    this.base,
    this.latest,
    this.draft,
    this.cars,
    this.locations,
    this.extrasPrices,
    this.showErrors = false,
    this.saving = false,
    this.notice,
    this.noticeFields = const [],
    this.failure,
  });

  final AdminBookingEditStatus status;

  /// The booking the edit started from. Changes are measured against it,
  /// and the save refuses to overwrite when an edited part of the stored
  /// booking no longer equals it.
  final Booking? base;

  /// The booking as the live read last delivered it. Equal to [base] until
  /// it is changed elsewhere while the form has unsaved changes.
  final Booking? latest;

  /// The fields as the admin entered them.
  final AdminBookingDraft? draft;

  /// Every car, also the hidden ones; null while not loaded.
  final List<Car>? cars;

  /// The fixed places from settings; null while not loaded.
  final List<PickupLocation>? locations;

  /// The current prices of the extras; null while not loaded.
  final ExtrasPrices? extrasPrices;

  /// True after the first press of Save: the form then shows every error.
  final bool showErrors;

  /// True while a save is running: the form is locked.
  final bool saving;

  /// What to tell the admin about the last attempt to save.
  final AdminBookingSaveNotice? notice;

  /// The field names that belong to [notice]: the unknown fields, or the
  /// stored names of the parts that were changed elsewhere.
  final List<String> noticeFields;

  /// Why loading failed; only for [AdminBookingEditStatus.failed].
  final AdminBookingsFailure? failure;

  /// The car of the draft; null when the cars are not loaded or no car has
  /// that ID.
  Car? get car {
    final carId = draft?.carId;
    for (final car in cars ?? const <Car>[]) {
      if (car.id == carId) return car;
    }
    return null;
  }

  /// The stored total next to the new one; null while there is no form.
  AdminTotalComparison? get totals {
    final base = this.base;
    final draft = this.draft;
    if (base == null || draft == null) return null;
    return compareTotals(
      base: base,
      draft: draft,
      car: car,
      extrasPrices: extrasPrices,
    );
  }

  /// Everything that stops a save: the problems of the fields and of the
  /// choice of the total. Empty while there is no form.
  Set<AdminBookingError> get errors {
    final base = this.base;
    final draft = this.draft;
    final totals = this.totals;
    if (base == null || draft == null || totals == null) return const {};
    return {
      ...validateAdminBooking(
        draft,
        base: base,
        carIds: cars == null ? null : {for (final car in cars!) car.id},
        locations: locations,
      ),
      ...totalErrors(totals, draft.totalChoice),
    };
  }

  /// The parts the admin changed in the form, as entered.
  Set<AdminBookingField> get editedFields {
    final base = this.base;
    final draft = this.draft;
    if (base == null || draft == null) return const {};
    return draftChanges(AdminBookingDraft.fromBooking(base), draft);
  }

  /// True when the form has changes that are not saved.
  bool get isDirty => editedFields.isNotEmpty || draft?.totalChoice != null;

  /// The parts a save would write, as far as the form knows: the parts
  /// the admin changed, and the total when "use the new total" is chosen
  /// and a new total would really be stored.
  Set<AdminBookingField> get fieldsToWrite {
    final totals = this.totals;
    final writesTotal =
        totals != null && totalToSave(totals, draft?.totalChoice) != null;
    return {...editedFields, if (writesTotal) AdminBookingField.total};
  }

  /// The parts that were changed elsewhere since the edit started and that
  /// a save would refuse as a conflict, as far as the live read knows. The
  /// rule is the one of the save itself ([conflictingFields]): with the
  /// total among the parts to write, the car, the dates and the extras are
  /// compared too, also when the admin did not edit them.
  Set<AdminBookingField> get changedElsewhere {
    final base = this.base;
    final latest = this.latest;
    if (base == null || latest == null) return const {};
    return conflictingFields(
      base: base,
      current: latest.toMap(),
      edited: fieldsToWrite,
    );
  }

  /// A copy with other values. [notice] and [noticeFields] are always set
  /// anew: leaving them out removes the notice.
  AdminBookingEditState copyWith({
    Booking? base,
    Booking? latest,
    AdminBookingDraft? draft,
    List<Car>? cars,
    List<PickupLocation>? locations,
    ExtrasPrices? extrasPrices,
    bool? showErrors,
    bool? saving,
    AdminBookingSaveNotice? notice,
    List<String> noticeFields = const [],
  }) {
    return AdminBookingEditState(
      status: status,
      base: base ?? this.base,
      latest: latest ?? this.latest,
      draft: draft ?? this.draft,
      cars: cars ?? this.cars,
      locations: locations ?? this.locations,
      extrasPrices: extrasPrices ?? this.extrasPrices,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      notice: notice,
      noticeFields: noticeFields,
      failure: failure,
    );
  }
}

/// The edit of one booking of the admin area: the drafts of the fields and
/// the save.
///
/// Like the detail, it is tied to the admin session: build() watches the
/// session, so the listener exists only while the session is admin and is
/// closed by this provider when the session becomes anything else. It is
/// auto-dispose: leaving the screen closes the listener and forgets the
/// drafts.
///
/// Nothing is logged here except the type of an unexpected error: never a
/// name, a phone number, an e-mail address or a note.
class AdminBookingEditNotifier extends Notifier<AdminBookingEditState> {
  AdminBookingEditNotifier(this.bookingId);

  final String bookingId;

  StreamSubscription<RawBookingAnswer>? _subscription;
  Timer? _giveUpTimer;

  // Counts the listeners that were started; an answer for an older one is
  // ignored.
  int _generation = 0;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminBookingEditState build() {
    ref.onDispose(_stopListening);

    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminBookingEditState();

    if (!isPlausibleBookingId(bookingId)) {
      return const AdminBookingEditState(
        status: AdminBookingEditStatus.missing,
      );
    }

    // The places and the prices of the extras, kept up to date. Listening
    // also keeps the two providers alive while the form is open.
    ref.listen(pickupLocationsProvider, (_, next) => _onSettings());
    ref.listen(extrasPricesProvider, (_, next) => _onSettings());

    _listen();
    _loadCars();
    return AdminBookingEditState(
      status: AdminBookingEditStatus.loading,
      locations: ref.read(pickupLocationsProvider).value,
      extrasPrices: ref.read(extrasPricesProvider).value,
    );
  }

  /// Replaces the fields of the form with [draft]. Ignored while a save is
  /// running.
  ///
  /// When the car, a date or the extras change, the choice of the total is
  /// removed: the admin chooses again, looking at the new numbers.
  void setDraft(AdminBookingDraft draft) {
    final current = state.draft;
    if (state.status != AdminBookingEditStatus.editing) return;
    if (current == null || state.saving) return;
    _setDraft(
      priceFieldsDiffer(current, draft)
          ? draft.copyWith(keepTotalChoice: false)
          : draft,
    );
  }

  // A message about a failed save stays while the admin goes on editing;
  // "Saved" does not, because the form has unsaved changes again.
  void _setDraft(AdminBookingDraft draft) {
    final keep = state.notice != AdminBookingSaveNotice.saved;
    state = state.copyWith(
      draft: draft,
      notice: keep ? state.notice : null,
      noticeFields: keep ? state.noticeFields : const [],
    );
  }

  /// Sets which total is saved. Ignored while a save is running.
  void chooseTotal(AdminTotalChoice choice) {
    final current = state.draft;
    if (state.status != AdminBookingEditStatus.editing) return;
    if (current == null || state.saving) return;
    _setDraft(current.copyWith(totalChoice: choice));
  }

  /// Removes the notice about the last attempt and leaves the form as it
  /// is ("Keep editing").
  void dismissNotice() {
    if (state.notice == null) return;
    state = state.copyWith(saving: state.saving);
  }

  /// Drops the changes of the form and shows the booking as it is stored
  /// now ("Load the current booking").
  void loadCurrent() {
    final latest = state.latest;
    if (state.status != AdminBookingEditStatus.editing) return;
    if (latest == null || state.saving) return;
    state = state.copyWith(
      base: latest,
      draft: AdminBookingDraft.fromBooking(latest),
      showErrors: false,
    );
  }

  /// Tries to load the booking again after a failure.
  void retry() {
    if (!_isAdmin || !isPlausibleBookingId(bookingId)) return;
    state = AdminBookingEditState(
      status: AdminBookingEditStatus.loading,
      cars: state.cars,
      locations: state.locations,
      extrasPrices: state.extrasPrices,
    );
    _listen();
    if (state.cars == null) _loadCars();
  }

  /// Saves the form.
  ///
  /// It has two stages. Stage 1 checks: the fields and the choice of the
  /// total must be valid and something must have changed; otherwise
  /// nothing is sent and the form shows its errors. Stage 2 writes the
  /// changed parts and waits for the server.
  ///
  /// While it runs, [AdminBookingEditState.saving] is true and a second
  /// call does nothing. Afterwards [AdminBookingEditState.notice] says what
  /// happened. Only after the server's answer does the form take the
  /// edited booking as its new starting point.
  Future<void> save() async {
    final base = state.base;
    final draft = state.draft;
    final totals = state.totals;
    if (!_isAdmin || state.saving) return;
    if (state.status != AdminBookingEditStatus.editing) return;
    if (base == null || draft == null || totals == null) return;

    // Stage 1: check.
    if (state.errors.isNotEmpty) {
      state = state.copyWith(showErrors: true);
      return;
    }
    final edited = editedBooking(
      base: base,
      draft: draft,
      newTotal: totalToSave(totals, draft.totalChoice),
    );
    final changes = AdminBookingChanges.between(base, edited);
    if (changes.isEmpty) {
      state = state.copyWith(showErrors: true);
      return;
    }

    state = state.copyWith(saving: true, showErrors: true);
    final mayWrite = await _checkBeforeSave(base, edited);
    if (!ref.mounted || !_isAdmin) return;
    if (!mayWrite) {
      state = state.copyWith(saving: false);
      return;
    }

    // Stage 2: write, and wait for the server's answer.
    AdminBookingSaveNotice notice;
    var noticeFields = const <String>[];
    try {
      await ref
          .read(adminBookingsRepositoryProvider)
          .updateBooking(bookingId, base: base, changes: changes);
      notice = AdminBookingSaveNotice.saved;
    } on AdminBookingSaveNoAnswer {
      notice = AdminBookingSaveNotice.noAnswer;
    } on AdminBookingSaveException catch (error) {
      notice = noticeForSaveFailure(error.failure);
      noticeFields = error.fields;
    } catch (error) {
      developer.log(
        'Saving an edit failed with an error of type ${error.runtimeType}',
        name: 'AdminBookingEditNotifier',
        level: 900, // warning
      );
      notice = AdminBookingSaveNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;

    if (notice == AdminBookingSaveNotice.saved) {
      // The server has it: the edited booking is the new starting point,
      // and the form has no unsaved changes.
      state = state.copyWith(
        base: edited,
        draft: AdminBookingDraft.fromBooking(edited),
        showErrors: false,
        saving: false,
        notice: notice,
      );
    } else {
      // The form keeps what the admin typed.
      state = state.copyWith(
        saving: false,
        notice: notice,
        noticeFields: noticeFields,
      );
    }
  }

  /// The last part of stage 1. Returns true when the write may go ahead.
  ///
  /// Nothing is checked yet. The conflict warning of Phase 5 (another
  /// confirmed booking of the same car at that time) belongs here.
  Future<bool> _checkBeforeSave(Booking base, Booking edited) async {
    return true;
  }

  void _onSettings() {
    if (state.status == AdminBookingEditStatus.inactive) return;
    state = state.copyWith(
      locations: ref.read(pickupLocationsProvider).value,
      extrasPrices: ref.read(extrasPricesProvider).value,
      saving: state.saving,
      notice: state.notice,
      noticeFields: state.noticeFields,
    );
  }

  void _listen() {
    _stopListening();
    _generation += 1;
    _subscription = ref
        .read(adminBookingsRepositoryProvider)
        .watchBooking(bookingId)
        .listen(_onAnswer, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;
  }

  void _onAnswer(RawBookingAnswer answer) {
    final read = readBookingAnswer(answer);
    if (read.state != AdminBookingReadState.notKnownYet) {
      _giveUpTimer?.cancel();
      _giveUpTimer = null;
    }

    switch (read.state) {
      case AdminBookingReadState.notKnownYet:
        // The saved copy does not have it. Wait for the server, but not
        // for ever; the same delay as for the offline note of the list.
        if (state.status == AdminBookingEditStatus.loading) {
          _giveUpTimer ??= Timer(offlineNoteDelay, _onGiveUp);
        }
      case AdminBookingReadState.missing:
        state = AdminBookingEditState(
          status: AdminBookingEditStatus.missing,
          notice: state.notice,
          noticeFields: state.noticeFields,
        );
      case AdminBookingReadState.unreadable:
        state = const AdminBookingEditState(
          status: AdminBookingEditStatus.unreadable,
        );
      case AdminBookingReadState.found:
        final booking = read.booking!;
        final keepForm =
            state.status == AdminBookingEditStatus.editing &&
            (state.isDirty || state.saving);
        state = AdminBookingEditState(
          status: AdminBookingEditStatus.editing,
          // With unsaved changes the form keeps its starting point, so the
          // save can tell what was changed elsewhere. Without them the
          // form simply follows the stored booking.
          base: keepForm ? state.base : booking,
          latest: booking,
          draft: keepForm
              ? state.draft
              : AdminBookingDraft.fromBooking(booking),
          cars: state.cars,
          locations: state.locations,
          extrasPrices: state.extrasPrices,
          showErrors: keepForm && state.showErrors,
          saving: state.saving,
          notice: state.notice,
          noticeFields: state.noticeFields,
        );
    }
  }

  void _onGiveUp() {
    _giveUpTimer = null;
    if (state.status != AdminBookingEditStatus.loading) return;
    // Nothing saved and no answer from the server. This is not "the
    // booking does not exist".
    _stopListening();
    state = AdminBookingEditState(
      status: AdminBookingEditStatus.failed,
      failure: AdminBookingsFailure.other,
      cars: state.cars,
      locations: state.locations,
      extrasPrices: state.extrasPrices,
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out the rules refuse the listener; that is not a failure
    // to show.
    if (!_isAdmin) return;
    _stopListening();
    state = AdminBookingEditState(
      status: AdminBookingEditStatus.failed,
      failure: error is AdminBookingsException
          ? error.failure
          : AdminBookingsFailure.other,
      cars: state.cars,
      locations: state.locations,
      extrasPrices: state.extrasPrices,
    );
  }

  Future<void> _loadCars() async {
    final generation = _generation;
    final List<Car> cars;
    try {
      cars = await ref.read(adminBookingsRepositoryProvider).readAllCars();
    } catch (error) {
      // The form then cannot offer another car; the save still checks
      // that the car exists.
      developer.log(
        'The cars could not be loaded for the edit: ${error.runtimeType}',
        name: 'AdminBookingEditNotifier',
        level: 900, // warning
      );
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if (state.status == AdminBookingEditStatus.inactive) return;
    state = state.copyWith(
      cars: List.unmodifiable(cars),
      saving: state.saving,
      notice: state.notice,
      noticeFields: state.noticeFields,
    );
  }
}

/// One edit per booking ID.
final adminBookingEditProvider = NotifierProvider.autoDispose
    .family<AdminBookingEditNotifier, AdminBookingEditState, String>(
      AdminBookingEditNotifier.new,
    );
