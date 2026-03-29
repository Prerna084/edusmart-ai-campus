import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';
import 'register_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Profile Header
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 64,
                      backgroundColor: AppColors.surface,
                      child: Icon(Icons.person, size: 80, color: AppColors.primaryStart),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Alex Student',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'alex.student@campus.edu',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),

              // Settings List
              _buildSettingsGroup(
                context,
                title: 'Account',
                items: [
                  _ListTileItem(icon: Icons.person_outline, label: 'Personal Information'),
                  _ListTileItem(
                    icon: Icons.face_retouching_natural, 
                    label: 'Enroll Face Attendance',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                    },
                  ),
                  _ListTileItem(icon: Icons.school_outlined, label: 'Academic Records'),
                  _ListTileItem(icon: Icons.security, label: 'Security & Password'),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsGroup(
                context,
                title: 'Preferences',
                items: [
                  _ListTileItem(icon: Icons.notifications_none, label: 'Notifications'),
                  _ListTileItem(icon: Icons.palette_outlined, label: 'Appearance', trailing: 'Light'),
                  _ListTileItem(icon: Icons.language, label: 'Language', trailing: 'English'),
                ],
              ),
              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Implement Logout
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Log Out'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, {required String title, required List<_ListTileItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStart),
          ),
        ),
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.map((item) {
              final isLast = item == items.last;
              return Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.background,
                      child: Icon(item.icon, color: AppColors.textPrimary, size: 20),
                    ),
                    title: Text(item.label, style: Theme.of(context).textTheme.titleMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailing != null)
                          Text(item.trailing!, style: Theme.of(context).textTheme.bodyMedium),
                        if (item.trailing != null) const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                    onTap: item.onTap ?? () {},
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: AppColors.glassBorder),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ListTileItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  _ListTileItem({required this.icon, required this.label, this.trailing, this.onTap});
}
