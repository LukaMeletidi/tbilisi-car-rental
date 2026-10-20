import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tbilisi_car_rental/core/router/app_router.dart';
import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';
import 'package:tbilisi_car_rental/features/home/presentation/widgets/home_photo_backdrop.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// The key of the hero, for tests.
const homeHeroKey = ValueKey('home-hero');

/// The top of Home: the hero photo with the large title and the subtitle at
/// the bottom left, white on a dark band. One button for screen readers,
/// named by the title; a tap anywhere opens the catalog (the Cars tab).
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    void open() => context.go(AppRoutes.cars);

    return Semantics(
      key: homeHeroKey,
      container: true,
      button: true,
      label: l10n.homeHeroTitle,
      onTap: open,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final photoWidth = constraints.maxWidth - 2 * homeGutter;
          return HomePhotoBackdrop(
            image: homeHeroImage,
            minHeight: photoWidth / homeHeroImageAspectRatio,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // As tall as the photo at its own shape, or taller when the
                // text needs it; the text stands at the bottom.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeScrimBand(
                      fadeAbove: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.homeHeroTitle,
                              style: textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.homeHeroSubtitle,
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: open),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
