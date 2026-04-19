import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../profile/profile_provider.dart';
import 'admin_login_screen.dart';
import 'student_register_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../home/home_screen.dart';
import '../syllabus/syllabus_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../profile/profile_screen.dart';
import '../teacher/teacher_dashboard_screen.dart';
import 'teacher_register_screen.dart';
import 'admin_main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFacultySelected = false; // Internal selection for landing view

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final profileData = data['profile'];

      // Update profile provider with user data
      final userProfile = UserProfile(
        name: data['name'] ?? '',
        email: profileData['email'] ?? '',
        phone: profileData['phone'] ?? '',
        userId: data['user_id'].toString(),
        collegeId: profileData['college_id'] ?? '',
        department: profileData['department'] ?? '',
        year: profileData['year'] ?? '',
        batch: profileData['batch'] ?? '',
        semester: profileData['semester'] ?? '',
        section: profileData['section'] ?? '',
        role: data['role'] ?? 'student',
      );

      await ref.read(profileProvider.notifier).updateProfile(userProfile);

      if (mounted) {
        if (userProfile.role == 'teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TeacherDashboardScreen()),
          );
        } else if (userProfile.role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminMainScreen())); // Admin should go to specific dashboard
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Forgot Password', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your registered email to receive a temporary password.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                final dio = ref.read(dioProvider);
                final res = await dio.post('/auth/forgot-password', data: {'email': email});
                if (context.mounted) {
                  Navigator.pop(context);
                  _showTempPasswordDialog(res.data['temp_password']);
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  void _showTempPasswordDialog(String tempPwd) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Temporary Password', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A temporary password has been generated for you:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(tempPwd, style: const TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            const Text('Use this to login and reset it from your profile.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(Icons.school_rounded, size: 80, color: AppColors.primaryStart),
                const SizedBox(height: 16),
                Text(
                  'EduSmart AI',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Your Intelligent Campus Companion', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 48),
                _isFacultySelected ? _buildFacultyLogin() : _buildStudentLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentLogin() {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Student Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 24),
          _buildTextField(_emailController, 'Student Email', Icons.email_outlined),
          const SizedBox(height: 16),
          _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscure: true),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Login'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No account? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRegisterScreen())),
                child: const Text('Register Now', style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const Divider(height: 40, color: AppColors.glassBorder),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isFacultySelected = true),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Switch to Faculty Admin'),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyLogin() {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_rounded, size: 48, color: AppColors.primaryStart),
          const SizedBox(height: 16),
          const Text('Faculty Admin Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text('Access academic console and controls.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
              child: const Text('Enter Admin Console'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Want to join as faculty? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRegisterScreen()));
                },
                child: const Text('Register Here', style: TextStyle(color: AppColors.primaryStart, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _isFacultySelected = false),
            child: const Text('Return to Student Portal'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primaryStart, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onTabNavigation: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      const SyllabusScreen(),
      const ChatbotScreen(),
      const DashboardScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Syllabus'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'AI Tutor'),
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
