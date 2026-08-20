import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/connections/presentation/components/connected_user_tile.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:go_router/go_router.dart';

class ConnectionsListScreen extends StatefulWidget {
  // Null means "my own connections". Set to view another user's instead —
  // this reuses the exact same list/panel either way.
  final String? userId;
  final String? userName;

  const ConnectionsListScreen({super.key, this.userId, this.userName});

  @override
  State<ConnectionsListScreen> createState() => _ConnectionsListScreenState();
}

class _ConnectionsListScreenState extends State<ConnectionsListScreen> {
  late Future<List<PublicUser>> _connectionsFuture;

  bool get _isOwn => widget.userId == null;

  Future<List<PublicUser>> _fetch() {
    final connectionsRepo = context.read<ConnectionsRepo>();
    return _isOwn
        ? connectionsRepo.getConnectedUsers()
        : connectionsRepo.getConnectionsOf(widget.userId!);
  }

  @override
  void initState() {
    super.initState();
    _connectionsFuture = _fetch();
  }

  void _retry() {
    setState(() => _connectionsFuture = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final title = _isOwn
        ? 'Connections'
        : "${widget.userName ?? 'Their'}'s Connections";
    final emptyMessage = _isOwn
        ? "You don't have any connections yet."
        : widget.userName != null
        ? "${widget.userName} doesn't have any connections yet."
        : "They don't have any connections yet.";

    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
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
                      title,
                      textAlign: TextAlign.center,
                      style: typography.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PublicUser>>(
                future: _connectionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              genericErrorMessage,
                              style: typography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(label: 'Retry', onPressed: _retry),
                          ],
                        ),
                      ),
                    );
                  }

                  final connections = snapshot.data ?? [];
                  if (connections.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              emptyMessage,
                              style: typography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: connections.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final user = connections[index];
                      return ConnectedUserTile(
                        user: user,
                        onTap: () async {
                          // The profile screen lets the viewer remove a
                          // connection of their own — refresh on return so
                          // this list reflects any change instead of going
                          // stale.
                          await context.push(
                            AppRoutes.userProfile,
                            extra: user.id,
                          );
                          if (context.mounted) _retry();
                        },
                      );
                    },
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
