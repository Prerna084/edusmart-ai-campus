class AuthSession {
  final String token;
  final int userId;
  final String email;
  final String name;
  final String role;
  final String semester;
  final String section;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.semester,
    required this.section,
  });

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';

  factory AuthSession.fromLoginResponse(Map<String, dynamic> json) {
    final token = json['token'] as String? ?? '';
    final u = json['user'] as Map<String, dynamic>? ?? {};
    return AuthSession(
      token: token,
      userId: (u['id'] as num).toInt(),
      email: u['email'] as String? ?? '',
      name: u['name'] as String? ?? '',
      role: u['role'] as String? ?? 'student',
      semester: u['semester'] as String? ?? '',
      section: u['section'] as String? ?? '',
    );
  }

  Map<String, dynamic> toStorage() => {
        'token': token,
        'userId': userId,
        'email': email,
        'name': name,
        'role': role,
        'semester': semester,
        'section': section,
      };

  factory AuthSession.fromStorage(Map<String, dynamic> m) {
    return AuthSession(
      token: m['token'] as String,
      userId: (m['userId'] as num).toInt(),
      email: m['email'] as String? ?? '',
      name: m['name'] as String? ?? '',
      role: m['role'] as String? ?? 'student',
      semester: m['semester'] as String? ?? '',
      section: m['section'] as String? ?? '',
    );
  }
}
