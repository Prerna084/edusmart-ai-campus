import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/camera_utils.dart';
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

  CameraController? _cameraController;
  bool _isCameraReady = false;
  List<Face> _faces = [];
  bool _isProcessingImage = false;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initCamera();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });

      _startImageStream();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((image) async {
      if (_isProcessingImage || _capturedImage != null || _isSuccess) return;

      _isProcessingImage = true;
      try {
        final inputImage = CameraUtils.inputImageFromCameraImage(
          image,
          _cameraController!.description,
        );

        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          if (mounted) {
            setState(() {
              _faces = faces;
            });
          }
        }
      } catch (e) {
        debugPrint('Face detection error: $e');
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  Future<void> _captureAndMark() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isScanning = true;
      _isSuccess = false;
      _matchedUserName = null;
      _statusMessage = 'Capturing...';
    });

    try {
      final image = await _cameraController!.takePicture();
      _capturedImage = image;
      _animationController.repeat(reverse: true);

      setState(() {
        _statusMessage = 'Scanning your face... Please hold still.';
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/attendance/mark',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: 'face.jpg',
          ),
        }),
      );

      final data = response.data ?? <String, dynamic>{};
      final user = data['user'] as Map<String, dynamic>?;
      final attendanceMarked = data['attendance_marked'] == true;

      if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _capturedImage = null; // Allow retry
        _statusMessage = detail ?? 'Unable to connect to server.';
      });
    } catch (_) {
      if (!mounted) return;
      _animationController.stop();
      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _capturedImage = null;
        _statusMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _isSuccess = false;
      _isScanning = false;
      _matchedUserName = null;
      _statusMessage = 'Position your face in the frame to check in.';
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
              const SizedBox(height: 32),
              Center(
                child: GlassContainer(
                  width: 320,
                  height: 400,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_capturedImage != null)
                          Image.file(
                            File(_capturedImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        else if (_isCameraReady)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_cameraController!),
                              if (_faces.isNotEmpty)
                                CustomPaint(
                                  painter: FaceOverlayPainter(
                                    faces: _faces,
                                    imageSize: _cameraController!.value.previewSize,
                                    rotation: _cameraController!.description.sensorOrientation,
                                  ),
                                ),
                            ],
                          )
                        else if (_isSuccess)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 100,
                          )
                        else
                          const Center(child: CircularProgressIndicator()),
                        
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Positioned(
                                top: _animationController.value * 390,
                                child: Container(
                                  width: 320,
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
                      ],
                    ),
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
                  onPressed: _isScanning
                      ? null
                      : (_isSuccess ? _reset : _captureAndMark),
                  child: Text(_isSuccess ? 'Scan Again' : 'Mark Attendance'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reuse the same painter or a slightly adapted one
class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final int rotation;

  FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppColors.success;

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        rotation: rotation,
      );
      canvas.drawRect(rect, paint);
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required int rotation,
  }) {
    double scaleX, scaleY;

    if (rotation == 90 || rotation == 270) {
      scaleX = widgetSize.width / imageSize.height;
      scaleY = widgetSize.height / imageSize.width;
    } else {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = widgetSize.height / imageSize.height;
    }

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
