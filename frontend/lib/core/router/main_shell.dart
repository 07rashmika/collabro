import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/realtime/user_notifications_service.dart';
import 'package:frontend/core/widgets/app_bottom_nav_bar.dart';

/// Root scaffold for the bottom-nav tabs (home, discovery, sessions, notes,
/// profile). Each tab keeps its own navigation stack and state via
/// [StatefulShellRoute.indexedStack]; detail screens are pushed as
/// top-level routes on top of this shell instead of inside a branch.
///
/// Also owns the single [UserNotificationsService] connection for the whole
/// logged-in session — this is the natural place since it's alive for as
/// long as any tab is, and every tab branch needs to be able to react to a
/// "your sessions changed" push regardless of which one is active.
class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final UserNotificationsService _notificationsService;

  @override
  void initState() {
    super.initState();
    _notificationsService = UserNotificationsService(
      storage: context.read<FlutterSecureStorage>(),
    )..connect();
  }

  @override
  void dispose() {
    _notificationsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _notificationsService,
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: AppBottomNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
