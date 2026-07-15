import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_typography.dart';

ThemeData buildAppTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.backgroundDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
    ),
    extensions: [colors, AppTypography.from(colors)],
  );
}
