import '../entities/study_area.dart';

abstract class StudyAreasRepo {
  Future<List<StudyArea>> getAllStudyAreas();

  /// Returns the existing study area if [name] already matches one
  /// (case-insensitive), otherwise creates it.
  Future<StudyArea> findOrCreateStudyArea(String name);
}
