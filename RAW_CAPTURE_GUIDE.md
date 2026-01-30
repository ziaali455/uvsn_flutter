# Apple ProRAW Capture Guide

## Overview

The UVSN Image Analyzer now supports **native Apple ProRAW capture** directly from the camera! This allows you to capture and analyze RAW images with maximum image quality and detail.

## Features

✅ **Native RAW Capture** - Capture Apple ProRAW (.DNG) images directly from your iPhone camera  
✅ **Manual Controls** - Full manual control over ISO, focus, and exposure  
✅ **Automatic Analysis** - Captured RAW images are automatically analyzed  
✅ **Python API Integration** - RAW files are analyzed using the Python API for best results  
✅ **Dual Save** - Images are saved to both app storage and Photos library  

## Device Requirements

- **iPhone 12 Pro or later** with Apple ProRAW support
- **iOS 14.3+** 
- **Python API deployed** (for optimal RAW analysis)

## How to Use

### 1. Access RAW Camera

On the main screen, tap the **red camera button** (floating action button) to open the RAW camera screen.

### 2. Configure Settings

**Format Selection:**
- Choose between DNG or RAW format
- Enable/disable JPEG preview

**Manual Mode:**
- Toggle manual controls ON
- Adjust ISO (typically 50-3200)
- Adjust focus (0-100%)
- Adjust exposure duration (1/8000s - 1s)

### 3. Capture Image

1. Tap the camera icon in the app bar to start camera preview
2. Configure your desired settings
3. Tap "Capture DNG" button
4. Wait for automatic analysis to complete
5. Image analysis appears on main screen

## Technical Details

### RAW Capture Flow

```
1. User taps capture button
2. Swift plugin captures Apple ProRAW
3. Image saved to app Documents directory
4. Image also saved to Photos library
5. Flutter reads RAW file bytes
6. Python API analyzes RAW data (if available)
7. Analysis returned to main screen
```

### File Format

- **Captured Format:** Apple DNG (Digital Negative)
- **File Size:** Typically 10-25 MB per image
- **Storage Location:** App Documents + Photos Library
- **Temporary Files:** Cleaned up after analysis

### Analysis Methods

**Python API (Recommended for RAW):**
- Uses `rawpy` library for RAW decoding
- Preserves full dynamic range
- Accurate color analysis
- Full EXIF data extraction

**Flutter Fallback:**
- Uses standard image decoder
- May lose some RAW data
- Still provides accurate chromaticity

## Existing Functionality (Unchanged)

The following existing features continue to work exactly as before:

✅ **File Upload** - Upload any RAW file (.DNG, .CR2, .NEF, .ARW, etc.)  
✅ **Regular Camera** - Capture standard JPEG images via file picker  
✅ **Gallery Selection** - Pick multiple images from camera roll  
✅ **Flutter Processing** - Toggle to use Flutter-based analysis  

## Python API Requirement

For best RAW analysis results, ensure your Python API is deployed and accessible:

- **Vercel Deployment:** Already configured
- **Health Check:** The app automatically detects if Python API is available
- **Fallback:** Flutter processing used if Python API unavailable

## Permissions Required

The app requires the following iOS permissions (already configured):

- **Camera Access** - `NSCameraUsageDescription`
- **Photo Library Read** - `NSPhotoLibraryUsageDescription`  
- **Photo Library Write** - `NSPhotoLibraryAddUsageDescription`

## Troubleshooting

### "RAW capture is not supported on this device"

- Your iPhone model doesn't support Apple ProRAW
- Solution: Use file upload to analyze RAW files from other cameras

### Camera preview not showing

- This is expected - the native camera preview requires additional implementation
- The capture functionality works without the preview

### Analysis fails

- Check that Python API is available (look for cloud icon in app bar)
- Try enabling Python API toggle on main screen
- Check file size - very large RAW files may take longer

### File not found after capture

- Ensure app has photo library permissions
- Check iOS Settings > Privacy > Photos > UVSN Image Analyzer

## Code Structure

```
ios/Runner/
  ├── RawCameraPlugin.swift          # Native Swift implementation
  └── AppDelegate.swift              # Plugin registration

lib/
  ├── screens/
  │   └── raw_camera_screen.dart     # RAW camera UI
  └── services/
      ├── raw_camera_service.dart    # Flutter service layer
      ├── python_image_service.dart  # Python API client
      └── unified_image_service.dart # Flutter analysis

api/
  └── analyze.py                     # Python RAW analysis (rawpy)
```

## Future Enhancements

Potential improvements for future versions:

- [ ] Live camera preview integration
- [ ] Histogram display
- [ ] Focus peaking
- [ ] Exposure zebra patterns
- [ ] Batch RAW capture
- [ ] RAW editing capabilities

## Related Files

- `IMPLEMENTATION_COMPLETE.md` - Full app implementation details
- `PYTHON_API_SUMMARY.md` - Python API documentation
- `DEPLOYMENT_SUCCESS.md` - Deployment guide

## Questions?

For issues or feature requests, check the existing documentation or test the feature on a ProRAW-capable device.






