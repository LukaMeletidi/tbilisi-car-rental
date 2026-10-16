import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/hide_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// Asks "Hide this car?" and returns true when the admin chose Hide. Used
/// by the Hide button of the list and by Save of the edit form when the
/// form hides the car. [outcome] says which confirmed bookings of the car
/// are not over yet (step 5.4); hiding is never blocked by them.
///
/// Cancel, Back and a tap beside the dialog all mean "Cancel". When
/// [context] is no longer shown, nothing is opened and the answer is
/// "Cancel".
Future<bool> confirmHideCar(
  BuildContext context,
  HideCheckOutcome outcome,
) async {
  if (!context.mounted) return false;
  final hide = await showDialog<bool>(
    context: context,
    builder: (context) => HideCarDialog(outcome: outcome),
  );
  return hide ?? false;
}

/// White, with dark text. Times and counts only, never a customer name.
class HideCarDialog extends StatelessWidget {
  const HideCarDialog({super.key, required this.outcome});

  final HideCheckOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final List<String> lines;
    switch (outcome) {
      case HideCheckClear():
        lines = const [];
      case HideCheckFailed():
        lines = const [adminHideUnchecked];
      case final HideCheckBookings bookings:
        final shown = hideWarningLines(bookings);
        lines = [
          if (shown.periods.isNotEmpty) ...[
            adminHideAheadIntro,
            for (final period in shown.periods) adminConflictPeriod(period),
            if (shown.more > 0) adminConflictMore(shown.more),
            adminTbilisiTimeNote,
          ],
          if (shown.unreadable > 0) adminHideUnreadable(shown.unreadable),
        ];
    }

    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(adminHideCarTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              const Text(adminHiddenCarNote),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(adminCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(adminCarHide),
          ),
        ],
      ),
    );
  }
}
