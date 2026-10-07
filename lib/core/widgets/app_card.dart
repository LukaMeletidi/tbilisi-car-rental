import 'package:flutter/material.dart';

import 'package:tbilisi_car_rental/core/theme/app_theme.dart';

/// Switches its child to dark text on white. Use it around anything that sits
/// on a white area; text placed there without it would be white on white.
class OnWhite extends StatelessWidget {
  const OnWhite({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).extension<PanelTheme>();
    if (panel == null) return child;
    return Theme(data: panel.data, child: child);
  }
}

/// A white card on the purple page. Text inside it is dark.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return OnWhite(
      child: Card(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
