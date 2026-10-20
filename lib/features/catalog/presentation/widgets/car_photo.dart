import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/l10n/generated/app_localizations.dart';

/// Photos are decoded at this width in pixels, to save memory.
const _photoCacheWidth = 1200;

/// The first photo of a car in a 16:9 frame, or a placeholder.
class CarPhoto extends StatelessWidget {
  const CarPhoto({super.key, required this.photos, this.aspectRatio = 16 / 9});

  final List<String> photos;

  /// Width divided by height of the frame. Home uses 4:3 for its small cards.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: photos.isEmpty
          ? const _PhotoPlaceholder()
          : Image.network(
              photos.first,
              fit: BoxFit.cover,
              cacheWidth: _photoCacheWidth,
              // On web, some hosts refuse cross-site image loading. This lets
              // the browser show the picture in a plain image element instead.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const _PhotoPlaceholder(loading: true),
              errorBuilder: (context, error, stackTrace) =>
                  const _PhotoPlaceholder(),
            ),
    );
  }
}

/// A tinted box with a car icon, or with a spinner while a photo loads.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Icon(
                Icons.directions_car,
                size: 64,
                color: scheme.onSurfaceVariant,
                semanticLabel: AppLocalizations.of(context).noPhoto,
              ),
      ),
    );
  }
}
