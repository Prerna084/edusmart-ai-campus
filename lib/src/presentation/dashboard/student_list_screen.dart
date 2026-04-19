import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

// ---------------------------------------------------------------------------
// Provider — fetches all registered students from the backend
// ---------------------------------------------------------------------------
final studentListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get<List<dynamic>>('/students');
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registered Students'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(studentListProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryStart),
          ),
          error: (err, _) => _ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(studentListProvider),
          ),
          data: (students) {
            if (students.isEmpty) {
              return _EmptyView(onRefresh: () => ref.invalidate(studentListProvider));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary banner ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryStart.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: AppColors.primaryStart,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${students.length} student${students.length == 1 ? '' : 's'} registered',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Full academic metadata monitoring',
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
                ),
                const SizedBox(height: 16),

                // ── Student Cards ────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _StudentCard(
                        student: student,
                        onDelete: () => _confirmDelete(context, ref, student),
                        onResetId: () => _confirmResetId(context, ref, student),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> student,
  ) async {
    final name = student['name']?.toString() ?? 'this student';
    final id = student['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Student?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('This will permanently remove "$name" and all their data.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete<dynamic>('/students/$id');
        ref.invalidate(studentListProvider);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  Future<void> _confirmResetId(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> student,
  ) async {
    final id = student['id'];
    final name = student['name'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset College ID?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('This will clear the College ID for "$name", allowing them to set a new one.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset ID'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.post('/admin/students/$id/reset-college-id');
        ref.invalidate(studentListProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('College ID cleared successfully.')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resetting: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Student Card
// ---------------------------------------------------------------------------
class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onDelete;
  final VoidCallback onResetId;

  const _StudentCard({required this.student, required this.onDelete, required this.onResetId});

  @override
  Widget build(BuildContext context) {
    final name = student['name']?.toString() ?? 'Unknown';
    final email = student['email']?.toString() ?? 'No Email';
    final collegeId = student['college_id']?.toString() ?? 'Not Set';
    final batch = student['batch']?.toString() ?? '—';
    final sem = student['semester']?.toString() ?? '—';
    final sec = student['section']?.toString() ?? '—';
    final totalAttendance = student['total_attendance'] ?? 0;

    final initials = name.trim().split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryStart.withOpacity(0.1),
                child: Text(initials, style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                    Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                      child: Text('College ID: $collegeId', style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('$totalAttendance days', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.glassBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metaChip('Batch', batch),
              _metaChip('Semester', sem),
              _metaChip('Section', sec),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onResetId,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.primaryStart.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Reset ID', style: TextStyle(color: AppColors.primaryStart, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(val, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
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
          const Text('Could not load student list.', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
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
          Icon(Icons.person_off_rounded, size: 80, color: AppColors.primaryStart.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No students registered yet.', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

