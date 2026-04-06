import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api/smart_campus_api.dart';
import '../widgets/glass_container.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(smartCampusApiProvider).recommendations();
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
        title: const Text('Study plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Weak topics (ranked)', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...(((_data!['ranked_weak_topics'] as List?) ?? []).map((e) {
                        final m = e as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Text('#${m['priority']}'),
                                const SizedBox(width: 12),
                                Expanded(child: Text(m['topic']?.toString() ?? '')),
                                Text('${m['wrong_rate']}%'),
                              ],
                            ),
                          ),
                        );
                      })),
                      const SizedBox(height: 24),
                      Text('Actions', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...(((_data!['improvement_actions'] as List?) ?? []).map((e) {
                        final m = e as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['topic']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text('Revision: ${m['revision']}'),
                                const SizedBox(height: 4),
                                Text('Practice: ${m['practice']}'),
                              ],
                            ),
                          ),
                        );
                      })),
                    ],
                  ),
      ),
    );
  }
}
