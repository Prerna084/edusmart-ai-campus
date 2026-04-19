import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../profile/profile_provider.dart';

class ScheduledTestModel {
  final int id;
  final String topic;
  final DateTime? createdAt;
  final int timeLimitMinutes;
  final DateTime? validUntil;
  final int numQuestions;
  final String difficulty;
  String? teacherFeedback;
  int userAttempts;

  ScheduledTestModel({
    required this.id,
    required this.topic,
    this.createdAt,
    this.timeLimitMinutes = 15,
    this.validUntil,
    this.max_attempts = 1,
    this.numQuestions = 5,
    this.difficulty = 'Mixed Mode',
    this.teacherFeedback,
    this.userAttempts = 0,
  });

  factory ScheduledTestModel.fromJson(Map<String, dynamic> json) {
    return ScheduledTestModel(
      id: json['id'],
      topic: json['topic'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      timeLimitMinutes: json['time_limit_minutes'] ?? 15,
      validUntil: json['valid_until'] != null ? DateTime.parse(json['valid_until']) : null,
      max_attempts: json['max_attempts'] ?? 1,
      numQuestions: json['num_questions'] ?? 5,
      difficulty: json['difficulty'] ?? 'Mixed Mode',
    );
  }
}

final scheduledTestsProvider = FutureProvider<List<ScheduledTestModel>>((ref) async {
  final dio = ref.read(dioProvider);
  
  // Fetch tests
  final response = await dio.get('/tests/scheduled');
  final List data = response.data;
  final tests = data.map((e) => ScheduledTestModel.fromJson(e)).toList();

  // Fetch personal attempts if user logged in successfully mapping
  final profileStrId = ref.read(profileProvider).valueOrNull?.studentId;
  final userId = int.tryParse(profileStrId ?? '');
  
  if (userId != null) {
      try {
          final attemptRes = await dio.get('/student/$userId/tests/results');
          final List attemptData = attemptRes.data;
          final attemptsMap = {
              for (var a in attemptData) a['test_id'] as int: a['attempts'] as int
          };
          final feedbackMap = {
              for (var a in attemptData) a['test_id'] as int: a['teacher_feedback'] as String?
          };
          for (var test in tests) {
              test.userAttempts = attemptsMap[test.id] ?? 0;
              test.teacherFeedback = feedbackMap[test.id];
          }
      } catch (e) {
          // Soft fail
      }
  }

  return tests;
});
