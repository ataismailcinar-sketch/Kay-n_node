import 'package:flutter/material.dart';

/// Kayın Tarım — Premium Modern Yeşil & Dark Mode Teması
///
/// Tasarım Prensipleri:
///   - Ticari Kalite: Zümrüt & Derin Yeşil renk paleti ile modern ve prestijli görünüm.
///   - Saha Uyumluluğu: Güneş ışığında yüksek okunabilirlik (Light) + Gece kullanımı için göz yormayan Dark Mode.
///   - Zero-Keyboard Uyumluluğu: Min 56dp yüksekliğinde büyük buton ve erişilebilir dokunma hedefleri.
class AppTheme {
  AppTheme._();

  // ── 🎨 Ortak Renk Paleti ───────────────────────────────────────────────
  static const Color primaryEmerald = Color(0xFF0F766E); // Derin Zümrüt Yeşili
  static const Color primaryMint = Color(0xFF10B981);    // Canlı Nane Yeşili
  static const Color secondaryGreen = Color(0xFF059669);  // Orman Yeşili
  static const Color accentGold = Color(0xFFF59E0B);      // Olgun Buğday Altını

  // Uyarı & Durum Renkleri
  static const Color dangerColor = Color(0xFFEF4444);     // Acil Su / Kritik Hastalık
  static const Color warningColor = Color(0xFFF59E0B);    // Dikkat
  static const Color successColor = Color(0xFF10B981);    // Yeterli Su / Sağlıklı
  static const Color infoColor = Color(0xFF3B82F6);       // Veri Bilgisi

  // Legacy Uyumluluk İçin Alias'lar
  static const Color primaryColor = primaryEmerald;
  static const Color secondaryColor = secondaryGreen;

  // ── ☀️ LIGHT MODE (Aydınlık Tema) ──────────────────────────────────────
  static const Color lightBg = Color(0xFFF0FDF4);         // Ferah Açık Nane Zemin
  static const Color lightCard = Color(0xFFFFFFFF);       // Temiz Beyaz Kart Surface
  static const Color lightTextPrimary = Color(0xFF064E3B); // Koyu Zümrüt Metin
  static const Color lightTextSecondary = Color(0xFF047857); // Orta Zümrüt Metin
  static const Color backgroundColor = lightBg;
  static const Color cardColor = lightCard;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryEmerald,
          secondary: primaryMint,
          tertiary: accentGold,
          error: dangerColor,
          surface: lightBg,
          onSurface: lightTextPrimary,
        ),
        scaffoldBackgroundColor: lightBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: primaryEmerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 3,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: Colors.white,
          selectedColor: primaryEmerald,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: lightTextPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFA7F3D0)),
          ),
        ),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 4,
          shadowColor: primaryEmerald.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextPrimary),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightTextPrimary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: lightTextPrimary),
          bodyLarge: TextStyle(fontSize: 18, color: lightTextPrimary),
          bodyMedium: TextStyle(fontSize: 16, color: lightTextSecondary),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  // ── 🌙 DARK MODE (Karanlık Tema) ───────────────────────────────────────
  static const Color darkBg = Color(0xFF0B1310);          // Derin Slate Zümrüt
  static const Color darkCard = Color(0xFF16221E);        // Yükseltilmiş Koyu Yüzey
  static const Color darkTextPrimary = Color(0xFFECFDF5);  // Nane Beyazı
  static const Color darkTextSecondary = Color(0xFFA7F3D0);// Yumuşak Nane

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primaryMint,
          secondary: primaryEmerald,
          tertiary: accentGold,
          error: dangerColor,
          surface: darkBg,
          onSurface: darkTextPrimary,
        ),
        scaffoldBackgroundColor: darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkCard,
          foregroundColor: darkTextPrimary,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkTextPrimary,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: primaryMint,
            foregroundColor: darkBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 4,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: darkCard,
          selectedColor: primaryMint,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: darkTextPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF1F352E)),
          ),
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 6,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkTextPrimary),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: darkTextPrimary),
          bodyLarge: TextStyle(fontSize: 18, color: darkTextPrimary),
          bodyMedium: TextStyle(fontSize: 16, color: darkTextSecondary),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
}
