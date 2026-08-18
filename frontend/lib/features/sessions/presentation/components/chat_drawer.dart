import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/presentation/components/compact_message_row.dart';
import 'package:frontend/features/sessions/presentation/cubits/session_chat_cubit.dart';

class ChatDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const ChatDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundMedium,
          borderRadius: .vertical(top: .circular(AppSpacing.radiusLg)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const .all(AppSpacing.sm),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text('Chat', style: typography.titleLarge),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close, color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SessionChatCubit, SessionChatState>(
                builder: (context, chatState) {
                  if (chatState is! ChatConnected) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }
                  return ListView.builder(
                    padding: const .symmetric(horizontal: AppSpacing.md),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, i) {
                      final message = chatState.messages[i];
                      return CompactMessageRow(
                        message: message,
                        isMine: message.senderId == chatState.currentUserId,
                      );
                    },
                  );
                },
              ),
            ),
            const _ChatInput(),
          ],
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final controller = TextEditingController();
    return Padding(
      padding: const .all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: typography.bodyMedium.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: colors.backgroundInput,
                contentPadding: const .symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: .circular(AppSpacing.radiusFull),
                  borderSide: .none,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isEmpty) return;
                context.read<SessionChatCubit>().sendMessage(text.trim());
                controller.clear();
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              context.read<SessionChatCubit>().sendMessage(text);
              controller.clear();
            },
            icon: Icon(Icons.send, color: colors.primary),
          ),
        ],
      ),
    );
  }
}
