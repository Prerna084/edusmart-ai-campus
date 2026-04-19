import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/camera_utils.dart';
import '../widgets/glass_container.dart';
import 'attendance_history_screen.dart';

// ---------------------------------------------------------------------------
// Provider — fetches today's attendance from the backend
// ---------------------------------------------------------------------------
final todayAttendanceProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get<List<dynamic>>('/attendance/today');
  return (response.data ?? []).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  /// When true, shows admin title and optional logout (e.g. after admin login).
  final bool isAdminMode;
  final VoidCallback? onAdminLogout;

  const AttendanceDashboardScreen({
    super.key,
    this.isAdminMode = false,
    this.onAdminLogout,
  });

  @override
  ConsumerState<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState
    extends ConsumerState<AttendanceDashboardScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;
  Timer? _scanTimer;
  bool _isAutoScanning = false;
  bool _isScanInProgress = false;
  String _scanStatus = 'Idle';
  final Set<int> _sessionMarkedStudentIds = <int>{};
  final List<String> _recentDetections = <String>[];
  
  // Camera Switching
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

  // Face Detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  List<Face> _faces = [];
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
        
        // On very first run, try to default to the FRONT camera
        final frontIdx = _availableCameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontIdx != -1) {
          _selectedCameraIndex = frontIdx;
        }
      }

      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraError = 'No camera available on this device.';
          });
        }
        return;
      }

      final controller = CameraController(
        _availableCameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _cameraError = null;
        _scanStatus = 'Camera ready';
      });

      _startImageStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera init failed: $e';
        _scanStatus = 'Camera unavailable';
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_availableCameras.length < 2) return;

    final wasAutoScanning = _isAutoScanning;
    if (wasAutoScanning) {
      _stopAutoScan();
    }

    setState(() {
      _cameraReady = false;
      _scanStatus = 'Switching camera...';
    });

    await _cameraController?.dispose();
    _cameraController = null;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _initCamera();

    if (wasAutoScanning && _cameraReady) {
      _startAutoScan();
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((image) async {
      if (_isProcessingImage) return;

      _isProcessingImage = true;
      try {
        final inputImage = CameraUtils.inputImageFromCameraImage(
          image,
          _availableCameras[_selectedCameraIndex],
        );

        if (inputImage != null) {
          try {
            final faces = await _faceDetector.processImage(inputImage);
            if (faces.isNotEmpty) {
              debugPrint('Faces detected: ${faces.length}');
            }
            if (mounted) {
              setState(() {
                _faces = faces;
              });
            }
          } catch (e) {
             // Silently handle transient conversion errors for specific frames
             if (e.toString().contains('InputImageConverterError')) {
                // Ignore format errors for individual frames to keep logs clean
             } else {
                debugPrint('Face detection error: $e');
             }
          }
        }
      } catch (e) {
        debugPrint('Face detection error: $e');
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void _stopImageStream() {
    _cameraController?.stopImageStream();
    if (mounted) {
      setState(() {
        _faces = [];
      });
    }
  }

  Future<void> _runSingleScanCycle() async {
    if (_isScanInProgress || !_isAutoScanning) return;
    if (!_cameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _isScanInProgress = true;

    try {
      if (mounted) {
        setState(() {
          _scanStatus = 'Capturing frame...';
        });
      }

      // Briefly stop image stream to allow high-res capture without hardware conflict
      await _cameraController!.stopImageStream();

      final image = await _cameraController!.takePicture();
      final imagePath = image.path;
      final imageName = image.name;

      // Immediately restart image stream for live tracking
      _startImageStream();

      final dio = ref.read(dioProvider);

      if (mounted) {
        setState(() {
          _scanStatus = 'Recognizing face...';
        });
      }

      final recognizeResponse = await dio.post<Map<String, dynamic>>(
        '/recognize',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath, filename: imageName),
        }),
      );

      final recognitionData = recognizeResponse.data ?? <String, dynamic>{};
      final recognized = recognitionData['recognized'] == true;

      if (!recognized) {
        if (mounted) {
          setState(() {
            _scanStatus = 'Unknown face';
            _recentDetections.insert(0, 'Unknown face detected');
            if (_recentDetections.length > 6) _recentDetections.removeLast();
          });
        }
        return;
      }

      final user = recognitionData['user'] as Map<String, dynamic>?;
      final dynamic rawUserId = user?['id'];
      final int? userId = rawUserId is int
          ? rawUserId
          : int.tryParse(rawUserId?.toString() ?? '');
      final userName = user?['name']?.toString() ?? 'Unknown';

      if (userId == null) {
        if (mounted) {
          setState(() {
            _scanStatus = 'Recognition payload invalid';
          });
        }
        return;
      }

      if (_sessionMarkedStudentIds.contains(userId)) {
        if (mounted) {
          setState(() {
            _scanStatus = 'Already marked recently: $userName';
            _recentDetections.insert(0, '$userName recognized (already marked)');
            if (_recentDetections.length > 6) _recentDetections.removeLast();
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _scanStatus = 'Marking attendance for $userName...';
        });
      }

      final markResponse = await dio.post<Map<String, dynamic>>(
        '/attendance/mark',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath, filename: imageName),
        }),
      );

      final markData = markResponse.data ?? <String, dynamic>{};
      final attendanceMarked = markData['attendance_marked'] == true;

      if (mounted) {
        setState(() {
          if (attendanceMarked) {
            _sessionMarkedStudentIds.add(userId);
            _scanStatus = 'Attendance marked: $userName';
            _recentDetections.insert(0, 'Marked: $userName');
          } else {
            _sessionMarkedStudentIds.add(userId);
            _scanStatus = 'Already marked today: $userName';
            _recentDetections.insert(0, 'Already marked today: $userName');
          }
          if (_recentDetections.length > 6) _recentDetections.removeLast();
        });
      }

      ref.invalidate(todayAttendanceProvider);
      unawaited(File(imagePath).delete().catchError((_) => File(imagePath)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanStatus = 'Scan error: $e';
        });
      }
    } finally {
      _isScanInProgress = false;
    }
  }

  void _startAutoScan() {
    if (_isAutoScanning || !_cameraReady) return;
    setState(() {
      _isAutoScanning = true;
      _scanStatus = 'Auto scan started';
    });
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _runSingleScanCycle();
    });
    _runSingleScanCycle();
  }

  void _stopAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (mounted) {
      setState(() {
        _isAutoScanning = false;
        _scanStatus = 'Auto scan stopped';
      });
    } else {
      _isAutoScanning = false;
    }
  }

  Future<void> _manualSingleScan() async {
    if (_isAutoScanning || !_cameraReady) return;
    setState(() {
      _isAutoScanning = true;
    });
    await _runSingleScanCycle();
    if (mounted) {
      setState(() {
        _isAutoScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(todayAttendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isAdminMode
          ? null // parent AdminMainScreen already has an AppBar + TabBar
          : AppBar(
              title: const Text('Live Attendance'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(todayAttendanceProvider),
                ),
              ],
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam, color: AppColors.primaryStart),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin Auto Scan',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_availableCameras.length > 1)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_outlined, size: 20),
                            onPressed: _cameraReady ? _toggleCamera : null,
                            tooltip: 'Switch Camera',
                            color: AppColors.primaryStart,
                          ),
                        Switch(
                          value: _isAutoScanning,
                          onChanged: (enabled) {
                            if (enabled) {
                              _startAutoScan();
                            } else {
                              _stopAutoScan();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scanStatus,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isAutoScanning || !_cameraReady) ? null : _manualSingleScan,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Scan Once'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _recentDetections.clear();
                                _sessionMarkedStudentIds.clear();
                              });
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear Session'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black,
                        width: double.infinity,
                        child: _cameraError != null
                            ? AspectRatio(
                                aspectRatio: 1.0,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      _cameraError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              )
                            : !_cameraReady || _cameraController == null
                                ? const AspectRatio(
                                    aspectRatio: 1.0,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primaryStart,
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        // The camera package's aspectRatio is width / height.
                                        // On many devices, this ratio can be inverted depending on rotation logic.
                                        // We force a vertical-friendly ratio here for the portrait container.
                                        double ratio = _cameraController!.value.aspectRatio;
                                        if (ratio > 1.0) ratio = 1.0 / ratio;

                                        return AspectRatio(
                                          aspectRatio: ratio,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CameraPreview(_cameraController!),
                                              if (_faces.isNotEmpty)
                                                CustomPaint(
                                                  painter: FaceOverlayPainter(
                                                    faces: _faces,
                                                    imageSize: _cameraController!.value.previewSize!,
                                                    rotation: _availableCameras[_selectedCameraIndex].sensorOrientation,
                                                    isFrontCamera: _availableCameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ),
                    ),
                    if (_recentDetections.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Recent detections',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      ..._recentDetections.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- $entry',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedToday() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ---------------------------------------------------------------------------
// Attendance Card Widget
// ---------------------------------------------------------------------------
class _AttendanceCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const _AttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final name = record['student_name']?.toString() ?? 'Unknown';
    final time = record['time']?.toString() ?? '--:--';
    final status = record['status']?.toString() ?? 'Present';

    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryStart.withOpacity(0.15),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primaryStart,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Name & time ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Status badge ─────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error View
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Could not load attendance data.',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty View
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: AppColors.primaryStart.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No attendance yet today.',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Students can check in using Face Recognition\nfrom the home screen.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Face Detection Overlay Painter
// ---------------------------------------------------------------------------
class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final int rotation;
  final bool isFrontCamera;

  FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    // Find the primary (largest) face
    Face? primaryFace;
    double maxArea = -1.0;

    for (final face in faces) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area > maxArea) {
        maxArea = area;
        primaryFace = face;
      }
    }

    final primaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.redAccent;

    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blueAccent;

    for (final face in faces) {
      final isPrimary = face == primaryFace;
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        rotation: rotation,
      );
      canvas.drawRect(rect, isPrimary ? primaryPaint : secondaryPaint);
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required int rotation,
  }) {
    double scaleX, scaleY;

    // ML Kit results are based on the sensor orientation.
    // If the image is rotated (90/270), we need to swap width and height for scaling.
    if (rotation == 90 || rotation == 270) {
      scaleX = widgetSize.width / imageSize.height;
      scaleY = widgetSize.height / imageSize.width;
    } else {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = widgetSize.height / imageSize.height;
    }

    final double scaledLeft = rect.left * scaleX;
    final double scaledRight = rect.right * scaleX;
    final double scaledTop = rect.top * scaleY;
    final double scaledBottom = rect.bottom * scaleY;

    final double left = isFrontCamera 
        ? widgetSize.width - scaledRight
        : scaledLeft;
    
    final double right = isFrontCamera
        ? widgetSize.width - scaledLeft
        : scaledRight;

    return Rect.fromLTRB(
      left,
      scaledTop,
      right,
      scaledBottom,
    );
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
