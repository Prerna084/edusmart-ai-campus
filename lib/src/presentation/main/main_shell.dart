import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../chatbot/chatbot_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../syllabus/syllabus_screen.dart';
import '../teacher/teacher_analytics_screen.dart';
import '../teacher/teacher_home_screen.dart';
import '../teacher/teacher_syllabus_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session == null) {
      return const SizedBox.shrink();
    }

    final screens = session.isTeacher
        ? <Widget>[
            TeacherHomeScreen(session: session),
            TeacherSyllabusScreen(session: session),
            ChatbotScreen(session: session),
            TeacherAnalyticsScreen(session: session),
            ProfileScreen(session: session),
          ]
        : <Widget>[
            HomeScreen(session: session),
            SyllabusScreen(session: session),
            ChatbotScreen(session: session),
            DashboardScreen(session: session),
            ProfileScreen(session: session),
          ];

    final items = session.isTeacher
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Teach'),
            BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: 'Syllabus'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Tutor'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Syllabus'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'AI Tutor'),
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ];

    final idx = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: screens[idx],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: items,
        ),
      ),
    );
  }
}
