import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/domain/admin_session.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_session_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/data/fleet_repository.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_write.dart';

/// The hide and show actions of the fleet list.
class AdminCarVisibilityState {
  const AdminCarVisibilityState({
    this.busy = const {},
    this.notice,
    this.noticeCount = 0,
  });

  /// The IDs of the cars whose hide or show is running.
  final Set<String> busy;

  /// What the last finished hide or show tells the admin.
  final CarActiveNotice? notice;

  /// Goes up by one with every finished hide or show, so the screen shows
  /// each notice once, also the same one twice in a row.
  final int noticeCount;
}

/// Hides and shows cars from the list, with setCarActive: only "active"
/// is written, so it works for every stored car, also one that needs
/// repair. Nothing is queued offline; the live list shows the result.
///
/// Nothing is logged here except the type of an unexpected error.
class AdminCarVisibilityNotifier extends Notifier<AdminCarVisibilityState> {
  @override
  AdminCarVisibilityState build() {
    ref.watch(adminSessionProvider);
    return const AdminCarVisibilityState();
  }

  /// Hides ([active] false) or shows the car [id]. A second call for the
  /// same car while the first runs does nothing.
  Future<void> setActive(String id, {required bool active}) async {
    if (ref.read(adminSessionProvider) != AdminSession.admin) return;
    if (state.busy.contains(id)) return;
    state = AdminCarVisibilityState(
      busy: {...state.busy, id},
      notice: state.notice,
      noticeCount: state.noticeCount,
    );

    CarActiveNotice notice;
    try {
      await ref.read(fleetRepositoryProvider).setCarActive(id, active: active);
      notice = active ? CarActiveNotice.shown : CarActiveNotice.hidden;
    } on CarWriteNoAnswer {
      notice = CarActiveNotice.noAnswer;
    } on CarWriteException catch (error) {
      notice = activeNoticeForFailure(error.failure);
    } catch (error) {
      developer.log(
        'Hiding or showing a car failed with an error of type '
        '${error.runtimeType}',
        name: 'AdminCarVisibilityNotifier',
        level: 900, // warning
      );
      notice = CarActiveNotice.unknown;
    }
    if (!ref.mounted) return;
    state = AdminCarVisibilityState(
      busy: {...state.busy}..remove(id),
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
