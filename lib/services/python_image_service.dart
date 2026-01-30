import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/image_analysis.dart';

/// Service to call Python backend for image analysis
/// This allows testing Python implementation alongside Flutter implementation
class PythonImageService {
  // Use environment variable or default to Render API
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://uvsn-flutter-python-api.onrender.com/api', // Production API for all platforms
  );

  /// Analyze image using Python backend
  /// Returns ImageAnalysis matching the same structure as Flutter implementation
  static Future<ImageAnalysis> analyzeImageFromBytes(
    Uint8List bytes,
    String fileName,
    int fileSize, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Uploading to server...');

      // Save the image to a temporary location so we can display it later
      String? savedPath;
      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedFileName =
              fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
          savedPath =
              path.join(tempDir.path, '${timestamp}_$sanitizedFileName');
          final file = File(savedPath);
          await file.writeAsBytes(bytes);
          debugPrint('Saved image to: $savedPath');
        } catch (e) {
          debugPrint('Failed to save image for preview: $e');
          savedPath = null;
        }
      }

      // Create multipart request
      final uri = Uri.parse('$_baseUrl/analyze');
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      onProgress?.call(0.3, 'Processing on server...');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }

      onProgress?.call(0.9, 'Parsing results...');

      // Parse response
      final Map<String, dynamic> data = json.decode(response.body);

      // Generate thumbnail from the original bytes
      onProgress?.call(0.95, 'Generating preview...');
      final thumbnailBase64 = data['thumbnailBase64'] ?? await _generateThumbnail(bytes);

      // Convert to ImageAnalysis
      final analysis = ImageAnalysis(
        imagePath: savedPath ?? fileName, // Use saved path if available
        fileName: data['fileName'] ?? fileName,
        meanRed: (data['meanRed'] ?? 0.0).toDouble(),
        meanGreen: (data['meanGreen'] ?? 0.0).toDouble(),
        meanBlue: (data['meanBlue'] ?? 0.0).toDouble(),
        meanRChromaticity: (data['meanRChromaticity'] ?? 0.0).toDouble(),
        meanGChromaticity: (data['meanGChromaticity'] ?? 0.0).toDouble(),
        stdRChromaticity: (data['stdRChromaticity'] ?? 0.0).toDouble(),
        stdGChromaticity: (data['stdGChromaticity'] ?? 0.0).toDouble(),
        maxRed: (data['maxRed'] ?? 0.0).toDouble(),
        maxGreen: (data['maxGreen'] ?? 0.0).toDouble(),
        maxBlue: (data['maxBlue'] ?? 0.0).toDouble(),
        exifData: Map<String, dynamic>.from(data['exifData'] ?? {}),
        analysisDate: DateTime.parse(
          data['analysisDate'] ?? DateTime.now().toIso8601String(),
        ),
        fileSize: data['fileSize'] ?? _formatFileSize(fileSize),
        imageFormat: data['imageFormat'] ?? _getFileExtension(fileName),
        imageWidth: data['imageWidth']?.toInt(),
        imageHeight: data['imageHeight']?.toInt(),
        lampCondition: data['lampCondition'],
        sV: data['sV']?.toDouble(),
        aV: data['aV']?.toDouble(),
        tV: data['tV']?.toDouble(),
        bV: data['bV']?.toDouble(),
        thumbnailBase64: thumbnailBase64,
      );

      onProgress?.call(1.0, 'Analysis complete!');
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('✅ Python API analysis complete for $fileName');

      return analysis;
    } catch (e) {
      debugPrint('❌ Python API error: $e');
      throw Exception('Failed to analyze image via Python API: $e');
    }
  }

  /// Check if Python API is available
  static Future<bool> isApiAvailable() async {
    try {
      // Check the root endpoint, not /api
      final baseUri = _baseUrl.replaceAll('/api', '');
      final uri = Uri.parse(baseUri);
      debugPrint('Checking Python API at: $uri');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 30), // Longer timeout for Render cold starts
          );
      debugPrint('Python API response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Python API not available: $e');
      return false;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'UNKNOWN';
  }

  /// Generate a thumbnail for preview (max 200x200)
  static Future<String?> _generateThumbnail(Uint8List bytes) async {
    try {
      debugPrint('Generating thumbnail...');
      
      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('Failed to decode image for thumbnail');
        return null;
      }

      // Calculate thumbnail size (max 200x200, maintain aspect ratio)
      const maxSize = 200;
      int thumbnailWidth;
      int thumbnailHeight;
      
      if (image.width > image.height) {
        thumbnailWidth = maxSize;
        thumbnailHeight = (maxSize * image.height / image.width).round();
      } else {
        thumbnailHeight = maxSize;
        thumbnailWidth = (maxSize * image.width / image.height).round();
      }

      // Resize image
      final thumbnail = img.copyResize(
        image,
        width: thumbnailWidth,
        height: thumbnailHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG with decent quality
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);
      
      // Convert to base64
      final base64Thumbnail = base64Encode(thumbnailBytes);
      
      debugPrint('Thumbnail generated: ${thumbnailWidth}x${thumbnailHeight}, ${thumbnailBytes.length} bytes');
      
      return base64Thumbnail;
    } catch (e) {
      debugPrint('Failed to generate thumbnail: $e');
      return null;
    }
  }
}
