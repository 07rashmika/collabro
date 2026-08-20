import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/components/auth_header.dart';
import 'package:frontend/features/auth/presentation/cubits/reset_password_cubit.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatelessWidget {
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ResetPasswordCubit(authRepo: context.read<AuthRepo>()),
      child: _ResetPasswordView(resetToken: resetToken),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  final String resetToken;

  const _ResetPasswordView({required this.resetToken});

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<ResetPasswordCubit>().reset(
      resetToken: widget.resetToken,
      newPassword: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<ResetPasswordCubit, ResetPasswordState>(
          listener: (context, state) {
            if (state is ResetPasswordSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset. Please sign in.'),
                ),
              );
              context.go(AppRoutes.signIn);
            } else if (state is ResetPasswordError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: colors.error,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const .symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Align(
                    alignment: .centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const AuthHeader(
                    tagline: 'Code confirmed. Choose a new password.',
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Container(
                    padding: const .all(AppSpacing.cardPaddingLarge),
                    decoration: BoxDecoration(
                      color: colors.backgroundCard,
                      borderRadius: .circular(AppSpacing.radiusXl),
                      border: .all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Text('New password', style: typography.titleLarge),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: 'New password',
                          hint: '••••••••••••',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          obscurable: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Confirm new password',
                          hint: '••••••••••••',
                          icon: Icons.lock_outline,
                          controller: _confirmController,
                          obscurable: true,
                          textInputAction: .done,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
                          builder: (context, state) {
                            return PrimaryButton(
                              label: 'Reset password',
                              trailingIcon: Icons.check,
                              isLoading: state is ResetPasswordLoading,
                              onPressed: () => _submit(context),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
