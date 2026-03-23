import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import '../assessment/assessment_screen.dart';
import '../attendance/attendance_screen.dart';

class HomeScreen extends ConsumerWidget {
  final Function(int)? onTabNavigation;

  const HomeScreen({super.key, this.onTabNavigation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        'Good Morning,',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Alex Student',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person, size: 32, color: AppColors.primaryStart),
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
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Announcements
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryStart.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications, color: AppColors.primaryStart),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exam Schedule Released',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mid-term exams start from Nov 15th.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
