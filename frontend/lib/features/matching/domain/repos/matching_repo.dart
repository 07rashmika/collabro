import '../entities/match_candidate.dart';

abstract class MatchingRepo {
  Future<List<MatchCandidate>> getMatches({int limit = 10});
}
