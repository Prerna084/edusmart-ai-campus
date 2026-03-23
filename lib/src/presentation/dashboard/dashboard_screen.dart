import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Dashboard',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor your progress and recent activities.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              
              // Key Metrics Row
              Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 32),
                          const SizedBox(height: 8),
                          Text('85%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Avg Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.flash_on, color: AppColors.warning, size: 32),
                          const SizedBox(height: 8),
                          Text('12', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Quizzes Taken', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.timeline, color: AppColors.primaryStart, size: 32),
                          const SizedBox(height: 8),
                          Text('+15%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Improvement', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Mock Activity List
              Expanded(
                child: ListView.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final activities = ['Completed Flutter Quiz', 'Read Architecture Guide', 'Practiced Dart Algorithms', 'Viewed History'];
                    final scores = ['90%', '-', '100%', '-'];
                    final icons = [Icons.quiz, Icons.menu_book, Icons.code, Icons.history];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.surface,
                              child: Icon(icons[index], color: AppColors.primaryStart, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(activities[index], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('2 hours ago', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (scores[index] != '-') 
                              Text(scores[index], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
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
      ),
    );
  }
}
