import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/booking_conflicts.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';

/// The screen's answer to a conflict dialog: true for "Continue anyway".
/// The screen checks that it is still shown before it opens the dialog,
/// and answers false when it is gone.
typedef ConflictDecision = Future<bool> Function(ConflictCheckOutcome outcome);

/// The answer when no screen is attached: "Cancel". Nothing is ever written
/// past a warning without the admin's "Continue anyway".
Future<bool> cancelOnConflict(ConflictCheckOutcome outcome) async => false;

/// The conflict check right before a write, shared by the status change,
/// the edit form and the new booking. Returns true when the write may go
/// ahead: no check needed, nothing found, or "Continue anyway".
///
/// [setChecking] is called with true before the read and with false after
/// it, so the screen can say "Checking…". It is not called again once the
/// provider is gone.
///
/// Never throws. Any failure of the read, also of the app itself, is
/// "could not be checked"; a [decide] that throws counts as "Cancel".
Future<bool> checkConflictsBeforeWrite(
  Ref ref, {
  required Booking? base,
  required Booking edited,
  required String? selfId,
  required ConflictDecision decide,
  required void Function(bool checking) setChecking,
}) async {
  if (!needsConflictCheck(base: base, edited: edited)) return true;
  setChecking(true);
  ConflictCheckOutcome outcome;
  try {
    final read = await ref
        .read(adminBookingsRepositoryProvider)
        .readConfirmedBookingsOfCar(edited.carId);
    outcome = conflictCheckOutcome(
      read: read,
      candidate: edited,
      selfId: selfId,
    );
  } catch (error) {
    if (kDebugMode) {
      debugPrint('A conflict check failed: ${error.runtimeType}');
    }
    outcome = const ConflictCheckFailed(ConflictCheckFailure.other);
  }
  if (!ref.mounted) return false;
  setChecking(false);
  if (outcome is ConflictCheckClear) return true;
  try {
    return await decide(outcome);
  } catch (error) {
    if (kDebugMode) {
      debugPrint('A conflict dialog failed: ${error.runtimeType}');
    }
    return false;
  }
}
