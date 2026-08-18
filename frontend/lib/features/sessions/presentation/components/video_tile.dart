import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/domain/entities/call_participant.dart';

class VideoTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final CallParticipant? participant;
  final bool mirror;

  const VideoTile({
    super.key,
    required this.renderer,
    required this.participant,
    required this.mirror,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          border: .all(color: colors.border, width: 1.5),
        ),
        child: Stack(
          fit: .expand,
          children: [
            if (participant?.isCameraOff != true)
              RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit: .RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Icon(
                  Icons.videocam_off,
                  color: colors.textTertiary,
                  size: 32,
                ),
              ),
            if (participant != null)
              Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  padding: const .symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.overlay,
                    borderRadius: .circular(AppSpacing.radiusXs),
                  ),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      if (participant!.isMicMuted)
                        const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: AppSpacing.iconSm,
                        ),
                      if (participant!.isScreenSharing)
                        const Padding(
                          padding: .only(left: 2),
                          child: Icon(
                            Icons.screen_share,
                            color: Colors.white,
                            size: AppSpacing.iconSm,
                          ),
                        ),
                      Padding(
                        padding: const .only(left: 2),
                        child: Text(
                          participant!.name,
                          style: typography.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
