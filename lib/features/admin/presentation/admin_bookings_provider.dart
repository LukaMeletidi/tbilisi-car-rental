import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_deleted_notice_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';

/// Where the admin bookings list stands.
enum AdminBookingsStatus {
  /// Nobody is signed in as an admin: nothing is asked for and nothing is
  /// kept.
  inactive,

  /// The first answer has not arrived yet.
  loading,

  /// There is a list to show (it may be empty).
  ready,

  /// The bookings could not be loaded; see [AdminBookingsState.failure].
  failed,
}

/// What the admin bookings screen shows.
class AdminBookingsState {
  const AdminBookingsState({
    this.status = AdminBookingsStatus.inactive,
    this.bookings = const [],
    this.unreadable = const [],
    this.carsById,
    this.hasMore = false,
    this.loadingMore = false,
    this.showOfflineNote = false,
    this.failure,
  });

  final AdminBookingsStatus status;

  /// The loaded bookings, newest first.
  final List<Booking> bookings;

  /// The loaded documents that could not be read as bookings.
  final List<UnreadableBooking> unreadable;

  /// Every car by its ID, also the hidden ones. Null while the cars are
  /// not loaded or could not be loaded.
  final Map<String, Car>? carsById;

  /// True when the last answer was as long as the limit, so there may be
  /// older bookings to load.
  final bool hasMore;

  /// True between a press of "Load more" and its answer.
  final bool loadingMore;

  /// True when the list has been showing saved data for a while.
  final bool showOfflineNote;

  /// Why loading failed. Set only while [status] is
  /// [AdminBookingsStatus.failed].
  final AdminBookingsFailure? failure;

  AdminBookingsState copyWith({
    AdminBookingsStatus? status,
    List<Booking>? bookings,
    List<UnreadableBooking>? unreadable,
    Map<String, Car>? carsById,
    bool? hasMore,
    bool? loadingMore,
    bool? showOfflineNote,
  }) {
    return AdminBookingsState(
      status: status ?? this.status,
      bookings: bookings ?? this.bookings,
      unreadable: unreadable ?? this.unreadable,
      carsById: carsById ?? this.carsById,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      showOfflineNote: showOfflineNote ?? this.showOfflineNote,
    );
  }
}

/// The live admin bookings list.
///
/// It is tied to the admin session: the Firestore listener exists only
/// while the session is [AdminSession.admin]. build() watches the session,
/// so the moment it becomes anything else, Riverpod runs the clean-up of
/// the previous build, which closes the listener, and only then builds the
/// inactive state. The listener is therefore closed by this provider
/// itself and not by an error from the rules. The screen also calls [stop]
/// before it signs out, so the listener is already closed when the sign-in
/// token goes away.
///
/// The provider is auto-dispose: leaving the bookings screen closes the
/// listener too.
class AdminBookingsNotifier extends Notifier<AdminBookingsState> {
  StreamSubscription<RawBookingsResult>? _subscription;
  Timer? _offlineTimer;
  DateTime? _fromCacheSince;
  int _limit = adminBookingsPageSize;

  // Counts the listeners that were started. An answer for an older one
  // (for example cars that arrive after a sign-out) is ignored.
  int _generation = 0;

  @override
  AdminBookingsState build() {
    ref.onDispose(_stopListening);
    // When the list is left, its one-time notice "Booking deleted." is
    // forgotten. Done right after the clean-up, because Riverpod does not
    // allow another provider to be changed inside it.
    final deletedNotice = ref.read(adminDeletedNoticeProvider.notifier);
    ref.onDispose(() => scheduleMicrotask(deletedNotice.clear));

    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) {
      _limit = adminBookingsPageSize;
      return const AdminBookingsState();
    }

    _listen();
    _loadCars();
    return const AdminBookingsState(status: AdminBookingsStatus.loading);
  }

  /// Loads [adminBookingsPageSize] more bookings. Does nothing when there
  /// are no more, or while a "load more" is already running.
  void loadMore() {
    if (state.status != AdminBookingsStatus.ready) return;
    if (!state.hasMore || state.loadingMore) return;
    _limit += adminBookingsPageSize;
    state = state.copyWith(loadingMore: true);
    _listen();
  }

  /// Tries again after a failure.
  void retry() {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    state = AdminBookingsState(
      status: AdminBookingsStatus.loading,
      carsById: state.carsById,
    );
    _listen();
    if (state.carsById == null) _loadCars();
  }

  /// Closes the listener and forgets the list. Called right before a
  /// sign-out, so that nothing is listening when the sign-in token goes.
  void stop() {
    _stopListening();
    state = const AdminBookingsState();
  }

  void _listen() {
    _stopListening();
    _generation += 1;
    _subscription = ref
        .read(adminBookingsRepositoryProvider)
        .watchNewestBookings(limit: _limit)
        .listen(_onResult, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _fromCacheSince = null;
  }

  void _onResult(RawBookingsResult result) {
    final parsed = parseBookings(result.documents, onSkipped: _logSkipped);
    final now = ref.read(clockProvider)();

    _fromCacheSince = fromCacheSinceAfter(
      previous: _fromCacheSince,
      fromCache: result.fromCache,
      now: now,
    );
    if (_fromCacheSince == null) {
      // The server answered: no "offline" note, and none pending.
      _offlineTimer?.cancel();
      _offlineTimer = null;
    } else {
      // Saved data. Look again when it has lasted long enough.
      _offlineTimer ??= Timer(offlineNoteDelay, _onOfflineTimer);
    }

    state = AdminBookingsState(
      status: AdminBookingsStatus.ready,
      bookings: parsed.bookings,
      unreadable: parsed.unreadable,
      carsById: state.carsById,
      // Exactly as many documents as were asked for: there may be more.
      hasMore: result.documents.length == _limit,
      showOfflineNote: shouldShowOfflineNote(
        fromCacheSince: _fromCacheSince,
        now: now,
      ),
    );
  }

  void _onOfflineTimer() {
    _offlineTimer = null;
    if (state.status != AdminBookingsStatus.ready) return;
    state = state.copyWith(
      showOfflineNote: shouldShowOfflineNote(
        fromCacheSince: _fromCacheSince,
        now: ref.read(clockProvider)(),
      ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // After a sign-out the rules refuse the listener. That is not a failure
    // to show; the session change puts this provider to rest.
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;

    _stopListening();
    state = AdminBookingsState(
      status: AdminBookingsStatus.failed,
      carsById: state.carsById,
      failure: error is AdminBookingsException
          ? error.failure
          : AdminBookingsFailure.other,
    );
  }

  Future<void> _loadCars() async {
    final generation = _generation;
    final List<Car> cars;
    try {
      cars = await ref.read(adminBookingsRepositoryProvider).readAllCars();
    } catch (error) {
      // The rows then say that the car could not be loaded.
      developer.log(
        'The cars could not be loaded for the admin list: $error',
        name: 'AdminBookingsNotifier',
        level: 900, // warning
      );
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if (state.status == AdminBookingsStatus.inactive) return;
    state = state.copyWith(carsById: {for (final car in cars) car.id: car});
  }
}

void _logSkipped(String id, Object error, StackTrace stackTrace) {
  // The ID and the reason only; never the contents of the document.
  developer.log(
    'Skipped booking document "$id": '
    '${error is FormatException ? error.message : error.runtimeType}',
    name: 'AdminBookingsNotifier',
    level: 900, // warning
  );
}

final adminBookingsProvider =
    NotifierProvider.autoDispose<AdminBookingsNotifier, AdminBookingsState>(
      AdminBookingsNotifier.new,
    );
