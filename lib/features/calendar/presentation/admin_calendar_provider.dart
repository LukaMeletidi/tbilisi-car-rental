import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/calendar/domain/calendar_grid.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// Where the calendar stands.
enum AdminCalendarStatus {
  /// Nobody is signed in as an admin: nothing is asked for and nothing is
  /// kept.
  inactive,

  /// The server has not yet answered both reads (the confirmed bookings and
  /// the cars). An answer from memory does not count: see
  /// [AdminCalendarNotifier].
  loading,

  /// The grid can be drawn. The server has answered both reads at least
  /// once, so an empty grid really means "no bookings".
  ready,

  /// The calendar could not be loaded; see [AdminCalendarState.failure].
  failed,
}

/// What the calendar screen shows.
class AdminCalendarState {
  const AdminCalendarState({
    required this.window,
    this.status = AdminCalendarStatus.inactive,
    this.cars = const [],
    this.bookings = const [],
    this.unreadable = 0,
    this.rows = const [],
    this.showOfflineNote = false,
    this.failure,
  });

  final AdminCalendarStatus status;

  /// The 14 days shown.
  final CalendarWindow window;

  /// Every readable car, also the hidden ones.
  final List<Car> cars;

  /// Every readable confirmed booking, of all time.
  final List<Booking> bookings;

  /// How many confirmed booking documents could not be read.
  final int unreadable;

  /// The rows of [window] (calendarRows). Empty unless [status] is ready.
  final List<CalendarRow> rows;

  /// True when the grid has been showing data from memory for a while.
  final bool showOfflineNote;

  /// Why loading failed. Set only while [status] is failed.
  final AdminBookingsFailure? failure;

  /// The same state for the days of [window].
  AdminCalendarState showing(CalendarWindow window) => AdminCalendarState(
    window: window,
    status: status,
    cars: cars,
    bookings: bookings,
    unreadable: unreadable,
    rows: status == AdminCalendarStatus.ready
        ? calendarRows(cars: cars, bookings: bookings, window: window)
        : const [],
    showOfflineNote: showOfflineNote,
    failure: failure,
  );
}

/// The calendar of the admin area: two live reads, every confirmed booking
/// and every car, and the 14 days shown.
///
/// It is tied to the admin session like the bookings and cars lists: the
/// listeners exist only while the session is admin, and the Sign out button
/// calls [stop] first.
///
/// The grid needs the word of the SERVER for both reads. An answer from
/// memory that comes before it is ignored, also when it is not empty:
/// memory may hold only some confirmed bookings (those the bookings list
/// loaded) or only the visible cars (those the catalog loaded), and a grid
/// drawn from that would show bookings or cars as missing. When no server
/// answer has come [serverAnswerWait] after such an answer, the calendar
/// is "failed" with noConnection; the listeners stay open, so the grid
/// appears by itself when the server answers.
///
/// Once the grid is shown, a later answer from memory (the connection
/// dropped) keeps it, and after [offlineNoteDelay] the offline note is
/// shown. Nothing is written here.
class AdminCalendarNotifier extends Notifier<AdminCalendarState> {
  StreamSubscription<RawBookingsResult>? _bookingsSubscription;
  StreamSubscription<RawCarsResult>? _carsSubscription;
  Timer? _giveUpTimer;
  Timer? _offlineTimer;
  DateTime? _fromCacheSince;

  // Null until the server has answered that read.
  ParsedBookings? _bookings;
  List<Car>? _cars;

  // Whether the newest answer of each read came from memory.
  bool _bookingsFromCache = false;
  bool _carsFromCache = false;

  @override
  AdminCalendarState build() {
    ref.onDispose(_stopListening);
    final window = CalendarWindow.startingToday(ref.read(clockProvider)());
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) {
      return AdminCalendarState(window: window);
    }
    _listen();
    return AdminCalendarState(
      window: window,
      status: AdminCalendarStatus.loading,
    );
  }

  /// Shows the 7 days before the first day shown.
  void showPrevious() => state = state.showing(state.window.previous());

  /// Shows the 7 days after the first day shown.
  void showNext() => state = state.showing(state.window.next());

  /// Shows the 14 days from today.
  void showToday() => state = state.showing(
    CalendarWindow.startingToday(ref.read(clockProvider)()),
  );

  /// Tries again after a failure.
  void retry() {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    state = AdminCalendarState(
      window: state.window,
      status: AdminCalendarStatus.loading,
    );
    _listen();
  }

  /// Closes the listeners and forgets the data. Called right before a
  /// sign-out, so that nothing is listening when the sign-in token goes.
  void stop() {
    _stopListening();
    state = AdminCalendarState(window: state.window);
  }

  void _listen() {
    _stopListening();
    _bookingsSubscription = ref
        .read(adminBookingsRepositoryProvider)
        .watchConfirmedBookings()
        .listen(_onBookings, onError: _onError);
    _carsSubscription = ref
        .read(fleetRepositoryProvider)
        .watchAllCars()
        .listen(_onCars, onError: _onError);
  }

  void _stopListening() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _carsSubscription?.cancel();
    _carsSubscription = null;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _fromCacheSince = null;
    _bookings = null;
    _cars = null;
    _bookingsFromCache = false;
    _carsFromCache = false;
  }

  void _onBookings(RawBookingsResult result) {
    if (result.fromCache && _bookings == null) {
      _waitForServer();
      return;
    }
    _bookingsFromCache = result.fromCache;
    // An empty answer from memory says nothing; what is shown stays.
    if (!(result.fromCache && result.documents.isEmpty)) {
      _bookings = parseBookings(result.documents, onSkipped: _logSkipped);
    }
    _show();
  }

  void _onCars(RawCarsResult result) {
    if (result.fromCache && _cars == null) {
      _waitForServer();
      return;
    }
    _carsFromCache = result.fromCache;
    if (!(result.fromCache && result.documents.isEmpty)) {
      final entries = fleetEntries(
        result.documents,
        now: ref.read(clockProvider)(),
      );
      _cars = [
        for (final entry in entries)
          if (entry is FleetCarEntry) entry.car,
      ];
      for (final entry in entries) {
        if (entry is FleetUnreadableEntry) _logUnreadableCar(entry.id);
      }
    }
    _show();
  }

  void _waitForServer() {
    if (state.status != AdminCalendarStatus.loading) return;
    _giveUpTimer ??= Timer(serverAnswerWait, _onGiveUp);
  }

  void _onGiveUp() {
    _giveUpTimer = null;
    if (state.status != AdminCalendarStatus.loading) return;
    // No connection. NOT "no bookings". The listeners stay open: when the
    // server answers both, _show draws the grid.
    state = AdminCalendarState(
      window: state.window,
      status: AdminCalendarStatus.failed,
      failure: AdminBookingsFailure.noConnection,
    );
  }

  void _show() {
    final bookings = _bookings;
    final cars = _cars;
    // The other read has no server answer yet.
    if (bookings == null || cars == null) return;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;

    final now = ref.read(clockProvider)();
    _fromCacheSince = fromCacheSinceAfter(
      previous: _fromCacheSince,
      fromCache: _bookingsFromCache || _carsFromCache,
      now: now,
    );
    if (_fromCacheSince == null) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
    } else {
      _offlineTimer ??= Timer(offlineNoteDelay, _onOfflineTimer);
    }

    state = AdminCalendarState(
      window: state.window,
      status: AdminCalendarStatus.ready,
      cars: cars,
      bookings: bookings.bookings,
      unreadable: bookings.unreadable.length,
      showOfflineNote: shouldShowOfflineNote(
        fromCacheSince: _fromCacheSince,
        now: now,
      ),
    ).showing(state.window);
  }

  void _onOfflineTimer() {
    _offlineTimer = null;
    if (state.status != AdminCalendarStatus.ready) return;
    final show = shouldShowOfflineNote(
      fromCacheSince: _fromCacheSince,
      now: ref.read(clockProvider)(),
    );
    state = AdminCalendarState(
      window: state.window,
      status: state.status,
      cars: state.cars,
      bookings: state.bookings,
      unreadable: state.unreadable,
      rows: state.rows,
      showOfflineNote: show,
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out the rules refuse the listeners. That is not a
    // failure to show; the session change puts this provider to rest.
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    _stopListening();
    state = AdminCalendarState(
      window: state.window,
      status: AdminCalendarStatus.failed,
      failure: _failureOf(error),
    );
  }
}

AdminBookingsFailure _failureOf(Object error) {
  if (error is AdminBookingsException) return error.failure;
  if (error is FleetLoadException) {
    switch (error.failure) {
      case FleetLoadFailure.permissionDenied:
        return AdminBookingsFailure.permissionDenied;
      case FleetLoadFailure.noConnection:
        return AdminBookingsFailure.noConnection;
      case FleetLoadFailure.other:
        return AdminBookingsFailure.other;
    }
  }
  return AdminBookingsFailure.other;
}

void _logSkipped(String id, Object error, StackTrace stackTrace) {
  // The ID and the error type only; never the contents of the document
  // nor the message of the error, which may quote a stored value.
  developer.log(
    'Unreadable booking document "$id" (${error.runtimeType})',
    name: 'AdminCalendarNotifier',
    level: 900, // warning
  );
}

void _logUnreadableCar(String id) {
  // The ID only; never the contents of the document.
  developer.log(
    'Unreadable car document "$id" (FormatException)',
    name: 'AdminCalendarNotifier',
    level: 900, // warning
  );
}

final adminCalendarProvider =
    NotifierProvider.autoDispose<AdminCalendarNotifier, AdminCalendarState>(
      AdminCalendarNotifier.new,
    );
