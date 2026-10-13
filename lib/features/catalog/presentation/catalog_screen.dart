import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/data/load_error_log.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_bar_logo.dart';
import 'package:tbilisi_car_rental/core/widgets/language_menu_button.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_filter_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_search_provider.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/cars_providers.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_grid.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_message.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/catalog_search_field.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/filters_button.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogCarsProvider);
    // For the developer: the type of the error, once per failure. The
    // screen shows only the translated text.
    ref.listen(activeCarsProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        logLoadError('The cars', next.error!);
      }
    });
    final hasFilters = ref.watch(
      carFilterProvider.select((filter) => filter.activeCount > 0),
    );
    final hasSearch = ref.watch(
      carSearchProvider.select((query) => query.trim().isNotEmpty),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarLogoToolbarHeight,
        title: const _LogoWithAdminEntry(),
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
            // Only a search is active: say "search", not "filters".
            final searchOnly = hasSearch && !hasFilters;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  // The button is stretched to the height of the search field.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: const CatalogSearchField(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const FiltersButton(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: result.cars.isEmpty
                      ? CatalogMessage(
                          icon: Icons.search_off,
                          text: searchOnly
                              ? l10n.catalogNoSearchMatch
                              : l10n.catalogNoMatch,
                          action: FilledButton(
                            onPressed: () {
                              ref.read(carFilterProvider.notifier).reset();
                              ref.read(carSearchProvider.notifier).clear();
                            },
                            child: Text(
                              searchOnly ? l10n.clearSearch : l10n.resetFilters,
                            ),
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

/// The logo of the catalog app bar. A long press on it opens the admin
/// sign-in page: the only way into the admin area on a phone, where no
/// address can be typed.
///
/// It gives no hint to the public: no tooltip, no ripple, no hand cursor,
/// and nothing extra for screen readers, which still read only the app
/// name. A normal tap does nothing.
class _LogoWithAdminEntry extends StatelessWidget {
  const _LogoWithAdminEntry();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Flutter's standard long press: about half a second.
      onLongPress: () => context.go(AppRoutes.adminLogin),
      // Without this, a screen reader would announce a long-press action.
      excludeFromSemantics: true,
      child: const AppBarLogo(),
    );
  }
}
