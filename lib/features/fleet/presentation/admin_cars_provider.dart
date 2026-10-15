import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// Where the admin fleet list stands.
enum AdminCarsStatus {
  /// Nobody is signed in as an admin: nothing is asked for and nothing is
  /// kept.
  inactive,

  /// No answer that says anything has arrived yet. An empty answer that did
  /// not come from the server does not count; see AnswerMeaning.
  loading,

  /// There is a list to show. It is empty only when the SERVER said that
  /// there are no cars.
  ready,

  /// The cars could not be loaded; see [AdminCarsState.failure].
  failed,
}

/// What the fleet list screen shows.
class AdminCarsState {
  const AdminCarsState({
    this.status = AdminCarsStatus.inactive,
    this.entries = const [],
    this.showOfflineNote = false,
    this.failure,
  });

  final AdminCarsStatus status;

  /// The rows, in the order of the list (fleetEntries).
  final List<FleetEntry> entries;

  /// True when the list has been showing data from memory for a while.
  final bool showOfflineNote;

  /// Why loading failed. Set only while [status] is failed.
  final FleetLoadFailure? failure;

  FleetCounts get counts => fleetCounts(entries);
}

/// The live fleet list of the admin: every car, also the hidden ones.
///
/// The same pattern as the bookings list. It is tied to the admin session:
/// the listener exists only while the session is admin. An empty answer
/// that did not come from the server says nothing: the list stays loading,
/// and after serverAnswerWait it becomes "failed" with
/// FleetLoadFailure.noConnection. The listener stays open meanwhile, so the
/// cars appear by themselves as soon as the server answers. Nothing is
/// written here, so nothing can be queued.
class AdminCarsNotifier extends Notifier<AdminCarsState> {
  StreamSubscription<RawCarsResult>? _subscription;
  Timer? _offlineTimer;
  Timer? _giveUpTimer;
  DateTime? _fromCacheSince;

  @override
  AdminCarsState build() {
    ref.onDispose(_stopListening);
    final session = ref.watch(adminSessionProvider);
    if (session != AdminSession.admin) return const AdminCarsState();
    _listen();
    return const AdminCarsState(status: AdminCarsStatus.loading);
  }

  /// Tries again after a failure.
  void retry() {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    state = const AdminCarsState(status: AdminCarsStatus.loading);
    _listen();
  }

  /// Closes the listener and forgets the list. Called right before a
  /// sign-out, so that nothing is listening when the sign-in token goes.
  void stop() {
    _stopListening();
    state = const AdminCarsState();
  }

  void _listen() {
    _stopListening();
    _subscription = ref
        .read(fleetRepositoryProvider)
        .watchAllCars()
        .listen(_onResult, onError: _onError);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;
    _fromCacheSince = null;
  }

  void _onResult(RawCarsResult result) {
    final meaning = answerMeaning(
      isEmpty: result.documents.isEmpty,
      fromCache: result.fromCache,
    );
    if (meaning == AnswerMeaning.notKnownYet) {
      // Nothing, and not from the server: this says nothing about the cars.
      // What is on the screen stays; while loading, the wait gets a limit.
      if (state.status == AdminCarsStatus.loading) {
        _giveUpTimer ??= Timer(serverAnswerWait, _onGiveUp);
      }
      return;
    }
    _giveUpTimer?.cancel();
    _giveUpTimer = null;

    final now = ref.read(clockProvider)();
    _fromCacheSince = fromCacheSinceAfter(
      previous: _fromCacheSince,
      fromCache: result.fromCache,
      now: now,
    );
    if (_fromCacheSince == null) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
    } else {
      _offlineTimer ??= Timer(offlineNoteDelay, _onOfflineTimer);
    }

    final entries = fleetEntries(result.documents, now: now);
    for (final entry in entries) {
      if (entry is FleetUnreadableEntry) _logUnreadable(entry.id);
    }
    state = AdminCarsState(
      status: AdminCarsStatus.ready,
      entries: entries,
      showOfflineNote: shouldShowOfflineNote(
        fromCacheSince: _fromCacheSince,
        now: now,
      ),
    );
  }

  void _onGiveUp() {
    _giveUpTimer = null;
    if (state.status != AdminCarsStatus.loading) return;
    // No connection. NOT "no cars". The listener stays open: when the
    // server answers, _onResult shows the list.
    state = const AdminCarsState(
      status: AdminCarsStatus.failed,
      failure: FleetLoadFailure.noConnection,
    );
  }

  void _onOfflineTimer() {
    _offlineTimer = null;
    if (state.status != AdminCarsStatus.ready) return;
    state = AdminCarsState(
      status: AdminCarsStatus.ready,
      entries: state.entries,
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
    state = AdminCarsState(
      status: AdminCarsStatus.failed,
      failure: error is FleetLoadException
          ? error.failure
          : FleetLoadFailure.other,
    );
  }
}

void _logUnreadable(String id) {
  // The ID and the error type only; never the contents of the document nor
  // the message of the error, which may quote a stored value. fleetEntryOf
  // makes an unreadable entry only from a FormatException.
  developer.log(
    'Unreadable car document "$id" (FormatException)',
    name: 'AdminCarsNotifier',
    level: 900, // warning
  );
}

final adminCarsProvider =
    NotifierProvider.autoDispose<AdminCarsNotifier, AdminCarsState>(
      AdminCarsNotifier.new,
    );
