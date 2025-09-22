import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'package:path/path.dart' as path;
import '../models/image_analysis.dart';
import 'photographic_calculations.dart';
import 'exif_adapter.dart';

class UnifiedImageService {
  static const List<String> supportedFormats = [
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'gif',
    'webp',
    'dng',
    'raw',
    'cr2',
    'nef',
    'arw',
    'rw2',
  ];

  static bool isSupportedFormat(String fileName) {
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceAll('.', '');
    return supportedFormats.contains(extension);
  }

  static Future<ImageAnalysis> analyzeImageFromBytes(
    Uint8List bytes,
    String fileName,
    int fileSize,
  ) async {
    try {
      // Extract EXIF data
      final exifData = await _extractExifData(bytes);

      // Calculate mean RGB and chromaticity values
      final rgbValues = await _calculateMeanRGB(bytes);
      final chromaticityValues = await _calculateChromaticityValues(bytes);

      // Calculate photographic values
      final photographicValues = PhotographicCalculations.calculateAllValues(
        exifData,
      );

      return ImageAnalysis(
        imagePath: fileName, // Use filename as path
        fileName: fileName,
        meanRed: rgbValues['red'] ?? 0.0,
        meanGreen: rgbValues['green'] ?? 0.0,
        meanBlue: rgbValues['blue'] ?? 0.0,
        meanRChromaticity: chromaticityValues['meanRChromaticity'] ?? 0.0,
        meanGChromaticity: chromaticityValues['meanGChromaticity'] ?? 0.0,
        stdRChromaticity: chromaticityValues['stdRChromaticity'] ?? 0.0,
        stdGChromaticity: chromaticityValues['stdGChromaticity'] ?? 0.0,
        maxRed: chromaticityValues['maxRed'] ?? 0.0,
        maxGreen: chromaticityValues['maxGreen'] ?? 0.0,
        maxBlue: chromaticityValues['maxBlue'] ?? 0.0,
        exifData: exifData,
        analysisDate: DateTime.now(),
        fileSize: _formatFileSize(fileSize),
        imageFormat: _getFileExtension(fileName),
        sV: photographicValues['sV'],
        aV: photographicValues['aV'],
        tV: photographicValues['tV'],
        bV: photographicValues['bV'],
      );
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  static Future<ImageAnalysis> analyzeImageFromFile(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName = path.basename(imagePath);
      final fileSize = await file.length();
      final bytes = await file.readAsBytes();

      final rgbValues = await _calculateMeanRGB(bytes);
      final chromaticityValues = await _calculateChromaticityValues(bytes);
      final exifData = await _extractExifData(bytes);
      final format = _getFileExtension(fileName);

      // Calculate photographic values
      final photographicValues = PhotographicCalculations.calculateAllValues(
        exifData,
      );

      return ImageAnalysis(
        imagePath: imagePath,
        fileName: fileName,
        meanRed: rgbValues['red'] ?? 0.0,
        meanGreen: rgbValues['green'] ?? 0.0,
        meanBlue: rgbValues['blue'] ?? 0.0,
        meanRChromaticity: chromaticityValues['meanRChromaticity'] ?? 0.0,
        meanGChromaticity: chromaticityValues['meanGChromaticity'] ?? 0.0,
        stdRChromaticity: chromaticityValues['stdRChromaticity'] ?? 0.0,
        stdGChromaticity: chromaticityValues['stdGChromaticity'] ?? 0.0,
        maxRed: chromaticityValues['maxRed'] ?? 0.0,
        maxGreen: chromaticityValues['maxGreen'] ?? 0.0,
        maxBlue: chromaticityValues['maxBlue'] ?? 0.0,
        exifData: exifData,
        analysisDate: DateTime.now(),
        fileSize: _formatFileSize(fileSize),
        imageFormat: format,
        sV: photographicValues['sV'],
        aV: photographicValues['aV'],
        tV: photographicValues['tV'],
        bV: photographicValues['bV'],
      );
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  static Future<Map<String, double>> _calculateMeanRGB(Uint8List bytes) async {
    try {
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      double totalRed = 0;
      double totalGreen = 0;
      double totalBlue = 0;
      int pixelCount = 0;

      // Process ALL pixels for accurate mean RGB calculation
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // Extract RGB values from pixel
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          totalRed += r.toDouble();
          totalGreen += g.toDouble();
          totalBlue += b.toDouble();
          pixelCount++;
        }
      }

      if (pixelCount == 0) {
        return {'red': 0.0, 'green': 0.0, 'blue': 0.0};
      }

      return {
        'red': totalRed / pixelCount,
        'green': totalGreen / pixelCount,
        'blue': totalBlue / pixelCount,
      };
    } catch (e) {
      throw Exception('Failed to calculate RGB values: $e');
    }
  }

  static Future<Map<String, double>> _calculateChromaticityValues(
    Uint8List bytes,
  ) async {
    try {
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final List<double> rChromaticity = [];
      final List<double> gChromaticity = [];

      // Track max RGB values from ALL pixels (separate from chromaticity)
      double maxR = 0.0;
      double maxG = 0.0;
      double maxB = 0.0;

      // Single pass through ALL pixels for both max values and chromaticity
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);

          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          // Update max RGB values (actual pixel values, not chromaticity)
          if (r > maxR) maxR = r;
          if (g > maxG) maxG = g;
          if (b > maxB) maxB = b;

          // Calculate chromaticity for ALL pixels
          final sum = r + g + b;
          if (sum > 0.001) {
            rChromaticity.add(r / sum);
            gChromaticity.add(g / sum);
          }
        }
      }

      // Debug output to verify max values
      debugPrint('Image dimensions: ${image.width}x${image.height}');
      debugPrint('Max RGB values: R=$maxR, G=$maxG, B=$maxB');

      if (rChromaticity.isEmpty) {
        return {
          'meanRChromaticity': 0.0,
          'meanGChromaticity': 0.0,
          'stdRChromaticity': 0.0,
          'stdGChromaticity': 0.0,
          'maxRed': maxR,
          'maxGreen': maxG,
          'maxBlue': maxB,
        };
      }

      // Calculate mean chromaticity values
      final meanR =
          rChromaticity.reduce((a, b) => a + b) / rChromaticity.length;
      final meanG =
          gChromaticity.reduce((a, b) => a + b) / gChromaticity.length;

      // Calculate standard deviation
      final stdR = sqrt(
        rChromaticity
                .map((val) => pow(val - meanR, 2))
                .reduce((a, b) => a + b) /
            rChromaticity.length,
      );
      final stdG = sqrt(
        gChromaticity
                .map((val) => pow(val - meanG, 2))
                .reduce((a, b) => a + b) /
            gChromaticity.length,
      );

      return {
        'meanRChromaticity': meanR,
        'meanGChromaticity': meanG,
        'stdRChromaticity': stdR,
        'stdGChromaticity': stdG,
        'maxRed': maxR,
        'maxGreen': maxG,
        'maxBlue': maxB,
      };
    } catch (e) {
      throw Exception('Failed to calculate chromaticity values: $e');
    }
  }

  static Future<Map<String, dynamic>> _extractExifData(Uint8List bytes) async {
    try {
      final exifData = await readExifFromBytes(bytes);
      debugPrint('Raw EXIF data found: ${exifData.length} entries');

      // Enhanced debugging for DNG files
      if (exifData.isNotEmpty) {
        debugPrint('EXIF keys found: ${exifData.keys.toList()}');

        // Check for specific tags that might indicate incomplete parsing
        final importantTags = [
          'EXIF ISOSpeedRatings',
          'ISOSpeedRatings',
          'EXIF FNumber',
          'FNumber',
          'EXIF ExposureTime',
          'ExposureTime',
          'Image Make',
          'Image Model',
          'EXIF DateTimeOriginal',
          'EXIF DateTimeDigitized',
        ];

        final foundTags = importantTags
            .where((tag) => exifData.containsKey(tag))
            .toList();
        final missingTags = importantTags
            .where((tag) => !exifData.containsKey(tag))
            .toList();

        debugPrint('Important tags found: $foundTags');
        debugPrint('Important tags missing: $missingTags');
      }

      if (exifData.isEmpty) {
        debugPrint('No EXIF data found in image - this may indicate:');
        debugPrint('1. File has no EXIF data');
        debugPrint('2. DNG/RAW format not fully supported by exif package');
        debugPrint('3. File is corrupted or encrypted');
        return {'message': 'No EXIF data found'};
      }

      final Map<String, dynamic> formattedExif = ExifAdapter.processExifData(
        exifData,
      );

      debugPrint('Successfully processed ${formattedExif.length} EXIF fields');
      return formattedExif;
    } catch (e) {
      debugPrint('EXIF extraction error: $e');
      debugPrint(
        'This is common with DNG files - the exif package has limited RAW format support',
      );
      return {'error': 'Failed to extract EXIF data: $e'};
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'unknown';
  }

  static Future<List<ImageAnalysis>> analyzeMultipleImages(
    List<String> imagePaths,
  ) async {
    final List<ImageAnalysis> analyses = [];

    for (final imagePath in imagePaths) {
      try {
        final analysis = await analyzeImageFromFile(imagePath);
        analyses.add(analysis);
      } catch (e) {
        debugPrint('Failed to analyze $imagePath: $e');
      }
    }

    return analyses;
  }
}
