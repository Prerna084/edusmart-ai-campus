import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main');
});

class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._ref) : super(null) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = AuthSession.fromStorage(map);
      } catch (_) {}
    }
  }

  final Ref _ref;

  static const _key = 'auth_session_json';

  Future<void> persist(AuthSession session) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, jsonEncode(session.toStorage()));
    state = session;
  }

  Future<void> clear() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
    state = null;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(ref);
});
