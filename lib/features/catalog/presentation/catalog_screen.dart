import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_grid.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/filters_button.dart';
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
          data: (result) {
            if (result.totalActive == 0) {
              return CatalogMessage(
                icon: Icons.directions_car,
                text: l10n.catalogEmpty,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FiltersButton(),
                  ),
                ),
                Expanded(
                  child: result.cars.isEmpty
                      ? CatalogMessage(
                          icon: Icons.search_off,
                          text: l10n.catalogNoMatch,
                          action: FilledButton(
                            onPressed: () =>
                                ref.read(carFilterProvider.notifier).reset(),
                            child: Text(l10n.resetFilters),
                          ),
                        )
                      : CarGrid(cars: result.cars),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
