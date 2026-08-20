import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/notifications/domain/repos/notifications_repo.dart';
import 'package:frontend/features/notifications/presentation/components/notification_tile.dart';
import 'package:go_router/go_router.dart';

import '../cubits/notifications_cubit.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NotificationsCubit(
              notificationsRepo: context.read<NotificationsRepo>(),
              connectionsRepo: context.read<ConnectionsRepo>(),
            )
            ..load()
            ..markAllRead(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const .symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: .center,
                      style: typography.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  if (state is NotificationsInitial ||
                      state is NotificationsLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }
                  if (state is NotificationsError) {
                    return Center(
                      child: Padding(
                        padding: const .symmetric(horizontal: AppSpacing.lg),
                        child: Text(
                          genericErrorMessage,
                          textAlign: .center,
                          style: typography.bodySmall,
                        ),
                      ),
                    );
                  }

                  final notifications =
                      (state as NotificationsLoaded).page.notifications;
                  if (notifications.isEmpty) {
                    return Center(
                      child: Text(
                        "You're all caught up.",
                        style: typography.bodySmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: colors.primary,
                    onRefresh: () => context.read<NotificationsCubit>().load(),
                    child: ListView.separated(
                      padding: const .symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) =>
                          NotificationTile(notification: notifications[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
