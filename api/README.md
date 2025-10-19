# UVSN Image Analyzer - Python API

This directory contains the Python backend for image analysis, providing better support for RAW formats and advanced image processing.

## Features

- **Enhanced RAW Support**: Uses `rawpy` for comprehensive RAW format support
- **Better Compression Handling**: Handles DNG compression types that Flutter can't process
- **Same Analysis Logic**: Replicates the exact chromaticity calculations from Flutter
- **Seamless Integration**: Returns data in the same format as Flutter implementation

## Local Development

### Prerequisites

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run with uvicorn
uvicorn analyze:app --reload --port 3000
```

The API will be available at `http://localhost:3000`

### Test the API

```bash
# Health check
curl http://localhost:3000/

# Analyze an image
curl -X POST -F "file=@/path/to/image.jpg" http://localhost:3000/api/analyze
```

## Deployment to Vercel

The API is automatically deployed to Vercel when you push to your repository.

### Manual Deployment

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

## API Endpoints

### `GET /`
Health check endpoint

**Response:**
```json
{
  "status": "ok",
  "service": "UVSN Image Analyzer API",
  "version": "1.0.0"
}
```

### `POST /api/analyze`
Analyze an image and return RGB, chromaticity, and EXIF data

**Request:**
- Method: `POST`
- Content-Type: `multipart/form-data`
- Body: `file` (image file)

**Response:**
```json
{
  "fileName": "image.jpg",
  "meanRed": 128.5,
  "meanGreen": 130.2,
  "meanBlue": 125.8,
  "meanRChromaticity": 0.333,
  "meanGChromaticity": 0.338,
  "stdRChromaticity": 0.025,
  "stdGChromaticity": 0.028,
  "maxRed": 255.0,
  "maxGreen": 255.0,
  "maxBlue": 255.0,
  "exifData": {...},
  "analysisDate": "2025-10-19T12:00:00",
  "fileSize": "2.5 MB",
  "imageFormat": "JPG",
  "sV": 5.0,
  "aV": 4.0,
  "tV": 6.0,
  "bV": 5.0,
  "lampCondition": null
}
```

## Supported Formats

- **Standard Formats**: JPG, PNG, BMP, GIF, WebP
- **RAW Formats**: DNG, CR2, NEF, ARW, RW2, and more
- **Better Compression Support**: Handles DNG compression type 7 and other advanced compressions

## Architecture

The Python API replicates the exact logic from the Flutter implementation:

1. **Image Decoding**: Uses Pillow for standard formats, rawpy for RAW
2. **RGB Analysis**: Calculates mean RGB values across all pixels
3. **Chromaticity Analysis**: Computes chromaticity coordinates and standard deviations
4. **EXIF Extraction**: Uses exifread for comprehensive EXIF data
5. **Photographic Calculations**: Calculates S_v, A_v, T_v, and B_v values

## Performance

- Processes images in parallel with NumPy for efficiency
- Handles large images without memory issues
- Faster than Flutter for large RAW files

## Troubleshooting

### Python API not available in Flutter app

1. Make sure the server is running locally or deployed to Vercel
2. Check the console for API availability messages
3. Verify CORS settings in `analyze.py`

### RAW files not processing

1. Ensure `rawpy` is installed: `pip install rawpy`
2. Check that libraw is available on your system
3. Some proprietary RAW formats may still have limitations

### Deployment issues

1. Verify `vercel.json` includes the Python build configuration
2. Check Vercel logs for deployment errors
3. Ensure all dependencies are in `requirements.txt`

