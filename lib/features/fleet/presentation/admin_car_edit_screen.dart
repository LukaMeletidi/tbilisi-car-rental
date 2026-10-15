import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_edit.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_edit_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_form.dart';

/// The edit form of one car of the admin area. The router shows it only to
/// an admin, and the Firestore rules accept the write only from an admin.
///
/// It lies below the fleet list: Back returns to the list, and so does a
/// successful save, with "Saved".
class AdminCarEditScreen extends ConsumerWidget {
  const AdminCarEditScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminCarEditProvider(carId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    void toList() => context.go(AppRoutes.adminCars);

    // After the server confirmed the save: "Saved", and back to the list.
    ref.listen(provider, (previous, next) {
      if (next.notice != CarSaveNotice.saved) return;
      if (previous?.notice == CarSaveNotice.saved) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(adminCarSaved)));
      toList();
    });

    /// Back, by the arrow of the app bar or by the system: blocked while a
    /// save is running; with unsaved changes the admin is asked first.
    Future<void> back() async {
      final current = ref.read(provider);
      if (current.saving) return;
      if (!current.isDirty) {
        toList();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => const _DiscardDialog(),
      );
      if (discard == true && context.mounted) toList();
    }

    final backToCars = FilledButton(
      onPressed: toList,
      child: const Text(adminBackToCars),
    );

    final Widget body;
    switch (state.status) {
      case AdminCarEditStatus.inactive:
      case AdminCarEditStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminCarEditStatus.missing:
        body = CatalogMessage(
          icon: Icons.search_off,
          text: adminCarMissing,
          action: backToCars,
        );
      case AdminCarEditStatus.unreadable:
        body = CatalogMessage(
          icon: Icons.warning_amber,
          text: adminCarUnreadableText,
          action: backToCars,
        );
      case AdminCarEditStatus.failed:
        final failure = state.failure ?? FleetLoadFailure.other;
        body = CatalogMessage(
          icon: failure == FleetLoadFailure.permissionDenied
              ? Icons.lock_outline
              : Icons.cloud_off,
          text: adminCarFailureText(failure),
          action: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: notifier.retry,
                child: const Text(adminTryAgain),
              ),
              backToCars,
            ],
          ),
        );
      case AdminCarEditStatus.editing:
        body = state.base == null || state.draft == null
            ? const Center(child: CircularProgressIndicator())
            // A new version of the form gets a new key: the old text
            // controllers are disposed and new ones made from the draft.
            : AdminCarForm(
                key: ValueKey(state.formVersion),
                carId: carId,
                state: state,
              );
    }

    return PopScope(
      // The system may close the page by itself only when nothing would be
      // lost. Otherwise it asks here first.
      canPop: !state.isDirty && !state.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: appBarLogoToolbarHeight,
          leading: BackButton(onPressed: back),
          title: const AppBarLogo(),
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

/// "Discard your changes?" before the form is left with unsaved changes.
/// White, with dark text.
class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog();

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(adminDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(adminKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(adminDiscard),
          ),
        ],
      ),
    );
  }
}
