import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';

final smartCampusApiProvider = Provider<SmartCampusApi>((ref) {
  return SmartCampusApi(ref.watch(dioProvider));
});

class SmartCampusApi {
  SmartCampusApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String semester,
    required String section,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'semester': semester,
        'section': section,
      },
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> health() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/health');
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> listSyllabi() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/syllabus');
    return r.data ?? {};
  }

  Future<void> uploadSyllabus({
    required String title,
    required String contentText,
    required String semester,
    required String section,
  }) async {
    await _dio.post<void>(
      '/api/syllabus',
      data: {
        'title': title,
        'content_text': contentText,
        'semester': semester,
        'section': section,
      },
    );
  }

  Future<void> addWeekPlan({
    required int syllabusId,
    required int weekNumber,
    required String topicsSummary,
  }) async {
    await _dio.post<void>(
      '/api/syllabus/$syllabusId/week-plan',
      data: {'week_number': weekNumber, 'topics_summary': topicsSummary},
    );
  }

  Future<Map<String, dynamic>> listWeekPlans(int syllabusId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/syllabus/$syllabusId/week-plans',
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> fetchDailyTest({int weekNumber = 1}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/tests/daily',
      data: {'week_number': weekNumber},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> fetchWeeklyTest({required int weekNumber}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/tests/weekly',
      data: {'week_number': weekNumber},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> submitTest({
    required int paperId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/tests/$paperId/submit',
      data: {'answers': answers},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> studentAnalytics() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/analytics/student/me');
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> classAnalytics({
    required String semester,
    required String section,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/analytics/class',
      queryParameters: {'semester': semester, 'section': section},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> chat(String message) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/chat',
      data: {'message': message},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> recommendations() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/recommendations/me');
    return r.data ?? {};
  }

  Future<void> registerFaceMultipart(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    await _dio.post<void>('/api/attendance/register-face', data: form);
  }

  /// Uses same Dio baseUrl; attendance mark is typically unauthenticated kiosk flow.
  Future<Map<String, dynamic>> markAttendanceMultipart(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/attendance/mark',
      data: form,
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> todayAttendance() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/attendance/today');
    return r.data ?? {};
  }
}
