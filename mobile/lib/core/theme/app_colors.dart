import 'package:flutter/material.dart';

class AppColors {
  // Clean Sky Blue Light Theme Tokens
  static const Color scaffoldBackground = Color(0xFFF0F6FF); // Soft Ice Blue Canvas
  static const Color surface = Color(0xFFFFFFFF);            // Card & Header Surfaces
  static const Color surfaceBorder = Color(0xFFE2E8F0);      // Hairline 1px Border
  static const Color surfaceSecondary = Color(0xFFF8FAFC);   // Subtle inner container

  // Primary Brand Accents
  static const Color primary = Color(0xFF2563EB);            // Vibrant Royal Blue
  static const Color primaryDark = Color(0xFF1D4ED8);        // Active / Pressed Accent
  static const Color primaryLight = Color(0xFF60A5FA);

  // Secondary Accents & Badges
  static const Color secondaryBadge = Color(0xFFE0EDFF);     // Accent Pill Surface
  static const Color secondaryBadgeText = Color(0xFF1D4ED8); // Accent Pill Text

  // Typography Palette (WCAG AA Contrast Compliant)
  static const Color textPrimary = Color(0xFF0F172A);        // Slate 900 (High-contrast)
  static const Color textSecondary = Color(0xFF64748B);      // Slate 500 (Metadata & captions)
  static const Color textMuted = Color(0xFF94A3B8);          // Slate 400 (Placeholders)

  // Feedback & Status Badges
  static const Color emerald = Color(0xFF059669);            // Verified / Success
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFD97706);              // Pending KYC / Warnings
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color rose = Color(0xFFE11D48);               // Live / Alert / Heart
  static const Color roseLight = Color(0xFFFFF1F2);

  // Design tokens aliases for screen convenience
  static const Color canvasBackground = scaffoldBackground;
  static const Color cardSurface = surface;
  static const Color primaryAccent = primary;
  static const Color secondaryBadgeBg = secondaryBadge;
  static const Color primaryText = textPrimary;
  static const Color mutedText = textSecondary;
  static const Color successGreen = emerald;
}
