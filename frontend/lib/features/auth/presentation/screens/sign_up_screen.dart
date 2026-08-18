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

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthCubit(authRepo: context.read<AuthRepo>()),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms of Service and Privacy Policy.',
          ),
        ),
      );
      return;
    }
    context.read<AuthCubit>().register(
      _nameController.text.trim(),
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
              showErrorSnackBar(context);
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
                  const AuthHeader(tagline: 'ELEVATE YOUR STUDY SESSIONS'),
                  const SizedBox(height: AppSpacing.xxxl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
                    decoration: BoxDecoration(
                      color: colors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        AuthTabBar(
                          active: AuthTab.createAccount,
                          onSignInTap: () => context.go(AppRoutes.signIn),
                          onCreateAccountTap: () {},
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Alex Johnson',
                          icon: Icons.person_outline,
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Email',
                          hint: 'alex.j@example.com',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
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
                            if (value == null || value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: .start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                activeColor: colors.primary,
                                onChanged: (value) => setState(
                                  () => _agreedToTerms = value ?? false,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Padding(
                                padding: const .only(top: AppSpacing.xs),
                                child: Text(
                                  'I agree to the Terms of Service and Privacy Policy.',
                                  style: typography.bodySmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return PrimaryButton(
                              label: 'Create Account',
                              isLoading: state is AuthLoading,
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
                              isLoading: state is AuthLoading,
                              onPressed: () =>
                                  context.read<AuthCubit>().loginWithGoogle(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: .center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: typography.bodySmall,
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.signIn),
                        child: Text(
                          'Sign In',
                          style: typography.bodySmall.copyWith(
                            color: colors.primaryLight,
                            fontWeight: .w600,
                          ),
                        ),
                      ),
                    ],
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
