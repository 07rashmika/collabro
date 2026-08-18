import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/error_messages.dart';

void showComingSoonSnackBar(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
}

void showErrorSnackBar(BuildContext context) {
  final colors = AppColors.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(genericErrorMessage),
      backgroundColor: colors.error,
    ),
  );
}
