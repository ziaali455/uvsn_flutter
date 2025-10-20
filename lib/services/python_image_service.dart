import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/image_analysis.dart';

/// Service to call Python backend for image analysis
/// This allows testing Python implementation alongside Flutter implementation
class PythonImageService {
  // Use environment variable or default to Render API
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: kIsWeb
        ? 'https://uvsn-flutter-python-api.onrender.com/api' // Render production
        : 'http://localhost:3000/api', // Local development
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

      // Convert to ImageAnalysis
      final analysis = ImageAnalysis(
        imagePath: fileName,
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
        lampCondition: data['lampCondition'],
        sV: data['sV']?.toDouble(),
        aV: data['aV']?.toDouble(),
        tV: data['tV']?.toDouble(),
        bV: data['bV']?.toDouble(),
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
      final uri = Uri.parse(_baseUrl);
      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );
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
}
