import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/notifications/domain/entities/app_notification.dart';
import 'package:frontend/features/notifications/presentation/cubits/notifications_cubit.dart';
import 'package:go_router/go_router.dart';

class NotificationTile extends StatefulWidget {
  final AppNotification notification;

  const NotificationTile({super.key, required this.notification});

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  bool _isResponding = false;

  Future<void> _respond(bool accept) async {
    final connectionId = widget.notification.connectionId;
    if (connectionId == null || _isResponding) return;
    setState(() => _isResponding = true);
    try {
      await context.read<NotificationsCubit>().respondToRequest(
        connectionId,
        accept: accept,
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  List<InlineSpan> _buildMessageSpans(
    AppNotification notification,
    TextStyle boldStyle,
  ) {
    final name = TextSpan(text: notification.actorName, style: boldStyle);
    if (notification.type == .connectionAccepted) {
      return [name, const TextSpan(text: ' accepted your connection request')];
    }
    if (notification.connectionStatus == 'ACCEPTED') {
      return [
        const TextSpan(text: 'You accepted '),
        name,
        const TextSpan(text: "'s connection request"),
      ];
    }
    if (notification.connectionStatus == 'DECLINED') {
      return [
        const TextSpan(text: 'You declined '),
        name,
        const TextSpan(text: "'s connection request"),
      ];
    }
    if (notification.type == .sessionInvite) {
      final title = notification.sessionTitle;
      return [
        name,
        TextSpan(
          text: title == null
              ? ' added you to a study session'
              : ' added you to "$title"',
        ),
      ];
    }
    return [name, const TextSpan(text: ' wants to connect with you')];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final notification = widget.notification;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onTap: notification.type == .sessionInvite
          ? () => context.go(AppRoutes.sessions)
          : null,
      child: Container(
        padding: const .all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          borderRadius: .circular(AppSpacing.radiusLg),
          border: .all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            InkWell(
              borderRadius: .circular(AppSpacing.avatarMd),
              onTap: () => context.push(
                AppRoutes.userProfile,
                extra: notification.actorId,
              ),
              child: UserAvatar(
                name: notification.actorName,
                imageUrl: notification.actorAvatarUrl,
                size: AppSpacing.avatarMd,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: typography.bodyMedium,
                      children: _buildMessageSpans(
                        notification,
                        typography.bodyMedium.copyWith(fontWeight: .w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo(notification.createdAt),
                    style: typography.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  if (notification.isActionableRequest) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Accept',
                            isLoading: _isResponding,
                            onPressed: () => _respond(true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SizedBox(
                            height: AppSpacing.buttonHeightMd,
                            child: OutlinedButton(
                              onPressed: _isResponding
                                  ? null
                                  : () => _respond(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textSecondary,
                                side: BorderSide(color: colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: .circular(AppSpacing.radiusMd),
                                ),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
