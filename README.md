# UVSN Image Analyzer

A Flutter application that analyzes images to extract mean RGB values and EXIF metadata, with support for various image formats including RAW files.

## Features

### Image Analysis
- **Mean RGB Extraction**: Calculates average red, green, and blue values from images
- **EXIF Data Support**: Extracts and displays metadata from images that contain EXIF information
- **Multiple Format Support**: Handles JPG, PNG, BMP, GIF, WebP, DNG, RAW, CR2, NEF, ARW, RW2 formats

### Image Input
- **Gallery Selection**: Pick images from device gallery
- **Camera Capture**: Take photos directly with the device camera
- **Bulk Processing**: Select and analyze multiple images at once
- **Native File Picker**: Uses platform-specific file pickers for optimal experience

### Export Functionality
- **Individual Export**: Export analysis results for single images as JSON
- **Bulk Export**: Export all analyses in a single JSON file
- **Structured Data**: Includes RGB values, EXIF metadata, file information, and analysis timestamps
- **Cross-Platform**: Works on iOS, Android, and Web platforms

### User Interface
- **Modern Material Design**: Clean, intuitive interface with Material 3 design
- **Responsive Layout**: Adapts to different screen sizes and orientations
- **Dark/Light Theme**: Automatic theme switching based on system preferences
- **Real-time Feedback**: Loading indicators and progress updates during analysis

## Supported Platforms

- ✅ iOS
- ✅ Android  
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## Installation

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- iOS: Xcode (for iOS builds)
- Android: Android Studio (for Android builds)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd uvsn_image_analyzer
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # For iOS
   flutter run -d ios
   
   # For Android
   flutter run -d android
   
   # For Web
   flutter run -d chrome
   ```

## Usage

### Basic Workflow

1. **Launch the app** - The main screen shows an empty state with instructions
2. **Add Images** - Tap the "Add Images" button to select images from gallery or camera
3. **View Analysis** - Each analyzed image displays:
   - Image thumbnail
   - File information (name, format, size)
   - Mean RGB values with color-coded indicators
   - EXIF metadata (if available)
4. **Export Results** - Use individual export buttons or bulk export from the menu

### Export Format

#### Individual Export
```json
{
  "imagePath": "/path/to/image.jpg",
  "fileName": "image.jpg",
  "meanRed": 128.5,
  "meanGreen": 156.2,
  "meanBlue": 89.7,
  "exifData": {
    "Make": "Canon",
    "Model": "EOS R5",
    "DateTime": "2024:01:15 14:30:25",
    "ExposureTime": "1/125",
    "FNumber": "f/2.8",
    "ISO": "100"
  },
  "analysisDate": "2024-01-15T14:30:25.123Z",
  "fileSize": "2.5 MB",
  "imageFormat": "jpg"
}
```

#### Bulk Export
```json
{
  "exportDate": "2024-01-15T14:30:25.123Z",
  "totalImages": 3,
  "analyses": [
    // Array of individual analysis objects
  ]
}
```

## Technical Details

### Architecture
- **Models**: Data classes for image analysis results
- **Services**: Business logic for image processing, file handling, and export
- **Widgets**: Reusable UI components
- **Screens**: Main application screens

### Key Dependencies
- `image`: Image processing and RGB calculation
- `exif`: EXIF metadata extraction
- `image_picker`: Camera and gallery access
- `file_picker`: File selection
- `path_provider`: File system access
- `permission_handler`: Platform permissions
- `flutter_staggered_grid_view`: Responsive grid layout

### Performance Optimizations
- **Pixel Sampling**: Analyzes every 10th pixel for faster processing
- **Async Processing**: Non-blocking image analysis
- **Memory Management**: Efficient image loading and disposal
- **Error Handling**: Graceful handling of unsupported formats and corrupted files

## Permissions

### iOS
- Camera access for photo capture
- Photo library access for image selection
- Photo library write access for exports

### Android
- Camera permission for photo capture
- Storage permission for file access
- External storage permission for exports

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure app has necessary permissions
   - Check device settings for camera/photo access

2. **Unsupported Format**
   - Verify image format is in supported list
   - Try converting image to JPG/PNG format

3. **Export Failed**
   - Check available storage space
   - Ensure write permissions are granted

4. **Slow Performance**
   - Large images may take longer to process
   - Consider resizing images before analysis

### Debug Mode
```bash
flutter run --debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the Flutter documentation for platform-specific issues
