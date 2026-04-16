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

  TestResultModel({
    required this.id,
    required this.studentName,
    required this.topic,
    required this.score,
    required this.totalQuestions,
    this.completedAt,
  });

  factory TestResultModel.fromJson(Map<String, dynamic> json) {
    return TestResultModel(
      id: json['id'],
      studentName: json['student_name'],
      topic: json['topic'],
      score: json['score'],
      totalQuestions: json['total_questions'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
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
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final res = results[index];
                        final rawPercent = (res.score / res.totalQuestions) * 100;
                        final percent = rawPercent.round();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
}
