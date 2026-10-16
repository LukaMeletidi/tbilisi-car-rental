import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_car_visibility_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_card.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_hide_car_dialog.dart';

/// The Cars section of the admin area: every car, also the hidden ones,
/// live and read only. The router shows it only to an admin, and the
/// Firestore rules give every car only to an admin.
class AdminCarsScreen extends ConsumerWidget {
  const AdminCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCarsProvider);
    final notifier = ref.read(adminCarsProvider.notifier);

    // Each finished hide or show is told once, in a SnackBar.
    ref.listen(adminCarVisibilityProvider, (previous, next) {
      final notice = next.notice;
      if (notice == null) return;
      if (previous != null && previous.noticeCount == next.noticeCount) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(adminCarActiveNoticeText(notice))),
        );
    });

    final Widget body;
    switch (state.status) {
      case AdminCarsStatus.inactive:
      case AdminCarsStatus.loading:
        body = const Center(child: CircularProgressIndicator());
      case AdminCarsStatus.failed:
        final failure = state.failure ?? FleetLoadFailure.other;
        body = CatalogMessage(
          icon: failure == FleetLoadFailure.permissionDenied
              ? Icons.lock_outline
              : Icons.cloud_off,
          text: adminCarsFailureText(failure),
          action: FilledButton(
            onPressed: notifier.retry,
            child: const Text(adminTryAgain),
          ),
        );
      case AdminCarsStatus.ready:
        body = state.entries.isEmpty
            ? const CatalogMessage(
                icon: Icons.directions_car,
                text: adminNoCars,
                action: _AddCarButton(),
              )
            : _CarsList(state: state);
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        automaticallyImplyLeading: false,
        title: const AppBarLogo(),
        actions: const [AdminSignOutButton()],
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Opens the "new car" form.
class _AddCarButton extends StatelessWidget {
  const _AddCarButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => context.go(AppRoutes.adminCarNew),
      icon: const Icon(Icons.add),
      label: const Text(adminAddCar),
    );
  }
}

class _CarsList extends ConsumerWidget {
  const _CarsList({required this.state});

  final AdminCarsState state;

  /// Hides after the check and "Hide this car?"; shows at once.
  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    FleetCarEntry entry,
  ) async {
    final notifier = ref.read(adminCarVisibilityProvider.notifier);
    if (!entry.car.active) {
      await notifier.setActive(entry.id, active: true);
      return;
    }
    await notifier.hide(
      entry.id,
      // The dialog; "Cancel" when this list is gone.
      decide: (outcome) => context.mounted
          ? confirmHideCar(context, outcome)
          : Future.value(false),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final visibility = ref.watch(adminCarVisibilityProvider);
    final busy = visibility.busy;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: carDetailMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adminCarsTitle, style: textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(adminFleetCounts(state.counts)),
                  if (state.showOfflineNote) ...[
                    const SizedBox(height: 8),
                    const AdminNote(
                      icon: Icons.cloud_off,
                      text: adminOfflineNote,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _AddCarButton(),
                ],
              ),
            ),
            for (final entry in state.entries)
              switch (entry) {
                final FleetCarEntry car => AdminCarCard(
                  entry: car,
                  busy: busy.contains(car.id),
                  checking: visibility.checking.contains(car.id),
                  onOpen: () => context.go(AppRoutes.adminCarEdit(car.id)),
                  onToggleActive: () => _toggle(context, ref, car),
                ),
                FleetUnreadableEntry() => AdminCarCard(entry: entry),
              },
          ],
        ),
      ),
    );
  }
}
