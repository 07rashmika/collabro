import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/realtime/user_notifications_service.dart';
import 'package:frontend/core/widgets/app_bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';

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
