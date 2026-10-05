import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/widgets/placeholder_home_page.dart';

/// Route paths in one place, so screens never hard-code URL strings.
abstract final class AppRoutes {
  static const home = '/';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PlaceholderHomePage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
