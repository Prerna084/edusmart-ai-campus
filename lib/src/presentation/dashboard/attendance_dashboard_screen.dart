import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

// ---------------------------------------------------------------------------
// Provider — fetches today's attendance from the backend
// ---------------------------------------------------------------------------
final todayAttendanceProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<dynamic>>('/attendance/today');
      return (response.data ?? []).cast<Map<String, dynamic>>();
    });

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AttendanceDashboardScreen extends ConsumerWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(todayAttendanceProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Text(
                "Today's Check-ins",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                _formattedToday(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Attendance List ──────────────────────────────────────────
              Expanded(
                child: attendanceAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryStart,
                    ),
                  ),
                  error: (err, _) => _ErrorView(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(todayAttendanceProvider),
                  ),
                  data: (records) {
                    if (records.isEmpty) {
                      return _EmptyView(
                        onRefresh: () =>
                            ref.invalidate(todayAttendanceProvider),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Summary badge ──────────────────────────────
                        GlassContainer(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people_alt,
                                color: AppColors.success,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${records.length} student${records.length == 1 ? '' : 's'} present',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'Marked via Face Recognition',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Records list ───────────────────────────────
                        Expanded(
                          child: ListView.separated(
                            itemCount: records.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return _AttendanceCard(record: record);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedToday() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ---------------------------------------------------------------------------
// Attendance Card Widget
// ---------------------------------------------------------------------------
class _AttendanceCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const _AttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final name = record['student_name']?.toString() ?? 'Unknown';
    final time = record['time']?.toString() ?? '--:--';
    final status = record['status']?.toString() ?? 'Present';

    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryStart.withOpacity(0.15),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primaryStart,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Name & time ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Status badge ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error View
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Could not load attendance data.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty View
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: AppColors.primaryStart.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No attendance yet today.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Students can check in using Face Recognition\nfrom the home screen.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
