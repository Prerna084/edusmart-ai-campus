import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityIconType {
  quiz,
  book,
  code,
  history,
}

extension ActivityIconMapping on ActivityIconType {
  IconData get iconData {
    switch (this) {
      case ActivityIconType.quiz:
        return Icons.quiz;
      case ActivityIconType.book:
        return Icons.menu_book;
      case ActivityIconType.code:
        return Icons.code;
      case ActivityIconType.history:
        return Icons.history;
    }
  }
}

class ActivityItem {
  final String title;
  final String timeAgo;
  final String? score; // If null, display '-'
  final ActivityIconType iconType;

  const ActivityItem({
    required this.title,
    required this.timeAgo,
    this.score,
    required this.iconType,
  });
}

class DashboardMetrics {
  final int averageScore;
  final int quizzesTaken;
  final String improvement;
  final List<ActivityItem> recentActivities;

  const DashboardMetrics({
    required this.averageScore,
    required this.quizzesTaken,
    required this.improvement,
    required this.recentActivities,
  });
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardMetrics>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    state = const AsyncValue.loading();
    
    try {
      // Simulate network request latency
      await Future.delayed(const Duration(milliseconds: 800));

      final metrics = DashboardMetrics(
        averageScore: 88,
        quizzesTaken: 14,
        improvement: '+18%',
        recentActivities: [
          const ActivityItem(
            title: 'Completed Flutter State Quiz',
            timeAgo: '1 hour ago',
            score: '92%',
            iconType: ActivityIconType.quiz,
          ),
          const ActivityItem(
            title: 'Read Architecture Guide',
            timeAgo: '3 hours ago',
            score: null,
            iconType: ActivityIconType.book,
          ),
          const ActivityItem(
            title: 'Practiced Dart Algorithms',
            timeAgo: 'Yesterday',
            score: '100%',
            iconType: ActivityIconType.code,
          ),
          const ActivityItem(
            title: 'Reviewed Syllabus Status',
            timeAgo: 'Yesterday',
            score: null,
            iconType: ActivityIconType.history,
          ),
        ],
      );

      state = AsyncValue.data(metrics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMetrics();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardMetrics>>((ref) {
  return DashboardNotifier();
});
