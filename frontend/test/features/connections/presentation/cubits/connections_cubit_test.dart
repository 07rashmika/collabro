import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/widgets/connect_button.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';

class MockConnectionsRepo extends Mock implements ConnectionsRepo {}

void main() {
  late MockConnectionsRepo connectionsRepo;

  setUp(() {
    connectionsRepo = MockConnectionsRepo();
  });

  ConnectionsCubit buildCubit() =>
      ConnectionsCubit(connectionsRepo: connectionsRepo);

  group('ConnectionsCubit.sendRequest', () {
    blocTest<ConnectionsCubit, ConnectionsState>(
      'records an optimistic "requested" override for that user',
      setUp: () {
        when(
          () => connectionsRepo.sendRequest('u2'),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.sendRequest('u2'),
      expect: () => [
        const ConnectionsState(overrides: {'u2': ConnectStatus.requested}),
      ],
      verify: (cubit) {
        expect(
          cubit.state.effectiveStatus('NONE', 'u2'),
          ConnectStatus.requested,
        );
      },
    );
  });

  group('ConnectionsCubit.cancelRequest', () {
    blocTest<ConnectionsCubit, ConnectionsState>(
      'clears the override back to "none" for that user',
      setUp: () {
        when(
          () => connectionsRepo.cancelRequest('u2'),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.cancelRequest('u2'),
      expect: () => [
        const ConnectionsState(overrides: {'u2': ConnectStatus.none}),
      ],
    );
  });

  group('ConnectionsCubit.removeConnection', () {
    blocTest<ConnectionsCubit, ConnectionsState>(
      'overrides the user to "none" after removing the connection',
      setUp: () {
        when(
          () => connectionsRepo.removeConnection('u3'),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.removeConnection('u3'),
      expect: () => [
        const ConnectionsState(overrides: {'u3': ConnectStatus.none}),
      ],
      verify: (_) {
        verify(() => connectionsRepo.removeConnection('u3')).called(1);
      },
    );
  });

  group('ConnectionsCubit.clearOverrides', () {
    blocTest<ConnectionsCubit, ConnectionsState>(
      'resets to an empty state when overrides exist',
      setUp: () {
        when(
          () => connectionsRepo.sendRequest('u2'),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.sendRequest('u2');
        cubit.clearOverrides();
      },
      expect: () => [
        const ConnectionsState(overrides: {'u2': ConnectStatus.requested}),
        const ConnectionsState(),
      ],
    );

    blocTest<ConnectionsCubit, ConnectionsState>(
      'emits nothing when there are no overrides to clear',
      build: buildCubit,
      act: (cubit) => cubit.clearOverrides(),
      expect: () => <ConnectionsState>[],
    );
  });
}
