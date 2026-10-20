import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/home/presentation/home_layout.dart';

/// A Home photo with rounded corners, inset by the gutter, behind [child].
/// The photo fills the whole area and is cropped as needed; it is
/// decorative, so screen readers skip it. The area is as tall as [child],
/// and at least [minHeight].
///
/// With [scrim] the whole photo is darkened, for white text anywhere on it.
class HomePhotoBackdrop extends StatelessWidget {
  const HomePhotoBackdrop({
    super.key,
    required this.image,
    required this.child,
    this.minHeight = 0,
    this.scrim = false,
  });

  final String image;
  final Widget child;
  final double minHeight;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: homeGutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(homeCornerRadius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Colors.black),
                ),
              ),
            ),
            if (scrim)
              const Positioned.fill(child: ColoredBox(color: homeScrimColor)),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// White text on a photo, on a dark band that fades into the photo on one
/// side: above the band for text at the bottom ([fadeAbove]), below it for
/// text at the top. Under the text itself the band is fully dark
/// ([homeScrimColor]).
class HomeScrimBand extends StatelessWidget {
  const HomeScrimBand({
    super.key,
    required this.child,
    required this.fadeAbove,
  });

  final Widget child;
  final bool fadeAbove;

  @override
  Widget build(BuildContext context) {
    final fade = SizedBox(
      height: homeScrimFade,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fadeAbove ? Alignment.topCenter : Alignment.bottomCenter,
            end: fadeAbove ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [Color(0x00000000), homeScrimColor],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fadeAbove) fade,
        ColoredBox(color: homeScrimColor, child: child),
        if (!fadeAbove) fade,
      ],
    );
  }
}
