import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

// Providers for fetching data
final adminTeachersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/admin/teachers');
  return response.data as List<dynamic>;
});

final adminSubjectsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/syllabus');
  return response.data as List<dynamic>;
});

class AdminCourseAssignmentScreen extends ConsumerStatefulWidget {
  const AdminCourseAssignmentScreen({super.key});

  @override
  ConsumerState<AdminCourseAssignmentScreen> createState() => _AdminCourseAssignmentScreenState();
}

class _AdminCourseAssignmentScreenState extends ConsumerState<AdminCourseAssignmentScreen> {
  int? _selectedTeacherId;
  int? _selectedSubjectId;
  
  String _selectedSemester = '1';
  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];
  
  String _selectedBatch = '2023-2027';
  final List<String> _batches = ['2021-2025', '2022-2026', '2023-2027', '2024-2028', '2025-2029'];
  
  String _selectedSection = 'A';
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  bool _isAssigning = false;

  Future<void> _assignSubject() async {
    if (_selectedTeacherId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a Teacher and a Subject.')),
      );
      return;
    }

    setState(() => _isAssigning = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/admin/assign-subject', data: {
        'teacher_id': _selectedTeacherId,
        'subject_id': _selectedSubjectId,
        'semester': _selectedSemester,
        'batch': _selectedBatch,
        'section': _selectedSection,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course successfully assigned to teacher!', style: TextStyle(color: Colors.white))),
        );
        // Optionally reset the form
        setState(() {
          _selectedTeacherId = null;
          _selectedSubjectId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign course: $e', style: const TextStyle(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(adminTeachersProvider);
    final subjectsAsync = ref.watch(adminSubjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Courses',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Map teachers to specific subjects and classes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Teacher', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                    const SizedBox(height: 8),
                    teachersAsync.when(
                      data: (teachers) {
                        if (teachers.isEmpty) {
                          return const Text('No teachers found.', style: TextStyle(color: AppColors.error));
                        }
                        return DropdownButtonFormField<int>(
                          value: _selectedTeacherId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          hint: const Text('Choose a teacher...', style: TextStyle(color: AppColors.textMuted)),
                          items: teachers.map((t) => DropdownMenuItem<int>(
                            value: t['id'],
                            child: Text('${t['name']} (${t['email']})'),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedTeacherId = val),
                          dropdownColor: AppColors.surface,
                          isExpanded: true,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error loading teachers: $e', style: const TextStyle(color: AppColors.error)),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text('Select Subject', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                    const SizedBox(height: 8),
                    subjectsAsync.when(
                      data: (subjects) {
                        if (subjects.isEmpty) {
                          return const Text('No subjects found in syllabus.', style: TextStyle(color: AppColors.error));
                        }
                        return DropdownButtonFormField<int>(
                          value: _selectedSubjectId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          hint: const Text('Choose a subject...', style: TextStyle(color: AppColors.textMuted)),
                          items: subjects.map((s) => DropdownMenuItem<int>(
                            value: s['id'],
                            child: Text(s['title']),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedSubjectId = val),
                          dropdownColor: AppColors.surface,
                          isExpanded: true,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error loading subjects: $e', style: const TextStyle(color: AppColors.error)),
                    ),

                    const SizedBox(height: 24),
                    const Text('Class Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSemester,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: _semesters.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _selectedSemester = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSection,
                            decoration: InputDecoration(
                              labelText: 'Section',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: _sections.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _selectedSection = val!),
                            dropdownColor: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBatch,
                      decoration: InputDecoration(
                        labelText: 'Batch (e.g. 2023-2027)',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: _batches.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedBatch = val!),
                      dropdownColor: AppColors.surface,
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAssigning ? null : _assignSubject,
                        child: _isAssigning
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Assign Course'),
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
