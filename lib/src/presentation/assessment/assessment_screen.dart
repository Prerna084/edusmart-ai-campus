import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assessment_controller.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../profile/profile_provider.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  final String? initialTopic;
  final int? scheduledTestId;

  const AssessmentScreen({super.key, this.initialTopic, this.scheduledTestId});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final TextEditingController _topicController;
  final Map<int, int> _selectedAnswers = {};

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
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  'AI Assessment',
                  style: Theme.of(context).textTheme.displayMedium,
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
                          onPressed: () async {
                            if (state.currentAssessment == null) return;
                            final total = state.currentAssessment!.questions.length;
                            if (_selectedAnswers.length < total) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please answer all questions before finishing.')),
                              );
                              return;
                            }

                            final correct = state.currentAssessment!.questions
                                .asMap()
                                .entries
                                .where((entry) => _selectedAnswers[entry.key] == entry.value.correctOptionIndex)
                                .length;
                            final percent = total == 0 ? 0 : ((correct / total) * 100).round();

                            controller.completeCurrentAssessment(_selectedAnswers);
                            _selectedAnswers.clear();

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

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Quiz completed! Score: $percent% ($correct/$total)')),
                            );
                          },
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
