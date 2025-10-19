# Project Structure

## Overview

```
uvsn_image_analyzer/
├── 📱 Flutter App (Client-side)
├── 🐍 Python API (Server-side)
├── 📚 Documentation
└── ⚙️ Configuration
```

## Complete File Tree

```
uvsn_image_analyzer/
│
├── 📱 Flutter Application
│   ├── lib/
│   │   ├── main.dart                          # App entry point
│   │   ├── models/
│   │   │   └── image_analysis.dart            # Data model for analysis results
│   │   ├── screens/
│   │   │   ├── main_screen.dart               # Main UI (with Python toggle)
│   │   │   └── raw_camera_screen.dart         # RAW camera capture (iOS)
│   │   ├── services/
│   │   │   ├── unified_image_service.dart     # Flutter image processing
│   │   │   ├── python_image_service.dart      # 🆕 Python API client
│   │   │   ├── photographic_calculations.dart # S_v, A_v, T_v, B_v calculations
│   │   │   ├── exif_adapter.dart              # EXIF data extraction
│   │   │   ├── simple_file_picker.dart        # File selection
│   │   │   ├── unified_export_service.dart    # JSON export
│   │   │   └── raw_camera_service.dart        # RAW camera (iOS)
│   │   └── widgets/
│   │       ├── image_analysis_card.dart       # Analysis result card
│   │       └── lamp_condition_selector.dart   # Lamp condition picker
│   │
│   ├── web/                                   # Web-specific files
│   ├── ios/                                   # iOS-specific files
│   ├── android/                               # Android-specific files
│   ├── pubspec.yaml                           # Flutter dependencies
│   └── analysis_options.yaml                  # Linter configuration
│
├── 🐍 Python API
│   ├── analyze.py                             # 🆕 Main FastAPI application
│   │   ├── PhotograpicCalculations class      # Replicates Flutter calculations
│   │   ├── ImageAnalyzer class                # Image processing logic
│   │   ├── GET /                              # Health check endpoint
│   │   └── POST /api/analyze                  # Image analysis endpoint
│   │
│   ├── requirements.txt                       # 🆕 Python dependencies
│   ├── test_local.py                          # 🆕 Local testing script
│   └── README.md                              # 🆕 API documentation
│
├── 📚 Documentation
│   ├── README.md                              # Main project documentation
│   ├── DEPLOYMENT.md                          # 🆕 Deployment guide
│   ├── QUICKSTART.md                          # 🆕 Quick start guide
│   ├── PYTHON_API_SUMMARY.md                  # 🆕 Python API overview
│   ├── TESTING_CHECKLIST.md                   # 🆕 Testing checklist
│   └── PROJECT_STRUCTURE.md                   # 🆕 This file
│
├── ⚙️ Configuration
│   ├── vercel.json                            # Vercel deployment config
│   ├── package.json                           # Node.js build scripts
│   ├── Makefile                               # Build automation
│   ├── build.sh                               # Build script
│   ├── build-vercel.sh                        # Vercel build script
│   └── deploy.sh                              # Deployment script
│
└── 🧪 Testing
    └── test/
        └── widget_test.dart                   # Flutter widget tests
```

## Key Components

### 🔄 Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         User                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   main_screen.dart                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Toggle: [Flutter] ◄──► [Python API]                │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             ▼                            ▼
┌────────────────────────┐   ┌──────────────────────────────┐
│ unified_image_service  │   │  python_image_service.dart   │
│      (Flutter)         │   │        (HTTP Client)         │
└────────────────────────┘   └──────────────┬───────────────┘
             │                               │
             │                               ▼
             │                   ┌──────────────────────────┐
             │                   │   api/analyze.py         │
             │                   │   (Python FastAPI)       │
             │                   └──────────────────────────┘
             │                               │
             └───────────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   ImageAnalysis      │
                  │   (Data Model)       │
                  └──────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   Display Results    │
                  └──────────────────────┘
```

### 📊 Image Processing Pipeline

#### Flutter Processing
```
Image File
    ↓
unified_image_service.dart
    ↓
├─ Decode image (image package)
├─ Calculate mean RGB
├─ Calculate chromaticity
├─ Extract EXIF (exif package)
└─ Calculate photographic values
    ↓
ImageAnalysis object
```

#### Python API Processing
```
Image File
    ↓
python_image_service.dart (HTTP upload)
    ↓
api/analyze.py
    ↓
├─ Decode image (Pillow/rawpy)
├─ Calculate mean RGB (NumPy)
├─ Calculate chromaticity (NumPy)
├─ Extract EXIF (exifread)
└─ Calculate photographic values
    ↓
JSON Response
    ↓
ImageAnalysis object
```

## New Files Added (Python API Integration)

### API Files
- ✅ `api/analyze.py` - Main FastAPI application
- ✅ `api/requirements.txt` - Python dependencies
- ✅ `api/test_local.py` - Testing script
- ✅ `api/README.md` - API documentation

### Flutter Integration
- ✅ `lib/services/python_image_service.dart` - HTTP client for API

### Documentation
- ✅ `DEPLOYMENT.md` - Deployment instructions
- ✅ `QUICKSTART.md` - Quick start guide
- ✅ `PYTHON_API_SUMMARY.md` - Architecture overview
- ✅ `TESTING_CHECKLIST.md` - Testing guide
- ✅ `PROJECT_STRUCTURE.md` - This file

### Modified Files
- ✅ `lib/screens/main_screen.dart` - Added toggle and API integration
- ✅ `pubspec.yaml` - Added `http` package
- ✅ `vercel.json` - Added Python build configuration
- ✅ `README.md` - Updated with Python API info

## Dependencies

### Flutter (`pubspec.yaml`)
```yaml
dependencies:
  image: ^4.1.7              # Image processing
  exif: ^3.3.0               # EXIF extraction
  http: ^1.1.0               # 🆕 HTTP client for Python API
  image_picker: ^1.0.7       # Camera/gallery
  file_picker: ^6.1.1        # File selection
  path_provider: ^2.1.2      # File system
  permission_handler: ^11.3.0 # Permissions
  flutter_staggered_grid_view: ^0.7.0  # Grid layout
```

### Python (`api/requirements.txt`)
```
fastapi==0.104.1           # Web framework
python-multipart==0.0.6    # File uploads
Pillow==10.1.0             # Image processing
numpy==1.24.3              # Numerical computations
rawpy==0.19.0              # RAW format support
exifread==3.0.0            # EXIF extraction
```

## Deployment Architecture

### Local Development
```
┌─────────────────────┐         ┌─────────────────────┐
│   Flutter Web App   │         │    Python API       │
│   localhost:8080    │◄───────►│   localhost:3000    │
│   (flutter run)     │  HTTP   │   (uvicorn)         │
└─────────────────────┘         └─────────────────────┘
```

### Production (Vercel)
```
┌─────────────────────────────────────────────────────┐
│              your-project.vercel.app                 │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │  Static Files    │      │  Serverless      │   │
│  │  (Flutter Web)   │      │  Functions       │   │
│  │                  │      │  (Python API)    │   │
│  │  /               │      │  /api/*          │   │
│  │  /index.html     │      │                  │   │
│  └──────────────────┘      └──────────────────┘   │
│                                                      │
│  CDN Edge Caching          Auto-scaling             │
└─────────────────────────────────────────────────────┘
```

## Code Organization Principles

### 1. Separation of Concerns
- **Models**: Data structures only
- **Services**: Business logic
- **Widgets**: Reusable UI components
- **Screens**: Page-level UI

### 2. Dual Processing Support
- **Flutter**: Client-side processing (fast, limited formats)
- **Python**: Server-side processing (slower, better formats)
- **Toggle**: User chooses which to use

### 3. Identical Logic
- Both implementations produce same results
- Same calculations
- Same data structures
- Easy to compare and validate

### 4. Progressive Enhancement
- App works without Python API
- Python API is optional enhancement
- Graceful fallback to Flutter processing

## Testing Strategy

### Unit Tests
- `test/widget_test.dart` - Flutter widget tests
- `api/test_local.py` - Python API tests

### Integration Tests
- Manual testing with checklist
- Compare Flutter vs Python results
- Test various image formats

### Deployment Tests
- Vercel preview deployments
- Production smoke tests
- Performance monitoring

## Next Steps for Development

### Phase 1: Validation ✅
- [x] Implement Python API
- [x] Add Flutter integration
- [x] Create documentation
- [ ] Test with real images
- [ ] Compare results

### Phase 2: Optimization
- [ ] Add caching
- [ ] Optimize performance
- [ ] Add batch processing
- [ ] Improve error handling

### Phase 3: Enhancement
- [ ] Add more RAW formats
- [ ] Implement ML features
- [ ] Add advanced analytics
- [ ] Scale infrastructure

## Maintenance

### When to Update Flutter Code
- Bug fixes in image processing
- New features in analysis
- UI/UX improvements

### When to Update Python API
- Keep in sync with Flutter changes
- Add support for new formats
- Performance optimizations

### When to Update Documentation
- After any significant changes
- When adding new features
- When deployment process changes

---

**Last Updated:** October 19, 2025  
**Version:** 1.0.0 with Python API Integration

