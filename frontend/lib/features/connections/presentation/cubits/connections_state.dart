part of 'connections_cubit.dart';

class ConnectionsState extends Equatable {
  final Map<String, ConnectStatus> overrides;

  const ConnectionsState({this.overrides = const {}});

  ConnectionsState copyWith({Map<String, ConnectStatus>? overrides}) =>
      ConnectionsState(overrides: overrides ?? this.overrides);

  ConnectStatus effectiveStatus(String backendConnectionStatus, String userId) {
    final override = overrides[userId];
    if (override != null) return override;
    if (backendConnectionStatus == 'CONNECTED') return .connected;
    if (backendConnectionStatus == 'REQUESTED') return .requested;
    return .none;
  }

  @override
  List<Object?> get props => [overrides];
}
