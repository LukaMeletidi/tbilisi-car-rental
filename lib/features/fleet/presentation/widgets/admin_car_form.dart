import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_fields.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_hide_car_dialog.dart';

/// The edit form of a car: its title, the repair note, the "changed
/// elsewhere" banner, the fields (AdminCarFields), the notices and the
/// Save button.
///
/// The draft in the notifier is the single source of truth. When the
/// notifier itself replaces the fields ("Load the current car", a change
/// elsewhere while the form has no changes), the screen builds this widget
/// anew with a key made from [AdminCarEditState.formVersion], and with it
/// the fields and their text controllers.
///
/// [state] must be in the "editing" status.
class AdminCarForm extends ConsumerWidget {
  const AdminCarForm({super.key, required this.carId, required this.state});

  final String carId;
  final AdminCarEditState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminCarEditProvider(carId);
    final notifier = ref.read(provider.notifier);
    final draft = state.draft!;
    final enabled = !state.saving && !state.locked;
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final showBanner =
        state.changedElsewhere &&
        notice != CarSaveNotice.changedElsewhere &&
        !state.locked;

    /// Changes the draft. The newest draft is read from the notifier, so
    /// two changes in the same moment do not undo each other.
    void change(CarDraft Function(CarDraft draft) update) {
      final current = ref.read(provider).draft;
      if (current != null) notifier.setDraft(update(current));
    }

    /// Save, or "Save again" after "No answer". A save that hides the car
    /// asks first, after the check of the bookings ahead (in the notifier);
    /// "Save again" does not ask again: the fields are locked then, so the
    /// notifier does not ask.
    Future<void> save({bool again = false}) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await notifier.save(
        // The dialog; "Cancel" when the form is gone.
        decideHide: (outcome) => context.mounted
            ? confirmHideCar(context, outcome)
            : Future.value(false),
      );
    }

    Widget noticeView(CarSaveNotice notice) {
      final text = adminCarSaveNoticeText(notice);
      switch (notice) {
        case CarSaveNotice.noAnswer:
          return AdminCarMessage(
            icon: Icons.help_outline,
            text: text,
            buttons: [
              FilledButton(
                onPressed: () => save(again: true),
                child: const Text(adminSaveAgain),
              ),
              OutlinedButton(
                onPressed: notifier.loadCurrent,
                child: const Text(adminLoadCurrentCar),
              ),
            ],
          );
        case CarSaveNotice.changedElsewhere:
          return AdminCarMessage(
            icon: Icons.sync_problem,
            text: text,
            buttons: [
              OutlinedButton(
                onPressed: notifier.dismissNotice,
                child: const Text(adminKeepEditing),
              ),
              FilledButton(
                onPressed: notifier.loadCurrent,
                child: const Text(adminLoadCurrentCar),
              ),
            ],
          );
        case CarSaveNotice.saved:
        case CarSaveNotice.noConnection:
        case CarSaveNotice.refused:
        case CarSaveNotice.carMissing:
        case CarSaveNotice.unknown:
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdminNote(icon: Icons.error_outline, text: text),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: adminDismissNotice,
                onPressed: notifier.dismissNotice,
              ),
            ],
          );
      }
    }

    const gap = SizedBox(height: 12);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(adminCarEditTitle, style: textTheme.headlineSmall),
              ),
              if (state.needsRepair)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: AdminNote(
                    icon: Icons.build_outlined,
                    text: adminCarRepairNote,
                  ),
                ),
              if (showBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: AdminCarMessage(
                    icon: Icons.sync_problem,
                    text: adminCarChangedElsewhereBanner,
                    buttons: [
                      FilledButton(
                        onPressed: state.saving ? null : notifier.loadCurrent,
                        child: const Text(adminLoadCurrentCar),
                      ),
                    ],
                  ),
                ),
              AdminCarFields(
                draft: draft,
                validation: state.validation,
                showErrors: state.showErrors,
                enabled: enabled,
                onChanged: change,
                visibilityNote: adminHiddenCarNote,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.saving) ...[
                      AdminCarSaving(
                        text: state.checking ? adminChecking : adminSaving,
                      ),
                      gap,
                    ],
                    if (notice != null && !state.saving) ...[
                      noticeView(notice),
                      gap,
                    ],
                    if (state.showErrors &&
                        state.validation.hasErrors &&
                        !state.saving) ...[
                      const AdminNote(
                        icon: Icons.error_outline,
                        text: adminCorrectFields,
                      ),
                      gap,
                    ],
                    if (!state.locked)
                      FilledButton(
                        // Disabled while nothing changed (unless the car
                        // needs repair) and while a save runs.
                        onPressed: state.canSave ? save : null,
                        child: const Text(adminSave),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
