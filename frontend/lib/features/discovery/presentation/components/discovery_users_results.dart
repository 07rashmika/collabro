import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/connections/presentation/connect_request_handler.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_user_card.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:go_router/go_router.dart';

class DiscoveryUsersResults extends StatelessWidget {
  final List<PublicUser> users;
  final String? currentUserId;
  final String emptyMessage;

  const DiscoveryUsersResults({
    super.key,
    required this.users,
    required this.currentUserId,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = currentUserId == null
        ? users
        : users.where((u) => u.id != currentUserId).toList();
    final connectionsState = context.watch<ConnectionsCubit>().state;

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: .center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final user = filtered[i];
        final status = connectionsState.effectiveStatus(
          user.connectionStatus,
          user.id,
        );
        return DiscoveryUserCard(
          user: user,
          connectStatus: status,
          onConnect: () => handleConnectPress(context, user.id, status),
          onTap: () => context.push(AppRoutes.userProfile, extra: user.id),
        );
      },
    );
  }
}
