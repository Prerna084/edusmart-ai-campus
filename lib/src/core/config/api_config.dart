import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _normalizeBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Candidate base URLs for the Flask API (no trailing slash).
///
/// Supports multiple URLs by setting `FLASK_BASE_URL` to a comma-separated list, e.g.
/// `http://10.0.2.2:5000,http://127.0.0.1:5000`.
final apiBaseUrlCandidatesProvider = Provider<List<String>>((ref) {
  final fromEnv = dotenv.env['FLASK_BASE_URL']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final parts = fromEnv.split(',').map(_normalizeBaseUrl).where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      final defaults = <String>[];
      if (kIsWeb) {
        defaults.add('http://127.0.0.1:5000');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        defaults.addAll(const ['http://127.0.0.1:5000']);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        defaults.addAll(const ['http://10.0.2.2:5000']);
      } else {
        defaults.addAll(const ['http://10.0.2.2:5000', 'http://127.0.0.1:5000']);
      }

      final merged = <String>[...parts];
      for (final d in defaults) {
        if (!merged.contains(d)) merged.add(d);
      }
      return merged;
    }
  }

  // Reasonable defaults:
  // - Android emulator: 10.0.2.2 points to the host machine.
  // - iOS simulator: 127.0.0.1 points to the host machine.
  // - Fallback for other platforms uses both.
  if (kIsWeb) return const ['http://127.0.0.1:5000'];

  if (defaultTargetPlatform == TargetPlatform.android) {
    return const ['http://10.0.2.2:5000', 'http://127.0.0.1:5000'];
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const ['http://127.0.0.1:5000', 'http://10.0.2.2:5000'];
  }

  return const ['http://10.0.2.2:5000', 'http://127.0.0.1:5000'];
});

/// Primary base URL for the Flask API (no trailing slash).
final apiBaseUrlProvider = Provider<String>((ref) {
  final candidates = ref.watch(apiBaseUrlCandidatesProvider);
  return candidates.isNotEmpty ? candidates.first : 'http://127.0.0.1:5000';
});
