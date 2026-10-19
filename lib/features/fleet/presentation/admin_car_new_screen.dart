import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_draft.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_new.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_new_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_fields.dart';

/// The "new car" form of the admin area. The router shows it only to an
/// admin, and the Firestore rules accept the create only from an admin.
///
/// It lies below the fleet list: Back returns to the list, and so does a
/// successful save, with "Saved". The new car is hidden unless the admin
/// turned the switch on.
class AdminCarNewScreen extends ConsumerWidget {
  const AdminCarNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCarNewProvider);
    final notifier = ref.read(adminCarNewProvider.notifier);

    void toList() => context.go(AppRoutes.adminCars);

    // After the server confirmed the car: "Saved", and back to the list.
    ref.listen(adminCarNewProvider, (previous, next) {
      if (!next.created || (previous?.created ?? false)) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              next.draft.active
                  ? adminNewCarSavedVisible
                  : adminNewCarSavedHidden,
            ),
          ),
        );
      toList();
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save runs; with something to lose the admin is asked first.
    Future<void> back() async {
      final current = ref.read(adminCarNewProvider);
      if (current.saving) return;
      if (!current.hasSomethingToLose) {
        toList();
        return;
      }
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _LeaveDialog(mayAlreadyExist: current.mayAlreadyExist),
      );
      if (leave == true && context.mounted) toList();
    }

    return PopScope(
      // The system may close the page by itself only when nothing would be
      // lost. Otherwise it asks here first.
      canPop: !state.hasSomethingToLose && !state.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          leading: BackButton(onPressed: back),
          title: const AppBarLogo(),
        ),
        body: SafeArea(
          child: state.carId == null
              ? const Center(child: CircularProgressIndicator())
              : _NewCarForm(state: state, notifier: notifier),
        ),
      ),
    );
  }
}

class _NewCarForm extends ConsumerWidget {
  const _NewCarForm({required this.state, required this.notifier});

  final AdminCarNewState state;
  final AdminCarNewNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final notice = state.notice;
    final locked = state.mayAlreadyExist || state.created;
    // For the soft warning of "Popular": from the admin list already in
    // memory (the form lies below it); never a read of its own.
    final otherVisiblePopular = ref.exists(adminCarsProvider)
        ? ref.watch(
            adminCarsProvider.select(
              (list) => otherVisiblePopularCount(list.entries),
            ),
          )
        : 0;

    /// Applied to the newest draft of the notifier, so two changes in the
    /// same moment do not undo each other.
    void change(CarDraft Function(CarDraft draft) update) =>
        notifier.setDraft(update(ref.read(adminCarNewProvider).draft));

    Future<void> save() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await notifier.save();
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
                child: Text(adminNewCarTitle, style: textTheme.headlineSmall),
              ),
              AdminCarFields(
                draft: state.draft,
                validation: state.validation,
                showErrors: state.showErrors,
                enabled: !state.saving && !locked,
                onChanged: change,
                visibilityNote: adminNewCarVisibilityNote,
                otherVisiblePopular: otherVisiblePopular,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.saving) ...[
                      AdminCarSaving(
                        text: state.mayAlreadyExist
                            ? adminChecking
                            : adminSaving,
                      ),
                      gap,
                    ],
                    if (notice != null &&
                        notice != CarCreateNotice.saved &&
                        !state.saving) ...[
                      if (state.mayAlreadyExist)
                        AdminCarMessage(
                          icon: Icons.help_outline,
                          text: adminCarCreateNoticeText(notice),
                          buttons: [
                            FilledButton(
                              onPressed: state.canCheckAgain
                                  ? notifier.checkAgain
                                  : null,
                              child: const Text(adminCheckAgain),
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AdminNote(
                                icon: Icons.error_outline,
                                text: adminCarCreateNoticeText(notice),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: adminDismissNotice,
                              onPressed: notifier.dismissNotice,
                            ),
                          ],
                        ),
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
                    // After an uncertain attempt the only way on is "Check
                    // again", with the same ID and the same values.
                    if (!locked)
                      FilledButton(
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

/// Usually "Discard your changes?". After an uncertain attempt the car may
/// already exist, so the words are stronger: "Leave this form?". White,
/// with dark text.
class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({required this.mayAlreadyExist});

  final bool mayAlreadyExist;

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(mayAlreadyExist ? adminLeaveTitle : adminDiscardTitle),
        content: mayAlreadyExist ? const Text(adminCarMayExistText) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(mayAlreadyExist ? adminStay : adminKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(mayAlreadyExist ? adminLeave : adminDiscard),
          ),
        ],
      ),
    );
  }
}
