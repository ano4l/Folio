import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Apple System Colors & Liquid Glass Tints
  static const teal = Color(0xFF007AFF); // Apple System Blue / Primary Accent
  static const tealAccent = Color(0xFF30B0C7); // Apple SF Cyan Accent
  static const tealLight = Color(0xFFE5F1FF); // Translucent Blue/Cyan Tint
  static const ink = Color(0xFF1C1C1E); // Apple System Primary Text
  static const slate = Color(0xFF8E8E93); // Apple System Secondary Text
  static const paper = Color(0xFFF2F2F7); // Apple System Grouped Background
  static const card = Color(0xFFFFFFFF); // Apple System Card Background
  static const line = Color(0x1F000000); // Hairline Separator (12% black)
  static const glassBorder = Color(0xCCFFFFFF); // Specular Highlight Border
  static const success = Color(0xFF34C759); // Apple System Green
  static const successLight = Color(0xFFE8F9ED);
  static const danger = Color(0xFFFF3B30); // Apple System Red
  static const warning = Color(0xFFFF9500); // Apple System Orange
  static const warningLight = Color(0xFFFFF4E5);
  static const purple = Color(0xFFAF52DE); // Apple System Purple
  static const purpleLight = Color(0xFFF7ECFB);
  static const navy = Color(0xFF5856D6); // Apple System Indigo
  static const navyLight = Color(0xFFEEEEFF);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.light,
        surface: AppColors.paper,
      ),
      scaffoldBackgroundColor: AppColors.paper,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        letterSpacing: -0.2,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.slate,
        letterSpacing: -0.1,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.slate,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.card.withValues(alpha: 0.8),
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.slate, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.slate,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
