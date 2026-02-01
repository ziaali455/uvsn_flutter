"""
Image Analysis API - Vercel Serverless Function
Replicates the Flutter chromaticity and RGB analysis logic in Python
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
import numpy as np
import io
import math
from datetime import datetime
from typing import Optional, Dict, Any
import exifread
import rawpy
import gc  # Garbage collection for memory management

app = FastAPI()

# Enable CORS for Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=False,  # Must be False when using wildcard origins
    allow_methods=["*"],
    allow_headers=["*"],
)


class PhotograpicCalculations:
    """Replicate the Flutter PhotographicCalculations class"""
    
    LAMP_CONDITIONS = [
        '222 Ushio',
        '222 Nukit',
        '222 Lumen',
        '222 Unfiltered',
        '207 KrBr',
        '254',
        '265 LED',
        '280 LED',
        '295 LED',
        '302',
        '365',
        'sunlight',
        'Room light (fluorescent)',
    ]
    
    @staticmethod
    def calculate_sv(iso_speed_ratings: Optional[int]) -> Optional[float]:
        """Calculate S_v = log2(ISOSpeedRatings/3.3333)"""
        if iso_speed_ratings is None or iso_speed_ratings <= 0:
            return None
        return math.log2(iso_speed_ratings / 3.3333)
    
    @staticmethod
    def calculate_av(f_number: Optional[float]) -> Optional[float]:
        """Calculate A_v = 2 * log2(FNumber)"""
        if f_number is None or f_number <= 0:
            return None
        return 2 * math.log2(f_number)
    
    @staticmethod
    def calculate_tv(exposure_time: Optional[float]) -> Optional[float]:
        """Calculate T_v = -log2(ExposureTime)"""
        if exposure_time is None or exposure_time <= 0:
            return None
        return -math.log2(exposure_time)
    
    @staticmethod
    def calculate_bv(av: Optional[float], tv: Optional[float], sv: Optional[float]) -> Optional[float]:
        """Calculate B_v = A_v + T_v - S_v"""
        if av is None or tv is None or sv is None:
            return None
        return av + tv - sv


class ImageAnalyzer:
    """Replicate the Flutter UnifiedImageService chromaticity logic"""
    
    @staticmethod
    def decode_image(file_bytes: bytes, filename: str) -> Image.Image:
        """
        Decode image with fallbacks for RAW formats
        Replicates _decodeImageWithFallbacks from Flutter
        """
        # Try standard image formats first
        try:
            img = Image.open(io.BytesIO(file_bytes))
            print(f"✅ SUCCESS: Standard decoder worked for {filename}")
            print(f"Image dimensions: {img.size}")
            return img
        except Exception as e:
            print(f"❌ Standard decoder failed: {e}")
        
        # Try RAW format if standard fails
        if filename.lower().endswith(('.dng', '.raw', '.cr2', '.nef', '.arw', '.rw2')):
            try:
                print(f"=== Attempting RAW decode for {filename} ===")
                with rawpy.imread(io.BytesIO(file_bytes)) as raw:
                    # Extract RGB image from RAW with memory-optimized settings
                    # Use 8-bit output to save memory (16-bit doubles memory usage)
                    rgb = raw.postprocess(
                        output_bps=8,           # 8-bit output (saves 50% memory vs 16-bit)
                        use_camera_wb=True,     # Use camera white balance
                        no_auto_bright=False,   # Allow auto brightness
                        half_size=False,        # Process full resolution (required)
                    )
                    img = Image.fromarray(rgb)
                    print(f"✅ SUCCESS: RAW decoder worked (8-bit, memory optimized)")
                    print(f"RAW dimensions: {img.size}")
                    return img
            except Exception as e:
                print(f"❌ RAW decoder failed: {e}")
        
        raise Exception(f"Failed to decode image - format may not be supported or file may be corrupted")
    
    @staticmethod
    def calculate_mean_rgb(img: Image.Image) -> Dict[str, float]:
        """
        Calculate mean RGB values - MEMORY OPTIMIZED
        Processes every pixel but uses row-by-row streaming to minimize RAM
        """
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        width, height = img.size
        total_pixels = height * width
        
        print(f"Image dimensions: {width}x{height} ({total_pixels} total pixels)")
        print(f"🧠 Using memory-optimized row-by-row processing")
        
        # Process row by row to minimize memory usage
        # Instead of loading entire image as float64 array
        sum_red = 0.0
        sum_green = 0.0
        sum_blue = 0.0
        
        # Get image data as bytes and process in chunks
        img_array = np.array(img, dtype=np.uint8)  # uint8 uses 1/8 the memory of float64
        
        # Process each row
        for y in range(height):
            row = img_array[y].astype(np.float32)  # Convert one row at a time
            sum_red += np.sum(row[:, 0])
            sum_green += np.sum(row[:, 1])
            sum_blue += np.sum(row[:, 2])
        
        del img_array  # Free memory immediately
        
        mean_red = sum_red / total_pixels
        mean_green = sum_green / total_pixels
        mean_blue = sum_blue / total_pixels
        
        print(f"✅ COMPLETED: Processed all {total_pixels} pixels")
        
        return {
            'red': float(mean_red),
            'green': float(mean_green),
            'blue': float(mean_blue)
        }
    
    @staticmethod
    def calculate_chromaticity_values(img: Image.Image) -> Dict[str, float]:
        """
        Calculate chromaticity values - MEMORY OPTIMIZED
        Uses streaming/online statistics to avoid storing all chromaticity values
        Processes every pixel but keeps memory under control
        """
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        width, height = img.size
        total_pixels = height * width
        
        print(f"Chromaticity analysis for {width}x{height} ({total_pixels} pixels)")
        print(f"🧠 Using memory-optimized streaming statistics")
        
        # Use Welford's online algorithm for mean and variance
        # This processes one row at a time instead of storing all values
        n = 0  # Count of valid chromaticity samples
        mean_r = 0.0
        mean_g = 0.0
        M2_r = 0.0  # Sum of squared differences for variance
        M2_g = 0.0
        
        max_red = 0.0
        max_green = 0.0
        max_blue = 0.0
        
        # Load image as uint8 (1/8 memory of float64)
        img_array = np.array(img, dtype=np.uint8)
        
        # Process row by row
        for y in range(height):
            # Convert single row to float32 (not float64)
            row = img_array[y].astype(np.float32)
            r = row[:, 0]
            g = row[:, 1]
            b = row[:, 2]
            
            # Update max values
            row_max_r = np.max(r)
            row_max_g = np.max(g)
            row_max_b = np.max(b)
            if row_max_r > max_red: max_red = row_max_r
            if row_max_g > max_green: max_green = row_max_g
            if row_max_b > max_blue: max_blue = row_max_b
            
            # Calculate chromaticity for this row
            rgb_sum = r + g + b
            valid_mask = rgb_sum > 0.001
            
            if np.any(valid_mask):
                r_chrom = r[valid_mask] / rgb_sum[valid_mask]
                g_chrom = g[valid_mask] / rgb_sum[valid_mask]
                
                # Welford's online algorithm for each valid pixel
                for i in range(len(r_chrom)):
                    n += 1
                    delta_r = r_chrom[i] - mean_r
                    delta_g = g_chrom[i] - mean_g
                    mean_r += delta_r / n
                    mean_g += delta_g / n
                    delta2_r = r_chrom[i] - mean_r
                    delta2_g = g_chrom[i] - mean_g
                    M2_r += delta_r * delta2_r
                    M2_g += delta_g * delta2_g
        
        del img_array  # Free memory immediately
        
        # Calculate final standard deviations
        std_r = np.sqrt(M2_r / n) if n > 1 else 0.0
        std_g = np.sqrt(M2_g / n) if n > 1 else 0.0
        
        print(f"✅ COMPLETED: Chromaticity analysis finished")
        print(f"Max RGB values: R={max_red}, G={max_green}, B={max_blue}")
        print(f"Chromaticity samples: {n}")
        print(f"Chromaticity means: R={mean_r}, G={mean_g}")
        print(f"Chromaticity std devs: R={std_r}, G={std_g}")
        
        return {
            'meanRChromaticity': float(mean_r),
            'meanGChromaticity': float(mean_g),
            'stdRChromaticity': float(std_r),
            'stdGChromaticity': float(std_g),
            'maxRed': float(max_red),
            'maxGreen': float(max_green),
            'maxBlue': float(max_blue),
        }
    
    @staticmethod
    def extract_exif_data(file_bytes: bytes) -> Dict[str, Any]:
        """Extract EXIF data from image"""
        exif_dict = {}
        
        try:
            # Use exifread to extract EXIF data
            tags = exifread.process_file(io.BytesIO(file_bytes), details=False)
            
            # Convert tags to dictionary
            for tag, value in tags.items():
                # Convert IfdTag values to strings
                exif_dict[tag] = str(value)
            
            print(f"Extracted {len(exif_dict)} EXIF tags")
            
        except Exception as e:
            print(f"EXIF extraction error: {e}")
        
        return exif_dict
    
    @staticmethod
    def extract_photographic_values(exif_data: Dict[str, Any]) -> Dict[str, Optional[float]]:
        """Extract and calculate photographic values from EXIF"""
        
        # Extract ISO
        iso = None
        for key in ['EXIF ISOSpeedRatings', 'ISOSpeedRatings', 'ISO']:
            if key in exif_data:
                try:
                    iso = int(exif_data[key])
                    break
                except:
                    pass
        
        # Extract F-Number
        f_number = None
        for key in ['EXIF FNumber', 'FNumber', 'F-Number']:
            if key in exif_data:
                try:
                    value = exif_data[key]
                    # Handle fraction format like "28/10"
                    if '/' in str(value):
                        parts = str(value).split('/')
                        f_number = float(parts[0]) / float(parts[1])
                    else:
                        f_number = float(value)
                    break
                except:
                    pass
        
        # Extract Exposure Time
        exposure_time = None
        for key in ['EXIF ExposureTime', 'ExposureTime']:
            if key in exif_data:
                try:
                    value = exif_data[key]
                    # Handle fraction format like "1/60"
                    if '/' in str(value):
                        parts = str(value).split('/')
                        exposure_time = float(parts[0]) / float(parts[1])
                    else:
                        exposure_time = float(value)
                    break
                except:
                    pass
        
        # Calculate photographic values
        sv = PhotograpicCalculations.calculate_sv(iso)
        av = PhotograpicCalculations.calculate_av(f_number)
        tv = PhotograpicCalculations.calculate_tv(exposure_time)
        bv = PhotograpicCalculations.calculate_bv(av, tv, sv)
        
        print(f"EXIF Data: ISO={iso}, FNumber={f_number}, ExposureTime={exposure_time}")
        print(f"Calculated: S_v={sv}, A_v={av}, T_v={tv}, B_v={bv}")
        
        return {
            'sV': sv,
            'aV': av,
            'tV': tv,
            'bV': bv
        }


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "UVSN Image Analyzer API",
        "version": "1.0.0"
    }


@app.post("/api/analyze")
async def analyze_image(file: UploadFile = File(...)):
    """
    Analyze image and return RGB, chromaticity, and EXIF data
    Memory-optimized to work within 512MB RAM limit
    """
    img = None
    file_bytes = None
    
    try:
        # Read file bytes
        file_bytes = await file.read()
        file_size = len(file_bytes)
        filename = file.filename or "unknown"
        
        print(f"\n=== Analyzing {filename} ({file_size} bytes) ===")
        print(f"🧠 Memory limit: 512MB - using optimized processing")
        
        # Extract EXIF data first (before we potentially modify file_bytes)
        exif_data = ImageAnalyzer.extract_exif_data(file_bytes)
        photographic_values = ImageAnalyzer.extract_photographic_values(exif_data)
        
        # Decode image
        img = ImageAnalyzer.decode_image(file_bytes, filename)
        img_width, img_height = img.size
        
        # Free file_bytes memory - we have the decoded image now
        del file_bytes
        file_bytes = None
        gc.collect()
        print(f"🧹 Freed file bytes from memory")
        
        # Calculate mean RGB values (memory optimized)
        rgb_values = ImageAnalyzer.calculate_mean_rgb(img)
        gc.collect()
        
        # Calculate chromaticity values (memory optimized)
        chromaticity_values = ImageAnalyzer.calculate_chromaticity_values(img)
        
        # Free image memory
        del img
        img = None
        gc.collect()
        print(f"🧹 Freed image from memory")
        
        # Get file format
        file_extension = filename.split('.')[-1].upper() if '.' in filename else 'UNKNOWN'
        
        # Format file size
        if file_size < 1024:
            file_size_str = f"{file_size} B"
        elif file_size < 1024 * 1024:
            file_size_str = f"{file_size / 1024:.1f} KB"
        elif file_size < 1024 * 1024 * 1024:
            file_size_str = f"{file_size / (1024 * 1024):.1f} MB"
        else:
            file_size_str = f"{file_size / (1024 * 1024 * 1024):.1f} GB"
        
        # Build response matching Flutter ImageAnalysis structure
        response = {
            "fileName": filename,
            "meanRed": rgb_values['red'],
            "meanGreen": rgb_values['green'],
            "meanBlue": rgb_values['blue'],
            "meanRChromaticity": chromaticity_values['meanRChromaticity'],
            "meanGChromaticity": chromaticity_values['meanGChromaticity'],
            "stdRChromaticity": chromaticity_values['stdRChromaticity'],
            "stdGChromaticity": chromaticity_values['stdGChromaticity'],
            "maxRed": chromaticity_values['maxRed'],
            "maxGreen": chromaticity_values['maxGreen'],
            "maxBlue": chromaticity_values['maxBlue'],
            "exifData": exif_data,
            "analysisDate": datetime.now().isoformat(),
            "fileSize": file_size_str,
            "imageFormat": file_extension,
            "imageWidth": img_width,
            "imageHeight": img_height,
            "sV": photographic_values['sV'],
            "aV": photographic_values['aV'],
            "tV": photographic_values['tV'],
            "bV": photographic_values['bV'],
            "lampCondition": None,
        }
        
        print(f"✅ Analysis complete for {filename}")
        gc.collect()
        
        return JSONResponse(content=response)
        
    except Exception as e:
        print(f"❌ Error analyzing image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to analyze image: {str(e)}")
    
    finally:
        # Ensure cleanup even on error
        if img is not None:
            del img
        if file_bytes is not None:
            del file_bytes
        gc.collect()


# Vercel serverless function handler
handler = app

