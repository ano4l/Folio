import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ink = Color(0xFF0B132B),
      ink2 = Color(0xFF1C2541),
      paper = Color(0xFFFAF9F5),
      card = Color(0xFFFFFFFF);
  static const teal = Color(0xFF0E7C74),
      tealAccent = Color(0xFF0A605E),
      tealLight = Color(0xFFE8F5F3);
  static const amber = Color(0xFF9A581B),
      amberLight = Color(0xFFFDF4E9),
      line = Color(0xFFEBE8E0),
      slate = Color(0xFF5E697C);
  static const danger = Color(0xFFB3432D),
      dangerLight = Color(0xFFFCECE8),
      success = Color(0xFF1E7E34),
      successLight = Color(0xFFEAF7EC);
  static const warning = amber,
      warningLight = amberLight,
      purple = Color(0xFF7256A8),
      purpleLight = Color(0xFFF1ECF8),
      navy = ink2,
      navyLight = Color(0xFFEEF0F5),
      glassBorder = line;
}

class AppTheme {
  static TextStyle display({double size = 30, Color color = AppColors.ink}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.12,
        letterSpacing: -.45,
      );
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      // Share Android's metrics and ink treatment without changing the real
      // platform (iOS still needs native editing and back-swipe behavior).
      typography: Typography.material2021(platform: TargetPlatform.android),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        surface: AppColors.paper,
      ),
      scaffoldBackgroundColor: AppColors.paper,
    );
    final body = GoogleFonts.dmSansTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: body.copyWith(
        headlineLarge: display(size: 30),
        headlineMedium: display(size: 24),
        headlineSmall: display(size: 19),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: AppColors.ink,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.slate,
          height: 1.45,
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.slate,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      dividerColor: AppColors.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink2,
        contentTextStyle: body.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF91E3D5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.slate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        labelStyle: GoogleFonts.dmSans(color: AppColors.slate, fontSize: 14),
        hintStyle: GoogleFonts.dmSans(color: AppColors.slate, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
      ),
    );
  }
}
