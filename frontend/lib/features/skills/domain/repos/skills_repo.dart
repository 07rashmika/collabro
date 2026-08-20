import '../entities/skill.dart';

abstract class SkillsRepo {
  Future<List<Skill>> getAllSkills();

  Future<Skill> findOrCreateSkill(String name);

  Future<List<String>> searchSkills(String query, {int count = 10});
}
