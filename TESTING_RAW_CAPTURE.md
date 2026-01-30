# Testing Apple ProRAW Capture - Quick Guide

## ⚡ Quick Start

### Prerequisites
- iPhone 12 Pro or later
- iOS 14.3+
- Python API deployed (recommended)

### Test Flow (2 minutes)

1. **Launch App**
   ```
   flutter run -d ios
   ```

2. **Access RAW Camera**
   - Look for RED camera FAB on main screen (bottom)
   - Tap to open RAW camera screen

3. **Verify UI**
   - ✅ Blue info banner at top
   - ✅ Camera preview area (black background)
   - ✅ Format selector (DNG/RAW)
   - ✅ JPEG preview toggle
   - ✅ Manual controls toggle
   - ✅ Capture button

4. **Capture Image**
   - Tap camera icon in app bar (start preview)
   - Tap "Capture DNG" button
   - Wait for success message
   - Wait for analysis to complete (~5-10 seconds)

5. **Verify Results**
   - Should automatically return to main screen
   - New analysis card should appear
   - Check file format shows "DNG"
   - Check EXIF data is present
   - Check RGB/chromaticity values

## 🧪 Test Cases

### Test Case 1: Basic Capture
```
Action: Capture with default settings
Expected: Image captured, analyzed, appears on main screen
```

### Test Case 2: Manual Mode
```
Action: Enable manual controls, adjust ISO
Expected: Settings applied, capture successful
```

### Test Case 3: Python API
```
Action: Capture with Python API available
Expected: Uses Python API (check logs for 🐍 emoji)
```

### Test Case 4: Fallback
```
Action: Capture with Python API unavailable
Expected: Uses Flutter processing (check logs for 📱 emoji)
```

### Test Case 5: Existing Features
```
Action: Use "Add Images" button (blue FAB)
Expected: Camera/Gallery/File picker still work
```

## 📋 Debug Checklist

### If Capture Fails

**Check Permissions:**
```
Settings > Privacy > Camera > UVSN Image Analyzer ✅
Settings > Privacy > Photos > UVSN Image Analyzer ✅
```

**Check Device:**
```
Device must be iPhone 12 Pro or later
Settings > Camera > Formats > Apple ProRAW ✅
```

**Check Logs:**
```bash
# Watch Xcode console for:
✅ RAW file saved to: /path/to/file.dng
📸 Analyzing RAW capture: raw_capture_[timestamp].dng
🐍 Python API progress: [0-100%]
✅ RAW analysis complete!
```

### If Analysis Fails

**Check Python API:**
```dart
// Look for this in logs:
🐍 Using Python API for RAW
// or
📱 Using Flutter processing (Python API unavailable)
```

**Check File:**
```
File should be in: Documents/raw_capture_[timestamp].dng
File size: 10-25 MB typical
```

**Check Network:**
```
Python API needs network access
Check Vercel deployment is live
```

## 🔍 Expected Logs

### Successful Capture

```
=== Swift Plugin ===
✅ RAW file saved to: /var/.../Documents/raw_capture_1234567890.dng
✅ RAW image also saved to Photos library

=== Flutter Analysis ===
📸 Analyzing RAW capture: raw_capture_1234567890.dng (15.2 MB)
🐍 Python API progress: 25% - Decoding RAW
🐍 Python API progress: 50% - Calculating RGB
🐍 Python API progress: 75% - Calculating chromaticity
🐍 Python API progress: 100% - Extracting EXIF
✅ RAW analysis complete!
```

### Successful Capture (Flutter Fallback)

```
📸 Analyzing RAW capture: raw_capture_1234567890.dng (15.2 MB)
📱 Flutter analysis progress: 25% - Loading image
📱 Flutter analysis progress: 50% - Analyzing pixels
📱 Flutter analysis progress: 75% - Calculating values
📱 Flutter analysis progress: 100% - Complete
✅ RAW analysis complete!
```

## 📱 Visual Verification

### Main Screen
```
┌──────────────────────────────┐
│  UVSN Image Analyzer    [≡]  │
├──────────────────────────────┤
│                              │
│  [Analysis Cards Grid]       │
│                              │
│                         [🔴] │ ← RED RAW camera FAB
│                         [+]  │ ← BLUE add images FAB
└──────────────────────────────┘
```

### RAW Camera Screen
```
┌──────────────────────────────┐
│  ← RAW Camera        [📹]    │
├──────────────────────────────┤
│ ℹ️ RAW images analyzed with  │
│   Python API for best results│
├──────────────────────────────┤
│                              │
│    [Camera Preview Area]     │
│                              │
├──────────────────────────────┤
│ Format: [DNG ▼] JPEG: [✓]   │
│ Manual Controls: [ ]         │
│                              │
│ [  Capture DNG  ]            │
└──────────────────────────────┘
```

## ⏱️ Performance Expectations

| Operation | Expected Time |
|-----------|--------------|
| Open RAW camera | < 1 second |
| Capture image | 2-3 seconds |
| Save to disk | < 1 second |
| Python API analysis | 5-10 seconds |
| Flutter analysis | 3-5 seconds |
| Return to main screen | < 1 second |

**Total:** ~10-15 seconds from capture to results

## ✅ Success Criteria

- [ ] RAW camera opens
- [ ] Image captures successfully
- [ ] File saved to Documents
- [ ] File saved to Photos library
- [ ] Analysis completes
- [ ] Results appear on main screen
- [ ] Existing features still work
- [ ] No crashes or errors

## 🐛 Known Limitations

1. **No Live Preview** - Camera preview placeholder only
   - Capture works fine without preview
   - Future enhancement

2. **iOS Only** - RAW camera button only appears on iOS
   - Android/Web can still upload RAW files
   - By design

3. **ProRAW Required** - Needs iPhone 12 Pro or later
   - Graceful error message on unsupported devices
   - Other RAW formats work via upload

## 🎯 Quick Commands

```bash
# Run on iOS
flutter run -d ios

# Build for iOS
flutter build ios --release

# Watch logs
# (Xcode console shows Swift + Flutter logs together)

# Clean build
flutter clean
cd ios && pod install && cd ..
flutter run -d ios
```

## 📞 Support

If issues occur:
1. Check this guide
2. Check `RAW_CAPTURE_GUIDE.md` for details
3. Check `RAW_IMPLEMENTATION_SUMMARY.md` for technical info
4. Verify device compatibility
5. Ensure Python API is deployed

---

**Ready to test!** 🚀

Expected: ~10-15 seconds from opening RAW camera to seeing results.






