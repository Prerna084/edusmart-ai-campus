import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../widgets/glass_container.dart';

class StudentRegisterScreen extends ConsumerStatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  ConsumerState<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends ConsumerState<StudentRegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _batchController = TextEditingController();
  final _semesterController = TextEditingController();
  final _sectionController = TextEditingController();
  final _collegeIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _batchController.dispose();
    _semesterController.dispose();
    _sectionController.dispose();
    _collegeIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Name, Email and Password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'batch': _batchController.text.trim(),
        'semester': _semesterController.text.trim(),
        'section': _sectionController.text.trim(),
        'college_id': _collegeIdController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.person_add, size: 48, color: AppColors.primaryStart),
                const SizedBox(height: 24),
                _buildTextField(_nameController, 'Full Name', Icons.person),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', Icons.email),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Password', Icons.lock, obscure: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_batchController, 'Batch', Icons.group)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(_semesterController, 'Semester', Icons.calendar_today)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_sectionController, 'Section', Icons.layers)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(_collegeIdController, 'College ID', Icons.badge)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}
