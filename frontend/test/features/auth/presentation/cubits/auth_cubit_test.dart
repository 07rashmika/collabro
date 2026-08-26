import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

class MockAuthRepo extends Mock implements AuthRepo {}

class MockUsersRepo extends Mock implements UsersRepo {}

void main() {
  late MockAuthRepo authRepo;
  late MockUsersRepo usersRepo;

  const user = AppUser(id: 'u1', name: 'Ada', email: 'ada@example.com');

  setUp(() {
    authRepo = MockAuthRepo();
    usersRepo = MockUsersRepo();
  });

  AuthCubit buildCubit() =>
      AuthCubit(authRepo: authRepo, usersRepo: usersRepo);

  group('AuthCubit.login', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, success] when login succeeds',
      setUp: () {
        when(
          () => authRepo.loginWithEmailPassword('ada@example.com', 'secret'),
        ).thenAnswer((_) async => user);
      },
      build: buildCubit,
      act: (cubit) => cubit.login('ada@example.com', 'secret'),
      expect: () => [
        const AuthLoading(AuthAction.emailPassword),
        const AuthSuccess(user),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] with a clean message when login fails',
      setUp: () {
        when(
          () => authRepo.loginWithEmailPassword(any(), any()),
        ).thenThrow(Exception('Invalid credentials'));
      },
      build: buildCubit,
      act: (cubit) => cubit.login('ada@example.com', 'wrong'),
      expect: () => [
        const AuthLoading(AuthAction.emailPassword),
        const AuthError('Invalid credentials'),
      ],
    );
  });

  group('AuthCubit.register', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, success] when registration succeeds',
      setUp: () {
        when(
          () => authRepo.registerWithEmailPassword(any(), any(), any()),
        ).thenAnswer((_) async => user);
      },
      build: buildCubit,
      act: (cubit) => cubit.register('Ada', 'ada@example.com', 'secret'),
      expect: () => [
        const AuthLoading(AuthAction.emailPassword),
        const AuthSuccess(user),
      ],
    );
  });

  group('AuthCubit.loginWithGoogle', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, success] when Google sign-in succeeds',
      setUp: () {
        when(() => authRepo.loginWithGoogle()).thenAnswer((_) async => user);
      },
      build: buildCubit,
      act: (cubit) => cubit.loginWithGoogle(),
      expect: () => [
        const AuthLoading(AuthAction.google),
        const AuthSuccess(user),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] when the Google sign-in flow is cancelled',
      setUp: () {
        when(
          () => authRepo.loginWithGoogle(),
        ).thenThrow(Exception('Sign-in cancelled'));
      },
      build: buildCubit,
      act: (cubit) => cubit.loginWithGoogle(),
      expect: () => [
        const AuthLoading(AuthAction.google),
        const AuthError('Sign-in cancelled'),
      ],
    );
  });

  group('AuthCubit.logout', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, loggedOut] and calls authRepo.logout',
      setUp: () {
        when(() => authRepo.logout()).thenAnswer((_) async {});
        when(
          () => usersRepo.unregisterDeviceToken(any()),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.logout(),
      expect: () => [
        const AuthLoading(AuthAction.logout),
        const AuthLoggedOut(),
      ],
      verify: (_) {
        verify(() => authRepo.logout()).called(1);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] when authRepo.logout fails',
      setUp: () {
        when(
          () => authRepo.logout(),
        ).thenThrow(Exception('Network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.logout(),
      expect: () => [
        const AuthLoading(AuthAction.logout),
        const AuthError('Network error'),
      ],
    );
  });
}
