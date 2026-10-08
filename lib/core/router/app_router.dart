import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/features/booking/presentation/booking_form_screen.dart';
import 'package:tbilisi_car_rental/features/booking/presentation/booking_sent_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/car_detail_screen.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_screen.dart';

/// Route paths in one place, so screens never hard-code URL strings.
abstract final class AppRoutes {
  static const home = '/';

  /// Path pattern of the car detail screen, below [home].
  static const carPattern = 'cars/:carId';

  /// The address of one car, for example "/cars/abc123".
  static String car(String carId) => '/cars/${Uri.encodeComponent(carId)}';

  /// Path pattern of the booking form, below the car detail screen.
  static const bookingPattern = 'book';

  /// The address of the booking form of one car: "/cars/abc123/book".
  static String booking(String carId) => '${car(carId)}/$bookingPattern';

  /// Path pattern of the thank-you screen, below [home].
  static const bookingSentPattern = 'booking-sent';

  /// The address of the thank-you screen shown after a request was sent.
  static const bookingSent = '/$bookingSentPattern';
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
            routes: [
              // Below the car, so Back returns to the car.
              GoRoute(
                path: AppRoutes.bookingPattern,
                builder: (context, state) =>
                    BookingFormScreen(carId: state.pathParameters['carId']!),
              ),
            ],
          ),
          // Below the catalog, so Back leads to the catalog and never back
          // into the form.
          GoRoute(
            path: AppRoutes.bookingSentPattern,
            builder: (context, state) => const BookingSentScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
