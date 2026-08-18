import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/network/secure_storage_keys.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/profiles/domain/entities/profile.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final storage = context.read<FlutterSecureStorage>();
    final accessToken = await storage.read(key: SecureStorageKeys.accessToken);

    if (!mounted) return;

    if (accessToken == null) {
      context.go(AppRoutes.onboarding);
      return;
    }

    try {
      final authRepo = context.read<AuthRepo>();
      final user = await authRepo.getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        context.go(AppRoutes.signIn);
        return;
      }

      final profilesRepo = context.read<ProfilesRepo>();
      Profile? profile;
      try {
        profile = await profilesRepo.getMyProfile();
      } catch (e) {
        profile = null;
      }
      if (!mounted) return;
      if (profile != null && profile.isComplete) {
        context.go(AppRoutes.home, extra: user);
      } else {
        context.go(AppRoutes.profileSetup, extra: user);
      }
    } catch (e) {
      await storage.deleteAll();
      if (!mounted) return;
      context.go(AppRoutes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Text('Collabro', style: typography.displayMedium),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: colors.primary),
          ],
        ),
      ),
    );
  }
}
