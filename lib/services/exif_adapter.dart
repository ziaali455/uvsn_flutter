import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';

class ExifAdapter {
  static Map<String, dynamic> processExifData(Map<String, IfdTag> exifData) {
    if (exifData.isEmpty) {
      debugPrint('No EXIF data found to process.');
      return const {};
    }

    final Map<String, dynamic> processedData = {};
    exifData.forEach((key, tag) {
      processedData[key] = _parseTag(tag);
      debugPrint(
        'EXIF: $key = ${processedData[key]} (type: ${processedData[key].runtimeType})',
      );
    });

    return processedData;
  }

  static dynamic _parseTag(IfdTag tag) {
    // Handle ratio values (common for FNumber, ExposureTime, etc.)
    if (tag.tagType == 5 || tag.tagType == 10) {
      // RATIONAL or SRATIONAL
      try {
        final values = tag.values.toList();
        if (values.isNotEmpty && values.first is Ratio) {
          final ratio = values.first as Ratio;
          if (ratio.denominator != 0) {
            final result = ratio.numerator / ratio.denominator;
            debugPrint(
              'Parsed ratio ${ratio.numerator}/${ratio.denominator} = $result',
            );
            return result;
          }
        }
      } catch (e) {
        debugPrint('Error parsing ratio: $e');
      }
    }

    // Fallback to string parsing for fractions
    final printable = tag.printable;
    if (printable.contains('/')) {
      final parts = printable.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) {
          final result = num / den;
          debugPrint('Parsed fraction $printable = $result');
          return result;
        }
      }
    }

    // Try parsing as number
    final doubleValue = double.tryParse(printable);
    if (doubleValue != null) {
      return doubleValue;
    }

    final intValue = int.tryParse(printable);
    if (intValue != null) {
      return intValue;
    }

    // Return as string if nothing else works
    return printable;
  }
}
