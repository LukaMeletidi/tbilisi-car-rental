import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_navigation.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';

/// The frame of the admin content: a side rail on wide screens, a bottom
/// bar on phones, and the page of the current section.
///
/// Which page shows the navigation is decided by adminShowsNavigation: never
/// on a form, so that a click cannot throw typed data away. The router puts
/// only admin content into this frame; the login, no-access, checking and
/// "not found" pages are outside it.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.navigationShell,
    required this.path,
  });

  /// The branches of the router; one per AdminSection, in its order.
  final StatefulNavigationShell navigationShell;

  /// The path of the current address.
  final String path;

  static const _destinations = [
    (icon: Icons.event_note, label: adminNavBookings),
    (icon: Icons.directions_car, label: adminNavCars),
  ];

  void _select(int index) {
    // Tapping the section that is shown returns to its first page.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = adminNavigationKind(MediaQuery.sizeOf(context).width);
    final show = adminShowsNavigation(path, kind);

    // Android's system Back on Cars goes to Bookings first. The decision is
    // in adminSystemBackTarget; with kIsWeb it is always null, so on the
    // web nothing is intercepted and the browser's Back follows its
    // history.
    final backTarget = adminSystemBackTarget(isWeb: kIsWeb, path: path);

    final Widget body;
    if (show && kind == AdminNavigationKind.rail) {
      body = Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              backgroundColor: appBackgroundColor,
              indicatorColor: Colors.white,
              selectedIconTheme: const IconThemeData(color: appBackgroundColor),
              unselectedIconTheme: const IconThemeData(color: Colors.white),
              selectedLabelTextStyle: const TextStyle(color: Colors.white),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.white24),
          Expanded(child: navigationShell),
        ],
      );
    } else {
      body = navigationShell;
    }

    return PopScope(
      canPop: backTarget == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && backTarget != null) {
          navigationShell.goBranch(backTarget.index);
        }
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: show && kind == AdminNavigationKind.bottomBar
            ? NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _select,
                backgroundColor: appBackgroundColor,
                indicatorColor: Colors.white,
                labelTextStyle: const WidgetStatePropertyAll(
                  TextStyle(color: Colors.white),
                ),
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon, color: Colors.white),
                      selectedIcon: Icon(
                        destination.icon,
                        color: appBackgroundColor,
                      ),
                      label: destination.label,
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
