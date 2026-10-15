import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_note.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/widgets/admin_sign_out_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/admin_cars_provider.dart';
import 'package:tbilisi_car_rental/features/fleet/presentation/widgets/admin_car_card.dart';

/// The Cars section of the admin area: every car, also the hidden ones,
/// live and read only. The router shows it only to an admin, and the
/// Firestore rules give every car only to an admin.
class AdminCarsScreen extends ConsumerWidget {
  const AdminCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCarsProvider);
    final notifier = ref.read(adminCarsProvider.notifier);

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

class _CarsList extends StatelessWidget {
  const _CarsList({required this.state});

  final AdminCarsState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                ],
              ),
            ),
            for (final entry in state.entries) AdminCarCard(entry: entry),
          ],
        ),
      ),
    );
  }
}
