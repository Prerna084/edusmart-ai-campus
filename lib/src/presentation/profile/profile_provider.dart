import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String studentId;
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
    name: 'Alex Student',
    email: 'alex.student@campus.edu',
    phone: '',
    studentId: 'STU-2024-001',
    department: 'Computer Science',
    year: '3rd Year',
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
    return UserProfile(
      name: prefs.getString(_kName) ?? UserProfile.defaults().name,
      email: prefs.getString(_kEmail) ?? UserProfile.defaults().email,
      phone: prefs.getString(_kPhone) ?? '',
      studentId: prefs.getString(_kStudentId) ?? UserProfile.defaults().studentId,
      department: prefs.getString(_kDepartment) ?? UserProfile.defaults().department,
      year: prefs.getString(_kYear) ?? UserProfile.defaults().year,
      avatarPath: prefs.getString(_kAvatarPath),
    );
  }

  Future<void> updateProfile(UserProfile updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, updated.name);
    await prefs.setString(_kEmail, updated.email);
    await prefs.setString(_kPhone, updated.phone);
    await prefs.setString(_kStudentId, updated.studentId);
    await prefs.setString(_kDepartment, updated.department);
    await prefs.setString(_kYear, updated.year);
    if (updated.avatarPath != null) {
      await prefs.setString(_kAvatarPath, updated.avatarPath!);
    }
    state = AsyncValue.data(updated);
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
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
