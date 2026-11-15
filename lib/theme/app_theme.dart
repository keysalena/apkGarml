import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semua warna & style dipusatkan di sini agar tidak ada lagi
/// warna hardcoded (mis. Color(0xFF1E8F4E)) yang diulang-ulang
/// di banyak file screen. Ubah sekali, konsisten di seluruh app.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1E8F4E);
  static const Color background = Colors.white;

  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textMuted = Colors.grey;

  static const MaterialColor xp = Colors.orange;
  static Color xpBg = Colors.orange.shade100;

  static const Color success = Colors.green;
  static const Color error = Colors.redAccent;

  static Color cardBorder = Colors.grey.shade200;
  static Color cardShadow = Colors.black.withValues(alpha: 0.03);

  /// Palet variasi warna untuk badge nomor modul, dsb — supaya daftar
  /// tidak terlihat monoton satu warna hijau berulang-ulang.
  static const List<Color> accents = [
    primary,
    Color(0xFF2563EB), // blue
    Color(0xFF9333EA), // purple
    Color(0xFFEA580C), // orange
    Color(0xFF0D9488), // teal
  ];

  static Color accentFor(int index) => accents[index % accents.length];
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.screenTitle,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}
