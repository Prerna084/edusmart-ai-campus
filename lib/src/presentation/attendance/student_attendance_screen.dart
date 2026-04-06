import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../profile/profile_provider.dart';
import '../widgets/glass_container.dart';

final studentAttendanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, studentId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get<Map<String, dynamic>>('/attendance/$studentId');
  return response.data ?? <String, dynamic>{};
});

class StudentAttendanceScreen extends ConsumerWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryStart)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Profile error: $e')),
      ),
      data: (profile) {
        final studentId = int.tryParse(profile.studentId.trim());
        if (studentId == null) {
          return _InvalidStudentIdView(studentIdValue: profile.studentId);
        }

        final attendanceAsync = ref.watch(studentAttendanceProvider(studentId));
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('My Attendance'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(studentAttendanceProvider(studentId)),
                icon: const Icon(Icons.refresh),
              )
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: attendanceAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryStart),
                ),
                error: (error, _) => _AttendanceErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(studentAttendanceProvider(studentId)),
                ),
                data: (payload) {
                  final summary = payload['summary'] as Map<String, dynamic>? ?? const {};
                  final recordsRaw = (payload['attendance'] as List?) ?? const [];
                  final records = recordsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                  final student = payload['student'] as Map<String, dynamic>? ?? const {};
                  final studentName = student['name']?.toString() ?? profile.name;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance Overview', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 8),
                      Text(studentName, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 20),
                      _SummaryCards(summary: summary),
                      const SizedBox(height: 20),
                      Text('History', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Expanded(
                        child: records.isEmpty
                            ? const Center(
                                child: Text(
                                  'No attendance records yet.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                itemCount: records.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, index) => _StudentAttendanceCard(record: records[index]),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalDays = summary['total_days']?.toString() ?? '0';
    final presentDays = summary['present_days']?.toString() ?? '0';
    final percentage = summary['attendance_percentage']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(child: _MetricCard(label: 'Total Days', value: totalDays)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(label: 'Present', value: presentDays)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(label: 'Rate', value: '$percentage%')),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const _StudentAttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = record['date']?.toString() ?? '-';
    final time = record['time']?.toString() ?? '-';
    final status = record['status']?.toString() ?? 'Present';
    final isPresent = status.toLowerCase() == 'present';

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? AppColors.success : AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: isPresent ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidStudentIdView extends StatelessWidget {
  final String studentIdValue;

  const _InvalidStudentIdView({required this.studentIdValue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Attendance profile not linked yet.',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Student ID is "$studentIdValue". Enroll face attendance first so backend user ID is saved.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AttendanceErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textSecondary, size: 52),
            const SizedBox(height: 8),
            const Text('Failed to load attendance', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
