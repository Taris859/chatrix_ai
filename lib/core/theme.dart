import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatrixTheme {
  // ═══════════════════════════════════════════
  // Core Colors — Luxury Dark Romance Palette
  // ═══════════════════════════════════════════
  static const Color background = Color(0xFF050507);       // Matte Black
  static const Color surface = Color(0xFF0F0F12);          // Charcoal
  static const Color surfaceLight = Color(0xFF161619);     // Elevated Charcoal
  static const Color cardDark = Color(0xFF0B0B0E);         // Deep Card

  // Subtle Accents — Restrained luxury
  static const Color amethyst = Color(0xFF4A3F5C);         // Muted Purple
  static const Color bioluminescence = Color(0xFF4A5A5A);  // Muted Silver
  static const Color accentGold = Color(0xFF8B7355);       // Muted Gold

  // Extended Luxury Palette
  static const Color roseDust = Color(0xFF6B3A4A);         // Dark Rose
  static const Color silverMist = Color(0xFF9EA3AB);       // Silver Mist
  static const Color champagneGold = Color(0xFFD4AF7A);    // Champagne Gold
  static const Color midnightCharcoal = Color(0xFF1A1A1F); // Midnight Charcoal
  static const Color warmIvory = Color(0xFFF5F0E8);        // Warm Ivory (for accents)

  // Error / Warning (replaces neonPink — luxury naming)
  static const Color errorRose = Color(0xFF8B3A4A);        // Muted Rose Error
  // Legacy alias for backward compatibility
  static const Color neonPink = errorRose;

  // Typography Colors
  static const Color textPrimary = Color(0xFFE8E8EB);     // Soft White
  static const Color textSecondary = Color(0xFF8A8A95);    // Muted Gray
  static const Color textTertiary = Color(0xFF5A5A65);     // Dim Gray

  // ═══════════════════════════════════════════
  // Theme Data
  // ═══════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: amethyst,
      colorScheme: const ColorScheme.dark(
        primary: amethyst,
        secondary: bioluminescence,
        surface: surface,
        onSurface: textPrimary,
        error: errorRose,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Cinematic Backgrounds
  // ═══════════════════════════════════════════
  static BoxDecoration get cinematicBackground {
    return BoxDecoration(
      color: background,
      image: DecorationImage(
        image: const AssetImage('assets/images/cinematic_bg.png'),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.6), // Darken the image so text stays highly readable
          BlendMode.darken,
        ),
      ),
    );
  }

  /// Premium card gradient — subtle charcoal to transparent
  static BoxDecoration premiumCardDecoration({
    Color? accentColor,
    double borderRadius = 20,
  }) {
    final accent = accentColor ?? amethyst;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: surface.withOpacity(0.3),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
        width: 1,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.04),
          Colors.transparent,
        ],
      ),
    );
  }

  /// Section divider gradient — subtle horizontal line
  static Widget sectionDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.06),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
