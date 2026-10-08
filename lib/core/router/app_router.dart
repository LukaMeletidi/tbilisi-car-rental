import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';

/// Route paths in one place, so screens never hard-code URL strings.
abstract final class AppRoutes {
  static const home = '/';

  /// Path pattern of the car detail screen, below [home].
  static const carPattern = 'cars/:carId';

  /// The address of one car, for example "/cars/abc123".
  static String car(String carId) => '/cars/${Uri.encodeComponent(carId)}';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const CatalogScreen(),
        routes: [
          GoRoute(
            path: AppRoutes.carPattern,
            builder: (context, state) =>
                CarDetailScreen(carId: state.pathParameters['carId']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
