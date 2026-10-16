import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/domain/conflict_warning.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// Shows the conflict dialog for [outcome] and returns true only for
/// "Continue anyway". Cancel, Back and a tap beside the dialog all mean
/// "Cancel". When [context] is no longer shown, nothing is opened and the
/// answer is "Cancel". A clear outcome needs no dialog: true.
///
/// This is the ConflictDecision every screen passes to its notifier.
Future<bool> confirmDespiteConflicts(
  BuildContext context,
  ConflictCheckOutcome outcome,
) async {
  if (outcome is ConflictCheckClear) return true;
  if (!context.mounted) return false;
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AdminConflictDialog(outcome: outcome),
  );
  return answer ?? false;
}

/// The dialog itself: times and counts only, never a customer name. White,
/// with dark text.
class AdminConflictDialog extends StatelessWidget {
  const AdminConflictDialog({super.key, required this.outcome});

  final ConflictCheckOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final String title;
    final List<String> lines;
    switch (outcome) {
      case ConflictCheckClear():
        title = adminConflictTitle;
        lines = const [];
      case ConflictCheckFailed():
        title = adminConflictUncheckedTitle;
        lines = const [adminConflictUncheckedText];
      case final ConflictCheckWarning warning:
        final shown = conflictWarningLines(warning);
        title = shown.periods.isEmpty
            ? adminConflictPartlyTitle
            : adminConflictTitle;
        lines = [
          if (shown.periods.isNotEmpty) ...[
            adminConflictIntro(),
            for (final period in shown.periods) adminConflictPeriod(period),
            if (shown.more > 0) adminConflictMore(shown.more),
            adminTbilisiTimeNote,
          ],
          if (shown.unreadable > 0) adminConflictUnreadable(shown.unreadable),
          adminConflictQuestion,
        ];
    }

    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
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
            child: const Text(adminContinueAnyway),
          ),
        ],
      ),
    );
  }
}
