import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/hide_check.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// The hide and show actions of the fleet list.
class AdminCarVisibilityState {
  const AdminCarVisibilityState({
    this.busy = const {},
    this.checking = const {},
    this.notice,
    this.noticeCount = 0,
  });

  /// The IDs of the cars whose hide or show is running, the check before
  /// hiding and its dialog included.
  final Set<String> busy;

  /// The IDs of the cars whose bookings are being read before hiding
  /// ("Checking…"). Each is in [busy] too.
  final Set<String> checking;

  /// What the last finished hide or show tells the admin.
  final CarActiveNotice? notice;

  /// Goes up by one with every finished hide or show, so the screen shows
  /// each notice once, also the same one twice in a row.
  final int noticeCount;

  AdminCarVisibilityState _copy({Set<String>? busy, Set<String>? checking}) {
    return AdminCarVisibilityState(
      busy: busy ?? this.busy,
      checking: checking ?? this.checking,
      notice: notice,
      noticeCount: noticeCount,
    );
  }
}

/// Hides and shows cars from the list, with setCarActive: only "active"
/// is written, so it works for every stored car, also one that needs
/// repair. Nothing is queued offline; the live list shows the result.
///
/// Hiding first reads the confirmed bookings of the car that are not over
/// yet and asks "Hide this car?" with them (askBeforeHide); showing is
/// never checked.
///
/// Nothing is logged here except the type of an unexpected error.
class AdminCarVisibilityNotifier extends Notifier<AdminCarVisibilityState> {
  bool get _isAdmin => ref.read(adminSessionProvider) == AdminSession.admin;

  @override
  AdminCarVisibilityState build() {
    ref.watch(adminSessionProvider);
    return const AdminCarVisibilityState();
  }

  /// Hides ([active] false) or shows the car [id], without a question. The
  /// list uses it to show a car; it hides with [hide]. A second call for
  /// the same car while the first runs does nothing.
  Future<void> setActive(String id, {required bool active}) async {
    if (!_isAdmin) return;
    if (state.busy.contains(id)) return;
    state = state._copy(busy: {...state.busy, id});
    await _write(id, active: active);
  }

  /// Hides the car [id] after the check: its confirmed bookings that are
  /// not over yet are read ("Checking…"), and [decide] (the screen's
  /// dialog) answers; without a screen the answer is "Cancel". Only after
  /// "Hide" is anything written. A second call for the same car while the
  /// first runs does nothing.
  Future<void> hide(String id, {HideDecision decide = cancelHide}) async {
    if (!_isAdmin) return;
    if (state.busy.contains(id)) return;
    state = state._copy(busy: {...state.busy, id});

    final hide = await askBeforeHide(
      ref,
      carId: id,
      decide: decide,
      setChecking: (checking) => state = state._copy(
        checking: checking
            ? {...state.checking, id}
            : ({...state.checking}..remove(id)),
      ),
    );
    if (!ref.mounted) return;
    if (!hide || !_isAdmin) {
      // Cancel: nothing is written and the card is as it was.
      state = state._copy(
        busy: {...state.busy}..remove(id),
        checking: {...state.checking}..remove(id),
      );
      return;
    }
    await _write(id, active: false);
  }

  // The write. The car [id] is in `state.busy` when this is called; it is
  // removed again here, whatever happens.
  Future<void> _write(String id, {required bool active}) async {
    CarActiveNotice notice;
    try {
      await ref.read(fleetRepositoryProvider).setCarActive(id, active: active);
      notice = active ? CarActiveNotice.shown : CarActiveNotice.hidden;
    } on CarWriteNoAnswer {
      notice = CarActiveNotice.noAnswer;
    } on CarWriteException catch (error) {
      notice = activeNoticeForFailure(error.failure);
    } catch (error) {
      // Not mapped by the repository (for example a refused ID): its
      // diagnosis line, then "unknown".
      debugPrintCarWriteDiagnosis(error);
      notice = CarActiveNotice.unknown;
    }
    if (!ref.mounted) return;
    state = AdminCarVisibilityState(
      busy: {...state.busy}..remove(id),
      checking: {...state.checking}..remove(id),
      notice: notice,
      noticeCount: state.noticeCount + 1,
    );
  }
}

final adminCarVisibilityProvider =
    NotifierProvider.autoDispose<
      AdminCarVisibilityNotifier,
      AdminCarVisibilityState
    >(AdminCarVisibilityNotifier.new);
