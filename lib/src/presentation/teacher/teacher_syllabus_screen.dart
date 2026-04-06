import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/smart_campus_api.dart';
import '../widgets/glass_container.dart';

class TeacherSyllabusScreen extends ConsumerStatefulWidget {
  final AuthSession session;

  const TeacherSyllabusScreen({super.key, required this.session});

  @override
  ConsumerState<TeacherSyllabusScreen> createState() => _TeacherSyllabusScreenState();
}

class _TeacherSyllabusScreenState extends ConsumerState<TeacherSyllabusScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _semester = TextEditingController();
  final _section = TextEditingController();
  final _weekNum = TextEditingController(text: '1');
  final _weekTopics = TextEditingController();
  int? _selectedSyllabusId;
  bool _busy = false;
  String? _msg;
  List<Map<String, dynamic>> _syllabi = [];

  @override
  void initState() {
    super.initState();
    _semester.text = widget.session.semester;
    _section.text = widget.session.section;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _semester.dispose();
    _section.dispose();
    _weekNum.dispose();
    _weekTopics.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(smartCampusApiProvider).listSyllabi();
      final list = (data['syllabi'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (!mounted) return;
      setState(() {
        _syllabi = list;
        _selectedSyllabusId ??= list.isNotEmpty ? list.first['id'] as int? : null;
        _busy = false;
        _msg = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msg = e.toString();
      });
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    try {
      await ref.read(smartCampusApiProvider).uploadSyllabus(
            title: _title.text.trim().isEmpty ? 'Syllabus' : _title.text.trim(),
            contentText: _content.text.trim(),
            semester: _semester.text.trim(),
            section: _section.text.trim(),
          );
      _content.clear();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addWeek() async {
    final sid = _selectedSyllabusId;
    if (sid == null) {
      setState(() => _msg = 'Select or create a syllabus first.');
      return;
    }
    final wn = int.tryParse(_weekNum.text) ?? 1;
    setState(() => _busy = true);
    try {
      await ref.read(smartCampusApiProvider).addWeekPlan(
            syllabusId: sid,
            weekNumber: wn,
            topicsSummary: _weekTopics.text.trim(),
          );
      _weekTopics.clear();
      if (mounted) setState(() => _msg = 'Week plan saved.');
    } catch (e) {
      if (mounted) setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Syllabus & week plans'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_msg!, style: const TextStyle(color: AppColors.error)),
              ),
            Text('Your syllabi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ..._syllabi.map(
              (s) => RadioListTile<int>(
                value: s['id'] as int,
                groupValue: _selectedSyllabusId,
                onChanged: (v) => setState(() => _selectedSyllabusId = v),
                title: Text(s['title']?.toString() ?? ''),
                subtitle: Text('${s['semester']} · ${s['section']}'),
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('New syllabus upload', style: Theme.of(context).textTheme.titleMedium),
                  TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(controller: _semester, decoration: const InputDecoration(labelText: 'Semester')),
                  TextField(controller: _section, decoration: const InputDecoration(labelText: 'Section')),
                  TextField(
                    controller: _content,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Full syllabus text',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _upload,
                      child: const Text('Upload syllabus'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Week plan', style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    controller: _weekNum,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Week number'),
                  ),
                  TextField(
                    controller: _weekTopics,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Topics / objectives for this week',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _addWeek,
                      child: const Text('Save week plan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
