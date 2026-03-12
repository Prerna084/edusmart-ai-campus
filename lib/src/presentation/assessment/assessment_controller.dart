import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/assessment/assessment.dart';
import '../../domain/assessment/generate_assessment_use_case.dart';
import '../../data/assessment/assessment_remote_datasource.dart';
import '../../data/assessment/assessment_repository_impl.dart';

// Providers
final assessmentRemoteDatasourceProvider = Provider((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return AssessmentRemoteDatasource(apiKey: apiKey);
});

final assessmentRepositoryProvider = Provider((ref) {
  final remote = ref.watch(assessmentRemoteDatasourceProvider);
  return AssessmentRepositoryImpl(remoteDatasource: remote);
});

final generateAssessmentUseCaseProvider = Provider((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return GenerateAssessmentUseCase(repo);
});

// State class
class AssessmentState {
  final bool isLoading;
  final Assessment? currentAssessment;
  final String? error;
  final List<Assessment> history;

  AssessmentState({
    this.isLoading = false,
    this.currentAssessment,
    this.error,
    this.history = const [],
  });

  AssessmentState copyWith({
    bool? isLoading,
    Assessment? currentAssessment,
    String? error,
    List<Assessment>? history,
  }) {
    return AssessmentState(
      isLoading: isLoading ?? this.isLoading,
      currentAssessment: currentAssessment ?? this.currentAssessment,
      error: error ?? this.error,
      history: history ?? this.history,
    );
  }
}

// Controller
class AssessmentController extends StateNotifier<AssessmentState> {
  final GenerateAssessmentUseCase _generateUseCase;

  AssessmentController(this._generateUseCase) : super(AssessmentState());

  Future<void> generate(String topic) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assessment = await _generateUseCase.execute(topic);
      state = state.copyWith(
        isLoading: false,
        currentAssessment: assessment,
        history: [...state.history, assessment],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = state.copyWith(currentAssessment: null, error: null);
  }
}

final assessmentControllerProvider =
    StateNotifierProvider<AssessmentController, AssessmentState>((ref) {
  final generateUseCase = ref.watch(generateAssessmentUseCaseProvider);
  return AssessmentController(generateUseCase);
});
