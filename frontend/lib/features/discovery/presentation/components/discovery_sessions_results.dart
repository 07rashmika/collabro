import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';

class DiscoverySessionsResults extends StatelessWidget {
  final List<StudySession> sessions;
  final String emptyMessage;
  final ValueChanged<StudySession> onOpen;

  const DiscoverySessionsResults({
    super.key,
    required this.sessions,
    required this.emptyMessage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: .center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => SessionListCard(
        session: sessions[i],
        onTap: () => onOpen(sessions[i]),
        onToggleSave: () =>
            context.read<DiscoveryCubit>().toggleSaveSession(sessions[i]),
      ),
    );
  }
}
