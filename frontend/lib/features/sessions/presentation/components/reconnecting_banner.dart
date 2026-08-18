import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';

class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: .infinity,
      color: colors.warning,
      padding: const .symmetric(vertical: AppSpacing.xs),
      child: const Text(
        'Reconnecting…',
        textAlign: .center,
        style: TextStyle(color: Colors.black, fontWeight: .w600),
      ),
    );
  }
}
