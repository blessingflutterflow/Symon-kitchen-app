import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF1A0A00);
  static const Color surface = Color(0xFF2A1508);
  static const Color surfaceLight = Color(0xFF3D1E0C);
  static const Color gold = Color(0xFFC8880A);
  static const Color goldLight = Color(0xFFE0A020);
  static const Color cream = Color(0xFFFAF0DC);
  static const Color creamMuted = Color(0xFFB09060);
  static const Color white = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFF3D1E0C);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        surface: AppColors.surface,
        onPrimary: AppColors.background,
        onSurface: AppColors.cream,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.cream),
          bodyMedium: TextStyle(color: AppColors.creamMuted),
          labelLarge: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.cream,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.background,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );
  }
}
