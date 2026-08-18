import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

enum ConnectStatus { none, requested, connected }

class ConnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final ConnectStatus status;

  const ConnectButton({
    super.key,
    required this.onPressed,
    this.status = .none,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    if (status == .connected) {
      return _StatusPill(
        icon: Icons.check,
        label: 'Connected',
        color: colors.success,
        typography: typography,
        onPressed: null,
      );
    }

    if (status == .requested) {
      return _StatusPill(
        icon: Icons.schedule,
        label: 'Requested',
        color: colors.warning,
        typography: typography,
        onPressed: onPressed,
      );
    }

    return SizedBox(
      height: AppSpacing.buttonHeightSm,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: .circular(AppSpacing.radiusSm),
          ),
          padding: const .symmetric(horizontal: AppSpacing.md),
          textStyle: typography.labelSmall,
        ),
        child: const Text('Connect'),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AppTypography typography;
  final VoidCallback? onPressed;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.typography,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeightSm,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: .circular(AppSpacing.radiusSm),
          ),
          padding: const .symmetric(horizontal: AppSpacing.md),
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: typography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
