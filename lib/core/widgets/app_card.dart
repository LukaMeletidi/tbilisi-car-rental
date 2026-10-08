import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';

/// Switches its child to dark text on white. Use it around anything that sits
/// on a white area; text placed there without it would be white on white.
class OnWhite extends StatelessWidget {
  const OnWhite({super.key, this.inCard = false, required this.child});

  /// True for the inside of a white card: text fields then get an outline,
  /// because a white field cannot be seen on a white card.
  final bool inCard;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).extension<PanelTheme>();
    if (panel == null) return child;
    return Theme(data: inCard ? panel.cardData : panel.data, child: child);
  }
}

/// A white card on the purple page. Text inside it is dark, and text fields
/// inside it have an outline.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, the whole card can be tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return OnWhite(
      inCard: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
