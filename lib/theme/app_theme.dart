import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens shared by screens and reusable widgets.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF006948);
  static const Color primaryContainer = Color(0xFF00855D);
  static const Color secondary = Color(0xFF006C49);
  static const Color mint = Color(0xFF6CF8BB);
  static const Color tertiary = Color(0xFF825100);
  static const Color tertiaryContainer = Color(0xFFA36700);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Colors.white;
  static const Color surfaceLow = Color(0xFFF2F3FF);
  static const Color surfaceHigh = Color(0xFFE2E7FF);

  static const Color textPrimary = Color(0xFF131B2E);
  static const Color textSecondary = Color(0xFF3D4A42);
  static const Color textMuted = Color(0xFF6D7A72);

  static const Color xp = Color(0xFFA36700);
  static const Color xpBg = Color(0xFFFFDDB8);

  static const Color success = Color(0xFF006948);
  static const Color error = Color(0xFFBA1A1A);

  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0x0D131B2E);

  static const List<Color> accents = [
    primary,
    secondary,
    primaryContainer,
    tertiaryContainer,
    Color(0xFF68DBA9),
  ];

  static Color accentFor(int index) => accents[index % accents.length];
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Text style yang dipakai berulang kali (judul section, judul kartu, dst)
/// dikumpulkan agar screen tinggal memanggil, bukan menulis ulang TextStyle.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.bold,
    fontSize: 20,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            surface: AppColors.surface,
            secondary: AppColors.secondary,
            tertiary: AppColors.tertiary,
            error: AppColors.error,
          ).copyWith(
            primaryContainer: AppColors.primaryContainer,
            secondaryContainer: AppColors.mint,
            tertiaryContainer: AppColors.tertiaryContainer,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            onSurfaceVariant: AppColors.textSecondary,
            outline: AppColors.textMuted,
            outlineVariant: const Color(0xFFBCCAC0),
          ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.screenTitle,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.mint, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
