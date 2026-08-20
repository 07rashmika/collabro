import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/features/sessions/presentation/cubits/video_call_cubit.dart';

bool get _isIOS => !kIsWeb && Platform.isIOS;

class CallControls extends StatelessWidget {
  final ActiveCallState state;
  final bool showChat;
  final VoidCallback onToggleChat;

  const CallControls({
    super.key,
    required this.state,
    required this.showChat,
    required this.onToggleChat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<VideoCallCubit>();
    return Padding(
      padding: const .symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: .spaceEvenly,
        children: [
          _ControlButton(
            icon: state.isMicMuted ? Icons.mic_off : Icons.mic,
            active: !state.isMicMuted,
            onPressed: cubit.toggleMic,
          ),
          _ControlButton(
            icon: state.isCameraOff ? Icons.videocam_off : Icons.videocam,
            active: !state.isCameraOff,
            onPressed: cubit.toggleCamera,
          ),
          if (!_isIOS)
            _ControlButton(
              icon: Icons.screen_share,
              active: state is ScreenSharing,
              onPressed: () {
                if (state is ScreenSharing) {
                  cubit.stopScreenShare();
                } else {
                  cubit.startScreenShare();
                }
              },
            )
          else
            const _ControlButton(
              icon: Icons.screen_share_outlined,
              active: false,
              onPressed: null,
              tooltip: 'Screen share isn\'t supported on iOS yet',
            ),
          _ControlButton(
            icon: Icons.chat_bubble_outline,
            active: showChat,
            onPressed: onToggleChat,
          ),
          _ControlButton(
            icon: Icons.call_end,
            active: false,
            backgroundColor: colors.error,
            onPressed: cubit.hangUp,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    required this.active,
    this.onPressed,
    this.backgroundColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor:
            backgroundColor ??
            (active ? colors.primary : colors.backgroundElevated),
        shape: const CircleBorder(),
        padding: const .all(AppSpacing.md),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }
}
