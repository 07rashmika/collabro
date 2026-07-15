import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/features/matching/presentation/cubits/matching_cubit.dart';

import 'partner_match_card.dart';

const double _kListHeight = 244;

/// Horizontal list of real, backend-ranked study-partner suggestions.
/// Renders the loading/loaded/error/empty states of [MatchingCubit].
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
            child: Center(child: CircularProgressIndicator(color: colors.primary)),
          );
        }

        if (state is MatchesError) {
          return SizedBox(
            height: _kListHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: typography.bodySmall,
                ),
              ),
            ),
          );
        }

        final matches = (state as MatchesLoaded).matches;
        if (matches.isEmpty) {
          return SizedBox(
            height: _kListHeight,
            child: Center(
              child: Text(
                'No study partners found yet. Check back soon!',
                textAlign: TextAlign.center,
                style: typography.bodySmall,
              ),
            ),
          );
        }

        return SizedBox(
          height: _kListHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => PartnerMatchCard(
              candidate: matches[i],
              onConnect: () => showComingSoonSnackBar(context, 'Connect requests'),
            ),
          ),
        );
      },
    );
  }
}
