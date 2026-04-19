import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

// View Models
class TestResultModel {
  final int id;
  final String studentName;
  final String topic;
  final int score;
  final int totalQuestions;
  final DateTime? completedAt;
  final String? questionsData;
  final String? userAnswersData;
  final String? teacherFeedback;
  final String? semester;
  final String? batch;

  TestResultModel({
    required this.id,
    required this.studentName,
    required this.topic,
    required this.score,
    required this.totalQuestions,
    this.completedAt,
    this.questionsData,
    this.userAnswersData,
    this.teacherFeedback,
    this.semester,
    this.batch,
  });

  factory TestResultModel.fromJson(Map<String, dynamic> json) {
    return TestResultModel(
      id: json['id'],
      studentName: json['student_name'],
      topic: json['topic'],
      score: json['score'],
      totalQuestions: json['total_questions'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      questionsData: json['questions_data'],
      userAnswersData: json['user_answers_data'],
      teacherFeedback: json['teacher_feedback'],
      semester: json['semester'],
      batch: json['batch'],
    );
  }
}

// Providers
final testResultsProvider = FutureProvider.autoDispose<List<TestResultModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/admin/tests/results');
  final List data = response.data;
  return data.map((e) => TestResultModel.fromJson(e)).toList();
});

class AdminAssessmentsScreen extends ConsumerStatefulWidget {
  const AdminAssessmentsScreen({super.key});

  @override
  ConsumerState<AdminAssessmentsScreen> createState() => _AdminAssessmentsScreenState();
}

class _AdminAssessmentsScreenState extends ConsumerState<AdminAssessmentsScreen> {
  final _topicController = TextEditingController();
  bool _isScheduling = false;
  
  int _selectedTimeLimit = 15;
  int _selectedAttempts = 1;
  int _selectedValidityHours = 24;
  int _selectedNumQuestions = 5;
  String _selectedDifficulty = 'Mixed Mode';
  final List<String> _difficulties = ['Easy', 'Beginner', 'Moderate', 'Advanced', 'Expert', 'Mixed Mode'];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _scheduleTest() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _isScheduling = true);
    try {
      final validUntil = DateTime.now().add(Duration(hours: _selectedValidityHours)).toUtc().toIso8601String();
      final dio = ref.read(dioProvider);
      await dio.post('/admin/tests', data: {
        'topic': topic,
        'time_limit_minutes': _selectedTimeLimit,
        'valid_until': validUntil,
        'max_attempts': _selectedAttempts,
        'num_questions': _selectedNumQuestions,
        'difficulty': _selectedDifficulty,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test scheduled successfully! Students will see it in Announcements.')),
        );
        _topicController.clear();
        setState(() {
          _selectedTimeLimit = 15;
          _selectedAttempts = 1;
          _selectedValidityHours = 24;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule test: $e', style: const TextStyle(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) setState(() => _isScheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(testResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule Assessment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _topicController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter test topic (e.g. Flutter Layouts)',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedTimeLimit,
                            decoration: InputDecoration(
                              labelText: 'Time Limit',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: [5, 10, 15, 30, 60].map((e) => DropdownMenuItem(value: e, child: Text('$e mins'))).toList(),
                            onChanged: (val) => setState(() => _selectedTimeLimit = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedValidityHours,
                            decoration: InputDecoration(
                              labelText: 'Validity',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: [2, 12, 24, 48, 72].map((e) => DropdownMenuItem(value: e, child: Text('$e hrs'))).toList(),
                            onChanged: (val) => setState(() => _selectedValidityHours = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedAttempts,
                            decoration: InputDecoration(
                              labelText: 'Attempts',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: [1, 2, 3, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                            onChanged: (val) => setState(() => _selectedAttempts = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedNumQuestions,
                            decoration: InputDecoration(
                              labelText: 'Questions',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: [5, 10, 15, 20, 25].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                            onChanged: (val) => setState(() => _selectedNumQuestions = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDifficulty,
                            decoration: InputDecoration(
                              labelText: 'Difficulty',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: _difficulties.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _selectedDifficulty = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isScheduling ? null : _scheduleTest,
                        child: _isScheduling
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Schedule Test'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Student Submissions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.primaryStart),
                    onPressed: () => ref.refresh(testResultsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: resultsAsync.when(
                  data: (results) {
                    if (results.isEmpty) {
                      return GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: const Center(
                          child: Text(
                            'No student submissions yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    // Group results by Semester and Batch
                    final Map<String, List<TestResultModel>> groupedResults = {};
                    for (var res in results) {
                      final key = '${res.semester ?? "No Semester"} - ${res.batch ?? "No Batch"}';
                      groupedResults.putIfAbsent(key, () => []).add(res);
                    }

                    return ListView.builder(
                      itemCount: groupedResults.length,
                      itemBuilder: (context, groupIndex) {
                        final groupKey = groupedResults.keys.elementAt(groupIndex);
                        final groupItems = groupedResults[groupKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                groupKey,
                                style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            ...groupItems.map((res) {
                              final rawPercent = (res.score / res.totalQuestions) * 100;
                              final percent = rawPercent.round();
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _showReviewDialog(context, res),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.surface,
                                          child: Text(
                                            res.studentName[0].toUpperCase(),
                                            style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                res.studentName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Topic: ${res.topic}',
                                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                              ),
                                              if (res.teacherFeedback != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                                      const SizedBox(width: 4),
                                                      const Text('Feedback Given', style: TextStyle(fontSize: 11, color: AppColors.success)),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$percent%',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: percent >= 70 ? AppColors.success : (percent >= 50 ? AppColors.warning : AppColors.error),
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '${res.score}/${res.totalQuestions}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading results', style: const TextStyle(color: AppColors.error))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, TestResultModel result) {
    import 'dart:convert';
    final List<dynamic> questions = result.questionsData != null ? jsonDecode(result.questionsData!) : [];
    final Map<String, dynamic> answers = result.userAnswersData != null ? jsonDecode(result.userAnswersData!) : {};
    final feedbackController = TextEditingController(text: result.teacherFeedback ?? '');
    bool isSavingFeedback = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Review Submission: ${result.studentName}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Topic: ${result.topic}', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Individual Feedback', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: feedbackController,
                            maxLines: 3,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Provide feedback for the student...',
                              hintStyle: const TextStyle(color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSavingFeedback ? null : () async {
                                setModalState(() => isSavingFeedback = true);
                                try {
                                  final dio = ref.read(dioProvider);
                                  await dio.post('/admin/tests/results/${result.id}/feedback', data: {
                                    'feedback': feedbackController.text.trim(),
                                  });
                                  ref.refresh(testResultsProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save feedback: $e')));
                                  }
                                } finally {
                                  setModalState(() => isSavingFeedback = false);
                                }
                              },
                              child: isSavingFeedback 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Send Feedback'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Question Breakdown', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (questions.isEmpty)
                      const Text('Detailed question data not available.', style: TextStyle(color: AppColors.textMuted))
                    else
                      ...List.generate(questions.length, (idx) {
                        final q = questions[idx];
                        final userAns = answers[idx.toString()];
                        final isCorrect = userAns == q['correctOptionIndex'];
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: Text('Q${idx + 1}: ${q['text']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                    Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? AppColors.success : AppColors.error, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...List.generate(q['options'].length, (optIdx) {
                                  final optText = q['options'][optIdx];
                                  final isAnswered = userAns == optIdx;
                                  final isCorrectChoice = q['correctOptionIndex'] == optIdx;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCorrectChoice ? Icons.check : (isAnswered ? Icons.close : Icons.circle_outlined),
                                          size: 14,
                                          color: isCorrectChoice ? AppColors.success : (isAnswered ? AppColors.error : AppColors.textMuted),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            optText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isCorrectChoice ? AppColors.success : (isAnswered ? AppColors.error : AppColors.textSecondary),
                                              fontWeight: (isAnswered || isCorrectChoice) ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
