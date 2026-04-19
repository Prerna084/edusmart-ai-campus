import 'assessment.dart';
import 'assessment_repository.dart';

class GenerateAssessmentUseCase {
  final AssessmentRepository repository;

  GenerateAssessmentUseCase(this.repository);

  Future<Assessment> execute(String topic, {String difficulty = 'Mixed Mode', int numQuestions = 5}) {
    return repository.generateAssessment(topic, difficulty: difficulty, numQuestions: numQuestions);
  }
}
