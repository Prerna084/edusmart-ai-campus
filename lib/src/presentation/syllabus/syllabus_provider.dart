import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

// ─── Models ────────────────────────────────────────────────────────────────

class TopicSummary {
  final int id;
  final String title;

  const TopicSummary({required this.id, required this.title});

  factory TopicSummary.fromJson(Map<String, dynamic> json) =>
      TopicSummary(id: json['id'], title: json['title']);
}

class CourseModule {
  final int id;
  final String title;
  final bool isCompleted;
  final List<TopicSummary> topics;

  const CourseModule({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.topics,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) => CourseModule(
        id: json['id'],
        title: json['title'],
        isCompleted: json['is_completed'] ?? false,
        topics: (json['topics'] as List)
            .map((t) => TopicSummary.fromJson(t))
            .toList(),
      );
}

class Course {
  final int id;
  final String title;
  final String tag;
  final double progress;
  final String? nextModule;
  final List<CourseModule> modules;

  const Course({
    required this.id,
    required this.title,
    required this.tag,
    required this.progress,
    this.nextModule,
    required this.modules,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'],
        title: json['title'],
        tag: json['tag'],
        progress: (json['progress'] as num).toDouble(),
        nextModule: json['next_module'],
        modules: (json['modules'] as List)
            .map((m) => CourseModule.fromJson(m))
            .toList(),
      );
}

class TopicDetail {
  final int id;
  final String title;
  final String? theory;
  final String? videoUrl;
  final String? docUrl;
  final String? codeExample;
  final String? practiceTask;

  const TopicDetail({
    required this.id,
    required this.title,
    this.theory,
    this.videoUrl,
    this.docUrl,
    this.codeExample,
    this.practiceTask,
  });

  factory TopicDetail.fromJson(Map<String, dynamic> json) => TopicDetail(
        id: json['id'],
        title: json['title'],
        theory: json['theory'],
        videoUrl: json['video_url'],
        docUrl: json['doc_url'],
        codeExample: json['code_example'],
        practiceTask: json['practice_task'],
      );
}

// ─── Providers ─────────────────────────────────────────────────────────────

/// Fetches all courses with modules from GET /syllabus
final syllabusProvider = FutureProvider<List<Course>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/syllabus');
  return (response.data as List).map((e) => Course.fromJson(e)).toList();
});

/// Fetches a single topic's rich content from GET /syllabus/topic/{id}
final topicDetailProvider =
    FutureProvider.family<TopicDetail, int>((ref, topicId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/syllabus/topic/$topicId');
  return TopicDetail.fromJson(response.data);
});
