import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Custom top bar (not a Scaffold [AppBar]) — menu button, centered title,
/// notification bell with an unread-dot indicator.
class HomeTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final bool hasUnreadNotifications;

  const HomeTopBar({
    super.key,
    required this.onMenuTap,
    required this.onNotificationsTap,
    this.hasUnreadNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: Icon(Icons.menu, color: colors.textPrimary),
        ),
        Text('Collabro', style: typography.headlineMedium),
        IconButton(
          onPressed: onNotificationsTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_outlined, color: colors.textPrimary),
              if (hasUnreadNotifications)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
