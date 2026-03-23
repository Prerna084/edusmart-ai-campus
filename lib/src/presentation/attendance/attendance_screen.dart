import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isSuccess = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _isSuccess = false;
    });
    
    _animationController.repeat(reverse: true);
    
    // Simulate API match delay
    await Future.delayed(const Duration(seconds: 3));
    
    _animationController.stop();
    setState(() {
      _isScanning = false;
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'AI Face Recognition Check-in',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              
              // Scanner Viewfinder
              Center(
                child: GlassContainer(
                  width: 280,
                  height: 380,
                  padding: EdgeInsets.zero,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Placeholder Avatar representing the camera feed
                      if (_isSuccess)
                        const Icon(Icons.check_circle, color: AppColors.success, size: 100)
                      else
                        Icon(Icons.face, size: 160, color: AppColors.primaryStart.withOpacity(0.2)),

                      // Animated Scanning Line
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Positioned(
                              top: _animationController.value * 360,
                              child: Container(
                                width: 280,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                      // Frame Corners
                      if (!_isSuccess) ...[
                        Positioned(top: 16, left: 16, child: _buildCorner(0)),
                        Positioned(top: 16, right: 16, child: _buildCorner(1)),
                        Positioned(bottom: 16, left: 16, child: _buildCorner(2)),
                        Positioned(bottom: 16, right: 16, child: _buildCorner(3)),
                      ],
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Status Text
              Center(
                child: Text(
                  _isSuccess 
                      ? 'Attendance marked successfully!' 
                      : _isScanning 
                          ? 'Scanning your face... Please hold still.' 
                          : 'Position your face in the frame to check in.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _isSuccess ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning || _isSuccess ? null : _startScan,
                  child: Text(_isSuccess ? 'Checked In' : 'Start Scan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(int index) {
    // A simple little hook for the corners of the scanner
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: index < 2 ? AppColors.primaryStart : Colors.transparent, width: 4),
          bottom: BorderSide(color: index >= 2 ? AppColors.primaryStart : Colors.transparent, width: 4),
          left: BorderSide(color: index % 2 == 0 ? AppColors.primaryStart : Colors.transparent, width: 4),
          right: BorderSide(color: index % 2 != 0 ? AppColors.primaryStart : Colors.transparent, width: 4),
        ),
      ),
    );
  }
}
