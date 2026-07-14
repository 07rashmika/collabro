import 'package:equatable/equatable.dart';

class MatchCandidate extends Equatable {
  final String userId;
  final String name;
  final int matchScore;
  final String? topCategory;
  final List<String> matchedSkills;
  final List<String> complementarySkills;
  final String reason;

  const MatchCandidate({
    required this.userId,
    required this.name,
    required this.matchScore,
    required this.matchedSkills,
    required this.complementarySkills,
    required this.reason,
    this.topCategory,
  });

  /// Skills worth showing as chips on a match card — prefers the ones that
  /// actually drove the match (shared or complementary) over the candidate's
  /// full skill list.
  List<String> get displaySkills {
    final combined = <String>{...matchedSkills, ...complementarySkills};
    return combined.take(2).toList();
  }

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final skills = ((student['skills'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();

    final matchedSkills = ((json['matchedSkills'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    final complementarySkills = ((json['complementarySkills'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();

    String? topCategory;
    if (skills.isNotEmpty) {
      final relevantName = matchedSkills.isNotEmpty
          ? matchedSkills.first
          : (complementarySkills.isNotEmpty ? complementarySkills.first : null);
      final match = relevantName == null
          ? skills.first
          : skills.firstWhere(
              (s) => (s['skill'] as Map<String, dynamic>)['name'] == relevantName,
              orElse: () => skills.first,
            );
      topCategory = (match['skill'] as Map<String, dynamic>)['category'] as String?;
    }

    return MatchCandidate(
      userId: student['userId'] as String,
      name: student['name'] as String,
      matchScore: (json['totalScore'] as num).round(),
      matchedSkills: matchedSkills,
      complementarySkills: complementarySkills,
      reason: json['aiReason'] as String? ?? '',
      topCategory: topCategory,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    name,
    matchScore,
    matchedSkills,
    complementarySkills,
    reason,
    topCategory,
  ];
}
