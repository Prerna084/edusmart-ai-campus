import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../assessment/assessment_controller.dart';

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

final dashboardProvider = Provider<DashboardMetrics>((ref) {
  final attempts = ref.watch(quizAttemptProvider);

  final quizzesTaken = attempts.length;
  final averageScore = quizzesTaken == 0
      ? 0
      : (attempts.map((a) => a.scorePercent).reduce((a, b) => a + b) / quizzesTaken).round();

  String improvement = '0%';
  if (quizzesTaken >= 2) {
    final latest = attempts.first.scorePercent;
    final previous = attempts[1].scorePercent;
    final delta = latest - previous;
    improvement = delta >= 0 ? '+$delta%' : '$delta%';
  }

  final recentActivities = attempts.take(8).map((attempt) {
    return ActivityItem(
      title: attempt.title,
      timeAgo: _relativeTime(attempt.completedAt),
      score: '${attempt.scorePercent}%',
      iconType: ActivityIconType.quiz,
    );
  }).toList();

  return DashboardMetrics(
    averageScore: averageScore,
    quizzesTaken: quizzesTaken,
    improvement: improvement,
    recentActivities: recentActivities,
  );
});

String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
