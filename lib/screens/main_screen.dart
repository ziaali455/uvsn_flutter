import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/foundation.dart';
import '../models/image_analysis.dart';
import '../services/simple_file_picker.dart';
import '../services/unified_image_service.dart';
import '../services/unified_export_service.dart';
import '../services/raw_camera_service.dart';
import '../widgets/image_analysis_card.dart';
import '../services/photographic_calculations.dart';
import 'raw_camera_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<ImageAnalysis> _analyses = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.analytics, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'UVSN Image Analyzer',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (_analyses.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text('Export All'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        const Icon(Icons.clear_all, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RAW Camera FAB (iOS only)
          if (!kIsWeb && Platform.isIOS)
            FloatingActionButton(
              heroTag: "raw_camera",
              onPressed: _openRawCamera,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Icon(Icons.camera_alt),
            ),
          if (!kIsWeb && Platform.isIOS) const SizedBox(height: 8),

          // Main Add Images FAB
          FloatingActionButton.extended(
            heroTag: "add_images",
            onPressed: _isLoading ? null : _pickImages,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            label: Text(
              _isLoading ? 'Analyzing...' : 'Add Images',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.add_photo_alternate),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _errorMessage = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_analyses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Ready to Analyze Images?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select images to extract RGB values and EXIF metadata',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Supported Formats',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          [
                                'JPG',
                                'PNG',
                                'BMP',
                                'GIF',
                                'WebP',
                                'DNG',
                                'RAW',
                                'CR2',
                                'NEF',
                                'ARW',
                                'RW2',
                              ]
                              .map(
                                (format) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    format,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analysis Summary',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_analyses.length} image${_analyses.length == 1 ? '' : 's'} analyzed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportAll,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Analysis grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MasonryGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: _getCrossAxisCount(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: _analyses.length,
                  itemBuilder: (context, index) {
                    final analysis = _analyses[index];
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: kIsWeb ? 300 : 280,
                        maxWidth: kIsWeb ? 400 : double.infinity,
                      ),
                      child: ImageAnalysisCard(
                        analysis: analysis,
                        onExport: () => _exportSingle(analysis),
                        onDelete: () => _deleteAnalysis(index),
                        onSelectLampCondition: () =>
                            _selectLampCondition(analysis),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  int _getCrossAxisCount() {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;

    // More responsive breakpoints for better web layout
    if (kIsWeb) {
      // Very aggressive for desktop web
      if (width > 2400)
        crossAxisCount = 10;
      else if (width > 2200)
        crossAxisCount = 9;
      else if (width > 2000)
        crossAxisCount = 8;
      else if (width > 1800)
        crossAxisCount = 7;
      else if (width > 1600)
        crossAxisCount = 6;
      else if (width > 1400)
        crossAxisCount = 5;
      else if (width > 1200)
        crossAxisCount = 4;
      else if (width > 900)
        crossAxisCount = 3;
      else if (width > 600)
        crossAxisCount = 2;
      else
        crossAxisCount = 1;
    } else {
      // Conservative for mobile
      if (width > 1200)
        crossAxisCount = 4;
      else if (width > 800)
        crossAxisCount = 3;
      else if (width > 600)
        crossAxisCount = 2;
      else
        crossAxisCount = 1;
    }

    debugPrint(
      'Screen width: $width, Cross axis count: $crossAxisCount, isWeb: $kIsWeb',
    );
    return crossAxisCount;
  }

  Future<void> _openRawCamera() async {
    try {
      // Check if RAW capture is supported
      final isSupported = await RawCameraService.isRawCaptureSupported();

      if (!isSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('RAW capture is not supported on this device'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navigate to RAW camera screen
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RawCameraScreen()),
        );

        // If an analysis was returned, add it to the list
        if (result is ImageAnalysis) {
          setState(() {
            _analyses.add(result);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open RAW camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final files = await SimpleFilePicker.pickImages(
        allowMultiple: true,
        includeCamera: true,
        context: context,
      );

      if (files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Filter supported formats
      final supportedFiles = files
          .where((file) => UnifiedImageService.isSupportedFormat(file['name']))
          .toList();

      if (supportedFiles.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No supported image formats found';
        });
        return;
      }

      // Analyze images
      final List<ImageAnalysis> newAnalyses = [];

      for (final file in supportedFiles) {
        try {
          ImageAnalysis analysis;

          if (file['bytes'] != null) {
            // Use bytes for all platforms if available
            analysis = await UnifiedImageService.analyzeImageFromBytes(
              file['bytes'],
              file['name'],
              file['size'] ?? 0,
            );
          } else if (file['path'] != null) {
            // Fallback for mobile/desktop if bytes are not available
            analysis = await UnifiedImageService.analyzeImageFromFile(
              file['path'],
            );
          } else {
            continue; // Skip files without proper data
          }

          newAnalyses.add(analysis);
        } catch (e) {
          debugPrint('Failed to analyze ${file['name']}: $e');
        }
      }

      setState(() {
        _analyses.addAll(newAnalyses);
        _isLoading = false;
      });

      if (mounted && newAnalyses.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully analyzed ${newAnalyses.length} image${newAnalyses.length == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to analyze images: $e';
      });
    }
  }

  Future<void> _exportSingle(ImageAnalysis analysis) async {
    try {
      final exportPath = await UnifiedExportService.exportSingleAnalysis(
        analysis,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Successful!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(exportPath),
                if (!kIsWeb && Platform.isIOS) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Find your file in the Files app under "UVSN Image Analyzer"',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectLampCondition(ImageAnalysis analysis) async {
    final selectedCondition = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Lamp Condition'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: PhotographicCalculations.lampConditions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('None'),
                    onTap: () => Navigator.of(context).pop(null),
                  );
                }
                final condition =
                    PhotographicCalculations.lampConditions[index - 1];
                return ListTile(
                  title: Text(condition),
                  onTap: () => Navigator.of(context).pop(condition),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedCondition != null || selectedCondition == null) {
      // Update the analysis with the selected lamp condition
      final updatedAnalysis = ImageAnalysis(
        imagePath: analysis.imagePath,
        fileName: analysis.fileName,
        meanRed: analysis.meanRed,
        meanGreen: analysis.meanGreen,
        meanBlue: analysis.meanBlue,
        meanRChromaticity: analysis.meanRChromaticity,
        meanGChromaticity: analysis.meanGChromaticity,
        stdRChromaticity: analysis.stdRChromaticity,
        stdGChromaticity: analysis.stdGChromaticity,
        maxRed: analysis.maxRed,
        maxGreen: analysis.maxGreen,
        maxBlue: analysis.maxBlue,
        exifData: analysis.exifData,
        analysisDate: analysis.analysisDate,
        fileSize: analysis.fileSize,
        imageFormat: analysis.imageFormat,
        lampCondition: selectedCondition,
        sV: analysis.sV,
        aV: analysis.aV,
        tV: analysis.tV,
        bV: analysis.bV,
      );

      setState(() {
        final index = _analyses.indexOf(analysis);
        if (index != -1) {
          _analyses[index] = updatedAnalysis;
        }
      });
    }
  }

  Future<void> _exportAll() async {
    try {
      final exportPath = await UnifiedExportService.exportBulkAnalysis(
        _analyses,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported all analyses: $exportPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteAnalysis(int index) {
    setState(() {
      _analyses.removeAt(index);
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export_all':
        _exportAll();
        break;
      case 'clear_all':
        _clearAll();
        break;
    }
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Analyses'),
        content: const Text(
          'Are you sure you want to clear all image analyses?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _analyses.clear());
              Navigator.of(context).pop();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
