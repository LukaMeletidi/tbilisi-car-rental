import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_deleted_notice_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/settings/presentation/settings_providers.dart';

/// Where the "new booking" form stands.
enum AdminBookingNewStatus {
  /// Nobody is signed in as an admin: there is no form and no ID.
  inactive,

  /// The form is shown.
  editing,
}

/// What the "new booking" form shows. Everything is plain Dart.
class AdminBookingNewState {
  const AdminBookingNewState({
    this.status = AdminBookingNewStatus.inactive,
    this.bookingId,
    this.draft = AdminNewBookingDraft.empty,
    this.cars,
    this.carsFailed = false,
    this.locations,
    this.extrasPrices,
    this.showErrors = false,
    this.saving = false,
    this.notice,
    this.pending,
    this.createdId,
  });

  final AdminBookingNewStatus status;

  /// The ID the booking gets. It is made once, when the form opens, and
  /// used for every attempt to save, so a repeated attempt cannot create a
  /// second booking. Null while the form is inactive.
  final String? bookingId;

  /// The fields as the admin entered them.
  final AdminNewBookingDraft draft;

  /// Every car, also the hidden ones; null while not loaded.
  final List<Car>? cars;

  /// True when the cars could not be loaded; see
  /// [AdminBookingNewNotifier.reloadCars].
  final bool carsFailed;

  /// The fixed places from settings; null while not loaded.
  final List<PickupLocation>? locations;

  /// The current prices of the extras; null while not loaded.
  final ExtrasPrices? extrasPrices;

  /// True after the first press of Save: the form then shows every error.
  final bool showErrors;

  /// True while a save is running: the form is locked.
  final bool saving;

  /// What to tell the admin about the last attempt to save.
  final AdminBookingCreateNotice? notice;

  /// The booking of an attempt whose outcome is not known: the server did
  /// not answer in time, so the booking MAY ALREADY EXIST. While this is
  /// set the fields are locked (the stored values could otherwise differ
  /// from the shown ones) and only "Check again" is offered. Leaving the
  /// form now can leave a booking behind that the admin did not see saved.
  final Booking? pending;

  /// The ID of the booking once the server confirmed that it exists. The
  /// screen then opens its detail.
  final String? createdId;

  /// True when the booking may already exist; see [pending].
  bool get mayAlreadyExist => pending != null;

  /// The chosen car; null when none is chosen, the cars are not loaded or
  /// no car has that ID.
  Car? get car {
    final carId = draft.fields.carId;
    for (final car in cars ?? const <Car>[]) {
      if (car.id == carId) return car;
    }
    return null;
  }

  /// The total at today's prices, or why there is none.
  AdminNewTotal get total =>
      newBookingTotal(draft: draft, car: car, extrasPrices: extrasPrices);

  /// Everything that stops a save: the problems of the fields and of the
  /// total.
  Set<AdminBookingError> get errors {
    final total = this.total;
    final errors = {
      ...validateNewBooking(
        draft,
        carIds: cars == null ? null : {for (final car in cars!) car.id},
        locations: locations,
      ),
      ...newTotalErrors(total),
    };
    // No field is wrong and still there is no total (the cars are not
    // loaded, so the car cannot be looked up): nothing can be saved.
    if (errors.isEmpty && total.state != AdminNewTotalState.ready) {
      errors.add(AdminBookingError.newTotalUnavailable);
    }
    return errors;
  }

  /// True when the admin entered or chose anything.
  bool get isDirty => newDraftIsDirty(draft);

  /// True when leaving the form would lose something: entered values, or
  /// the knowledge that a booking may have been created.
  bool get hasSomethingToLose => (isDirty || mayAlreadyExist) && !isCreated;

  /// True once the server confirmed that the booking exists.
  bool get isCreated => createdId != null;

  /// Whether the fields can be changed: not while a save runs, not while
  /// the booking may already exist, and not after it was created.
  bool get canEdit =>
      status == AdminBookingNewStatus.editing &&
      !saving &&
      !mayAlreadyExist &&
      !isCreated;

  /// Whether the Save button can be pressed: the fields can be changed,
  /// something was entered, and the prices are loaded (without them there
  /// is no total to store). Other errors do not disable it: pressing Save
  /// shows them.
  bool get canSave =>
      canEdit && isDirty && total.state != AdminNewTotalState.pricesNotLoaded;

  /// Whether "Check again" can be pressed.
  bool get canCheckAgain => mayAlreadyExist && !saving && !isCreated;

  /// A copy with other values. [notice] is always set anew: leaving it out
  /// removes the notice. [pending] is kept unless [clearPending] is true.
  AdminBookingNewState copyWith({
    AdminNewBookingDraft? draft,
    List<Car>? cars,
    bool? carsFailed,
    List<PickupLocation>? locations,
    ExtrasPrices? extrasPrices,
    bool? showErrors,
    bool? saving,
    AdminBookingCreateNotice? notice,
    Booking? pending,
    bool clearPending = false,
    String? createdId,
  }) {
    return AdminBookingNewState(
      status: status,
      bookingId: bookingId,
      draft: draft ?? this.draft,
      cars: cars ?? this.cars,
      carsFailed: carsFailed ?? this.carsFailed,
      locations: locations ?? this.locations,
      extrasPrices: extrasPrices ?? this.extrasPrices,
      showErrors: showErrors ?? this.showErrors,
      saving: saving ?? this.saving,
      notice: notice,
      pending: clearPending ? null : pending ?? this.pending,
      createdId: createdId ?? this.createdId,
    );
  }
}

/// The "new booking" form of the admin area: the drafts of the fields and
/// the save.
///
/// It is tied to the admin session: build() watches the session, so there
/// is a form only while the session is admin, and everything (the drafts,
/// the ID) is forgotten when the session becomes anything else. It is
/// auto-dispose: leaving the screen forgets the form too, and the next
/// form gets a new ID.
///
/// Nothing is logged here except the type of an unexpected error: never a
/// name, a phone number, an e-mail address or a note.
class AdminBookingNewNotifier extends Notifier<AdminBookingNewState> {
  // Counts the forms that were started; an answer for an older one is
  // ignored.
  int _generation = 0;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminBookingNewState build() {
    _generation += 1;
    // Opening the form ends the list's one-time notice "Booking deleted.".
    // Done right after this build, because Riverpod does not allow another
    // provider to be changed inside it.
    final deletedNotice = ref.read(adminDeletedNoticeProvider.notifier);
    scheduleMicrotask(deletedNotice.clear);
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminBookingNewState();

    // The places and the prices of the extras, kept up to date. Listening
    // also keeps the two providers alive while the form is open.
    ref.listen(pickupLocationsProvider, (_, next) => _onSettings());
    ref.listen(extrasPricesProvider, (_, next) => _onSettings());

    _loadCars();
    return AdminBookingNewState(
      status: AdminBookingNewStatus.editing,
      // Made once per form; no request is sent for it.
      bookingId: ref.read(adminBookingsRepositoryProvider).newBookingId(),
      locations: ref.read(pickupLocationsProvider).value,
      extrasPrices: ref.read(extrasPricesProvider).value,
    );
  }

  /// Replaces the fields of the form with [draft]. Ignored while a save
  /// runs, while the booking may already exist, and after it was created.
  ///
  /// A message about a failed save stays while the admin goes on editing.
  void setDraft(AdminNewBookingDraft draft) {
    if (!state.canEdit) return;
    state = state.copyWith(draft: draft, notice: state.notice);
  }

  /// Removes the notice about the last attempt. Not while the booking may
  /// already exist: that message must stay until "Check again" has an
  /// answer.
  void dismissNotice() {
    if (state.notice == null || state.mayAlreadyExist) return;
    state = state.copyWith(saving: state.saving);
  }

  /// Tries to load the cars again.
  void reloadCars() {
    if (state.status != AdminBookingNewStatus.editing) return;
    if (state.cars != null) return;
    state = state.copyWith(
      carsFailed: false,
      saving: state.saving,
      notice: state.notice,
    );
    _loadCars();
  }

  /// Saves the form.
  ///
  /// It has two stages. Stage 1 checks: the fields and the total must be
  /// valid; otherwise nothing is sent and the form shows its errors. Stage
  /// 2 creates the booking under the ID of this form and waits for the
  /// server.
  ///
  /// While it runs, [AdminBookingNewState.saving] is true and a second
  /// call does nothing. Afterwards [AdminBookingNewState.notice] says what
  /// happened:
  /// - the server confirmed it: [AdminBookingNewState.createdId] is set;
  /// - certainly not created: the form stays as it is and can be saved
  ///   again;
  /// - no answer in time: the booking may exist. The form is locked
  ///   ([AdminBookingNewState.mayAlreadyExist]) and [checkAgain] finds out.
  Future<void> save() async {
    final id = state.bookingId;
    if (!_isAdmin || id == null || !state.canEdit) return;

    // Stage 1: check.
    final total = state.total.totalToSave;
    if (state.errors.isNotEmpty || total == null) {
      state = state.copyWith(showErrors: true);
      return;
    }
    final booking = newBookingFromDraft(draft: state.draft, total: total);

    state = state.copyWith(saving: true, showErrors: true);
    final mayWrite = await _checkBeforeSave(booking);
    if (!ref.mounted || !_isAdmin) return;
    if (!mayWrite) {
      state = state.copyWith(saving: false);
      return;
    }

    // Stage 2: write, and wait for the server's answer.
    await _write(id, booking);
  }

  /// After "no answer from the server": asks again with the same ID and
  /// the same booking. When the booking exists nothing is written; when it
  /// does not, it is created now. Either way there is exactly one booking.
  Future<void> checkAgain() async {
    final id = state.bookingId;
    final booking = state.pending;
    if (!_isAdmin || id == null || booking == null) return;
    if (!state.canCheckAgain) return;

    state = state.copyWith(saving: true);
    await _write(id, booking);
  }

  /// The last part of stage 1. Returns true when the write may go ahead.
  ///
  /// Nothing is checked yet. The conflict warning of Phase 5 (another
  /// confirmed booking of the same car at that time) belongs here.
  Future<bool> _checkBeforeSave(Booking booking) async {
    return true;
  }

  // Stage 2. `state.saving` is true when this is called.
  Future<void> _write(String id, Booking booking) async {
    final generation = _generation;
    final wasPending = state.mayAlreadyExist;
    AdminBookingCreateNotice notice;
    try {
      // "Created" and "already created" are the same good news: the
      // booking exists once.
      await ref
          .read(adminBookingsRepositoryProvider)
          .createBooking(id, booking);
      notice = AdminBookingCreateNotice.saved;
    } on AdminBookingCreateNoAnswer {
      notice = AdminBookingCreateNotice.noAnswer;
    } on AdminBookingCreateException catch (error) {
      notice = noticeForCreateFailure(error.failure);
    } catch (error) {
      developer.log(
        'Creating a booking failed with an error of type ${error.runtimeType}',
        name: 'AdminBookingNewNotifier',
        level: 900, // warning
      );
      notice = AdminBookingCreateNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin || generation != _generation) return;

    switch (notice) {
      case AdminBookingCreateNotice.saved:
        state = state.copyWith(
          saving: false,
          notice: notice,
          clearPending: true,
          createdId: id,
        );
      case AdminBookingCreateNotice.noAnswer:
      case AdminBookingCreateNotice.stillUnknown:
        // It may exist: lock the form and remember what was sent.
        state = state.copyWith(
          saving: false,
          notice: wasPending ? AdminBookingCreateNotice.stillUnknown : notice,
          pending: booking,
        );
      case AdminBookingCreateNotice.carMissing:
        // The transaction looked: the booking does not exist. Whatever
        // was unknown before is known now, and the car can be changed.
        state = state.copyWith(
          saving: false,
          notice: notice,
          clearPending: true,
        );
      case AdminBookingCreateNotice.noConnection:
      case AdminBookingCreateNotice.refused:
      case AdminBookingCreateNotice.unknown:
        // This attempt wrote nothing. After an earlier "no answer" that
        // says nothing about the earlier attempt, so the form stays
        // locked and says that it is still not known; otherwise the
        // reason is shown and the form can be saved again.
        state = state.copyWith(
          saving: false,
          notice: wasPending ? AdminBookingCreateNotice.stillUnknown : notice,
        );
    }
  }

  void _onSettings() {
    if (state.status == AdminBookingNewStatus.inactive) return;
    state = state.copyWith(
      locations: ref.read(pickupLocationsProvider).value,
      extrasPrices: ref.read(extrasPricesProvider).value,
      saving: state.saving,
      notice: state.notice,
    );
  }

  Future<void> _loadCars() async {
    final generation = _generation;
    final List<Car> cars;
    try {
      cars = await ref.read(adminBookingsRepositoryProvider).readAllCars();
    } catch (error) {
      developer.log(
        'The cars could not be loaded for a new booking: ${error.runtimeType}',
        name: 'AdminBookingNewNotifier',
        level: 900, // warning
      );
      if (!ref.mounted || generation != _generation) return;
      if (state.status == AdminBookingNewStatus.inactive) return;
      state = state.copyWith(
        carsFailed: true,
        saving: state.saving,
        notice: state.notice,
      );
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if (state.status == AdminBookingNewStatus.inactive) return;
    state = state.copyWith(
      cars: List.unmodifiable(cars),
      carsFailed: false,
      saving: state.saving,
      notice: state.notice,
    );
  }
}

/// The "new booking" form. One at a time; a new form gets a new ID.
final adminBookingNewProvider =
    NotifierProvider.autoDispose<AdminBookingNewNotifier, AdminBookingNewState>(
      AdminBookingNewNotifier.new,
    );
