import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assessment_controller.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  final TextEditingController _topicController = TextEditingController();

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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.background, Color(0xFF1E293B)],
          ),
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter a topic (e.g. Flutter, Biology...)',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.glassBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.isLoading
                                ? null
                                : () => controller.generate(_topicController.text),
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
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      title: Text(question.options[optIndex], style: const TextStyle(color: Colors.white)),
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppColors.primaryStart,
                                        child: Text(
                                          String.fromCharCode(65 + optIndex),
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Selected: ${question.options[optIndex]}'),
                                            duration: const Duration(milliseconds: 500),
                                          ),
                                        );
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
                          onPressed: () => controller.reset(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.glassBorder),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Quiz completed! Progress saved.')),
                            );
                            controller.reset();
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
