import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/home/domain/public_navigation.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The frame of the four tab pages of the public app: the page of the
/// current tab and a bottom bar, at every width (never a rail).
///
/// The router puts only the tab pages into this frame. The car page, the
/// booking form, the thank-you page and the admin area lie above it, so
/// they never show the bar.
class PublicShell extends StatelessWidget {
  const PublicShell({
    super.key,
    required this.navigationShell,
    required this.path,
  });

  /// The branches of the router; one per PublicTab, in its order.
  final StatefulNavigationShell navigationShell;

  /// The path of the current address.
  final String path;

  void _select(int index) {
    // Tapping the tab that is shown returns to its first page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // One entry per PublicTab, in its order: Home, Cars, Contact, FAQ.
    final destinations = [
      (icon: Icons.home_outlined, label: l10n.tabHome),
      (icon: Icons.directions_car, label: l10n.tabCars),
      (icon: Icons.info_outline, label: l10n.tabContact),
      (icon: Icons.help_outline, label: l10n.tabFaq),
    ];

    // Android's system Back on Cars, Contact and FAQ goes to Home first.
    // With kIsWeb it is always null: on the web nothing is intercepted and
    // the browser's Back follows its history.
    final backTarget = publicSystemBackTarget(isWeb: kIsWeb, path: path);

    return PopScope(
      canPop: backTarget == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && backTarget != null) {
          navigationShell.goBranch(backTarget.index);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          backgroundColor: appBackgroundColor,
          indicatorColor: Colors.white,
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(color: Colors.white),
          ),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon, color: Colors.white),
                selectedIcon: Icon(destination.icon, color: appBackgroundColor),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
