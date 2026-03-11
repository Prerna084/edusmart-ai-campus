import '../../domain/assessment/assessment.dart';
import '../../domain/assessment/assessment_repository.dart';
import 'assessment_remote_datasource.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  final AssessmentRemoteDatasource remoteDatasource;
  final List<Assessment> _history = [];

  AssessmentRepositoryImpl({required this.remoteDatasource});

  @override
  Future<Assessment> generateAssessment(String topic) async {
    final assessment = await remoteDatasource.generateAssessment(topic);
    _history.add(assessment);
    return assessment;
  }

  @override
  Future<List<Assessment>> getAssessmentHistory() async {
    return _history;
  }

  @override
  Future<void> saveAssessment(Assessment assessment) async {
    // In a real app, save to Firebase or local DB
    if (!_history.contains(assessment)) {
      _history.add(assessment);
    }
  }
}
