import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

/// Where the detail of one booking stands.
enum AdminBookingDetailStatus {
  /// Nobody is signed in as an admin: nothing is asked for.
  inactive,

  /// No usable answer has arrived yet.
  loading,

  /// The booking is shown.
  found,

  /// The server says there is no such booking.
  missing,

  /// The document cannot be read as a booking.
  unreadable,

  /// The booking could not be loaded; see [AdminBookingDetailState.failure].
  failed,
}

/// What the booking detail screen shows.
class AdminBookingDetailState {
  const AdminBookingDetailState({
    this.status = AdminBookingDetailStatus.inactive,
    this.booking,
    this.unreadableReason,
    this.car = const AdminCarLabel(AdminCarState.notLoaded),
    this.showOfflineNote = false,
    this.failure,
    this.saving = false,
    this.notice,
  });

  final AdminBookingDetailStatus status;

  /// The booking as the live read last delivered it. The status chip shows
  /// THIS status, never the one of an attempted change.
  final Booking? booking;

  /// Why the document cannot be read; only for
  /// [AdminBookingDetailStatus.unreadable].
  final String? unreadableReason;

  /// The car of the booking.
  final AdminCarLabel car;

  /// True when the booking has been shown from saved data for a while.
  final bool showOfflineNote;

  /// Why loading failed; only for [AdminBookingDetailStatus.failed].
  final AdminBookingsFailure? failure;

  /// True while a status change is running: the choices are disabled.
  final bool saving;

  /// What to tell the admin about the last attempt to change the status.
  final AdminStatusChangeNotice? notice;

  /// A copy with other values. [notice] is always set anew: leaving it out
  /// removes the notice.
  AdminBookingDetailState copyWith({
    AdminCarLabel? car,
    bool? showOfflineNote,
    bool? saving,
    AdminStatusChangeNotice? notice,
  }) {
    return AdminBookingDetailState(
      status: status,
      booking: booking,
      unreadableReason: unreadableReason,
      car: car ?? this.car,
      showOfflineNote: showOfflineNote ?? this.showOfflineNote,
      failure: failure,
      saving: saving ?? this.saving,
      notice: notice,
    );
  }
}

/// One booking of the admin area, live, and the change of its status.
///
/// Like the list, it is tied to the admin session: build() watches the
/// session, so the listener exists only while the session is admin and is
/// closed by this provider when the session becomes anything else. It is
/// auto-dispose: leaving the screen closes the listener.
///
/// No customer data is logged here.
class AdminBookingDetailNotifier extends Notifier<AdminBookingDetailState> {
  AdminBookingDetailNotifier(this.bookingId);

  final String bookingId;

  StreamSubscription<RawBookingAnswer>? _subscription;
  Timer? _offlineTimer;
  DateTime? _fromCacheSince;

  // The car that was asked for, so it is read once per car.
  String? _carIdAskedFor;

  // Counts the listeners that were started; an answer for an older one is
  // ignored.
  int _generation = 0;

  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminBookingDetailState build() {
    ref.onDispose(_stopListening);

    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminBookingDetailState();

    // An ID of an impossible shape (a typed address can hold anything) is
    // simply "no such booking"; Firestore is not asked.
    if (!isPlausibleBookingId(bookingId)) {
      return const AdminBookingDetailState(
        status: AdminBookingDetailStatus.missing,
      );
    }

    _listen();
    return const AdminBookingDetailState(
      status: AdminBookingDetailStatus.loading,
    );
  }

  /// Tries to load the booking again after a failure.
  void retry() {
    if (!_isAdmin || !isPlausibleBookingId(bookingId)) return;
    state = const AdminBookingDetailState(
      status: AdminBookingDetailStatus.loading,
    );
    _listen();
  }

  /// Removes the notice about the last attempt.
  void dismissNotice() {
    if (state.notice != null) state = state.copyWith(saving: state.saving);
  }

  /// Changes the status of the booking to [status].
  ///
  /// It has two stages. Stage 1 checks whether the change should go ahead;
  /// today nothing is checked. The conflict warning of Phase 5 belongs
  /// there. Stage 2 writes and waits for the server.
  ///
  /// While it runs, [AdminBookingDetailState.saving] is true and a second
  /// call does nothing. The status on screen is never set here: it changes
  /// only when the live read delivers the new one. Afterwards
  /// [AdminBookingDetailState.notice] says what happened.
  Future<void> changeStatus(BookingStatus status) async {
    final booking = state.booking;
    if (!_isAdmin || state.saving) return;
    if (state.status != AdminBookingDetailStatus.found || booking == null) {
      return;
    }
    if (booking.status == status) return;

    state = state.copyWith(saving: true);

    // Stage 1: check.
    final mayChange = await _checkBeforeChange(booking, status);
    if (!ref.mounted || !_isAdmin) return;
    if (!mayChange) {
      state = state.copyWith(saving: false);
      return;
    }

    // Stage 2: write, and wait for the server's answer.
    AdminStatusChangeNotice notice;
    try {
      await ref
          .read(adminBookingsRepositoryProvider)
          .changeStatus(bookingId, status);
      notice = AdminStatusChangeNotice.saved;
    } on AdminStatusChangeNoAnswer {
      notice = AdminStatusChangeNotice.noAnswer;
    } on AdminStatusChangeException catch (error) {
      notice = noticeForFailure(error.failure);
    } catch (error) {
      developer.log(
        'A status change failed with an error of type ${error.runtimeType}',
        name: 'AdminBookingDetailNotifier',
        level: 900, // warning
      );
      notice = AdminStatusChangeNotice.unknown;
    }
    if (!ref.mounted || !_isAdmin) return;
    state = state.copyWith(saving: false, notice: notice);
  }

  /// Stage 1 of a status change. Returns true when the change may go ahead.
  ///
  /// Nothing is checked yet. In Phase 5 a change to "confirmed" looks here
  /// for other confirmed bookings of the same car and asks the admin
  /// "Continue anyway?".
  Future<bool> _checkBeforeChange(Booking booking, BookingStatus to) async {
    return true;
  }

  void _listen() {
    _stopListening();
    _generation += 1;
    _carIdAskedFor = null;
    _subscription = ref
        .read(adminBookingsRepositoryProvider)
        .watchBooking(bookingId)
        .listen(_onAnswer, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _fromCacheSince = null;
  }

  void _onAnswer(RawBookingAnswer answer) {
    final now = ref.read(clockProvider)();

    // The same rule as in the list: "offline" only after the answers have
    // come from the saved copy for a while without a break.
    _fromCacheSince = fromCacheSinceAfter(
      previous: _fromCacheSince,
      fromCache: answer.fromCache,
      now: now,
    );
    if (_fromCacheSince == null) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
    } else {
      _offlineTimer ??= Timer(offlineNoteDelay, _onOfflineTimer);
    }
    final showOfflineNote = shouldShowOfflineNote(
      fromCacheSince: _fromCacheSince,
      now: now,
    );

    final read = readBookingAnswer(answer);
    switch (read.state) {
      case AdminBookingReadState.notKnownYet:
        // The saved copy does not have it. Wait for the server; the timer
        // above gives up after a while.
        return;
      case AdminBookingReadState.missing:
        state = AdminBookingDetailState(
          status: AdminBookingDetailStatus.missing,
          notice: state.notice,
        );
      case AdminBookingReadState.unreadable:
        _logUnreadable(read.reason);
        state = AdminBookingDetailState(
          status: AdminBookingDetailStatus.unreadable,
          unreadableReason: read.reason,
        );
      case AdminBookingReadState.found:
        final booking = read.booking!;
        state = AdminBookingDetailState(
          status: AdminBookingDetailStatus.found,
          booking: booking,
          car: booking.carId == _carIdAskedFor
              ? state.car
              : const AdminCarLabel(AdminCarState.notLoaded),
          showOfflineNote: showOfflineNote,
          saving: state.saving,
          notice: state.notice,
        );
        if (booking.carId != _carIdAskedFor) _loadCar(booking.carId);
    }
  }

  void _onOfflineTimer() {
    _offlineTimer = null;
    final stillFromCache = shouldShowOfflineNote(
      fromCacheSince: _fromCacheSince,
      now: ref.read(clockProvider)(),
    );
    if (state.status == AdminBookingDetailStatus.found) {
      state = state.copyWith(
        showOfflineNote: stillFromCache,
        saving: state.saving,
        notice: state.notice,
      );
    } else if (state.status == AdminBookingDetailStatus.loading &&
        stillFromCache) {
      // Nothing saved and no answer from the server: say so, with a way to
      // try again. This is not "the booking does not exist".
      _stopListening();
      state = const AdminBookingDetailState(
        status: AdminBookingDetailStatus.failed,
        failure: AdminBookingsFailure.other,
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out the rules refuse the listener; that is not a failure
    // to show.
    if (!_isAdmin) return;
    _stopListening();
    state = AdminBookingDetailState(
      status: AdminBookingDetailStatus.failed,
      failure: error is AdminBookingsException
          ? error.failure
          : AdminBookingsFailure.other,
    );
  }

  Future<void> _loadCar(String carId) async {
    _carIdAskedFor = carId;
    final generation = _generation;
    final Car? car;
    try {
      car = await ref.read(adminBookingsRepositoryProvider).readCar(carId);
    } catch (error) {
      // The screen then says that the car could not be loaded.
      developer.log(
        'The car of a booking could not be loaded: ${error.runtimeType}',
        name: 'AdminBookingDetailNotifier',
        level: 900, // warning
      );
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if (state.booking?.carId != carId) return;
    state = state.copyWith(
      car: adminCarLabel(carId, {carId: ?car}),
      saving: state.saving,
      notice: state.notice,
    );
  }

  void _logUnreadable(String? reason) {
    // The ID and the reason only; never the contents of the document.
    developer.log(
      'Booking document "$bookingId" cannot be read: $reason',
      name: 'AdminBookingDetailNotifier',
      level: 900, // warning
    );
  }
}

/// One detail per booking ID.
final adminBookingDetailProvider = NotifierProvider.autoDispose
    .family<AdminBookingDetailNotifier, AdminBookingDetailState, String>(
      AdminBookingDetailNotifier.new,
    );
