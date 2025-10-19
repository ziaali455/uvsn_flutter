# Quick Start Guide

Get up and running with UVSN Image Analyzer in 5 minutes!

## Option 1: Flutter Only (No Python API)

Perfect for standard image formats (JPG, PNG, etc.)

```bash
# 1. Install dependencies
flutter pub get

# 2. Run the app
flutter run -d chrome  # or ios, android
```

That's it! The app will use Flutter's built-in image processing.

## Option 2: With Python API (Enhanced RAW Support)

For better RAW format support and DNG compression handling.

### Terminal 1: Start Python API

```bash
# Navigate to api directory
cd api

# Create virtual environment (first time only)
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies (first time only)
pip install -r requirements.txt

# Start the API server
uvicorn analyze:app --reload --port 3000
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:3000
```

### Terminal 2: Start Flutter App

```bash
# In project root directory
flutter run -d chrome  # or ios, android
```

### Using the Python API

1. Open the app in your browser
2. Look for the **cloud icon toggle** in the top-right corner of the app bar
3. If the Python API is running, the toggle will be enabled
4. **Switch it ON** to use Python processing
5. Upload an image to test!

## Testing the Python API

```bash
# In the api directory
python test_local.py path/to/your/image.jpg
```

Expected output:
```
✅ Health check passed
✅ Analysis passed
   File: image.jpg
   Mean RGB: R=128.50, G=130.20, B=125.80
   Chromaticity: r=0.3330, g=0.3380
```

## Deploy to Vercel

```bash
# Install Vercel CLI (first time only)
npm install -g vercel

# Login to Vercel
vercel login

# Deploy
vercel --prod
```

Your app will be live at `https://your-project.vercel.app`

## Troubleshooting

### Python API not starting?

```bash
# Make sure you're in the api directory
cd api

# Check if port 3000 is already in use
lsof -i :3000  # On Mac/Linux
netstat -ano | findstr :3000  # On Windows

# Try a different port
uvicorn analyze:app --reload --port 8000
```

Then update `lib/services/python_image_service.dart`:
```dart
defaultValue: 'http://localhost:8000/api'
```

### Flutter app not finding Python API?

1. Check that the API is running at `http://localhost:3000`
2. Look in the browser console for error messages
3. Verify the toggle appears in the app bar (if not, API is not reachable)

### Dependencies not installing?

```bash
# Flutter
flutter clean
flutter pub get

# Python
pip install --upgrade pip
pip install -r api/requirements.txt
```

## What's Next?

- 📖 Read [README.md](README.md) for full feature list
- 🚀 Read [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment
- 🔧 Read [api/README.md](api/README.md) for API documentation

## Quick Reference

### Flutter Commands
```bash
flutter run -d chrome        # Run on web
flutter run -d ios          # Run on iOS
flutter run -d android      # Run on Android
flutter build web           # Build for production
```

### Python API Commands
```bash
uvicorn analyze:app --reload --port 3000  # Development
uvicorn analyze:app --host 0.0.0.0       # Production
python test_local.py image.jpg            # Test API
```

### Vercel Commands
```bash
vercel                # Deploy to preview
vercel --prod        # Deploy to production
vercel logs          # View logs
```

## Need Help?

- Check the console output for error messages
- Review the logs in your terminal
- Make sure all dependencies are installed
- Try restarting both the API and Flutter app

Happy analyzing! 🎉

