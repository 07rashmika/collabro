import '../entities/skill.dart';

abstract class SkillsRepo {
  Future<List<Skill>> getAllSkills();

  /// Returns the existing skill if [name] already matches one
  /// (case-insensitive), otherwise creates it.
  Future<Skill> findOrCreateSkill(String name);

  /// Live typeahead suggestions from the apilayer Skills API — bare names,
  /// not yet local [Skill] rows. Pick one via [findOrCreateSkill].
  Future<List<String>> searchSkills(String query, {int count = 10});
}
