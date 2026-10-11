import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ProDFOS cinematic design system.
///
/// IMPORTANT: fonts are applied ONLY through [TextTheme]. Never set a global
/// `fontFamily` on ThemeData — it overrides the MaterialIcons font and turns
/// every icon into random glyphs.
class AppTheme {
  AppTheme._();

  // ── Cinematic palette ────────────────────────────────────────────────
  static const Color voidBlack = Color(0xFF07070A);
  static const Color cream = Color(0xFFF0EDE6);
  static const Color creamMuted = Color(0x99F0EDE6); // 60%
  static const Color creamFaint = Color(0x59F0EDE6); // 35%

  static const Color brandGold = Color(0xFFD4A843);
  static const Color brandGoldLight = Color(0xFFF2D78B);
  static const Color brandGoldDark = Color(0xFF9A7424);

  // ── Surfaces (names kept — used across the whole app) ────────────────
  static const Color darkBg = voidBlack;
  static const Color darkSurface = Color(0xFF0E0E13);
  static const Color darkCard = Color(0xFF15151C);
  static const Color darkBorder = Color(0xFF26262F);

  static const Color goldHairline = Color(0x40D4A843); // 25% gold

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB8892E), Color(0xFFF2D78B), Color(0xFFD4A843)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Type helpers ─────────────────────────────────────────────────────
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w700, Color color = cream, bool italic = false,
           double? letterSpacing, double? height}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size, fontWeight: weight, color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: letterSpacing ?? -0.5, height: height ?? 1.1,
      );

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400, Color color = cream, double? letterSpacing, double? height}) =>
      GoogleFonts.dmSans(
        fontSize: size, fontWeight: weight, color: color,
        letterSpacing: letterSpacing, height: height,
      );

  static TextStyle kicker({Color color = brandGold}) => GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.9),
        letterSpacing: 2.4,
      );

  // ══════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    final base = ThemeData.dark().textTheme;
    final disp = GoogleFonts.playfairDisplayTextTheme(base);
    final text = GoogleFonts.dmSansTextTheme(base);

    final textTheme = TextTheme(
      displayLarge: disp.displayLarge,
      displayMedium: disp.displayMedium,
      displaySmall: disp.displaySmall,
      headlineLarge: disp.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: disp.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: disp.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: disp.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge,
      bodyMedium: text.bodyMedium,
      bodySmall: text.bodySmall,
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: text.labelMedium,
      labelSmall: text.labelSmall,
    ).apply(bodyColor: cream, displayColor: cream);

    final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,
      scaffoldBackgroundColor: voidBlack,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: const ColorScheme.dark(
        primary: brandGold,
        onPrimary: Colors.black,
        secondary: brandGoldLight,
        onSecondary: Colors.black,
        surface: darkSurface,
        onSurface: cream,
        surfaceContainerHighest: darkCard,
        outline: darkBorder,
        error: Color(0xFFFF6B6B),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: voidBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: cream,
        iconTheme: const IconThemeData(color: cream),
        titleTextStyle: display(21),
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: display(20),
        contentTextStyle: body(14, color: creamMuted, height: 1.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: goldHairline),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: goldHairline),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        textStyle: body(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: body(14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: goldHairline),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGold,
          foregroundColor: Colors.black,
          disabledBackgroundColor: brandGold.withValues(alpha: 0.25),
          shape: shape14,
          textStyle: body(14, weight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandGold,
          side: const BorderSide(color: Color(0x66D4A843)),
          shape: shape14,
          textStyle: body(14, weight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandGold,
          textStyle: body(14, weight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandGold,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        hintStyle: body(14, color: creamFaint),
        labelStyle: body(14, color: creamMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandGold, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: brandGold.withValues(alpha: 0.18),
        side: const BorderSide(color: darkBorder),
        labelStyle: body(13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? brandGold : creamMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? brandGold.withValues(alpha: 0.35) : darkBorder),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: brandGold,
        inactiveTrackColor: darkBorder,
        thumbColor: brandGold,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: brandGold,
        textColor: cream,
        titleTextStyle: body(15, weight: FontWeight.w500),
        subtitleTextStyle: body(13, color: creamFaint),
      ),

      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandGold,
        linearTrackColor: darkCard,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: brandGold,
        unselectedItemColor: creamFaint,
        type: BottomNavigationBarType.fixed,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: goldHairline),
        ),
        textStyle: body(12),
      ),
    );
  }
}
