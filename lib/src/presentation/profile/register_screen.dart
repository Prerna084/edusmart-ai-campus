import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_base_url.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/glass_container.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  File? _image;
  final picker = ImagePicker();
  final nameController = TextEditingController();
  bool _isLoading = false;

  String get _apiBaseUrl => resolveApiBaseUrl();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> registerUser() async {
    if (_image == null || nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name and capture your face.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Compress before upload — caps at 800px, quality 70
      // Shrinks a 5 MB phone photo to ~150 KB, preventing OOM on the server.
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        _image!.path,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      final File uploadFile;
      if (compressed != null) {
        final tmpDir = await getTemporaryDirectory();
        final tmpPath = p.join(tmpDir.path, 'face_upload.jpg');
        uploadFile = await File(tmpPath).writeAsBytes(compressed);
      } else {
        uploadFile = _image!; // fallback: send original
      }

      final dio = Dio();
      final formData = FormData.fromMap({
        'name': nameController.text.trim(),
        'file': await MultipartFile.fromFile(
          uploadFile.path,
          filename: 'face.jpg',
        ),
      });

      final response = await dio.post(
        '$_apiBaseUrl/register/',
        data: formData,
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data;
      final userId = data['user_id'];
      final alreadyExisted = data['already_existed'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_student_id', userId.toString());
        await prefs.setString('profile_name', data['name']?.toString() ?? nameController.text.trim());
      }

      final message = alreadyExisted
          ? 'Already registered as ${data['name']} (ID: ${data['user_id']}). No duplicate created.'
          : 'Face registered for ${data['name']} (ID: ${data['user_id']}).';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: alreadyExisted ? AppColors.warning : AppColors.success,
        ),
      );
      Navigator.pop(context);
      
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      
      final responseData = error.response?.data;
      String errorMessage = 'Unknown error';
      if (responseData is Map<String, dynamic> && responseData.containsKey('detail')) {
        errorMessage = responseData['detail'].toString();
      } else if (responseData != null) {
        errorMessage = responseData.toString();
      }

      final message = errorMessage.contains('No face found')
          ? 'No face found. Retake the photo with your full face centered, good light, and if possible without glasses.'
          : 'Registration failed: $errorMessage';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error: make sure the FastAPI backend is running at $_apiBaseUrl.\nDetails: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enroll Face Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Register your face to seamlessly mark your attendance when entering the classroom via CCTV.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: pickImage,
              child: GlassContainer(
                width: 200,
                height: 200,
                padding: EdgeInsets.zero,
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: AppColors.primaryStart.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap to Capture',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : registerUser,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Upload to System'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
