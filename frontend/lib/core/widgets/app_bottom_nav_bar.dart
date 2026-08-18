import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const List<_NavItem> _navItems = [
  _NavItem(Icons.home_outlined, Icons.home, 'Home'),
  _NavItem(Icons.explore_outlined, Icons.explore, 'Discovery'),
  _NavItem(Icons.groups_outlined, Icons.groups, 'Sessions'),
  _NavItem(Icons.description_outlined, Icons.description, 'Notes'),
  _NavItem(Icons.person_outline, Icons.person, 'Profile'),
];

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      height: AppSpacing.bottomNavHeight,
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final isActive = i == currentIndex;
          final color = isActive ? colors.navActive : colors.navInactive;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  Icon(isActive ? item.activeIcon : item.icon, color: color),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: typography.caption.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
