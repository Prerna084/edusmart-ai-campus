import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class ScheduledTestModel {
  final int id;
  final String topic;
  final DateTime? createdAt;

  ScheduledTestModel({
    required this.id,
    required this.topic,
    this.createdAt,
  });

  factory ScheduledTestModel.fromJson(Map<String, dynamic> json) {
    return ScheduledTestModel(
      id: json['id'],
      topic: json['topic'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

final scheduledTestsProvider = FutureProvider<List<ScheduledTestModel>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/tests/scheduled');
  final List data = response.data;
  return data.map((e) => ScheduledTestModel.fromJson(e)).toList();
});
