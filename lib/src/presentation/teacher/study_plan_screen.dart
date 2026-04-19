import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  final int assignmentId;
  final String subjectTitle;

  const StudyPlanScreen({
    super.key,
    required this.assignmentId,
    required this.subjectTitle,
  });

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  bool _isLoading = true;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/teachers/subjects/${widget.assignmentId}/plans');
      setState(() {
        _plans = response.data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/teachers/subjects/${widget.assignmentId}/generate-plan');
      _fetchPlans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Study Plan generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.subjectTitle} - Study Plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (_plans.isEmpty)
                    _buildSelectionPrompt()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _plans.length,
                        itemBuilder: (context, index) => _buildWeekPlan(_plans[index]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectionPrompt() {
    return Expanded(
      child: Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 80, color: AppColors.primaryStart),
              const SizedBox(height: 24),
              const Text('No Study Plan Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text(
                'Let our AI analyze your syllabus and generate a structured weekly breakdown for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _generatePlan,
                icon: const Icon(Icons.bolt),
                label: const Text('Generate Plan with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekPlan(dynamic plan) {
    final Map<String, dynamic> content = json.decode(plan['content']);
    final topics = content['topics'] as List<dynamic>? ?? [];
    final objective = content['objective'] as String? ?? 'N/A';
    final sequence = content['suggested_sequence'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryStart,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('WEEK ${plan['week_number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan['title'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField('Learning Objective', objective, Icons.ads_click, AppColors.accent),
                const SizedBox(height: 16),
                _buildTagList('Topics Covered', topics, Icons.list_alt, AppColors.primaryStart),
                const SizedBox(height: 16),
                _buildSequenceList('Teaching Sequence', sequence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildTagList(String label, List<dynamic> tags, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(t.toString(), style: TextStyle(color: color, fontSize: 12)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSequenceList(String label, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text('Suggested Sequence', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.glassBorder),
                child: Center(child: Text((entry.key + 1).toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.value.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            ],
          ),
        )).toList(),
      ],
    );
  }
}
