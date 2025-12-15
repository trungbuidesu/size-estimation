import 'package:flutter/material.dart';

class AppTheme {
  // Atlassian Design System - Dark Mode Palette
  static const Color _primaryColor =
      Color(0xFF579DFF); // Blue 400 (High contrast blue)
  static const Color _surfaceColor = Color(0xFF22272B); // Elevation Surface
  static const Color _backgroundColor = Color(0xFF1D2125); // Base Background
  static const Color _onSurfaceColor = Color(0xFFDCDFE4); // Main Text
  static const Color _onBackgroundSecondary =
      Color(0xFF8590A2); // Secondary Text
  static const Color _borderColor = Color(0xFF2C333A); // Subtle Border

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _backgroundColor,

      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _primaryColor,
        surface: _surfaceColor,
        background: _backgroundColor,
        onSurface: _onSurfaceColor,
        onPrimary: Color(0xFF1D2125), // Dark text on bright blue button
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceColor,
        elevation: 0, // Flat design with border usually prefered
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Subtle rounding
          side: const BorderSide(color: _borderColor, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: _onSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: _onSurfaceColor,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: _borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle:
            false, // Professional tools often align left, but center is safe
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: _onSurfaceColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _onSurfaceColor),
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: const Color(0xFF1D2125), // Contrast text
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3), // Tighter radius
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12), // Compact
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurfaceColor,
          side: const BorderSide(color: _borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: Colors.transparent,
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: _onBackgroundSecondary, // Slightly muted icons usually
        size: 20, // Smaller, more precise icons
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: _borderColor,
        space: 1,
        thickness: 1,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _backgroundColor, // Input often darker than surface
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Compact
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: _onBackgroundSecondary),
        hintStyle: TextStyle(color: _onBackgroundSecondary.withOpacity(0.5)),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryColor,
        inactiveTrackColor: _borderColor,
        thumbColor: Colors.white,
        trackHeight: 4,
        overlayColor: _primaryColor.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
    );
  }

  // Atlassian Design System - Light Mode Palette (Tokens)
  static const Color _surfaceDefaultLight =
      Color(0xFFFFFFFF); // color.background.default (Page/Main Surface)
  static const Color _surfaceNeutralLight =
      Color(0xFFF1F2F4); // color.background.neutral (Cards, Inputs, Sidebar)
  static const Color _onSurfacePrimaryLight =
      Color(0xFF172B4D); // color.text (N800 - Reading Text)
  static const Color _onSurfaceSecondaryLight =
      Color(0xFF44546F); // color.text.subtlest (N600ish - Labels)

  static const Color _brandBoldLight =
      Color(0xFF0C66E4); // color.background.brand.bold (Deep Blue/Action)

  static const Color _borderLight =
      Color(0xFFDCDFE4); // color.border (Neutral border)

  // Semantic Colors
  static const Color _successColor =
      Color(0xFF22A06B); // color.background.success.bold
  static const Color _warningColor =
      Color(0xFFE2B203); // color.background.warning.bold
  static const Color _dangerColor =
      Color(0xFFCA3521); // color.background.danger.bold

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _brandBoldLight,
      scaffoldBackgroundColor: _surfaceDefaultLight, // Pure White Foundation

      colorScheme: const ColorScheme.light(
        primary: _brandBoldLight,
        secondary: _brandBoldLight,
        surface: _surfaceDefaultLight,
        background: _surfaceDefaultLight,
        onSurface: _onSurfacePrimaryLight,
        onPrimary: Colors.white,
        error: _dangerColor,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor:
            _surfaceDefaultLight, // Modals usually White on Overlay
        elevation: 6, // Modals need lift
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        titleTextStyle: const TextStyle(
          color: _onSurfacePrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: _onSurfaceSecondaryLight,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        // "Using neutral tones for secondary layers/content"
        color: _surfaceNeutralLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          // No border needed if using distinct neutral background,
          // but low contrast might need one or keep it flat neutral.
          // ADS often uses N10 backgrounds for cards on White, no border.
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceDefaultLight,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: _onSurfacePrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _onSurfacePrimaryLight),
        // Add a bottom border for separation since bg is white
        shape: Border(bottom: BorderSide(color: _borderLight, width: 1)),
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandBoldLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black
                  .withOpacity(0.1); // Slightly darker pressed state
            }
            return null;
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _brandBoldLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _brandBoldLight.withOpacity(0.1);
            }
            return null;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurfacePrimaryLight,
          side: const BorderSide(color: _borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: Colors.transparent,
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: _onSurfaceSecondaryLight,
        size: 20,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: _borderLight,
        space: 1,
        thickness: 1,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // "Neutral tones... for usage"
        fillColor: _surfaceNeutralLight, // Inputs on White typically N10/N20
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              const BorderSide(color: Colors.transparent), // Flat styling
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Colors.transparent),
          // Standard ADS inputs are often N10 background, no border until hover/focus
          // Or N10 with N40 border. Let's stick to N10 background.
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: _brandBoldLight, width: 2),
        ),
        labelStyle: const TextStyle(color: _onSurfaceSecondaryLight),
        hintStyle: TextStyle(color: _onSurfaceSecondaryLight.withOpacity(0.6)),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: _brandBoldLight,
        inactiveTrackColor: _borderLight,
        thumbColor: Colors.white,
        trackHeight: 4,
        overlayColor: _brandBoldLight.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
    );
  }
}
