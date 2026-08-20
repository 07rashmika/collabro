import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/domain/entities/call_participant.dart';
import 'package:frontend/features/sessions/presentation/components/video_tile.dart';
import 'package:frontend/features/sessions/presentation/cubits/video_call_cubit.dart';

CallParticipant? _findParticipant(
  List<CallParticipant> participants,
  String userId,
) {
  for (final p in participants) {
    if (p.userId == userId) return p;
  }
  return null;
}

class VideoGrid extends StatelessWidget {
  final ActiveCallState state;
  final RTCVideoRenderer localRenderer;
  final bool localRendererReady;
  final Map<String, RTCVideoRenderer> remoteRenderers;

  const VideoGrid({
    super.key,
    required this.state,
    required this.localRenderer,
    required this.localRendererReady,
    required this.remoteRenderers,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final remoteEntries = remoteRenderers.entries.toList();
    final isSharingScreen = state is ScreenSharing;

    if (remoteEntries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: localRendererReady
                  ? VideoTile(
                      renderer: localRenderer,
                      participant: CallParticipant(
                        userId: 'local',
                        name: 'You',
                        isMicMuted: state.isMicMuted,
                        isCameraOff: state.isCameraOff,
                        isScreenSharing: isSharingScreen,
                      ),
                      mirror: !isSharingScreen,
                    )
                  : Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Waiting for others to join…', style: typography.bodyMedium),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: switch (remoteEntries.length) {
              1 => 1,
              2 || 3 || 4 => 2,
              _ => 3,
            },
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 3 / 4,
          ),
          itemCount: remoteEntries.length,
          itemBuilder: (context, i) {
            final userId = remoteEntries[i].key;
            final renderer = remoteEntries[i].value;
            final participant = _findParticipant(state.participants, userId);
            return VideoTile(
              renderer: renderer,
              participant: participant,
              mirror: false,
            );
          },
        ),
        if (localRendererReady)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            width: 100,
            height: 140,
            child: VideoTile(
              renderer: localRenderer,
              participant: CallParticipant(
                userId: 'local',
                name: 'You',
                isMicMuted: state.isMicMuted,
                isCameraOff: state.isCameraOff,
                isScreenSharing: isSharingScreen,
              ),
              mirror: !isSharingScreen,
            ),
          ),
      ],
    );
  }
}
