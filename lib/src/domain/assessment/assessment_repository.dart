import 'assessment.dart';

abstract class AssessmentRepository {
  Future<Assessment> generateAssessment(String topic, {String difficulty = 'Mixed Mode', int numQuestions = 5});
  Future<void> saveAssessment(Assessment assessment);
  Future<List<Assessment>> getAssessmentHistory();
}
