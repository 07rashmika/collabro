import 'package:flutter/material.dart';

/// App color palette, exposed as a [ThemeExtension] so it can vary between
/// [AppColors.dark] (the original look) and [AppColors.light] based on the
/// active [ThemeMode]. Access via `AppColors.of(context)` inside widgets.
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryGradientStart;
  final Color primaryGradientEnd;

  //backgrounds
  final Color backgroundDark;
  final Color backgroundMedium;
  final Color backgroundCard;
  final Color backgroundElevated;
  final Color backgroundInput;

  //text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textHint;

  //statuses
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  //match badge
  final Color matchBadge;
  final Color matchBadgeText;

  //borders
  final Color border;
  final Color borderLight;

  //bottom nav
  final Color navActive;
  final Color navInactive;

  //chip backgrounds
  final Color chipBackground;
  final Color chipBorder;

  //second stop for heroGradient
  final Color heroGradientEnd;

  //transparent overlays
  final Color overlay;
  final Color overlayLight;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryGradientStart,
    required this.primaryGradientEnd,
    required this.backgroundDark,
    required this.backgroundMedium,
    required this.backgroundCard,
    required this.backgroundElevated,
    required this.backgroundInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.matchBadge,
    required this.matchBadgeText,
    required this.border,
    required this.borderLight,
    required this.navActive,
    required this.navInactive,
    required this.chipBackground,
    required this.chipBorder,
    required this.heroGradientEnd,
    required this.overlay,
    required this.overlayLight,
  });

  /// Original dark palette — unchanged from before theming was introduced.
  static const AppColors dark = AppColors(
    primary: Color(0xFF7B5CF5),
    primaryLight: Color(0xFF9D7FF8),
    primaryDark: Color(0xFF5A3DD4),
    primaryGradientStart: Color(0xFF7B5CF5),
    primaryGradientEnd: Color(0xFF06B6D4),
    backgroundDark: Color(0xFF0E0E14),
    backgroundMedium: Color(0xFF16161F),
    backgroundCard: Color(0xFF1C1C28),
    backgroundElevated: Color(0xFF22222F),
    backgroundInput: Color(0xFF1A1A25),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0C8),
    textTertiary: Color(0xFF6B6B85),
    textHint: Color(0xFF4A4A60),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    matchBadge: Color(0xFF7B5CF5),
    matchBadgeText: Color(0xFFFFFFFF),
    border: Color(0xFF2A2A3D),
    borderLight: Color(0xFF32324A),
    navActive: Color(0xFF7B5CF5),
    navInactive: Color(0xFF6B6B85),
    chipBackground: Color(0xFF2A2A3D),
    chipBorder: Color(0xFF3D3D55),
    heroGradientEnd: Color(0xFF1A103A),
    overlay: Color(0x80000000),
    overlayLight: Color(0x40000000),
  );

  /// Light palette — same brand accents as [dark], with backgrounds/text/
  /// borders inverted for a light UI.
  static const AppColors light = AppColors(
    primary: Color(0xFF7B5CF5),
    primaryLight: Color(0xFF9D7FF8),
    primaryDark: Color(0xFF5A3DD4),
    primaryGradientStart: Color(0xFF7B5CF5),
    primaryGradientEnd: Color(0xFF06B6D4),
    backgroundDark: Color(0xFFF7F7FA),
    backgroundMedium: Color(0xFFFFFFFF),
    backgroundCard: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFF0F0F5),
    backgroundInput: Color(0xFFF2F2F7),
    textPrimary: Color(0xFF15151F),
    textSecondary: Color(0xFF55556B),
    textTertiary: Color(0xFF8A8AA3),
    textHint: Color(0xFFB5B5C9),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    matchBadge: Color(0xFF7B5CF5),
    matchBadgeText: Color(0xFFFFFFFF),
    border: Color(0xFFE2E2EA),
    borderLight: Color(0xFFECECF2),
    navActive: Color(0xFF7B5CF5),
    navInactive: Color(0xFF9A9AB3),
    chipBackground: Color(0xFFF0F0F5),
    chipBorder: Color(0xFFDCDCE6),
    heroGradientEnd: Color(0xFFEDE7FB),
    overlay: Color(0x80000000),
    overlayLight: Color(0x40000000),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryGradientStart, primaryGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  LinearGradient get joinButtonGradient => primaryGradient;

  LinearGradient get cardGradient => LinearGradient(
    colors: [backgroundCard, backgroundElevated],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get heroGradient => LinearGradient(
    colors: [backgroundDark, heroGradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? primaryGradientStart,
    Color? primaryGradientEnd,
    Color? backgroundDark,
    Color? backgroundMedium,
    Color? backgroundCard,
    Color? backgroundElevated,
    Color? backgroundInput,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? matchBadge,
    Color? matchBadgeText,
    Color? border,
    Color? borderLight,
    Color? navActive,
    Color? navInactive,
    Color? chipBackground,
    Color? chipBorder,
    Color? heroGradientEnd,
    Color? overlay,
    Color? overlayLight,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryGradientStart: primaryGradientStart ?? this.primaryGradientStart,
      primaryGradientEnd: primaryGradientEnd ?? this.primaryGradientEnd,
      backgroundDark: backgroundDark ?? this.backgroundDark,
      backgroundMedium: backgroundMedium ?? this.backgroundMedium,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      backgroundInput: backgroundInput ?? this.backgroundInput,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textHint: textHint ?? this.textHint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      matchBadge: matchBadge ?? this.matchBadge,
      matchBadgeText: matchBadgeText ?? this.matchBadgeText,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      chipBackground: chipBackground ?? this.chipBackground,
      chipBorder: chipBorder ?? this.chipBorder,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      overlay: overlay ?? this.overlay,
      overlayLight: overlayLight ?? this.overlayLight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}
