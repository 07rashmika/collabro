import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/components/auth_header.dart';
import 'package:frontend/features/auth/presentation/components/auth_tab_bar.dart';
import 'package:frontend/features/auth/presentation/components/google_sign_in_button.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/profiles/domain/entities/profile.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthCubit(authRepo: context.read<AuthRepo>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              Profile? profile;
              try {
                profile = await context.read<ProfilesRepo>().getMyProfile();
              } catch (_) {
                profile = null;
              }
              if (!context.mounted) return;
              if (profile != null && profile.isComplete) {
                context.go(AppRoutes.home, extra: state.user);
              } else {
                context.go(AppRoutes.profileSetup, extra: state.user);
              }
            } else if (state is AuthError) {
              showErrorSnackBar(context, state.message);
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
                  const AuthHeader(tagline: 'Focus together. Achieve more.'),
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
                        AuthTabBar(
                          active: .signIn,
                          onSignInTap: () {},
                          onCreateAccountTap: () =>
                              context.go(AppRoutes.signUp),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: 'Email',
                          hint: 'alex.j@example.com',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: .emailAddress,
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
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Password',
                          hint: '••••••••••••',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          obscurable: true,
                          textInputAction: .done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: .centerRight,
                          child: TextButton(
                            onPressed: () =>
                                context.push(AppRoutes.forgotPassword),
                            child: Text(
                              'Forgot Password?',
                              style: typography.bodySmall.copyWith(
                                color: colors.primaryLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return PrimaryButton(
                              label: 'Sign In',
                              trailingIcon: Icons.arrow_forward,
                              isLoading:
                                  state is AuthLoading &&
                                  state.action == AuthAction.emailPassword,
                              onPressed: () => _submit(context),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(child: Divider(color: colors.border)),
                            Padding(
                              padding: const .symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              child: Text('or', style: typography.bodySmall),
                            ),
                            Expanded(child: Divider(color: colors.border)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return GoogleSignInButton(
                              isLoading:
                                  state is AuthLoading &&
                                  state.action == AuthAction.google,
                              onPressed: () =>
                                  context.read<AuthCubit>().loginWithGoogle(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    "By continuing, you agree to Collabro's Terms of Service and Privacy Policy.",
                    textAlign: TextAlign.center,
                    style: typography.caption,
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
