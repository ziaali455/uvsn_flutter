import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'unified_image_service.dart';

enum PickerSource { camera, gallery, file }

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
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: UnifiedImageService.supportedFormats,
        allowMultiple: allowMultiple,
      );

      if (files != null) {
        return files.files
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

        return await _pickFromSource(source, allowMultiple);
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
                leading: const Icon(Icons.folder),
                title: const Text('File Picker'),
                onTap: () => Navigator.of(context).pop(PickerSource.file),
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
  ) async {
    switch (source) {
      case PickerSource.camera:
        return await _pickFromCamera();
      case PickerSource.gallery:
        return await _pickFromGallery(allowMultiple);
      case PickerSource.file:
        return await _pickFromFilePicker(allowMultiple);
    }
  }

  static Future<List<Map<String, dynamic>>> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        final file = File(image.path);
        return [
          {'path': image.path, 'name': image.name, 'size': await file.length()},
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
            selectedFiles.add({
              'path': file.path!,
              'name': file.name,
              'size': file.size,
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

  static Future<String?> pickSingleImage() async {
    final files = await pickImages(allowMultiple: false);
    return files.isNotEmpty ? files.first['name'] : null;
  }

  static Future<List<Map<String, dynamic>>> pickMultipleImages() async {
    return await pickImages(allowMultiple: true);
  }
}
