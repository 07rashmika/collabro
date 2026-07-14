import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primary = Color(0xFF7B5CF5);
  static const Color primaryLight = Color(0xFF9D7FF8);
  static const Color primaryDark = Color(0xFF5A3DD4);
  static const Color primaryGradientStart = Color(0xFF7B5CF5);
  static const Color primaryGradientEnd = Color(0xFF06B6D4); // cyan accent

  //backgrounds
  static const Color backgroundDark = Color(0xFF0E0E14);
  static const Color backgroundMedium = Color(0xFF16161F);
  static const Color backgroundCard = Color(0xFF1C1C28);
  static const Color backgroundElevated = Color(0xFF22222F);
  static const Color backgroundInput = Color(0xFF1A1A25);

  //text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textTertiary = Color(0xFF6B6B85);
  static const Color textHint = Color(0xFF4A4A60);

  //statuses
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  //match badge
  static const Color matchBadge = Color(0xFF7B5CF5);
  static const Color matchBadgeText = Color(0xFFFFFFFF);

  //borders
  static const Color border = Color(0xFF2A2A3D);
  static const Color borderLight = Color(0xFF32324A);

  //bottom nav
  static const Color navActive = Color(0xFF7B5CF5);
  static const Color navInactive = Color(0xFF6B6B85);

  //chip backgrounds
  static const Color chipBackground = Color(0xFF2A2A3D);
  static const Color chipBorder = Color(0xFF3D3D55);

  //gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGradientStart, primaryGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1C28), Color(0xFF22222F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0E0E14), Color(0xFF1A103A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient joinButtonGradient = LinearGradient(
    colors: [Color(0xFF7B5CF5), Color(0xFF06B6D4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  //transparent overlays
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
}
