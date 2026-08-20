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
import 'package:frontend/features/auth/presentation/cubits/forgot_password_cubit.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ForgotPasswordCubit(authRepo: context.read<AuthRepo>()),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordCubit>().sendCode(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
          listener: (context, state) {
            if (state is ForgotPasswordCodeSent) {
              context.push(AppRoutes.verifyResetCode, extra: state.email);
            } else if (state is ForgotPasswordError) {
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
                    tagline: "We'll email you a code to reset your password.",
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
                        Text('Forgot password', style: typography.titleLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Enter the email you sign in with.',
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: 'Email',
                          hint: 'alex.j@example.com',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: .emailAddress,
                          textInputAction: .done,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                          builder: (context, state) {
                            return PrimaryButton(
                              label: 'Send reset code',
                              trailingIcon: Icons.arrow_forward,
                              isLoading: state is ForgotPasswordLoading,
                              onPressed: () => _submit(context),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'Back to sign in',
                        style: typography.bodySmall.copyWith(
                          color: colors.primaryLight,
                        ),
                      ),
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
