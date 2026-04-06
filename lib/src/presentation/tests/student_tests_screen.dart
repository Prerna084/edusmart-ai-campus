import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/api/smart_campus_api.dart';
import '../widgets/glass_container.dart';

class StudentTestsScreen extends ConsumerStatefulWidget {
  const StudentTestsScreen({super.key});

  @override
  ConsumerState<StudentTestsScreen> createState() => _StudentTestsScreenState();
}

class _StudentTestsScreenState extends ConsumerState<StudentTestsScreen> {
  String _mode = 'daily';
  late final TextEditingController _weekController;
  Map<String, dynamic>? _paper;
  final Map<int, int> _selections = {};
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _weekController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  int get _weekNumber => int.tryParse(_weekController.text) ?? 1;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _paper = null;
      _selections.clear();
      _result = null;
    });
    try {
      final api = ref.read(smartCampusApiProvider);
      final data = _mode == 'daily'
          ? await api.fetchDailyTest(weekNumber: _weekNumber)
          : await api.fetchWeeklyTest(weekNumber: _weekNumber);
      if (!mounted) return;
      setState(() {
        _paper = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    final paper = _paper;
    if (paper == null) return;
    final qs = (paper['questions'] as List?) ?? [];
    final answers = <Map<String, dynamic>>[];
    for (final q in qs) {
      final m = q as Map<String, dynamic>;
      final id = m['id'] as int;
      final sel = _selections[id];
      if (sel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer every question before submitting.')),
        );
        return;
      }
      answers.add({'question_id': id, 'selected_index': sel});
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(smartCampusApiProvider);
      final res = await api.submitTest(
        paperId: paper['paper_id'] as int,
        answers: answers,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Adaptive tests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily (3 Q) & weekly (10 Q) tests use your syllabus and week plan.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Daily'),
                    selected: _mode == 'daily',
                    onSelected: (v) {
                      if (v) setState(() => _mode = 'daily');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Weekly'),
                    selected: _mode == 'weekly',
                    onSelected: (v) {
                      if (v) setState(() => _mode = 'weekly');
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _weekController,
                      decoration: const InputDecoration(
                        labelText: 'Week',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _load,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Load / refresh test'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: ${_result!['score']}/${_result!['max_score']} '
                        '(${_result!['accuracy_percent']}%)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Weak topics: ${(_result!['weak_topics'] as List?)?.join(', ') ?? '—'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _paper == null
                    ? const Center(child: Text('Load a test to begin'))
                    : ListView.builder(
                        itemCount: (_paper!['questions'] as List).length,
                        itemBuilder: (context, i) {
                          final q = (_paper!['questions'] as List)[i] as Map<String, dynamic>;
                          final id = q['id'] as int;
                          final opts = (q['options'] as List).map((e) => e.toString()).toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q${i + 1}: ${q['text']}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(opts.length, (oi) {
                                    return RadioListTile<int>(
                                      value: oi,
                                      groupValue: _selections[id],
                                      onChanged: (v) {
                                        setState(() => _selections[id] = v!);
                                      },
                                      title: Text(opts[oi], style: const TextStyle(color: AppColors.textPrimary)),
                                      dense: true,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_paper != null && _result == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit answers'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
