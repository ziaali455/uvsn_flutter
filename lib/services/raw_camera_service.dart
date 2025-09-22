import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RawCameraService {
  static const MethodChannel _channel = MethodChannel('raw_camera_service');

  /// Check if RAW capture is supported on this device
  static Future<bool> isRawCaptureSupported() async {
    if (!Platform.isIOS) return false;

    try {
      final bool isSupported = await _channel.invokeMethod(
        'isRawCaptureSupported',
      );
      return isSupported;
    } catch (e) {
      debugPrint('Error checking RAW support: $e');
      return false;
    }
  }

  /// Get available RAW formats on this device
  static Future<List<String>> getAvailableRawFormats() async {
    if (!Platform.isIOS) return [];

    try {
      final List<dynamic> formats = await _channel.invokeMethod(
        'getAvailableRawFormats',
      );
      return formats.cast<String>();
    } catch (e) {
      debugPrint('Error getting RAW formats: $e');
      return [];
    }
  }

  /// Capture a RAW image and return the file path
  static Future<String?> captureRawImage({
    String format = 'dng', // 'dng' or 'raw'
    bool includeJpegPreview = true,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('RAW capture is only supported on iOS');
    }

    try {
      final String? filePath = await _channel.invokeMethod('captureRawImage', {
        'format': format,
        'includeJpegPreview': includeJpegPreview,
      });
      return filePath;
    } catch (e) {
      debugPrint('Error capturing RAW image: $e');
      return null;
    }
  }

  /// Configure camera settings for optimal RAW capture
  static Future<bool> configureCameraSettings({
    String? isoMode = 'auto', // 'auto', 'manual'
    int? manualIso,
    String? focusMode = 'auto', // 'auto', 'manual'
    double? manualFocusDistance,
    String? exposureMode = 'auto', // 'auto', 'manual'
    double? exposureDuration,
    bool enableImageStabilization = true,
  }) async {
    if (!Platform.isIOS) return false;

    try {
      final bool success = await _channel
          .invokeMethod('configureCameraSettings', {
            'isoMode': isoMode,
            'manualIso': manualIso,
            'focusMode': focusMode,
            'manualFocusDistance': manualFocusDistance,
            'exposureMode': exposureMode,
            'exposureDuration': exposureDuration,
            'enableImageStabilization': enableImageStabilization,
          });
      return success;
    } catch (e) {
      debugPrint('Error configuring camera: $e');
      return false;
    }
  }

  /// Start camera preview
  static Future<bool> startCameraPreview() async {
    if (!Platform.isIOS) return false;

    try {
      final bool success = await _channel.invokeMethod('startCameraPreview');
      return success;
    } catch (e) {
      debugPrint('Error starting camera preview: $e');
      return false;
    }
  }

  /// Stop camera preview
  static Future<bool> stopCameraPreview() async {
    if (!Platform.isIOS) return false;

    try {
      final bool success = await _channel.invokeMethod('stopCameraPreview');
      return success;
    } catch (e) {
      debugPrint('Error stopping camera preview: $e');
      return false;
    }
  }

  /// Get camera capabilities (max resolution, supported formats, etc.)
  static Future<Map<String, dynamic>> getCameraCapabilities() async {
    if (!Platform.isIOS) return {};

    try {
      final Map<dynamic, dynamic> capabilities = await _channel.invokeMethod(
        'getCameraCapabilities',
      );
      return capabilities.cast<String, dynamic>();
    } catch (e) {
      debugPrint('Error getting camera capabilities: $e');
      return {};
    }
  }
}
