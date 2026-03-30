import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import 'syllabus_provider.dart';
import 'topic_detail_screen.dart';

class SyllabusScreen extends ConsumerWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCourses = ref.watch(syllabusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: asyncCourses.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryStart),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Unable to load syllabus.\nMake sure the backend is running.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(syllabusProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStart,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (courses) => RefreshIndicator(
            color: AppColors.primaryStart,
            onRefresh: () async => ref.invalidate(syllabusProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Courses', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text('Track your academic progress',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) =>
                        _buildCourseCard(context, course: courses[index]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, {required Course course}) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(course.title, style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(course.tag,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),

          // Progress
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: Theme.of(context).textTheme.bodyMedium),
              Text('${(course.progress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: course.progress,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
                course.progress > 0.8 ? AppColors.success : AppColors.primaryStart),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),

          // Modules list
          const SizedBox(height: 20),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Text('Modules', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...course.modules.map((mod) => _buildModuleRow(context, module: mod)),
        ],
      ),
    );
  }

  Widget _buildModuleRow(BuildContext context, {required CourseModule module}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          if (module.topics.isNotEmpty) {
            // Navigate to the first topic in this module
            _showModuleTopics(context, module);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                module.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: module.isCompleted ? AppColors.success : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: module.isCompleted ? TextDecoration.lineThrough : null,
                        color: module.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                ),
              ),
              if (module.topics.isNotEmpty) ...[
                Text('${module.topics.length} topic${module.topics.length > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showModuleTopics(BuildContext context, CourseModule module) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(module.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            Text('Select a topic to begin studying',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const Divider(color: AppColors.glassBorder),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: module.topics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final topic = module.topics[idx];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // close bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(
                            topicId: topic.id,
                            topicTitle: topic.title,
                          ),
                        ),
                      );
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryStart.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.article_outlined,
                                color: AppColors.primaryStart, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(topic.title,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
