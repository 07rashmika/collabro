import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/widgets/app_bottom_nav_bar.dart';

/// Root scaffold for the bottom-nav tabs (home, discovery, sessions, notes,
/// profile). Each tab keeps its own navigation stack and state via
/// [StatefulShellRoute.indexedStack]; detail screens are pushed as
/// top-level routes on top of this shell instead of inside a branch.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
