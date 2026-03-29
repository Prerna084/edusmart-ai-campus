import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_base_url.dart';

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = resolveApiBaseUrl();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // Add interceptors here if needed (e.g., for logging or auth tokens)
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});
