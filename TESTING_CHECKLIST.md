# Testing Checklist

Use this checklist to verify everything works correctly.

## ✅ Local Development Testing

### Python API Setup

- [ ] Navigate to `api` directory
- [ ] Create virtual environment: `python3 -m venv venv`
- [ ] Activate virtual environment: `source venv/bin/activate`
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Start API server: `uvicorn analyze:app --reload --port 3000`
- [ ] Verify server starts without errors
- [ ] Check health endpoint: `curl http://localhost:3000/`
- [ ] Should see: `{"status":"ok","service":"UVSN Image Analyzer API",...}`

### Python API Testing

- [ ] Run test script: `python test_local.py`
- [ ] Health check passes ✅
- [ ] Test with an image: `python test_local.py path/to/image.jpg`
- [ ] Analysis completes successfully ✅
- [ ] RGB values are reasonable (0-255 range)
- [ ] Chromaticity values are reasonable (0-1 range)

### Flutter App Setup

- [ ] In project root, run: `flutter pub get`
- [ ] Dependencies install successfully
- [ ] No errors in terminal

### Flutter App Testing (Without Python API)

- [ ] Run: `flutter run -d chrome` (or your preferred platform)
- [ ] App launches successfully
- [ ] No cloud toggle visible in app bar (Python API not detected)
- [ ] Click "Add Images" button
- [ ] Select a test image (JPG or PNG)
- [ ] Image analyzes successfully with Flutter processing
- [ ] Results display correctly:
  - [ ] Image thumbnail shows
  - [ ] File name and size display
  - [ ] Mean RGB values display
  - [ ] Chromaticity values display
  - [ ] EXIF data shows (if available)
- [ ] Export single analysis works
- [ ] Export all analyses works

### Flutter App Testing (With Python API)

- [ ] Ensure Python API is running (`uvicorn analyze:app --reload --port 3000`)
- [ ] Refresh Flutter app or restart
- [ ] Cloud toggle appears in app bar ✅
- [ ] Toggle is OFF by default (using Flutter processing)
- [ ] Click toggle to turn ON
- [ ] Snackbar shows: "Switched to Python API (better RAW support)"
- [ ] Upload same test image
- [ ] Progress indicator shows "🐍" emoji
- [ ] Image analyzes successfully with Python API
- [ ] Results match Flutter processing (for standard formats)
- [ ] Check browser console for: "🐍 Using Python API for [filename]"

### Comparison Testing

Test the same image with both methods:

**Test Image 1: Standard JPG**
- [ ] Process with Flutter (toggle OFF)
  - Note: Mean RGB values: R=___, G=___, B=___
  - Note: Chromaticity: r=___, g=___
- [ ] Process with Python (toggle ON)
  - Note: Mean RGB values: R=___, G=___, B=___
  - Note: Chromaticity: r=___, g=___
- [ ] Values match (within rounding tolerance) ✅

**Test Image 2: DNG/RAW (if available)**
- [ ] Process with Flutter (toggle OFF)
  - Result: _______________
- [ ] Process with Python (toggle ON)
  - Result: _______________
- [ ] Python handles formats Flutter can't ✅

### Error Handling

- [ ] Upload unsupported file format
  - [ ] Error message displays appropriately
- [ ] Upload corrupted image
  - [ ] Error message displays appropriately
- [ ] Turn off Python API while toggle is ON
  - [ ] Upload image
  - [ ] Error message displays
  - [ ] App doesn't crash

## 🚀 Deployment Testing

### Pre-Deployment

- [ ] All local tests pass
- [ ] Git repository is up to date
- [ ] `vercel.json` is configured correctly
- [ ] `api/requirements.txt` is complete
- [ ] `package.json` has build script

### Vercel Deployment

- [ ] Install Vercel CLI: `npm install -g vercel`
- [ ] Login: `vercel login`
- [ ] Deploy: `vercel --prod`
- [ ] Deployment succeeds without errors
- [ ] Note deployment URL: _______________

### Production Testing

- [ ] Visit deployment URL
- [ ] Flutter app loads correctly
- [ ] Cloud toggle appears (Python API is available)
- [ ] Test image upload with Flutter processing (toggle OFF)
- [ ] Test image upload with Python API (toggle ON)
- [ ] Both processing modes work
- [ ] Export functionality works
- [ ] No console errors

### API Endpoint Testing

- [ ] Test health check: `curl https://your-project.vercel.app/`
- [ ] Returns OK status
- [ ] Test analyze endpoint:
  ```bash
  curl -X POST -F "file=@test.jpg" https://your-project.vercel.app/api/analyze
  ```
- [ ] Returns JSON with analysis results

## 📊 Performance Testing

### Small Images (< 1MB)

- [ ] Flutter processing time: ___ seconds
- [ ] Python API processing time: ___ seconds
- [ ] Both complete in reasonable time

### Medium Images (1-5MB)

- [ ] Flutter processing time: ___ seconds
- [ ] Python API processing time: ___ seconds
- [ ] Both complete in reasonable time

### Large Images (> 5MB)

- [ ] Flutter processing time: ___ seconds
- [ ] Python API processing time: ___ seconds
- [ ] Note any performance issues

### RAW Files (if available)

- [ ] DNG file size: ___
- [ ] Flutter result: _______________
- [ ] Python API result: _______________
- [ ] Python handles better ✅

## 🐛 Known Issues to Check

- [ ] DNG compression type 7 files
  - [ ] Flutter fails gracefully with clear error
  - [ ] Python API processes successfully
- [ ] Very large images (> 20MB)
  - [ ] May timeout on Vercel Hobby plan
  - [ ] Consider upgrading to Pro if needed
- [ ] CORS issues
  - [ ] No CORS errors in browser console
  - [ ] API accessible from Flutter web app

## 📝 Documentation Review

- [ ] README.md is up to date
- [ ] DEPLOYMENT.md has clear instructions
- [ ] QUICKSTART.md is easy to follow
- [ ] PYTHON_API_SUMMARY.md explains architecture
- [ ] api/README.md documents API endpoints

## ✨ Final Checks

- [ ] All tests pass
- [ ] Both processing modes work
- [ ] Toggle switches smoothly
- [ ] Error handling is graceful
- [ ] Documentation is complete
- [ ] Ready for production use

## 📸 Test Images Needed

Prepare these test images:

1. **Standard JPG** (< 1MB)
   - Should work with both Flutter and Python
   - Use for comparison testing

2. **Large JPG** (> 5MB)
   - Test performance with both methods

3. **PNG with transparency**
   - Verify both handle transparency

4. **DNG file** (if available)
   - Preferably with compression type 7
   - Test Python's enhanced RAW support

5. **Image with EXIF data**
   - Verify EXIF extraction works
   - Check photographic calculations (S_v, A_v, T_v, B_v)

## 🎯 Success Criteria

- ✅ Python API runs locally without errors
- ✅ Flutter app runs locally without errors
- ✅ Toggle between processing modes works
- ✅ Both modes produce accurate results
- ✅ Python handles formats Flutter can't
- ✅ Deployment to Vercel succeeds
- ✅ Production app works correctly
- ✅ Documentation is clear and complete

## 📞 If Something Doesn't Work

1. **Check console output** for error messages
2. **Review logs** in terminal
3. **Verify dependencies** are installed
4. **Restart services** (API and Flutter app)
5. **Check DEPLOYMENT.md** troubleshooting section
6. **Review PYTHON_API_SUMMARY.md** for architecture details

---

**Testing Date:** _______________  
**Tester:** _______________  
**Overall Result:** ⬜ Pass / ⬜ Fail  
**Notes:** _______________

