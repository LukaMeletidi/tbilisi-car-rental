import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/widgets/app_card.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/catalog/presentation/widgets/car_photo.dart';
import 'package:tbilisi_car_rental/features/fleet/domain/fleet_list.dart';

/// The side of the square photo of a car in the fleet list.
const adminCarPhotoSize = 88.0;

/// One row of the fleet list: a white card. A readable car shows its first
/// photo (or the placeholder), "Brand Model", the year, the price per day,
/// its badges and a Hide or Show button; a tap opens its edit form. An
/// unreadable document shows only a warning and its shortened ID, and
/// cannot be tapped.
class AdminCarCard extends StatelessWidget {
  const AdminCarCard({
    super.key,
    required this.entry,
    this.onOpen,
    this.onToggleActive,
    this.busy = false,
    this.checking = false,
  });

  final FleetEntry entry;

  /// Opens the edit form. Not used for an unreadable document.
  final VoidCallback? onOpen;

  /// Hides a visible car or shows a hidden one.
  final VoidCallback? onToggleActive;

  /// True while a hide or show of this car runs.
  final bool busy;

  /// True while the bookings of this car are read before hiding: the
  /// spinner says "Checking…".
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final FleetCarEntry car => AppCard(
        onTap: busy ? null : onOpen,
        child: _CarContent(
          entry: car,
          onToggleActive: busy ? null : onToggleActive,
          busy: busy,
          checking: checking,
        ),
      ),
      final FleetUnreadableEntry unreadable => AppCard(
        child: _UnreadableContent(id: unreadable.id),
      ),
    };
  }
}

/// Built inside the white card, so Theme.of(context) is the dark-on-white one.
class _CarContent extends StatelessWidget {
  const _CarContent({
    required this.entry,
    required this.onToggleActive,
    required this.busy,
    required this.checking,
  });

  final FleetCarEntry entry;
  final VoidCallback? onToggleActive;
  final bool busy;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final car = entry.car;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The tight square overrides the 16:9 frame of CarPhoto; the photo
        // is cropped to fill it.
        SizedBox.square(
          dimension: adminCarPhotoSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CarPhoto(photos: car.photos),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${car.brand} ${car.model}', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(adminCarYear(car.year)),
              Text(adminCarPrice(car.pricePerDay)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  car.active
                      ? const AdminCarBadge(
                          text: adminCarBadgeVisible,
                          color: Color(0xFF2E7D32), // green
                        )
                      : const AdminCarBadge(
                          text: adminCarBadgeHidden,
                          color: Color(0xFF616161), // neutral grey
                        ),
                  if (entry.needsRepair)
                    const AdminCarBadge(
                      text: adminCarNeedsRepair,
                      color: Color(0xFF8A5A00), // amber, dark enough
                    ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            if (checking) ...[
                              const SizedBox(width: 8),
                              const Text(adminChecking),
                            ],
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: onToggleActive,
                        child: Text(car.active ? adminCarHide : adminCarShow),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnreadableContent extends StatelessWidget {
  const _UnreadableContent({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(Icons.warning_amber, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(adminCarUnreadable, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(adminCarIdText(shortCarId(id))),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small coloured label with white text, as the status chips of the
/// bookings.
class AdminCarBadge extends StatelessWidget {
  const AdminCarBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
