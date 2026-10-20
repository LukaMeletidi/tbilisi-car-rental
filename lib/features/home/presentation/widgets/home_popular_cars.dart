import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/car_limits.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_popular_provider.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_section_title.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The key of the photo card of the car [carId], for tests.
ValueKey<String> homePopularCarKey(String carId) =>
    ValueKey('home-popular-$carId');

/// "The most popular cars": up to 3 photo cards in one centered row. A tap
/// opens the car page on top of Home, so Back returns here. Hidden when no
/// visible car is marked, while the cars load and when they cannot be
/// loaded.
class HomePopularCars extends ConsumerWidget {
  const HomePopularCars({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(homePopularCarsProvider);
    if (cars.isEmpty) return const SizedBox.shrink();

    const gap = 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(AppLocalizations.of(context).homeTopCarsTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: homeGutter),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A card is always a third of the row, so it has the same size
              // with one, two or three cars. Three fill the row; one or two
              // stand in the middle.
              final width =
                  (constraints.maxWidth - gap * (homePopularMax - 1)) /
                  homePopularMax;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, car) in cars.indexed) ...[
                    if (index > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: width,
                      child: _PhotoCard(car: car),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The photo of one car, without text. Without a photo, or when it fails,
/// the catalog's placeholder shows: a grey box with a car icon (a spinner
/// while the photo loads). Screen readers read the brand and the model.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    void open() => context.push(AppRoutes.car(car.id));

    return Semantics(
      container: true,
      button: true,
      label: '${car.brand} ${car.model}',
      onTap: open,
      excludeSemantics: true,
      child: AppCard(
        key: homePopularCarKey(car.id),
        padding: EdgeInsets.zero,
        onTap: open,
        child: CarPhoto(photos: car.photos, aspectRatio: 4 / 3),
      ),
    );
  }
}
