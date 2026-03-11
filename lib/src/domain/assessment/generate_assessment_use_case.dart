import 'assessment.dart';
import 'assessment_repository.dart';

class GenerateAssessmentUseCase {
  final AssessmentRepository repository;

  GenerateAssessmentUseCase(this.repository);

  Future<Assessment> execute(String topic) {
    return repository.generateAssessment(topic);
  }
}
