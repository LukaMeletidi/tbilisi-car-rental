import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/time/clock_provider.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/confirmed_bookings_read.dart';
import 'package:tbilisi_car_rental/features/admin/domain/hide_warning.dart';

/// The screen's answer to the "Hide this car?" dialog: true for "Hide".
/// The screen checks that it is still shown before it opens the dialog,
/// and answers false when it is gone.
typedef HideDecision = Future<bool> Function(HideCheckOutcome outcome);

/// Without a screen the answer is "Cancel": nothing is hidden without the
/// admin's "Hide".
Future<bool> cancelHide(HideCheckOutcome outcome) async => false;

/// The check before hiding the car [carId], shared by the Hide button of
/// the list and the Visible switch of the edit form: reads its confirmed
/// bookings from the server (10 second limit, never from memory) and asks
/// [decide]. Hiding has always asked first, so [decide] is asked for every
/// outcome, also a clear one. Returns true for "Hide".
///
/// [setChecking] is called with true before the read and with false after
/// it, so the screen can say "Checking…". It is not called again once the
/// provider is gone. "Now" comes from the clock provider.
///
/// Never throws: a failed read is HideCheckFailed, and a [decide] that
/// throws counts as "Cancel".
Future<bool> askBeforeHide(
  Ref ref, {
  required String carId,
  required HideDecision decide,
  required void Function(bool checking) setChecking,
}) async {
  setChecking(true);
  HideCheckOutcome outcome;
  try {
    final read = await ref
        .read(adminBookingsRepositoryProvider)
        .readConfirmedBookingsOfCar(carId);
    outcome = hideCheckOutcome(
      read: read,
      carId: carId,
      now: ref.read(clockProvider)().toUtc(),
    );
  } catch (error) {
    if (kDebugMode) debugPrint('A hide check failed: ${error.runtimeType}');
    outcome = const HideCheckFailed(ConflictCheckFailure.other);
  }
  if (!ref.mounted) return false;
  setChecking(false);
  try {
    return await decide(outcome);
  } catch (error) {
    if (kDebugMode) debugPrint('A hide dialog failed: ${error.runtimeType}');
    return false;
  }
}
