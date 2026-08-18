import '../entities/study_area.dart';

abstract class StudyAreasRepo {
  Future<List<StudyArea>> getAllStudyAreas();

  Future<StudyArea> findOrCreateStudyArea(String name);
}
