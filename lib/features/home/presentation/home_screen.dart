import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_card_sections.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_hero.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_popular_cars.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_process_section.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/public_tab_app_bar.dart';

/// The Home tab of the public app (step 6b.6), one page scrolled down: the
/// hero, the popular cars, the rental process, the benefits, the conditions
/// and the traffic rules. Only the popular cars come from Firestore; all
/// other texts are in the ARB files and the photos are bundled.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PublicTabAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: homeMaxWidth),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHero(),
                    HomePopularCars(),
                    HomeProcessSection(),
                    HomeBenefitsSection(),
                    HomeConditionsSection(),
                    HomeTrafficSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
