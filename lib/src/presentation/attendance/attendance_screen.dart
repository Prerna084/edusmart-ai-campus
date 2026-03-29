import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isSuccess = false;
  XFile? _capturedImage;
  String _statusMessage = 'Position your face in the frame to check in.';
  String? _matchedUserName;
  late AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();

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
      _matchedUserName = null;
      _statusMessage = 'Opening camera...';
    });

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );

    if (!mounted) {
      return;
    }

    if (image == null) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Capture cancelled. Try again when you are ready.';
      });
      return;
    }

    _capturedImage = image;
    _animationController.repeat(reverse: true);

    try {
      setState(() {
        _statusMessage = 'Scanning your face... Please hold still.';
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/attendance/mark',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        }),
      );

      final data = response.data ?? <String, dynamic>{};
      final user = data['user'] as Map<String, dynamic>?;
      final attendanceMarked = data['attendance_marked'] == true;

      if (!mounted) {
        return;
      }

      _animationController.stop();
      setState(() {
        _isScanning = false;
        _isSuccess = true;
        _matchedUserName = user?['name']?.toString();
        _statusMessage = attendanceMarked
            ? 'Attendance marked successfully!'
            : 'Attendance already marked for today.';
      });
    } on DioException catch (error) {
      _animationController.stop();
      final responseData = error.response?.data;
      final detail = responseData is Map<String, dynamic>
          ? responseData['detail']?.toString()
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _statusMessage = detail ?? 'Unable to connect to the attendance server.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _animationController.stop();
      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _statusMessage = 'Something went wrong while scanning. Please try again.';
      });
    }
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
              Center(
                child: GlassContainer(
                  width: 280,
                  height: 380,
                  padding: EdgeInsets.zero,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_capturedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.file(
                            File(_capturedImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_isSuccess)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 100,
                        )
                      else
                        Icon(
                          Icons.face,
                          size: 160,
                          color: AppColors.primaryStart.withOpacity(0.2),
                        ),
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
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      if (!_isSuccess) ...[
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _buildCorner(0),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildCorner(1),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: _buildCorner(2),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: _buildCorner(3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  _matchedUserName == null
                      ? _statusMessage
                      : '$_statusMessage\n$_matchedUserName',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _isSuccess
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  child: Text(_isSuccess ? 'Scan Again' : 'Start Scan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(int index) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: index < 2 ? AppColors.primaryStart : Colors.transparent,
            width: 4,
          ),
          bottom: BorderSide(
            color: index >= 2 ? AppColors.primaryStart : Colors.transparent,
            width: 4,
          ),
          left: BorderSide(
            color: index % 2 == 0 ? AppColors.primaryStart : Colors.transparent,
            width: 4,
          ),
          right: BorderSide(
            color: index % 2 != 0 ? AppColors.primaryStart : Colors.transparent,
            width: 4,
          ),
        ),
      ),
    );
  }
}
