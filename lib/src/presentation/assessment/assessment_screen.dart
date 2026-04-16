import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'assessment_controller.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../profile/profile_provider.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  final String? initialTopic;
  final int? scheduledTestId;
  final int? timeLimitMinutes;

  const AssessmentScreen({super.key, this.initialTopic, this.scheduledTestId, this.timeLimitMinutes});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final TextEditingController _topicController;
  final Map<int, int> _selectedAnswers = {};
  Timer? _timer;
  int _timeLeftSeconds = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(assessmentControllerProvider.notifier).generate(widget.initialTopic!);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _topicController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (widget.timeLimitMinutes == null || widget.timeLimitMinutes! <= 0) return;
    setState(() {
      _timeLeftSeconds = widget.timeLimitMinutes! * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftSeconds > 0) {
        if (mounted) setState(() => _timeLeftSeconds--);
      } else {
        timer.cancel();
        _submitTest(isAuto: true);
      }
    });
  }

  String _formatTime() {
    final m = _timeLeftSeconds ~/ 60;
    final s = _timeLeftSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitTest({bool isAuto = false}) async {
    if (_isSubmitting) return;
    final state = ref.read(assessmentControllerProvider);
    final controller = ref.read(assessmentControllerProvider.notifier);

    if (state.currentAssessment == null) return;
    final total = state.currentAssessment!.questions.length;

    if (!isAuto && _selectedAnswers.length < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before finishing.')),
      );
      return;
    }

    _isSubmitting = true;
    _timer?.cancel();

    final correct = state.currentAssessment!.questions
        .asMap()
        .entries
        .where((entry) => _selectedAnswers[entry.key] == entry.value.correctOptionIndex)
        .length;
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();

    controller.completeCurrentAssessment(_selectedAnswers);
    
    if (widget.scheduledTestId != null) {
      try {
        final dio = ref.read(dioProvider);
        final userId = int.tryParse(ref.read(profileProvider).valueOrNull?.studentId ?? '') ?? 0;
        if (userId > 0) {
          await dio.post(
            '/tests/${widget.scheduledTestId}/submit',
            data: {
              'user_id': userId,
              'score': correct,
              'total_questions': total,
            },
          );
        }
      } catch (e) {
        debugPrint('Failed to submit result: $e');
      }
    }

    _selectedAnswers.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAuto ? 'Time is up! Auto-submitted. Score: $percent%' : 'Quiz completed! Score: $percent% ($correct/$total)')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(assessmentControllerProvider, (prev, next) {
      if (prev?.currentAssessment == null && next.currentAssessment != null) {
        if (_timer == null) {
          _startTimer();
        }
      }
    });

    final state = ref.watch(assessmentControllerProvider);
    final controller = ref.read(assessmentControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Assessment',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    if (_timer != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _timeLeftSeconds < 60 ? AppColors.error.withOpacity(0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _timeLeftSeconds < 60 ? AppColors.error : AppColors.primaryStart),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer, color: _timeLeftSeconds < 60 ? AppColors.error : AppColors.primaryStart, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(),
                              style: TextStyle(
                                color: _timeLeftSeconds < 60 ? AppColors.error : AppColors.primaryStart,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Challenge yourself with AI-generated questions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (state.currentAssessment == null) ...[
                  // Intro section
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _topicController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Enter a topic (e.g. Flutter, Biology...)',
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    _selectedAnswers.clear();
                                    controller.generate(_topicController.text);
                                  },
                            child: state.isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Generate Quiz'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Quiz questions
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.currentAssessment!.questions.length,
                      itemBuilder: (context, index) {
                        final question = state.currentAssessment!.questions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${index + 1}: ${question.text}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(
                                  question.options.length,
                                  (optIndex) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(question.options[optIndex], style: const TextStyle(color: AppColors.textPrimary)),
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: _selectedAnswers[index] == optIndex
                                            ? AppColors.success
                                            : AppColors.primaryStart,
                                        child: Text(
                                          String.fromCharCode(65 + optIndex),
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedAnswers[index] = optIndex;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _selectedAnswers.clear();
                            controller.reset();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.textMuted),
                            foregroundColor: AppColors.textPrimary,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _submitTest(isAuto: false),
                          child: const Text('Finish Quiz'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
