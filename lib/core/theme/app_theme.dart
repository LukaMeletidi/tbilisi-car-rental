import 'package:flutter/material.dart';

/// The purple of the page background and the app bar.
const appBackgroundColor = Color(0xFF673AB7);

/// The outline of a text field inside a white card.
const panelFieldOutlineColor = Color(0xFF8A8A8A);

/// The dark-on-white themes used on white areas. They are stored in the page
/// theme so that the OnWhite widget can find them.
class PanelTheme extends ThemeExtension<PanelTheme> {
  const PanelTheme(this.data, {required this.cardData});

  /// For a white area directly on the purple page, such as the search field.
  /// A text field has no outline; the purple around it is its edge.
  final ThemeData data;

  /// For the inside of a white card. A text field there would be white on
  /// white, so it gets a thin grey outline: purple when focused, red on
  /// error.
  final ThemeData cardData;

  @override
  PanelTheme copyWith({ThemeData? data, ThemeData? cardData}) =>
      PanelTheme(data ?? this.data, cardData: cardData ?? this.cardData);

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
    extensions: [
      PanelTheme(
        _buildPanelTheme(outlinedFields: false),
        cardData: _buildPanelTheme(outlinedFields: true),
      ),
    ],
  );
}

/// White surfaces with dark text; purple for accents such as a price.
/// With [outlinedFields] a text field gets an outline (see [PanelTheme]).
ThemeData _buildPanelTheme({required bool outlinedFields}) {
  const white = Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: appBackgroundColor,
  ).copyWith(surface: white, primary: appBackgroundColor, onPrimary: white);

  OutlineInputBorder outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    colorScheme: scheme,
    cardTheme: const CardThemeData(color: white),
    inputDecorationTheme: outlinedFields
        ? InputDecorationThemeData(
            filled: true,
            fillColor: white,
            // A long error text wraps instead of being cut off.
            errorMaxLines: 3,
            helperMaxLines: 2,
            border: outline(panelFieldOutlineColor),
            enabledBorder: outline(panelFieldOutlineColor),
            disabledBorder: outline(
              panelFieldOutlineColor.withValues(alpha: 0.4),
            ),
            focusedBorder: outline(appBackgroundColor, width: 2),
            errorBorder: outline(scheme.error),
            focusedErrorBorder: outline(scheme.error, width: 2),
          )
        : InputDecorationThemeData(
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
