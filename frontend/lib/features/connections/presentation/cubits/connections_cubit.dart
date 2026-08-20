import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/widgets/connect_button.dart';

import '../../domain/repos/connections_repo.dart';

part 'connections_state.dart';

class ConnectionsCubit extends Cubit<ConnectionsState> {
  final ConnectionsRepo connectionsRepo;

  ConnectionsCubit({required this.connectionsRepo})
    : super(const ConnectionsState());

  Future<void> sendRequest(String userId) async {
    await connectionsRepo.sendRequest(userId);
    emit(
      state.copyWith(
        overrides: {...state.overrides, userId: ConnectStatus.requested},
      ),
    );
  }

  Future<void> cancelRequest(String userId) async {
    await connectionsRepo.cancelRequest(userId);
    emit(
      state.copyWith(
        overrides: {...state.overrides, userId: ConnectStatus.none},
      ),
    );
  }

  Future<void> removeConnection(String userId) async {
    await connectionsRepo.removeConnection(userId);
    emit(
      state.copyWith(
        overrides: {...state.overrides, userId: ConnectStatus.none},
      ),
    );
  }

  /// Drops all optimistic overrides so the next backend-fetched status wins
  /// — call this whenever something may have changed a connection's status
  /// from the OTHER side (e.g. a request was accepted or declined), since
  /// an override set from this side's own action would otherwise mask that
  /// change indefinitely.
  void clearOverrides() {
    if (state.overrides.isEmpty) return;
    emit(const ConnectionsState());
  }
}
