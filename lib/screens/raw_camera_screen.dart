import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/raw_camera_service.dart';
import '../services/unified_image_service.dart';
import '../models/image_analysis.dart';

class RawCameraScreen extends StatefulWidget {
  const RawCameraScreen({Key? key}) : super(key: key);

  @override
  State<RawCameraScreen> createState() => _RawCameraScreenState();
}

class _RawCameraScreenState extends State<RawCameraScreen> {
  bool _isRawSupported = false;
  bool _isCameraActive = false;
  bool _isCapturing = false;
  List<String> _availableFormats = [];
  Map<String, dynamic> _cameraCapabilities = {};
  String _selectedFormat = 'dng';
  bool _includeJpegPreview = true;

  // Manual controls
  bool _manualMode = false;
  double _manualISO = 100;
  double _manualFocus = 0.5;
  double _manualExposure = 1.0 / 60.0;

  @override
  void initState() {
    super.initState();
    _checkRawSupport();
  }

  Future<void> _checkRawSupport() async {
    try {
      final isSupported = await RawCameraService.isRawCaptureSupported();
      final formats = await RawCameraService.getAvailableRawFormats();
      final capabilities = await RawCameraService.getCameraCapabilities();

      setState(() {
        _isRawSupported = isSupported;
        _availableFormats = formats;
        _cameraCapabilities = capabilities;
        if (formats.isNotEmpty) {
          _selectedFormat = formats.first;
        }
      });

      if (capabilities.isNotEmpty) {
        _manualISO = (capabilities['minISO'] as num?)?.toDouble() ?? 100;
      }
    } catch (e) {
      _showError('Failed to check RAW support: $e');
    }
  }

  Future<void> _startCamera() async {
    try {
      final success = await RawCameraService.startCameraPreview();
      setState(() {
        _isCameraActive = success;
      });

      if (!success) {
        _showError('Failed to start camera');
      }
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<void> _stopCamera() async {
    try {
      await RawCameraService.stopCameraPreview();
      setState(() {
        _isCameraActive = false;
      });
    } catch (e) {
      _showError('Failed to stop camera: $e');
    }
  }

  Future<void> _captureRawImage() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Configure camera settings if in manual mode
      if (_manualMode) {
        await RawCameraService.configureCameraSettings(
          isoMode: 'manual',
          manualIso: _manualISO.toInt(),
          focusMode: 'manual',
          manualFocusDistance: _manualFocus,
          exposureMode: 'manual',
          exposureDuration: _manualExposure,
        );
      } else {
        await RawCameraService.configureCameraSettings(
          isoMode: 'auto',
          focusMode: 'auto',
          exposureMode: 'auto',
        );
      }

      final filePath = await RawCameraService.captureRawImage(
        format: _selectedFormat,
        includeJpegPreview: _includeJpegPreview,
      );

      if (filePath != null) {
        _showSuccess('RAW image captured: $filePath');
        // Here you could automatically analyze the captured image
        // final analysis = await UnifiedImageService.analyzeImageFromFile(filePath);
        // Navigator.pop(context, analysis);
      } else {
        _showError('Failed to capture RAW image');
      }
    } catch (e) {
      _showError('Capture error: $e');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAW Camera'),
        actions: [
          if (_isRawSupported)
            IconButton(
              icon: Icon(_isCameraActive ? Icons.videocam_off : Icons.videocam),
              onPressed: _isCameraActive ? _stopCamera : _startCamera,
            ),
        ],
      ),
      body: _isRawSupported ? _buildCameraInterface() : _buildUnsupportedView(),
    );
  }

  Widget _buildUnsupportedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'RAW Capture Not Supported',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This device does not support RAW image capture',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraInterface() {
    return Column(
      children: [
        // Camera preview placeholder
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: _isCameraActive
                ? const Center(
                    child: Text(
                      'Camera Preview\n(Native implementation needed)',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap the camera icon to start preview',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Controls
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildFormatSelector(),
                  const SizedBox(height: 16),
                  _buildModeToggle(),
                  if (_manualMode) ...[
                    const SizedBox(height: 16),
                    _buildManualControls(),
                  ],
                  const SizedBox(height: 16),
                  _buildCaptureButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Row(
      children: [
        const Text('Format: '),
        DropdownButton<String>(
          value: _selectedFormat,
          items: _availableFormats.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Text(format.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFormat = value;
              });
            }
          },
        ),
        const Spacer(),
        Row(
          children: [
            const Text('JPEG Preview: '),
            Switch(
              value: _includeJpegPreview,
              onChanged: (value) {
                setState(() {
                  _includeJpegPreview = value;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Row(
      children: [
        const Text('Manual Controls: '),
        Switch(
          value: _manualMode,
          onChanged: (value) {
            setState(() {
              _manualMode = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildManualControls() {
    final minISO = (_cameraCapabilities['minISO'] as num?)?.toDouble() ?? 50;
    final maxISO = (_cameraCapabilities['maxISO'] as num?)?.toDouble() ?? 3200;
    final minExposure =
        (_cameraCapabilities['minExposureDuration'] as num?)?.toDouble() ??
        1.0 / 8000;
    final maxExposure =
        (_cameraCapabilities['maxExposureDuration'] as num?)?.toDouble() ?? 1.0;

    return Column(
      children: [
        // ISO Control
        Row(
          children: [
            const Text('ISO: '),
            Text(_manualISO.toInt().toString()),
            Expanded(
              child: Slider(
                value: _manualISO,
                min: minISO,
                max: maxISO,
                divisions: 20,
                onChanged: (value) {
                  setState(() {
                    _manualISO = value;
                  });
                },
              ),
            ),
          ],
        ),

        // Focus Control
        Row(
          children: [
            const Text('Focus: '),
            Text('${(_manualFocus * 100).toInt()}%'),
            Expanded(
              child: Slider(
                value: _manualFocus,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  setState(() {
                    _manualFocus = value;
                  });
                },
              ),
            ),
          ],
        ),

        // Exposure Control
        Row(
          children: [
            const Text('Exposure: '),
            Text('1/${(1 / _manualExposure).toInt()}s'),
            Expanded(
              child: Slider(
                value: _manualExposure,
                min: minExposure,
                max: maxExposure,
                divisions: 50,
                onChanged: (value) {
                  setState(() {
                    _manualExposure = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCameraActive && !_isCapturing ? _captureRawImage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: _isCapturing
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('Capture ${_selectedFormat.toUpperCase()}'),
      ),
    );
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }
}
