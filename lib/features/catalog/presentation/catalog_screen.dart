import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_grid.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogCarsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: catalog.when(
          // Show the spinner again after "Try again" is pressed.
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => CatalogMessage(
            icon: Icons.cloud_off,
            text: l10n.catalogError,
            // The technical reason, for the developer only.
            detail: kDebugMode ? '$error' : null,
            action: FilledButton(
              onPressed: () => ref.invalidate(activeCarsProvider),
              child: Text(l10n.tryAgain),
            ),
          ),
          data: (result) => result.totalActive == 0
              ? CatalogMessage(
                  icon: Icons.directions_car,
                  text: l10n.catalogEmpty,
                )
              : CarGrid(cars: result.cars),
        ),
      ),
    );
  }
}
