import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraUtils {
  static InputImage? inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    
    // Convert rotation to ML Kit format
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation90deg;

    // Correct format mapping
    final InputImageFormat? format = _getInputImageFormat(image);

    if (format == null) return null;

    // For Android (YUV420), we need to concatenate the planes correctly.
    // For iOS (BGRA8888), we can usually take the first plane.
    final bytes = _concatenatePlanes(image, format);
    if (bytes == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  static InputImageFormat? _getInputImageFormat(CameraImage image) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 35 is YUV_420_888 on Android
      if (image.format.raw == 35) return InputImageFormat.yuv420;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // 1111970369 is BGRA8888 on iOS
      if (image.format.raw == 1111970369) return InputImageFormat.bgra8888;
    }
    return InputImageFormatValue.fromRawValue(image.format.raw);
  }

  static Uint8List? _concatenatePlanes(CameraImage image, InputImageFormat format) {
    if (format == InputImageFormat.yuv420) {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      return allBytes.done().buffer.asUint8List();
    } else {
      // For BGRA8888 or other formats, the first plane usually contains everything needed
      return image.planes[0].bytes;
    }
  }
}
