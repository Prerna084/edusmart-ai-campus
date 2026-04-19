import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../dashboard/attendance_dashboard_screen.dart';
import '../dashboard/attendance_history_screen.dart';
import '../dashboard/student_list_screen.dart';
import '../dashboard/admin_assessments_screen.dart';
import 'login_screen.dart';

/// Admin-only shell with two tabs:
///   0 → Live Attendance (face scan + today's check-ins)
///   1 → Registered Students list
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryStart,
          labelColor: AppColors.primaryStart,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.videocam_rounded),
              text: 'Attendance',
            ),
            Tab(
              icon: Icon(Icons.how_to_reg_rounded),
              text: 'Check-ins',
            ),
            Tab(
              icon: Icon(Icons.people_alt_rounded),
              text: 'Students',
            ),
            Tab(
              icon: Icon(Icons.assignment),
              text: 'Tests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0 — Live attendance / face scan (no double appbar)
          AttendanceDashboardScreen(
            isAdminMode: true,
            onAdminLogout: null, // logout is handled by parent AppBar
          ),

          // Tab 1 — New! Today's Check-ins dedicated tab
          const AttendanceHistoryScreen(),

          // Tab 2 — Registered student list
          const StudentListScreen(),

          // Tab 3 — Admin Assessments and results
          const AdminAssessmentsScreen(),
        ],
      ),
    );
  }
}
