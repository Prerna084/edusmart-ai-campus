import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String studentId; // numeric DB user_id stored as string after registration
  final String department;
  final String year;
  final String? avatarPath; // local file path

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.studentId,
    required this.department,
    required this.year,
    this.avatarPath,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? studentId,
    String? department,
    String? year,
    String? avatarPath,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        studentId: studentId ?? this.studentId,
        department: department ?? this.department,
        year: year ?? this.year,
        avatarPath: avatarPath ?? this.avatarPath,
      );

  static const _defaults = UserProfile(
    name: 'Student',
    email: '',
    phone: '',
    studentId: '',
    department: '',
    year: '',
    avatarPath: null,
  );

  static UserProfile defaults() => _defaults;
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences Keys
// ─────────────────────────────────────────────────────────────────────────────
const _kName = 'profile_name';
const _kEmail = 'profile_email';
const _kPhone = 'profile_phone';
const _kStudentId = 'profile_student_id';
const _kDepartment = 'profile_department';
const _kYear = 'profile_year';
const _kAvatarPath = 'profile_avatar_path';

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────
class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final prefs = await SharedPreferences.getInstance();

    // Build base profile from local cache first (instant load)
    final local = UserProfile(
      name: prefs.getString(_kName) ?? UserProfile.defaults().name,
      email: prefs.getString(_kEmail) ?? '',
      phone: prefs.getString(_kPhone) ?? '',
      studentId: prefs.getString(_kStudentId) ?? '',
      department: prefs.getString(_kDepartment) ?? '',
      year: prefs.getString(_kYear) ?? '',
      avatarPath: prefs.getString(_kAvatarPath),
    );

    // If we have a numeric student ID, fetch latest profile from backend DB
    final id = int.tryParse(local.studentId.trim());
    if (id != null) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get<Map<String, dynamic>>('/students/$id/profile');
        final data = res.data ?? {};

        final synced = local.copyWith(
          name: (data['name'] as String?)?.isNotEmpty == true
              ? data['name'] as String
              : local.name,
          email: data['email'] as String? ?? local.email,
          phone: data['phone'] as String? ?? local.phone,
          department: data['department'] as String? ?? local.department,
          year: data['year'] as String? ?? local.year,
        );

        // Persist the synced values locally too
        await _saveToPrefs(synced);
        return synced;
      } catch (_) {
        // Backend unreachable — fall back to local cache silently
      }
    }

    return local;
  }

  /// Save profile: writes to SharedPreferences AND pushes to backend DB.
  Future<void> updateProfile(UserProfile updated) async {
    await _saveToPrefs(updated);
    state = AsyncValue.data(updated);

    // Push to backend if user is registered (has numeric ID)
    final id = int.tryParse(updated.studentId.trim());
    if (id != null) {
      try {
        final dio = ref.read(dioProvider);
        await dio.put<dynamic>(
          '/students/$id/profile',
          data: {
            'email': updated.email,
            'phone': updated.phone,
            'department': updated.department,
            'year': updated.year,
          },
        );
      } catch (_) {
        // Best-effort — local save already succeeded
      }
    }
  }

  Future<void> pickAndSetAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final current = state.valueOrNull ?? UserProfile.defaults();
    await updateProfile(current.copyWith(avatarPath: picked.path));
  }

  // ── private ────────────────────────────────────────────────────────────────
  Future<void> _saveToPrefs(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, p.name);
    await prefs.setString(_kEmail, p.email);
    await prefs.setString(_kPhone, p.phone);
    await prefs.setString(_kStudentId, p.studentId);
    await prefs.setString(_kDepartment, p.department);
    await prefs.setString(_kYear, p.year);
    if (p.avatarPath != null) {
      await prefs.setString(_kAvatarPath, p.avatarPath!);
    }
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
