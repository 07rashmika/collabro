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
}
