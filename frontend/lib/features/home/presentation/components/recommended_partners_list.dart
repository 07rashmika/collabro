import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/features/connections/presentation/connect_request_handler.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';
import 'package:frontend/features/matching/presentation/cubits/matching_cubit.dart';
import 'package:go_router/go_router.dart';

import 'partner_match_card.dart';

const double _kListHeight = 244;

class RecommendedPartnersList extends StatelessWidget {
  const RecommendedPartnersList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchingCubit, MatchingState>(
      builder: (context, state) {
        final colors = AppColors.of(context);
        final typography = AppTypography.of(context);
        if (state is MatchesInitial || state is MatchesLoading) {
          return SizedBox(
            height: _kListHeight,
            child: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }

        if (state is MatchesError) {
          return SizedBox(
            height: _kListHeight,
            child: Center(
              child: Padding(
                padding: const .symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  genericErrorMessage,
                  textAlign: .center,
                  style: typography.bodySmall,
                ),
              ),
            ),
          );
        }

        final matches = (state as MatchesLoaded).matches;
        final connectionsState = context.watch<ConnectionsCubit>().state;
        if (matches.isEmpty) {
          return SizedBox(
            height: _kListHeight,
            child: Center(
              child: Text(
                'No study partners found yet. Check back soon!',
                textAlign: .center,
                style: typography.bodySmall,
              ),
            ),
          );
        }

        return SizedBox(
          height: _kListHeight,
          child: ListView.separated(
            scrollDirection: .horizontal,
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final candidate = matches[i];
              final status = connectionsState.effectiveStatus(
                candidate.connectionStatus,
                candidate.userId,
              );
              return PartnerMatchCard(
                candidate: candidate,
                connectStatus: status,
                onConnect: () =>
                    handleConnectPress(context, candidate.userId, status),
                onTap: () => context.push(
                  AppRoutes.userProfile,
                  extra: candidate.userId,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
