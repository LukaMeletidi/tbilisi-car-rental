import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/catalog_layout.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_card.dart';

const _gap = 12.0;

/// The cars as one column on a phone, or as a grid on a wide screen.
class CarGrid extends StatelessWidget {
  const CarGrid({super.key, required this.cars});

  final List<Car> cars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = catalogColumnCount(constraints.maxWidth);

        if (columns == 1) {
          return ListView.separated(
            padding: const EdgeInsets.all(_gap),
            itemCount: cars.length,
            separatorBuilder: (context, index) => const SizedBox(height: _gap),
            itemBuilder: (context, index) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: catalogSingleColumnMaxWidth,
                ),
                child: CarCard(
                  key: ValueKey(cars[index].id),
                  car: cars[index],
                  onTap: () => context.go(AppRoutes.car(cars[index].id)),
                ),
              ),
            ),
          );
        }

        final cardWidth =
            ((constraints.maxWidth - _gap * (columns + 1)) / columns)
                .floorToDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_gap),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final car in cars)
                SizedBox(
                  width: cardWidth,
                  child: CarCard(
                    key: ValueKey(car.id),
                    car: car,
                    onTap: () => context.go(AppRoutes.car(car.id)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
