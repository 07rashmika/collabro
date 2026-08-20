import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography extends ThemeExtension<AppTypography> {
  static const String fontFamily = 'Inter';

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle caption;

  const AppTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.caption,
  });

  factory AppTypography.from(AppColors colors) {
    return AppTypography(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: .w800,
        color: colors.textPrimary,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: .w700,
        color: colors.textPrimary,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: .w700,
        color: colors.textPrimary,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: .w700,
        color: colors.textPrimary,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: .w400,
        color: colors.textSecondary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: .w400,
        color: colors.textSecondary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: .w400,
        color: colors.textSecondary,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.3,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: .w600,
        color: colors.textPrimary,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: .w500,
        color: colors.textSecondary,
        height: 1.3,
      ),
      caption: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: .w400,
        color: colors.textTertiary,
        height: 1.4,
      ),
    );
  }

  static final AppTypography dark = .from(AppColors.dark);
  static final AppTypography light = .from(AppColors.light);

  static AppTypography of(BuildContext context) =>
      Theme.of(context).extension<AppTypography>() ?? dark;

  @override
  AppTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
    TextStyle? caption,
  }) {
    return AppTypography(
      displayLarge: displayLarge ?? this.displayLarge,
      displayMedium: displayMedium ?? this.displayMedium,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      titleSmall: titleSmall ?? this.titleSmall,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? this.labelSmall,
      caption: caption ?? this.caption,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return t < 0.5 ? this : other;
  }
}
