import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/domain/entities/session_message.dart';

class CompactMessageRow extends StatelessWidget {
  final SessionMessage message;
  final bool isMine;

  const CompactMessageRow({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Padding(
      padding: const .symmetric(vertical: 2),
      child: Align(
        alignment: isMine ? .centerRight : .centerLeft,
        child: Text(
          isMine
              ? message.content
              : '${message.senderName}: ${message.content}',
          style: typography.bodySmall,
        ),
      ),
    );
  }
}
