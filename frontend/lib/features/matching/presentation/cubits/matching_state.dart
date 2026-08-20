part of 'matching_cubit.dart';

sealed class MatchingState extends Equatable {
  const MatchingState();

  @override
  List<Object?> get props => [];
}

final class MatchesInitial extends MatchingState {
  const MatchesInitial();
}

final class MatchesLoading extends MatchingState {
  const MatchesLoading();
}

final class MatchesLoaded extends MatchingState {
  final List<MatchCandidate> matches;
  const MatchesLoaded(this.matches);

  @override
  List<Object?> get props => [matches];
}

final class MatchesError extends MatchingState {
  final String message;
  const MatchesError(this.message);

  @override
  List<Object?> get props => [message];
}
