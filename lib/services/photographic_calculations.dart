import 'dart:math';
import 'package:flutter/foundation.dart';

class PhotographicCalculations {
  static const List<String> lampConditions = [
    '222Lumen',
    '222Nukit',
    '222Ushio',
    '222unfiltered',
    '254',
    '265LED',
    '280LED',
    '295LED',
    '365',
    'KrBr',
    'room',
  ];

  /// Calculate S_v = log2(ISOSpeedRatings/3.3333)
  static double? calculateSV(int? isoSpeedRatings) {
    if (isoSpeedRatings == null || isoSpeedRatings <= 0) return null;
    return log(isoSpeedRatings / 3.3333) / log(2);
  }

  /// Calculate A_v = 2 * log2(FNumber)
  static double? calculateAV(double? fNumber) {
    if (fNumber == null || fNumber <= 0) return null;
    return 2 * log(fNumber) / log(2);
  }

  /// Calculate T_v = -log2(ExposureTime)
  static double? calculateTV(double? exposureTime) {
    if (exposureTime == null || exposureTime <= 0) return null;
    return -log(exposureTime) / log(2);
  }

  /// Calculate B_v = A_v + T_v - S_v
  static double? calculateBV(double? aV, double? tV, double? sV) {
    if (aV == null || tV == null || sV == null) return null;
    return aV + tV - sV;
  }

  /// Extract and calculate all photographic values from EXIF data
  static Map<String, double?> calculateAllValues(
    Map<String, dynamic> exifData,
  ) {
    // Extract EXIF values
    final isoSpeedRatings = _extractISOSpeedRatings(exifData);
    final fNumber = _extractFNumber(exifData);
    final exposureTime = _extractExposureTime(exifData);

    // Calculate values
    final sV = calculateSV(isoSpeedRatings);
    final aV = calculateAV(fNumber);
    final tV = calculateTV(exposureTime);
    final bV = calculateBV(aV, tV, sV);

    // Debug output
    debugPrint(
      'EXIF Data: ISO=$isoSpeedRatings, FNumber=$fNumber, ExposureTime=$exposureTime',
    );
    debugPrint('Calculated: S_v=$sV, A_v=$aV, T_v=$tV, B_v=$bV');

    return {'sV': sV, 'aV': aV, 'tV': tV, 'bV': bV};
  }

  /// Extract ISO Speed Ratings from EXIF data
  static int? _extractISOSpeedRatings(Map<String, dynamic> exifData) {
    // Try different possible EXIF keys for ISO
    final isoKeys = [
      'EXIF ISOSpeedRatings',
      'ISOSpeedRatings',
      'ISO',
      'ISOSpeedRating',
      'PhotographicSensitivity',
    ];

    for (final key in isoKeys) {
      final value = exifData[key];
      if (value != null) {
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  /// Extract F-Number from EXIF data
  static double? _extractFNumber(Map<String, dynamic> exifData) {
    // Try different possible EXIF keys for F-Number
    final fNumberKeys = [
      'EXIF FNumber',
      'FNumber',
      'F-Number',
      'EXIF ApertureValue',
      'ApertureValue',
    ];

    for (final key in fNumberKeys) {
      final value = exifData[key];
      if (value != null) {
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  /// Extract Exposure Time from EXIF data
  static double? _extractExposureTime(Map<String, dynamic> exifData) {
    // Try different possible EXIF keys for Exposure Time
    final exposureKeys = [
      'EXIF ExposureTime',
      'ExposureTime',
      'Exposure Time',
      'EXIF ShutterSpeedValue',
      'ShutterSpeedValue',
    ];

    for (final key in exposureKeys) {
      final value = exifData[key];
      if (value != null) {
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) {
          // Handle fractions like "1/60"
          if (value.contains('/')) {
            final parts = value.split('/');
            if (parts.length == 2) {
              final numerator = double.tryParse(parts[0]);
              final denominator = double.tryParse(parts[1]);
              if (numerator != null &&
                  denominator != null &&
                  denominator != 0) {
                return numerator / denominator;
              }
            }
          } else {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
      }
    }
    return null;
  }

  /// Test method to verify calculations are working correctly
  static void testCalculations() {
    debugPrint('=== Testing Photographic Calculations ===');

    // Test with sample values
    final testISO = 100;
    final testFNumber = 2.8;
    final testExposureTime = 1.0 / 60.0; // 1/60 second

    final sV = calculateSV(testISO);
    final aV = calculateAV(testFNumber);
    final tV = calculateTV(testExposureTime);
    final bV = calculateBV(aV, tV, sV);

    debugPrint(
      'Test values: ISO=$testISO, FNumber=$testFNumber, ExposureTime=$testExposureTime',
    );
    debugPrint('S_v = log2($testISO/3.3333) = log2(${testISO / 3.3333}) = $sV');
    debugPrint(
      'A_v = 2 * log2($testFNumber) = 2 * ${log(testFNumber) / log(2)} = $aV',
    );
    debugPrint(
      'T_v = -log2($testExposureTime) = -${log(testExposureTime) / log(2)} = $tV',
    );
    debugPrint('B_v = $aV + $tV - $sV = $bV');

    // Test with null values
    debugPrint('Testing with null values:');
    final nullSV = calculateSV(null);
    final nullAV = calculateAV(null);
    final nullTV = calculateTV(null);
    final nullBV = calculateBV(null, null, null);
    debugPrint(
      'Null S_v = $nullSV, A_v = $nullAV, T_v = $nullTV, B_v = $nullBV',
    );

    debugPrint('=== End Test ===');
  }
}
