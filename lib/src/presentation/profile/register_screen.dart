import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> registerUser() async {
    if (_image == null || nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name and capture your face.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For Android Emulator localhost: 10.0.2.2
      // For physical device, change to your PC's IP address (e.g., 192.168.1.X)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("http://10.0.2.2:8000/register/"),
      );

      request.fields['name'] = nameController.text;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _image!.path,
        ),
      );

      var response = await request.send();

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Face Registered Successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Go back after success
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Registration Failed: Status ${response.statusCode}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Network Error: Make sure FastAPI backend is running.\nDetails: $e"),
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
        title: const Text("Enroll Face Attendance"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "Register your face to seamlessly mark your attendance when entering the classroom via CCTV.",
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Image Preview Container
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
                          Icon(Icons.camera_alt, size: 48, color: AppColors.primaryStart.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          const Text("Tap to Capture", style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Name Input
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 48),
            
            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : registerUser,
                child: _isLoading 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text("Upload to System"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
