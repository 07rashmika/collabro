import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:go_router/go_router.dart';

class JoinSessionScreen extends StatelessWidget {
  const JoinSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SessionsCubit(sessionsRepo: context.read<SessionsRepo>()),
      child: const _JoinSessionView(),
    );
  }
}

class _JoinSessionView extends StatefulWidget {
  const _JoinSessionView();

  @override
  State<_JoinSessionView> createState() => _JoinSessionViewState();
}

class _JoinSessionViewState extends State<_JoinSessionView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordRequired = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _join(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<SessionsCubit>().joinSessionByCode(
      joinCode: _codeController.text.trim(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<SessionsCubit, SessionsState>(
          listener: (context, state) {
            if (state is SessionSaved) {
              context.pop(true);
            } else if (state is SessionPasswordRequired) {
              setState(() => _passwordRequired = true);
              showErrorSnackBar(context, state.message);
            } else if (state is SessionsError) {
              showErrorSnackBar(context, state.message);
            }
          },
          child: SingleChildScrollView(
            padding: const .symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          'Join Session',
                          textAlign: .center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Enter the code someone shared with you to join their session.',
                    style: typography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Join Code',
                    hint: 'e.g. cmrkispam0002n3jq8r1qi6n5',
                    icon: Icons.link,
                    controller: _codeController,
                    textInputAction: .next,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Join code is required'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: _passwordRequired
                        ? 'Password (required)'
                        : 'Password (if any)',
                    hint: 'Leave blank unless the host set one',
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                    obscurable: true,
                    validator: (value) {
                      if (_passwordRequired &&
                          (value == null || value.trim().isEmpty)) {
                        return 'This session requires a password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BlocBuilder<SessionsCubit, SessionsState>(
                    builder: (context, state) {
                      return PrimaryButton(
                        label: 'Join Session',
                        isLoading: state is SessionSaving,
                        onPressed: () => _join(context),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
