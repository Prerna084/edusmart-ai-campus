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
          try {
            final faces = await _faceDetector.processImage(inputImage);
            if (mounted) {
              setState(() {
                _faces = faces;
              });
            }
          } catch (e) {
            if (!e.toString().contains('InputImageConverterError')) {
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

  Future<void> _captureAndMark() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isScanning = true;
      _isSuccess = false;
      _matchedUserName = null;
      _statusMessage = 'Capturing...';
    });

    try {
      // Pause image stream to allow high-res capture without hardware conflict
      await _cameraController!.stopImageStream();

      final image = await _cameraController!.takePicture();
      _capturedImage = image;

      // The ImageStream is not restarted here because we show the captured photo 
      // instead of the live preview once _capturedImage is set.
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
                                      imageSize: _cameraController!.value.previewSize!,
                                      rotation: _cameraController!.description.sensorOrientation,
                                      isFrontCamera: _cameraController!.description.lensDirection == CameraLensDirection.front,
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
