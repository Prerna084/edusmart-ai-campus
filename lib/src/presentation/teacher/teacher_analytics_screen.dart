import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/smart_campus_api.dart';
import '../widgets/glass_container.dart';

class TeacherAnalyticsScreen extends ConsumerStatefulWidget {
  final AuthSession session;

  const TeacherAnalyticsScreen({super.key, required this.session});

  @override
  ConsumerState<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends ConsumerState<TeacherAnalyticsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sem = widget.session.semester.trim();
    final sec = widget.session.section.trim();
    if (sem.isEmpty || sec.isEmpty) {
      setState(() => _error = 'Set semester & section on your teacher profile (re-register or update backend).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(smartCampusApiProvider).classAnalytics(semester: sem, section: sec);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Class analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: AppColors.error))
                  : _data == null
                      ? const SizedBox.shrink()
                      : ListView(
                          children: [
                            Text(
                              'Students: ${_data!['student_count']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (_data!['syllabus_title'] != null)
                              Text(
                                'Syllabus: ${_data!['syllabus_title']}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            const SizedBox(height: 20),
                            Text('Class weak topics', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ...(((_data!['class_weak_topics'] as List?) ?? []).map((e) {
                              final m = e as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(m['topic']?.toString() ?? '')),
                                      Text('${m['wrong_count']} misses'),
                                    ],
                                  ),
                                ),
                              );
                            })),
                            const SizedBox(height: 20),
                            Text('Per-student averages', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ...(((_data!['combined_scores'] as List?) ?? []).map((e) {
                              final m = e as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(m['name']?.toString() ?? ''),
                                            Text(
                                              m['email']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text('${m['average_percent']}%'),
                                    ],
                                  ),
                                ),
                              );
                            })),
                          ],
                        ),
        ),
      ),
    );
  }
}
