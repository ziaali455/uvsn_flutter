import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'unified_image_service.dart';
import 'raw_camera_service.dart';
import '../screens/raw_camera_screen.dart';
import '../models/image_analysis.dart';

enum PickerSource { camera, gallery, file, folder }

class SimpleFilePicker {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<List<Map<String, dynamic>>> pickImages({
    bool allowMultiple = true,
    bool includeCamera = true,
    BuildContext? context,
  }) async {
    try {
      if (kIsWeb) {
        return await _pickImagesWeb(allowMultiple);
      } else {
        return await _pickImagesMobile(allowMultiple, includeCamera, context);
      }
    } catch (e) {
      throw Exception('Failed to pick images: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _pickImagesWeb(
    bool allowMultiple,
  ) async {
    try {
      // On web, always allow multiple file selection for batch imports
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: UnifiedImageService.supportedFormats,
        allowMultiple: true, // Always allow multiple for batch import
        withData: true, // Ensure we get the bytes
      );

      if (files != null) {
        debugPrint('📁 Selected ${files.files.length} files on web');
        return files.files
            .where((file) => file.bytes != null)
            .map(
              (file) => {
                'name': file.name,
                'size': file.size,
                'bytes': file.bytes,
              },
            )
            .toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to pick images on web: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _pickImagesMobile(
    bool allowMultiple,
    bool includeCamera,
    BuildContext? context,
  ) async {
    try {
      // Request permissions for mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isDenied) {
          throw Exception('Photo permission denied');
        }

        if (includeCamera) {
          final cameraStatus = await Permission.camera.request();
          if (cameraStatus.isDenied) {
            throw Exception('Camera permission denied');
          }
        }
      }

      // Show selection dialog for mobile
      if (context != null && includeCamera) {
        final source = await _showImageSourceDialog(context);
        if (source == null) return [];

        return await _pickFromSource(source, allowMultiple, context);
      } else {
        // Fallback to file picker if no context or camera not included
        return await _pickFromFilePicker(allowMultiple);
      }
    } catch (e) {
      throw Exception('Failed to pick images on mobile: $e');
    }
  }

  static Future<PickerSource?> _showImageSourceDialog(
    BuildContext context,
  ) async {
    return await showDialog<PickerSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(PickerSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Camera Roll'),
                onTap: () => Navigator.of(context).pop(PickerSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Select Files'),
                onTap: () => Navigator.of(context).pop(PickerSource.file),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Import Folder'),
                subtitle: const Text('Batch import all images'),
                onTap: () => Navigator.of(context).pop(PickerSource.folder),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<List<Map<String, dynamic>>> _pickFromSource(
    PickerSource source,
    bool allowMultiple,
    BuildContext? context,
  ) async {
    switch (source) {
      case PickerSource.camera:
        return await _pickFromCamera(context);
      case PickerSource.gallery:
        return await _pickFromGallery(allowMultiple);
      case PickerSource.file:
        return await _pickFromFilePicker(allowMultiple);
      case PickerSource.folder:
        return await _pickFromFolder();
    }
  }

  static Future<List<Map<String, dynamic>>> _pickFromCamera(
    BuildContext? context,
  ) async {
    try {
      // Check if RAW capture is supported (iOS only, non-web)
      if (!kIsWeb && Platform.isIOS && context != null) {
        final rawSupported = await RawCameraService.isRawCaptureSupported();

        if (rawSupported) {
          debugPrint(
              '✅ RAW capture supported - using RAW camera automatically');

          // Navigate to RAW camera screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RawCameraScreen()),
          );

          // If user captured a RAW image, return the file data
          if (result is ImageAnalysis) {
            try {
              final file = File(result.imagePath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                return [
                  {
                    'path': result.imagePath,
                    'name': result.fileName,
                    'size': await file.length(),
                    'bytes': bytes,
                  },
                ];
              }
            } catch (e) {
              debugPrint(
                  '⚠️ Failed to read RAW file, falling back to JPEG camera: $e');
              // Fall through to regular camera below
            }
          } else if (result == null) {
            // User cancelled
            return [];
          }
        }
      }

      // Fall back to regular JPEG camera
      debugPrint('📸 Using standard JPEG camera');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Full quality for analysis
      );

      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes(); // Read full image bytes
        return [
          {
            'path': image.path,
            'name': image.name,
            'size': await file.length(),
            'bytes': bytes, // Include bytes for proper analysis
          },
        ];
      }
      return [];
    } catch (e) {
      throw Exception('Failed to pick from camera: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _pickFromGallery(
    bool allowMultiple,
  ) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );

      final List<Map<String, dynamic>> selectedFiles = [];
      for (final image in images) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        selectedFiles.add({
          'path': image.path,
          'name': image.name,
          'size': await file.length(),
          'bytes': bytes,
        });
      }

      return selectedFiles;
    } catch (e) {
      throw Exception('Failed to pick from gallery: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _pickFromFilePicker(
    bool allowMultiple,
  ) async {
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: UnifiedImageService.supportedFormats,
        allowMultiple: allowMultiple,
      );

      if (files != null) {
        final List<Map<String, dynamic>> selectedFiles = [];
        for (final file in files.files) {
          if (file.path != null) {
            // Read bytes for proper analysis (especially important for RAW files)
            final fileObj = File(file.path!);
            final bytes = await fileObj.readAsBytes();
            selectedFiles.add({
              'path': file.path!,
              'name': file.name,
              'size': file.size,
              'bytes': bytes, // Include bytes for full analysis
            });
          }
        }
        return selectedFiles;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to pick from file picker: $e');
    }
  }

  /// Pick all images from a folder (batch import)
  static Future<List<Map<String, dynamic>>> _pickFromFolder() async {
    try {
      final String? directoryPath =
          await FilePicker.platform.getDirectoryPath();

      if (directoryPath == null) {
        return [];
      }

      debugPrint('📁 Scanning folder: $directoryPath');

      final directory = Directory(directoryPath);
      final List<Map<String, dynamic>> selectedFiles = [];

      // Get all files in the directory (including subdirectories)
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = entity.path.split('/').last.split('\\').last;
          final extension = fileName.contains('.')
              ? fileName.split('.').last.toLowerCase()
              : '';

          // Check if this is a supported image format
          if (UnifiedImageService.supportedFormats.contains(extension)) {
            try {
              final bytes = await entity.readAsBytes();
              final stat = await entity.stat();

              selectedFiles.add({
                'path': entity.path,
                'name': fileName,
                'size': stat.size,
                'bytes': bytes,
              });

              debugPrint(
                  '  ✅ Found: $fileName (${_formatFileSize(stat.size)})');
            } catch (e) {
              debugPrint('  ⚠️ Failed to read: $fileName - $e');
            }
          }
        }
      }

      debugPrint('📁 Found ${selectedFiles.length} images in folder');
      return selectedFiles;
    } catch (e) {
      throw Exception('Failed to pick from folder: $e');
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<String?> pickSingleImage() async {
    final files = await pickImages(allowMultiple: false);
    return files.isNotEmpty ? files.first['name'] : null;
  }

  static Future<List<Map<String, dynamic>>> pickMultipleImages() async {
    return await pickImages(allowMultiple: true);
  }
}
