import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class SyllabusScreen extends StatelessWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Courses',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Track your academic progress',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              _buildCourseCard(
                context,
                title: 'Data Structures & Algorithms',
                tag: 'CS301',
                progress: 0.65,
                nextModule: 'Binary Search Trees',
              ),
              const SizedBox(height: 20),
              _buildCourseCard(
                context,
                title: 'Artificial Intelligence',
                tag: 'CS405',
                progress: 0.40,
                nextModule: 'Neural Networks Basics',
              ),
              const SizedBox(height: 20),
              _buildCourseCard(
                context,
                title: 'User Interface Design',
                tag: 'DES201',
                progress: 0.85,
                nextModule: 'Figma Prototyping',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context, {
    required String title,
    required String tag,
    required double progress,
    required String nextModule,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: Theme.of(context).textTheme.bodyMedium),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.8 ? AppColors.success : AppColors.primaryStart),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Up Next', style: Theme.of(context).textTheme.bodySmall),
                    Text(nextModule, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
