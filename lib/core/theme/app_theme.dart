import 'package:flutter/material.dart';

/// The purple of the page background and the app bar.
const appBackgroundColor = Color(0xFF673AB7);

/// The dark-on-white theme used inside white cards and text fields.
/// It is stored in the page theme so that the OnWhite widget can find it.
class PanelTheme extends ThemeExtension<PanelTheme> {
  const PanelTheme(this.data);

  final ThemeData data;

  @override
  PanelTheme copyWith({ThemeData? data}) => PanelTheme(data ?? this.data);

  @override
  PanelTheme lerp(PanelTheme? other, double t) => this;
}

/// Builds the app theme: a purple page and app bar with white text, and white
/// buttons with purple text.
///
/// Material calls this a "dark" scheme because its text is light. The app
/// still has one fixed theme; this is not a dark mode.
ThemeData buildAppTheme() {
  const white = Colors.white;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: appBackgroundColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: appBackgroundColor,
        onSurface: white,
        onSurfaceVariant: white,
        surfaceContainerLowest: appBackgroundColor,
        surfaceContainerLow: _lighten(appBackgroundColor, 0.06),
        surfaceContainer: _lighten(appBackgroundColor, 0.09),
        surfaceContainerHigh: _lighten(appBackgroundColor, 0.12),
        surfaceContainerHighest: _lighten(appBackgroundColor, 0.15),
        surfaceTint: Colors.transparent,
        primary: white,
        onPrimary: appBackgroundColor,
        secondaryContainer: white,
        onSecondaryContainer: appBackgroundColor,
        outline: white,
        outlineVariant: white.withValues(alpha: 0.6),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: appBackgroundColor,
    appBarTheme: const AppBarThemeData(
      backgroundColor: appBackgroundColor,
      foregroundColor: white,
      scrolledUnderElevation: 0,
    ),
    extensions: [PanelTheme(_buildPanelTheme())],
  );
}

/// White surfaces with dark text; purple for accents such as a price.
ThemeData _buildPanelTheme() {
  const white = Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: appBackgroundColor,
  ).copyWith(surface: white, primary: appBackgroundColor, onPrimary: white);

  return ThemeData(
    colorScheme: scheme,
    cardTheme: const CardThemeData(color: white),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Color _lighten(Color color, double amount) =>
    Color.alphaBlend(Colors.white.withValues(alpha: amount), color);
