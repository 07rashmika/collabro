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
import 'package:frontend/features/auth/presentation/cubits/verify_reset_code_cubit.dart';
import 'package:go_router/go_router.dart';

class VerifyResetCodeScreen extends StatelessWidget {
  final String email;

  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          VerifyResetCodeCubit(authRepo: context.read<AuthRepo>()),
      child: _VerifyResetCodeView(email: email),
    );
  }
}

class _VerifyResetCodeView extends StatefulWidget {
  final String email;

  const _VerifyResetCodeView({required this.email});

  @override
  State<_VerifyResetCodeView> createState() => _VerifyResetCodeViewState();
}

class _VerifyResetCodeViewState extends State<_VerifyResetCodeView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<VerifyResetCodeCubit>().verify(
      email: widget.email,
      code: _codeController.text.trim(),
    );
  }

  Future<void> _resendCode(BuildContext context) async {
    setState(() => _resending = true);
    final colors = AppColors.of(context);
    try {
      await context.read<AuthRepo>().requestPasswordReset(widget.email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code resent.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      if (context.mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<VerifyResetCodeCubit, VerifyResetCodeState>(
          listener: (context, state) {
            if (state is VerifyResetCodeVerified) {
              context.push(
                AppRoutes.resetPassword,
                extra: state.resetToken,
              );
            } else if (state is VerifyResetCodeError) {
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
                    tagline: 'Enter the code we emailed you.',
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
                        Text('Enter code', style: typography.titleLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Code sent to ${widget.email}',
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: '6-digit code',
                          hint: '123456',
                          icon: Icons.pin_outlined,
                          controller: _codeController,
                          keyboardType: .number,
                          textInputAction: .done,
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Code is required';
                            if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                              return 'Enter the 6-digit code';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: .centerRight,
                          child: TextButton(
                            onPressed: _resending
                                ? null
                                : () => _resendCode(context),
                            child: Text(
                              _resending ? 'Resending…' : 'Resend code',
                              style: typography.bodySmall.copyWith(
                                color: colors.primaryLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        BlocBuilder<VerifyResetCodeCubit, VerifyResetCodeState>(
                          builder: (context, state) {
                            return PrimaryButton(
                              label: 'Confirm code',
                              trailingIcon: Icons.arrow_forward,
                              isLoading: state is VerifyResetCodeLoading,
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
