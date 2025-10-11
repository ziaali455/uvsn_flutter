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
    final extension =
        path.extension(fileName).toLowerCase().replaceAll('.', '');
    return supportedFormats.contains(extension);
  }

  static Future<ImageAnalysis> analyzeImageFromBytes(
    Uint8List bytes,
    String fileName,
    int fileSize, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // Process all images regardless of size - no limits for accurate analysis
      debugPrint(
          'Processing image: ${fileName} (${_formatFileSize(fileSize)})');

      // No timeout - let it process completely for accurate results
      onProgress?.call(0.0, 'Starting analysis...');
      return await _performAnalysis(bytes, fileName, fileSize,
          onProgress: onProgress);
    } catch (e) {
      // Check if this is a compression type 7 issue and provide helpful error message
      if (e.toString().contains('Unsupported Compression Type: 7')) {
        throw Exception(
            '❌ DNG Compression Issue: This DNG file uses compression type 7 (JPEG new-style) which is not supported. This is common with phone camera DNG files. Try using a different DNG file or convert it to JPEG/TIFF first.');
      }
      if (e
          .toString()
          .contains('Failed to decode image - format may not be supported')) {
        throw Exception(
            '❌ DNG Format Issue: This DNG file format is not supported by the analyzer. Phone DNG files often use proprietary compression. Try using the embedded JPEG preview or convert the file first.');
      }
      throw Exception('Failed to analyze image: $e');
    }
  }

  static Future<ImageAnalysis> _performAnalysis(
    Uint8List bytes,
    String fileName,
    int fileSize, {
    Function(double progress, String status)? onProgress,
  }) async {
    // Extract EXIF data
    onProgress?.call(0.1, 'Extracting EXIF data...');
    final exifData = await _extractExifData(bytes);

    // Calculate mean RGB and chromaticity values with proper error handling
    onProgress?.call(0.2, 'Analyzing RGB values...');
    final rgbValues = await _calculateMeanRGB(bytes, onProgress: onProgress);

    onProgress?.call(0.7, 'Calculating chromaticity...');
    final chromaticityValues =
        await _calculateChromaticityValues(bytes, onProgress: onProgress);

    // Calculate photographic values
    onProgress?.call(0.95, 'Finalizing analysis...');
    final photographicValues = PhotographicCalculations.calculateAllValues(
      exifData,
    );

    onProgress?.call(1.0, 'Analysis complete!');

    // Brief pause to show completion
    await Future.delayed(const Duration(milliseconds: 500));

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

  static Future<Map<String, double>> _calculateMeanRGB(
    Uint8List bytes, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // Decode image with enhanced DNG support
      final image = await _decodeImageWithFallbacks(bytes);
      if (image == null) {
        throw Exception(
            'Failed to decode image - format may not be supported or file may be corrupted');
      }

      final totalPixels = image.width * image.height;
      debugPrint(
          'Image dimensions: ${image.width}x${image.height} (${totalPixels} total pixels)');

      // Performance safeguard: Use intelligent processing strategy
      const maxDirectPixels = 2000000; // 2M pixels - safe for direct processing
      const batchSize = 10000; // Process in batches to avoid blocking

      // Emergency safeguard: Warn about very large images
      if (totalPixels > 20000000) {
        // 20M pixels
        debugPrint(
            '⚠️  WARNING: Very large image detected (${totalPixels} pixels)');
        debugPrint('⚠️  This may take significant time to process');
      }

      double totalRed = 0;
      double totalGreen = 0;
      double totalBlue = 0;
      int pixelCount = 0;

      if (totalPixels <= maxDirectPixels) {
        // Small/medium images: Process all pixels directly
        debugPrint(
            '✅ PROCESSING ALL ${totalPixels} PIXELS (small/medium image)');

        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r;
            final g = pixel.g;
            final b = pixel.b;
            totalRed += r.toDouble();
            totalGreen += g.toDouble();
            totalBlue += b.toDouble();
            pixelCount++;
          }

          // Yield to event loop every few rows to prevent freezing
          if (y % 100 == 0) {
            await Future.delayed(Duration.zero);
            // Update progress for RGB calculation (20% to 70% of total)
            final progress = 0.2 + (y / image.height) * 0.5;
            onProgress?.call(progress,
                'Processing RGB: ${(y / image.height * 100).toStringAsFixed(1)}%');
          }
        }
      } else {
        // Large images: Process in batches with yielding
        debugPrint(
            '⚡ PROCESSING ALL ${totalPixels} PIXELS IN BATCHES (large image)');

        int processedInBatch = 0;

        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r;
            final g = pixel.g;
            final b = pixel.b;
            totalRed += r.toDouble();
            totalGreen += g.toDouble();
            totalBlue += b.toDouble();
            pixelCount++;
            processedInBatch++;

            // Yield to event loop every batch to prevent browser freeze
            if (processedInBatch >= batchSize) {
              await Future.delayed(Duration.zero);
              processedInBatch = 0;

              // Progress update for large images
              if (pixelCount % 100000 == 0) {
                final imageProgress = pixelCount / totalPixels;
                final overallProgress =
                    0.2 + imageProgress * 0.5; // RGB is 20% to 70% of total
                final progressPercent =
                    (imageProgress * 100).toStringAsFixed(1);
                debugPrint(
                    'Progress: $progressPercent% (${pixelCount}/${totalPixels} pixels)');
                onProgress?.call(
                    overallProgress, 'Processing RGB: $progressPercent%');
              }
            }
          }
        }
      }

      debugPrint(
          '✅ COMPLETED: Processed all $pixelCount pixels (${image.width}x${image.height})');

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
    Uint8List bytes, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // Decode image with enhanced DNG support
      final image = await _decodeImageWithFallbacks(bytes);
      if (image == null) {
        throw Exception(
            'Failed to decode image - format may not be supported or file may be corrupted');
      }

      final totalPixels = image.width * image.height;
      debugPrint(
          'Chromaticity analysis for ${image.width}x${image.height} (${totalPixels} pixels)');

      // Performance safeguards for chromaticity calculation
      const maxDirectPixels = 2000000; // 2M pixels safe for direct processing
      const batchSize = 10000; // Process in batches

      // Use streaming statistics instead of storing all values
      double sumRChromaticity = 0.0;
      double sumGChromaticity = 0.0;
      double sumRChromaticitySquared = 0.0;
      double sumGChromaticitySquared = 0.0;
      int chromaticityCount = 0;

      // Track max RGB values (separate from chromaticity)
      double maxR = 0.0;
      double maxG = 0.0;
      double maxB = 0.0;

      if (totalPixels <= maxDirectPixels) {
        // Small/medium images: Process all pixels with streaming stats
        debugPrint(
            '✅ PROCESSING ALL ${totalPixels} PIXELS FOR CHROMATICITY (small/medium image)');

        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();

            // Update max RGB values
            if (r > maxR) maxR = r;
            if (g > maxG) maxG = g;
            if (b > maxB) maxB = b;

            // Calculate chromaticity using streaming statistics
            final sum = r + g + b;
            if (sum > 0.001) {
              final rChrom = r / sum;
              final gChrom = g / sum;

              sumRChromaticity += rChrom;
              sumGChromaticity += gChrom;
              sumRChromaticitySquared += rChrom * rChrom;
              sumGChromaticitySquared += gChrom * gChrom;
              chromaticityCount++;
            }
          }

          // Yield every few rows
          if (y % 100 == 0) {
            await Future.delayed(Duration.zero);
            // Update progress for chromaticity calculation (70% to 95% of total)
            final progress = 0.7 + (y / image.height) * 0.25;
            onProgress?.call(progress,
                'Calculating chromaticity: ${(y / image.height * 100).toStringAsFixed(1)}%');
          }
        }
      } else {
        // Large images: Process in batches with streaming stats
        debugPrint(
            '⚡ PROCESSING ALL ${totalPixels} PIXELS FOR CHROMATICITY IN BATCHES (large image)');

        int processedInBatch = 0;
        int totalProcessed = 0;

        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();

            // Update max RGB values
            if (r > maxR) maxR = r;
            if (g > maxG) maxG = g;
            if (b > maxB) maxB = b;

            // Calculate chromaticity using streaming statistics
            final sum = r + g + b;
            if (sum > 0.001) {
              final rChrom = r / sum;
              final gChrom = g / sum;

              sumRChromaticity += rChrom;
              sumGChromaticity += gChrom;
              sumRChromaticitySquared += rChrom * rChrom;
              sumGChromaticitySquared += gChrom * gChrom;
              chromaticityCount++;
            }

            totalProcessed++;
            processedInBatch++;

            // Yield to event loop every batch
            if (processedInBatch >= batchSize) {
              await Future.delayed(Duration.zero);
              processedInBatch = 0;

              // Progress update
              if (totalProcessed % 100000 == 0) {
                final imageProgress = totalProcessed / totalPixels;
                final overallProgress = 0.7 +
                    imageProgress * 0.25; // Chromaticity is 70% to 95% of total
                final progressPercent =
                    (imageProgress * 100).toStringAsFixed(1);
                debugPrint(
                    'Chromaticity progress: $progressPercent% (${totalProcessed}/${totalPixels} pixels)');
                onProgress?.call(overallProgress,
                    'Calculating chromaticity: $progressPercent%');
              }
            }
          }
        }
      }

      debugPrint('✅ COMPLETED: Chromaticity analysis finished');
      debugPrint(
          'Max RGB values (16-bit precision): R=$maxR, G=$maxG, B=$maxB');
      debugPrint('Chromaticity samples: $chromaticityCount');

      if (chromaticityCount == 0) {
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

      // Calculate mean chromaticity values using streaming statistics
      final meanR = sumRChromaticity / chromaticityCount;
      final meanG = sumGChromaticity / chromaticityCount;

      // Calculate standard deviation using streaming statistics
      // Var(X) = E[X²] - (E[X])²
      final varianceR =
          (sumRChromaticitySquared / chromaticityCount) - (meanR * meanR);
      final varianceG =
          (sumGChromaticitySquared / chromaticityCount) - (meanG * meanG);

      final stdR = sqrt(
          varianceR.abs()); // abs() to handle floating point precision issues
      final stdG = sqrt(varianceG.abs());

      debugPrint('Chromaticity means: R=$meanR, G=$meanG');
      debugPrint('Chromaticity std devs: R=$stdR, G=$stdG');

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

  /// Enhanced image decoder with fallbacks for DNG and other RAW formats
  static Future<img.Image?> _decodeImageWithFallbacks(Uint8List bytes) async {
    // Quick check: if this looks like a standard JPEG/PNG, skip DNG analysis
    final isLikelyStandardFormat = _isLikelyStandardImageFormat(bytes);
    if (!isLikelyStandardFormat) {
      // Only analyze DNG structure for files that might be DNG/RAW
      await _analyzeDngFileStructure(bytes);
    }

    // Attempt 1: Standard decode (catches compression issues)
    debugPrint('=== DECODE ATTEMPT 1: Standard decoder ===');
    try {
      final image = img.decodeImage(bytes);
      if (image != null) {
        debugPrint('✅ SUCCESS: Standard decoder worked');
        debugPrint('Image dimensions: ${image.width}x${image.height}');
        debugPrint('Image format: ${image.format}');
        debugPrint('Image channels: ${image.numChannels}');
        return image;
      }
      debugPrint('❌ Standard decoder returned null');
    } catch (e) {
      debugPrint('❌ Standard decoder failed: $e');
      if (e.toString().contains('Unsupported Compression Type')) {
        debugPrint('🔍 COMPRESSION ISSUE DETECTED: ${e.toString()}');
        debugPrint(
            'This DNG uses unsupported compression - trying preview extraction...');
      }
    }

    // Attempt 2: TIFF/DNG decoder (may handle different compression)
    debugPrint('=== DECODE ATTEMPT 2: TIFF/DNG decoder ===');
    try {
      final dngImage = img.decodeTiff(bytes);
      if (dngImage != null) {
        debugPrint('✅ SUCCESS: TIFF/DNG decoder worked');
        debugPrint('DNG dimensions: ${dngImage.width}x${dngImage.height}');
        return dngImage;
      }
      debugPrint('❌ TIFF decoder returned null');
    } catch (e) {
      debugPrint('❌ TIFF decoder failed: $e');
      if (e.toString().contains('Unsupported Compression Type')) {
        debugPrint('🔍 TIFF COMPRESSION ISSUE: ${e.toString()}');
      }
    }

    // Attempt 3: Direct JPEG preview search (bypass compression issues)
    debugPrint('=== DECODE ATTEMPT 3: Direct JPEG preview extraction ===');
    try {
      final previewImage = await _extractDngPreview(bytes);
      if (previewImage != null) {
        debugPrint('✅ SUCCESS: Extracted JPEG preview from DNG');
        debugPrint(
            'Preview dimensions: ${previewImage.width}x${previewImage.height}');
        return previewImage;
      }
      debugPrint('❌ No JPEG preview found in DNG');
    } catch (e) {
      debugPrint('❌ JPEG preview extraction failed: $e');
    }

    // Attempt 4: Multiple JPEG preview search (some DNGs have multiple previews)
    debugPrint('=== DECODE ATTEMPT 4: Multiple JPEG preview search ===');
    try {
      final multiPreviewImage = await _extractMultipleDngPreviews(bytes);
      if (multiPreviewImage != null) {
        debugPrint('✅ SUCCESS: Found alternative JPEG preview');
        debugPrint(
            'Alt preview dimensions: ${multiPreviewImage.width}x${multiPreviewImage.height}');
        return multiPreviewImage;
      }
      debugPrint('❌ No alternative previews found');
    } catch (e) {
      debugPrint('❌ Multiple preview search failed: $e');
    }

    // Attempt 5: Try PNG decoder (some DNG files have PNG previews)
    debugPrint('=== DECODE ATTEMPT 5: PNG preview decoder ===');
    try {
      final pngImage = img.decodePng(bytes);
      if (pngImage != null) {
        debugPrint('✅ SUCCESS: Found PNG preview in DNG');
        return pngImage;
      }
      debugPrint('❌ No PNG preview found');
    } catch (e) {
      debugPrint('❌ PNG decoder failed: $e');
    }

    // Attempt 6: Raw JPEG decoder on full file
    debugPrint('=== DECODE ATTEMPT 6: Raw JPEG decoder ===');
    try {
      final jpegImage = img.decodeJpg(bytes);
      if (jpegImage != null) {
        debugPrint('✅ SUCCESS: File decoded as JPEG');
        return jpegImage;
      }
      debugPrint('❌ File is not a JPEG');
    } catch (e) {
      debugPrint('❌ JPEG decoder failed: $e');
    }

    debugPrint('💥 ALL DECODE ATTEMPTS FAILED');
    debugPrint('🔍 DIAGNOSIS: This DNG file cannot be processed because:');
    debugPrint(
        '   1. Uses unsupported compression (likely compression type 7)');
    debugPrint('   2. No accessible embedded previews found');
    debugPrint('   3. Flutter image package limitations with this DNG variant');
    debugPrint('📱 PHONE DNG ISSUE: Many phone cameras create DNG files with');
    debugPrint(
        '   proprietary compression that requires manufacturer-specific decoders');

    return null;
  }

  /// Quick check to see if this is likely a standard image format (JPEG, PNG, etc.)
  static bool _isLikelyStandardImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // Check for common image format signatures
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      debugPrint('🔍 Detected JPEG format - skipping DNG analysis');
      return true;
    }

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      debugPrint('🔍 Detected PNG format - skipping DNG analysis');
      return true;
    }

    // GIF: 47 49 46 38 or 47 49 46 39
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        (bytes[3] == 0x38 || bytes[3] == 0x39)) {
      debugPrint('🔍 Detected GIF format - skipping DNG analysis');
      return true;
    }

    // WebP: 52 49 46 46 (RIFF) + WEBP at offset 8
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      debugPrint('🔍 Detected WebP format - skipping DNG analysis');
      return true;
    }

    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      debugPrint('🔍 Detected BMP format - skipping DNG analysis');
      return true;
    }

    debugPrint('🔍 Unknown format - will perform DNG analysis');
    return false;
  }

  /// Analyzes DNG file structure to understand compression and format
  static Future<void> _analyzeDngFileStructure(Uint8List bytes) async {
    try {
      debugPrint('🔍 ANALYZING DNG FILE STRUCTURE');
      debugPrint('File size: ${bytes.length} bytes');

      // Check file signature
      if (bytes.length >= 4) {
        final signature = bytes.sublist(0, 4);
        debugPrint(
            'File signature: ${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

        // Check for TIFF signature (DNG is based on TIFF)
        if ((signature[0] == 0x49 && signature[1] == 0x49) ||
            (signature[0] == 0x4D && signature[1] == 0x4D)) {
          debugPrint('✅ Valid TIFF/DNG signature detected');
        } else {
          debugPrint('❌ Invalid TIFF/DNG signature');
        }
      }

      // Look for DNG version info
      final dngVersionIndex =
          _findByteSequence(bytes, [0x01, 0x00, 0x00, 0x00]); // DNG version tag
      if (dngVersionIndex != -1) {
        debugPrint('📋 DNG version info found at offset $dngVersionIndex');
      }

      // Count JPEG markers (indicates embedded previews)
      final jpegCount = _countJpegMarkers(bytes);
      debugPrint('📸 JPEG markers found: $jpegCount');
      if (jpegCount > 0) {
        debugPrint('✅ Embedded JPEG previews likely present');
      } else {
        debugPrint('❌ No JPEG previews detected');
      }

      // Skip compression analysis - too noisy and unreliable
    } catch (e) {
      debugPrint('Error analyzing DNG structure: $e');
    }
  }

  /// Analyzes compression information in the DNG file

  /// Counts JPEG markers in the file
  static int _countJpegMarkers(Uint8List bytes) {
    int count = 0;
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
        count++;
      }
    }
    return count;
  }

  /// Finds a byte sequence in the file
  static int _findByteSequence(Uint8List bytes, List<int> sequence) {
    for (int i = 0; i <= bytes.length - sequence.length; i++) {
      bool found = true;
      for (int j = 0; j < sequence.length; j++) {
        if (bytes[i + j] != sequence[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Attempts to find multiple JPEG previews in DNG files
  static Future<img.Image?> _extractMultipleDngPreviews(Uint8List bytes) async {
    try {
      final jpegMarker = [0xFF, 0xD8];
      final jpegEndMarker = [0xFF, 0xD9];
      final List<img.Image> foundPreviews = [];

      int searchStart = 0;

      // Look for multiple JPEG previews
      while (searchStart < bytes.length - 1) {
        int startIndex = -1;

        // Find next JPEG start marker
        for (int i = searchStart; i < bytes.length - 1; i++) {
          if (bytes[i] == jpegMarker[0] && bytes[i + 1] == jpegMarker[1]) {
            startIndex = i;
            break;
          }
        }

        if (startIndex == -1) break;

        // Find corresponding end marker
        int endIndex = -1;
        for (int i = startIndex + 2; i < bytes.length - 1; i++) {
          if (bytes[i] == jpegEndMarker[0] &&
              bytes[i + 1] == jpegEndMarker[1]) {
            endIndex = i + 2;
            break;
          }
        }

        if (endIndex != -1) {
          try {
            final previewBytes = bytes.sublist(startIndex, endIndex);
            final previewImage = img.decodeJpg(previewBytes);
            if (previewImage != null) {
              debugPrint(
                  'Found JPEG preview: ${previewImage.width}x${previewImage.height} at offset $startIndex');
              foundPreviews.add(previewImage);
            }
          } catch (e) {
            debugPrint('Failed to decode JPEG at offset $startIndex: $e');
          }
        }

        searchStart = startIndex + 2;
      }

      if (foundPreviews.isNotEmpty) {
        // Return the largest preview found
        foundPreviews
            .sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
        final largest = foundPreviews.first;
        debugPrint(
            'Returning largest preview: ${largest.width}x${largest.height}');
        return largest;
      }

      return null;
    } catch (e) {
      debugPrint('Error in multiple preview extraction: $e');
      return null;
    }
  }

  /// Attempts to extract embedded preview from DNG files
  static Future<img.Image?> _extractDngPreview(Uint8List bytes) async {
    try {
      // Look for JPEG preview markers in the DNG file
      // DNG files often contain embedded JPEG previews
      const jpegMarker = [0xFF, 0xD8]; // JPEG start marker
      const jpegEndMarker = [0xFF, 0xD9]; // JPEG end marker

      int startIndex = -1;
      int endIndex = -1;

      // Find JPEG start marker
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == jpegMarker[0] && bytes[i + 1] == jpegMarker[1]) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        debugPrint('No JPEG preview found in DNG');
        return null;
      }

      // Find JPEG end marker
      for (int i = startIndex + 2; i < bytes.length - 1; i++) {
        if (bytes[i] == jpegEndMarker[0] && bytes[i + 1] == jpegEndMarker[1]) {
          endIndex = i + 2;
          break;
        }
      }

      if (endIndex == -1) {
        debugPrint('Incomplete JPEG preview found in DNG');
        return null;
      }

      // Extract and decode the JPEG preview
      final previewBytes = bytes.sublist(startIndex, endIndex);
      debugPrint(
          'Extracted ${previewBytes.length} bytes of JPEG preview from DNG');

      final previewImage = img.decodeJpg(previewBytes);
      if (previewImage != null) {
        debugPrint(
            'Successfully decoded DNG JPEG preview: ${previewImage.width}x${previewImage.height}');
      }

      return previewImage;
    } catch (e) {
      debugPrint('Error extracting DNG preview: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _extractExifData(Uint8List bytes) async {
    try {
      // First attempt: Direct EXIF extraction
      debugPrint('Attempting direct EXIF extraction...');
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

        final foundTags =
            importantTags.where((tag) => exifData.containsKey(tag)).toList();
        final missingTags =
            importantTags.where((tag) => !exifData.containsKey(tag)).toList();

        debugPrint('Important tags found: $foundTags');
        debugPrint('Important tags missing: $missingTags');

        if (foundTags.isNotEmpty) {
          final Map<String, dynamic> formattedExif =
              ExifAdapter.processExifData(
            exifData,
          );
          debugPrint(
              'Successfully processed ${formattedExif.length} EXIF fields');
          return formattedExif;
        }
      }

      // Second attempt: Try extracting EXIF from embedded JPEG preview in DNG
      debugPrint(
          'Direct EXIF extraction failed or incomplete, trying DNG preview EXIF...');
      final previewExif = await _extractExifFromDngPreview(bytes);
      if (previewExif.isNotEmpty && !previewExif.containsKey('error')) {
        debugPrint('Successfully extracted EXIF from DNG preview');
        return previewExif;
      }

      // If no EXIF data found
      if (exifData.isEmpty) {
        debugPrint('No EXIF data found in image - this may indicate:');
        debugPrint('1. File has no EXIF data');
        debugPrint('2. DNG/RAW format not fully supported by exif package');
        debugPrint('3. File is corrupted or encrypted');
        debugPrint('4. Phone DNG may lack standard EXIF structure');
        return {
          'message': 'No EXIF data found',
          'note':
              'DNG files from phones may have limited or non-standard EXIF data'
        };
      }

      // Fallback: Return whatever EXIF data we found, even if incomplete
      final Map<String, dynamic> formattedExif = ExifAdapter.processExifData(
        exifData,
      );
      debugPrint(
          'Processed ${formattedExif.length} EXIF fields (may be incomplete)');
      return formattedExif;
    } catch (e) {
      debugPrint('EXIF extraction error: $e');
      debugPrint(
        'This is common with DNG files - the exif package has limited RAW format support',
      );
      return {
        'error': 'Failed to extract EXIF data: $e',
        'note':
            'DNG files from phones often have compatibility issues with standard EXIF readers'
      };
    }
  }

  /// Attempts to extract EXIF data from embedded JPEG preview in DNG files
  static Future<Map<String, dynamic>> _extractExifFromDngPreview(
      Uint8List bytes) async {
    try {
      // Look for JPEG preview in DNG and extract its EXIF
      const jpegMarker = [0xFF, 0xD8];
      const jpegEndMarker = [0xFF, 0xD9];

      int startIndex = -1;
      int endIndex = -1;

      // Find JPEG start marker
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == jpegMarker[0] && bytes[i + 1] == jpegMarker[1]) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) return {};

      // Find JPEG end marker
      for (int i = startIndex + 2; i < bytes.length - 1; i++) {
        if (bytes[i] == jpegEndMarker[0] && bytes[i + 1] == jpegEndMarker[1]) {
          endIndex = i + 2;
          break;
        }
      }

      if (endIndex == -1) return {};

      // Extract and read EXIF from JPEG preview
      final previewBytes = bytes.sublist(startIndex, endIndex);
      debugPrint(
          'Attempting EXIF extraction from ${previewBytes.length} byte JPEG preview');

      final previewExifData = await readExifFromBytes(previewBytes);
      if (previewExifData.isNotEmpty) {
        debugPrint(
            'Found ${previewExifData.length} EXIF entries in DNG preview');
        return ExifAdapter.processExifData(previewExifData);
      }

      return {};
    } catch (e) {
      debugPrint('Error extracting EXIF from DNG preview: $e');
      return {};
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
