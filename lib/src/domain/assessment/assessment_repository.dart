import 'assessment.dart';

abstract class AssessmentRepository {
  Future<Assessment> generateAssessment(String topic);
  Future<void> saveAssessment(Assessment assessment);
  Future<List<Assessment>> getAssessmentHistory();
}
