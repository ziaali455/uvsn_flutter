import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/image_analysis.dart';

class UnifiedExportService {
  static Future<String> exportSingleAnalysis(ImageAnalysis analysis) async {
    try {
      if (kIsWeb) {
        // For web, trigger download using universal_html
        return await _exportForWeb(
          analysis.toJsonString(),
          '${analysis.fileName}_analysis.json',
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, use file system export (share plugin is unreliable)
        return await _exportForMobileSimple(
          analysis.toJsonString(),
          '${analysis.fileName}_analysis.json',
        );
      } else {
        // For desktop, save to file system
        return await _exportForMobile(
          analysis.toJsonString(),
          '${analysis.fileName}_analysis.json',
        );
      }
    } catch (e) {
      throw Exception('Failed to export analysis: $e');
    }
  }

  static Future<String> exportBulkAnalysis(List<ImageAnalysis> analyses) async {
    try {
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalImages': analyses.length,
        'analyses': analyses.map((analysis) => analysis.toJson()).toList(),
      };

      final jsonString = jsonEncode(exportData);
      final fileName =
          'bulk_analysis_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        return await _exportForWeb(jsonString, fileName);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, use file system export (share plugin is unreliable)
        return await _exportForMobileSimple(jsonString, fileName);
      } else {
        return await _exportForMobile(jsonString, fileName);
      }
    } catch (e) {
      throw Exception('Failed to export bulk analysis: $e');
    }
  }

  static Future<String> _exportForWeb(
    String jsonString,
    String fileName,
  ) async {
    try {
      // Create a blob with the JSON data
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);

      // Create a download link
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      // Clean up the URL
      html.Url.revokeObjectUrl(url);

      return 'Downloaded: $fileName';
    } catch (e) {
      throw Exception('Web export failed: $e');
    }
  }

  static Future<String> _exportForMobileShare(
    String jsonString,
    String fileName,
  ) async {
    try {
      // For mobile, create a file in a dedicated export directory
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(directory.path, 'Exports'));

      // Create export directory if it doesn't exist
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final file = File(path.join(exportDir.path, fileName));
      await file.writeAsString(jsonString);

      // Use Share.shareXFiles to get native iOS export options
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Image Analysis Data',
        subject: 'Image Analysis Export',
      );
      return 'Exported: $fileName';
    } catch (e) {
      // Fallback to file system if sharing fails
      debugPrint('Share failed, falling back to file system: $e');
      return await _exportForMobile(jsonString, fileName);
    }
  }

    static Future<String> _exportForMobileSimple(
    String jsonString,
    String fileName,
  ) async {
    try {
      // Simple file system export without any plugins
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(directory.path, 'Exports'));
      
      // Create export directory if it doesn't exist
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      final file = File(path.join(exportDir.path, fileName));
      await file.writeAsString(jsonString);
      
      if (Platform.isIOS) {
        return 'Saved to Files app: UVSN Image Analyzer/Exports/$fileName';
      } else if (Platform.isAndroid) {
        return 'Saved to: ${file.path}';
      } else {
        return file.path;
      }
    } catch (e) {
      throw Exception('Simple export failed: $e');
    }
  }

  static Future<String> _exportForMobile(
    String jsonString,
    String fileName,
  ) async {
    try {
      final directory = await _getExportDirectory();
      final file = File(path.join(directory.path, fileName));

      await file.writeAsString(jsonString);

      if (Platform.isAndroid || Platform.isIOS) {
        return 'Saved to: ${file.path}';
      } else {
        return file.path;
      }
    } catch (e) {
      throw Exception('Mobile export failed: $e');
    }
  }

  static Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Try external storage first, fallback to app documents
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          return externalDir;
        }
      } catch (e) {
        // Fallback to app documents directory
      }

      final appDir = await getApplicationDocumentsDirectory();
      return appDir;
    } else {
      // For desktop, use documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    }
  }

  static Future<String> getExportPath() async {
    final directory = await _getExportDirectory();
    return directory.path;
  }

  static Future<List<String>> listExportedFiles() async {
    try {
      final directory = await _getExportDirectory();
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => path.extension(file.path) == '.json')
          .map((file) => file.path)
          .toList();
      return files;
    } catch (e) {
      throw Exception('Failed to list exported files: $e');
    }
  }

  static Future<void> deleteExportedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete exported file: $e');
    }
  }
}
