import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/features/sessions/presentation/components/call_controls.dart';
import 'package:frontend/features/sessions/presentation/components/chat_drawer.dart';
import 'package:frontend/features/sessions/presentation/components/reconnecting_banner.dart';
import 'package:frontend/features/sessions/presentation/components/video_grid.dart';
import 'package:frontend/features/sessions/presentation/cubits/video_call_cubit.dart';

class ActiveCallView extends StatelessWidget {
  final ActiveCallState state;
  final RTCVideoRenderer localRenderer;
  final bool localRendererReady;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool showChat;
  final VoidCallback onToggleChat;
  final VoidCallback onCloseChat;

  const ActiveCallView({
    super.key,
    required this.state,
    required this.localRenderer,
    required this.localRendererReady,
    required this.remoteRenderers,
    required this.showChat,
    required this.onToggleChat,
    required this.onCloseChat,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (state.isReconnecting) const ReconnectingBanner(),
            Expanded(
              child: VideoGrid(
                state: state,
                localRenderer: localRenderer,
                localRendererReady: localRendererReady,
                remoteRenderers: remoteRenderers,
              ),
            ),
            CallControls(
              state: state,
              showChat: showChat,
              onToggleChat: onToggleChat,
            ),
          ],
        ),
        if (showChat) ChatDrawer(onClose: onCloseChat),
      ],
    );
  }
}
