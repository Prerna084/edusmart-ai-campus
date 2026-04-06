import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class TeacherHomeScreen extends StatelessWidget {
  final AuthSession session;

  const TeacherHomeScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher hub', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                '${session.name} · Sem ${session.semester} · Sec ${session.section}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Upload syllabus (semester + section).\n'
                      '2. Add week plans (topics per week).\n'
                      '3. Students receive daily (3Q) and weekly (10Q) tests.\n'
                      '4. Review class analytics for weak topics.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
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
