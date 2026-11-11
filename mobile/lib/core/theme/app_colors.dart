import 'package:flutter/material.dart';

/// Premium Apple / Tier-1 Light Design System Tokens (PREMIUM_UI_DESIGN.md)
class AppColors {
  AppColors._();

  // Canvas & Surfaces (Apple Light Mode Palette)
  static const Color scaffoldBackground = Color(0xFFF5F5F7); // #F5F5F7 Canvas
  static const Color surface = Color(0xFFFFFFFF);            // #FFFFFF Elevated Card Surface
  static const Color surfaceSecondary = Color(0xFFF9FAFB);   // Subtle nested surface
  static const Color surfaceBorder = Color(0x14000000);      // rgba(0, 0, 0, 0.08) Hairline Border
  static const Color borderSubtle = Color(0x0F000000);       // rgba(0, 0, 0, 0.06)

  // Accent Discipline: Used sparingly (<10% of UI)
  static const Color primary = Color(0xFF2563EB);            // Brand Royal Blue
  static const Color primaryDark = Color(0xFF1D4ED8);        // Active / Pressed Accent
  static const Color primaryLight = Color(0xFF60A5FA);

  // High-contrast Monochrome Action (Apple style)
  static const Color darkPill = Color(0xFF1D1D1F);
  static const Color darkPillText = Color(0xFFFFFFFF);

  // Secondary Accents & Badges
  static const Color secondaryBadge = Color(0xFFEFF6FF);     // Soft Blue Pill Surface
  static const Color secondaryBadgeText = Color(0xFF1D4ED8); // Accent Pill Text

  // Typography Palette (Apple 3 Strict Tiers)
  static const Color textPrimary = Color(0xFF1D1D1F);        // #1D1D1F Tier 1 Primary
  static const Color textSecondary = Color(0xFF86868B);      // #86868B Tier 2 Secondary
  static const Color textMuted = Color(0xFF71717A);          // Zinc-500 Tier 3 Muted Labels

  // Feedback & Status Badges
  static const Color emerald = Color(0xFF10B981);            // Verified / Success
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFF59E0B);              // Pending KYC / Warnings
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color rose = Color(0xFFEF4444);               // Live / Alert / Heart
  static const Color roseLight = Color(0xFFFEF2F2);

  // Skeleton shimmer base & highlight
  static const Color shimmerBase = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF3F4F6);

  // Aliases for screen convenience
  static const Color canvasBackground = scaffoldBackground;
  static const Color cardSurface = surface;
  static const Color primaryAccent = primary;
  static const Color secondaryBadgeBg = secondaryBadge;
  static const Color primaryText = textPrimary;
  static const Color mutedText = textSecondary;
  static const Color successGreen = emerald;
}
