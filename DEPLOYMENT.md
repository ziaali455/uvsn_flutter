# Deployment Guide - UVSN Image Analyzer with Python API

This guide covers deploying both the Flutter web app and Python API to Vercel.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Vercel Deployment                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┐       ┌──────────────────┐       │
│  │  Flutter Web App │       │   Python API     │       │
│  │  (Static Build)  │◄─────►│  (Serverless)    │       │
│  │                  │       │                  │       │
│  │  /               │       │  /api/analyze    │       │
│  │  /index.html     │       │                  │       │
│  └──────────────────┘       └──────────────────┘       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **Vercel CLI** (optional): `npm install -g vercel`
3. **Git Repository**: Your code should be in a Git repository

## Quick Deploy (Recommended)

### Option 1: Deploy via Vercel Dashboard (Easiest)

1. **Connect Repository**
   - Go to [vercel.com/new](https://vercel.com/new)
   - Import your Git repository
   - Vercel will auto-detect the configuration from `vercel.json`

2. **Configure Build Settings**
   - Framework Preset: `Other`
   - Build Command: `npm run build` (from package.json)
   - Output Directory: `build/web`

3. **Deploy**
   - Click "Deploy"
   - Vercel will build both Flutter web and Python API
   - Your app will be live at `https://your-project.vercel.app`

### Option 2: Deploy via CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Deploy to production
vercel --prod
```

## Local Development

### 1. Run Python API Locally

```bash
# Navigate to project root
cd /Users/alizia/dev/uvsn_flutter/uvsn_image_analyzer

# Create Python virtual environment
python3 -m venv api/venv
source api/venv/bin/activate  # On Windows: api\venv\Scripts\activate

# Install Python dependencies
pip install -r api/requirements.txt

# Run the API server
cd api
uvicorn analyze:app --reload --port 3000

# Test the API
python test_local.py
```

The API will be available at `http://localhost:3000`

### 2. Run Flutter Web App

```bash
# In a new terminal, navigate to project root
cd /Users/alizia/dev/uvsn_flutter/uvsn_image_analyzer

# Run Flutter web
flutter run -d chrome

# Or build for production
flutter build web
```

### 3. Test Integration

1. Open the Flutter app in your browser
2. Look for the cloud icon toggle in the top-right corner
3. If the Python API is running, the toggle will be enabled
4. Switch it on to use Python API for image processing
5. Upload an image to test the integration

## Testing Before Deployment

### Test Python API

```bash
# Start the API server
cd api
uvicorn analyze:app --reload --port 3000

# In another terminal, run tests
python test_local.py path/to/test/image.jpg
```

### Test Flutter App

```bash
# Build the Flutter web app
flutter build web

# Serve it locally
cd build/web
python3 -m http.server 8080

# Open http://localhost:8080 in your browser
```

## Deployment Checklist

- [ ] Python API works locally
- [ ] Flutter app works locally
- [ ] Integration between Flutter and Python API tested
- [ ] `vercel.json` is properly configured
- [ ] `api/requirements.txt` includes all dependencies
- [ ] `package.json` has correct build script
- [ ] Git repository is up to date

## Vercel Configuration

Your `vercel.json` should look like this:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build/web"
      }
    },
    {
      "src": "api/analyze.py",
      "use": "@vercel/python"
    }
  ],
  "rewrites": [
    {
      "source": "/api/(.*)",
      "destination": "/api/$1"
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

## Environment Variables

If you need to configure the API URL for different environments:

### In Vercel Dashboard

1. Go to your project settings
2. Navigate to "Environment Variables"
3. Add: `API_URL` = `/api` (for production)

### In Flutter Code

The app automatically uses:
- Production (Vercel): `/api` (relative path, same domain)
- Local Development: `http://localhost:3000/api`

## Troubleshooting

### Python API not working after deployment

1. **Check Vercel Logs**
   ```bash
   vercel logs
   ```

2. **Verify Python dependencies**
   - Make sure all packages are in `api/requirements.txt`
   - Check for version compatibility issues

3. **Test the API endpoint**
   ```bash
   curl https://your-project.vercel.app/api/
   ```

### Flutter app not finding Python API

1. **Check browser console** for CORS errors
2. **Verify API URL** in `lib/services/python_image_service.dart`
3. **Test API availability** - the toggle should appear in the app bar

### Build failures

1. **Flutter build fails**
   ```bash
   # Clear build cache
   flutter clean
   flutter pub get
   flutter build web
   ```

2. **Python build fails**
   - Check `api/requirements.txt` for syntax errors
   - Verify Python version compatibility (3.9+)

### Image processing errors

1. **RAW files not processing**
   - Check that `rawpy` is installed
   - Some proprietary formats may still have limitations

2. **Large files timing out**
   - Vercel serverless functions have a 10-second timeout on hobby plan
   - Consider upgrading to Pro for 60-second timeout

## Performance Optimization

### For Large Images

1. **Increase Vercel timeout** (Pro plan)
2. **Add image size limits** in the Flutter app
3. **Implement chunked processing** for very large files

### For Better Response Times

1. **Use CDN caching** for static assets
2. **Optimize image uploads** with compression
3. **Add loading states** for better UX

## Monitoring

### Vercel Analytics

Enable analytics in your Vercel dashboard to monitor:
- API response times
- Error rates
- Usage patterns

### Logs

```bash
# View real-time logs
vercel logs --follow

# View logs for specific deployment
vercel logs [deployment-url]
```

## Costs

### Vercel Hobby Plan (Free)
- ✅ Unlimited deployments
- ✅ 100GB bandwidth/month
- ✅ Serverless functions
- ⚠️ 10-second function timeout
- ⚠️ 1024MB function memory

### Vercel Pro Plan ($20/month)
- ✅ Everything in Hobby
- ✅ 60-second function timeout
- ✅ 3008MB function memory
- ✅ Better for production use

## Next Steps

1. **Deploy to Vercel** using the dashboard or CLI
2. **Test the live deployment** with various image formats
3. **Monitor performance** and adjust as needed
4. **Consider upgrading** to Pro if you need longer timeouts

## Support

- Vercel Documentation: https://vercel.com/docs
- FastAPI Documentation: https://fastapi.tiangolo.com
- Flutter Web Documentation: https://flutter.dev/web

## Migration Path

Currently, the app supports **both** Flutter and Python processing:

1. **Phase 1** (Current): Side-by-side comparison
   - Toggle between Flutter and Python
   - Test Python API with real images
   - Verify results match

2. **Phase 2**: Gradual migration
   - Use Python API for problematic formats (DNG, RAW)
   - Keep Flutter for standard formats (JPG, PNG)

3. **Phase 3**: Full Python API
   - Remove Flutter processing code
   - Use Python API exclusively
   - Optimize for performance

