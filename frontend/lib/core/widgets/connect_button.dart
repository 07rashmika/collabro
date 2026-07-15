import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class ConnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isConnected;

  const ConnectButton({
    super.key,
    required this.onPressed,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return SizedBox(
      height: AppSpacing.buttonHeightSm,
      width: double.infinity,
      child: isConnected
          ? OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.success,
                side: BorderSide(color: colors.success),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Connected',
                    style: typography.labelSmall.copyWith(
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                padding: EdgeInsets.zero,
                textStyle: typography.labelSmall,
              ),
              child: const Text('Connect'),
            ),
    );
  }
}