import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../assessment/assessment_screen.dart';
import '../attendance/attendance_screen.dart';
import '../dashboard/attendance_dashboard_screen.dart';
import '../profile/profile_provider.dart';
import 'scheduled_tests_provider.dart';

class HomeScreen extends ConsumerWidget {
  final Function(int)? onTabNavigation;

  const HomeScreen({super.key, this.onTabNavigation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final name = profileAsync.valueOrNull?.name ?? 'Welcome!';
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final greeting = _greeting();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryStart.withOpacity(0.1),
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: AppColors.primaryStart,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Upcoming Class Card (Hero)
              GlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Happening Now', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Advanced UI Development',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('10:00 AM - 11:30 AM', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Room 304', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Quick Actions Grid
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.face,
                      label: 'Mark\nAttendance',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.quiz,
                      label: 'AI\nAssessment',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AssessmentScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.bar_chart,
                      label: 'Live\nDashboard',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceDashboardScreen()));
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Announcements
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final testsAsync = ref.watch(scheduledTestsProvider);
                  return testsAsync.when(
                    data: (tests) {
                      if (tests.isEmpty) {
                        return GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: const Text('No new announcements at this time.', style: TextStyle(color: AppColors.textSecondary)),
                        );
                      }
                      return Column(
                        children: tests.map((test) {
                          final isExpired = test.validUntil != null && DateTime.now().isAfter(test.validUntil!);
                          final isSubmitted = test.userAttempts >= test.maxAttempts;
                          final isLocked = isExpired || isSubmitted;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: isLocked 
                                ? null 
                                : () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AssessmentScreen(
                                      initialTopic: test.topic,
                                      scheduledTestId: test.id,
                                      timeLimitMinutes: test.timeLimitMinutes,
                                    )));
                                  },
                              child: GlassContainer(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isLocked ? AppColors.surface : AppColors.primaryStart.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isLocked ? Icons.lock : Icons.notifications_active, 
                                        color: isLocked ? AppColors.textMuted : AppColors.primaryStart
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Scheduled Test: ${test.topic}',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
                                              decoration: isLocked && isExpired ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isSubmitted ? 'Submitted.' : (isExpired ? 'Expired.' : 'Tap to attempt this test.'),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isSubmitted ? AppColors.success : (isExpired ? AppColors.error : AppColors.textSecondary),
                                              fontWeight: isLocked ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLocked) const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error loading announcements', style: const TextStyle(color: AppColors.error)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primaryStart),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
