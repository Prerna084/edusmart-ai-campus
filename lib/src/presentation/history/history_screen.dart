import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../assessment/assessment_controller.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentControllerProvider);

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
                  'Assessment History',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Review your past learning achievements.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: state.history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_edu, size: 64, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                'No assessments yet.',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.history.length,
                          itemBuilder: (context, index) {
                            final assessment = state.history[index];
                            final date = DateFormat('MMM dd, yyyy • hh:mm a').format(assessment.createdAt);
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: ListTile(
                                  title: Text(
                                    assessment.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  subtitle: Text(
                                    '$date\n${assessment.questions.length} Questions',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.primaryStart),
                                  onTap: () {
                                    // Could show details or retake
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
