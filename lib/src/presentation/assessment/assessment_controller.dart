import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/assessment/assessment.dart';
import '../../domain/assessment/generate_assessment_use_case.dart';
import '../../data/assessment/assessment_remote_datasource.dart';
import '../../data/assessment/assessment_repository_impl.dart';

// Providers
final assessmentRemoteDatasourceProvider = Provider((ref) {
  const dartDefineKey = String.fromEnvironment('GEMINI_API_KEY');
  final dotenvKey = dotenv.env['GEMINI_API_KEY'];
  
  final apiKey = dartDefineKey.isNotEmpty ? dartDefineKey : (dotenvKey ?? '');
  
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

class QuizAttempt {
  final String assessmentId;
  final String title;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctAnswers;
  final int scorePercent;

  const QuizAttempt({
    required this.assessmentId,
    required this.title,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.scorePercent,
  });
}

class QuizAttemptNotifier extends StateNotifier<List<QuizAttempt>> {
  QuizAttemptNotifier() : super(const []);

  void addAttempt(QuizAttempt attempt) {
    state = [attempt, ...state];
  }
}

final quizAttemptProvider =
    StateNotifierProvider<QuizAttemptNotifier, List<QuizAttempt>>((ref) {
  return QuizAttemptNotifier();
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
  final Ref _ref;
  final GenerateAssessmentUseCase _generateUseCase;

  AssessmentController(this._ref, this._generateUseCase) : super(AssessmentState());

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

  void completeCurrentAssessment(Map<int, int> selectedAnswers) {
    final assessment = state.currentAssessment;
    if (assessment == null) return;

    var correct = 0;
    for (var i = 0; i < assessment.questions.length; i++) {
      final selected = selectedAnswers[i];
      if (selected != null && selected == assessment.questions[i].correctOptionIndex) {
        correct++;
      }
    }

    final total = assessment.questions.length;
    final scorePercent = total == 0 ? 0 : ((correct / total) * 100).round();

    final completedAssessment = Assessment(
      id: assessment.id,
      title: assessment.title,
      description: assessment.description,
      createdAt: assessment.createdAt,
      questions: assessment.questions,
      score: scorePercent,
    );

    _ref.read(quizAttemptProvider.notifier).addAttempt(
      QuizAttempt(
        assessmentId: assessment.id,
        title: assessment.title,
        completedAt: DateTime.now(),
        totalQuestions: total,
        correctAnswers: correct,
        scorePercent: scorePercent,
      ),
    );

    final updatedHistory = [...state.history];
    if (updatedHistory.isNotEmpty && updatedHistory.last.id == assessment.id) {
      updatedHistory[updatedHistory.length - 1] = completedAssessment;
    }

    state = state.copyWith(currentAssessment: null, history: updatedHistory, error: null);
  }
}

final assessmentControllerProvider =
    StateNotifierProvider<AssessmentController, AssessmentState>((ref) {
  final generateUseCase = ref.watch(generateAssessmentUseCaseProvider);
  return AssessmentController(ref, generateUseCase);
});
