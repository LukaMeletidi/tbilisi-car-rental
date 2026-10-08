import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo.dart';
import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// All photos of a car in a 16:9 frame. With two or more photos the user can
/// swipe between them, and dots show the position. With one photo or none it
/// looks exactly like the photo on a catalog card.
class CarPhotoGallery extends StatefulWidget {
  const CarPhotoGallery({super.key, required this.photos});

  final List<String> photos;

  @override
  State<CarPhotoGallery> createState() => _CarPhotoGalleryState();
}

class _CarPhotoGalleryState extends State<CarPhotoGallery> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.length < 2) return CarPhoto(photos: photos);

    final l10n = AppLocalizations.of(context);
    // The photo count can shrink while the screen is open.
    final page = _page < photos.length ? _page : photos.length - 1;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // On web, also allow dragging the photos with a mouse.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) =>
                  CarPhoto(photos: [photos[index]]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: _PageDots(
                count: photos.length,
                current: page,
                label: l10n.photoPosition(page + 1, photos.length),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dots on a dark pill, one per photo; the current one is brighter.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: i == current ? 1 : 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
