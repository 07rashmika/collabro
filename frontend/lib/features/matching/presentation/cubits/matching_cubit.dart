import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/match_candidate.dart';
import '../../domain/repos/matching_repo.dart';

part 'matching_state.dart';

class MatchingCubit extends Cubit<MatchingState> {
  final MatchingRepo matchingRepo;

  MatchingCubit({required this.matchingRepo}) : super(const MatchesInitial());

  Future<void> loadMatches({int limit = 10}) async {
    emit(const MatchesLoading());
    try {
      final matches = await matchingRepo.getMatches(limit: limit);
      emit(MatchesLoaded(matches));
    } catch (e) {
      emit(MatchesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
