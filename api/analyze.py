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
                    # Extract RGB image from RAW
                    rgb = raw.postprocess()
                    img = Image.fromarray(rgb)
                    print(f"✅ SUCCESS: RAW decoder worked")
                    print(f"RAW dimensions: {img.size}")
                    return img
            except Exception as e:
                print(f"❌ RAW decoder failed: {e}")
        
        raise Exception(f"Failed to decode image - format may not be supported or file may be corrupted")
    
    @staticmethod
    def calculate_mean_rgb(img: Image.Image) -> Dict[str, float]:
        """
        Calculate mean RGB values
        Replicates _calculateMeanRGB from Flutter
        """
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Convert to numpy array for efficient processing
        img_array = np.array(img, dtype=np.float64)
        height, width = img_array.shape[:2]
        total_pixels = height * width
        
        print(f"Image dimensions: {width}x{height} ({total_pixels} total pixels)")
        
        # Calculate mean RGB values
        mean_red = np.mean(img_array[:, :, 0])
        mean_green = np.mean(img_array[:, :, 1])
        mean_blue = np.mean(img_array[:, :, 2])
        
        print(f"✅ COMPLETED: Processed all {total_pixels} pixels")
        
        return {
            'red': float(mean_red),
            'green': float(mean_green),
            'blue': float(mean_blue)
        }
    
    @staticmethod
    def calculate_chromaticity_values(img: Image.Image) -> Dict[str, float]:
        """
        Calculate chromaticity values with streaming statistics
        Replicates _calculateChromaticityValues from Flutter
        """
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Convert to numpy array
        img_array = np.array(img, dtype=np.float64)
        height, width = img_array.shape[:2]
        total_pixels = height * width
        
        print(f"Chromaticity analysis for {width}x{height} ({total_pixels} pixels)")
        
        # Extract RGB channels
        r = img_array[:, :, 0]
        g = img_array[:, :, 1]
        b = img_array[:, :, 2]
        
        # Calculate sum for chromaticity (r + g + b)
        rgb_sum = r + g + b
        
        # Avoid division by zero - only calculate chromaticity where sum > 0.001
        valid_mask = rgb_sum > 0.001
        
        # Calculate chromaticity values
        r_chromaticity = np.zeros_like(r)
        g_chromaticity = np.zeros_like(g)
        
        r_chromaticity[valid_mask] = r[valid_mask] / rgb_sum[valid_mask]
        g_chromaticity[valid_mask] = g[valid_mask] / rgb_sum[valid_mask]
        
        # Calculate statistics only on valid pixels
        valid_r_chrom = r_chromaticity[valid_mask]
        valid_g_chrom = g_chromaticity[valid_mask]
        
        chromaticity_count = np.sum(valid_mask)
        
        # Calculate means
        mean_r_chromaticity = float(np.mean(valid_r_chrom)) if chromaticity_count > 0 else 0.0
        mean_g_chromaticity = float(np.mean(valid_g_chrom)) if chromaticity_count > 0 else 0.0
        
        # Calculate standard deviations
        std_r_chromaticity = float(np.std(valid_r_chrom)) if chromaticity_count > 0 else 0.0
        std_g_chromaticity = float(np.std(valid_g_chrom)) if chromaticity_count > 0 else 0.0
        
        # Calculate max RGB values
        max_red = float(np.max(r))
        max_green = float(np.max(g))
        max_blue = float(np.max(b))
        
        print(f"✅ COMPLETED: Chromaticity analysis finished")
        print(f"Max RGB values: R={max_red}, G={max_green}, B={max_blue}")
        print(f"Chromaticity samples: {chromaticity_count}")
        print(f"Chromaticity means: R={mean_r_chromaticity}, G={mean_g_chromaticity}")
        print(f"Chromaticity std devs: R={std_r_chromaticity}, G={std_g_chromaticity}")
        
        return {
            'meanRChromaticity': mean_r_chromaticity,
            'meanGChromaticity': mean_g_chromaticity,
            'stdRChromaticity': std_r_chromaticity,
            'stdGChromaticity': std_g_chromaticity,
            'maxRed': max_red,
            'maxGreen': max_green,
            'maxBlue': max_blue,
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
    Replicates the Flutter analyzeImageFromBytes functionality
    """
    try:
        # Read file bytes
        file_bytes = await file.read()
        file_size = len(file_bytes)
        filename = file.filename or "unknown"
        
        print(f"\n=== Analyzing {filename} ({file_size} bytes) ===")
        
        # Decode image
        img = ImageAnalyzer.decode_image(file_bytes, filename)
        
        # Calculate mean RGB values
        rgb_values = ImageAnalyzer.calculate_mean_rgb(img)
        
        # Calculate chromaticity values
        chromaticity_values = ImageAnalyzer.calculate_chromaticity_values(img)
        
        # Extract EXIF data
        exif_data = ImageAnalyzer.extract_exif_data(file_bytes)
        
        # Calculate photographic values
        photographic_values = ImageAnalyzer.extract_photographic_values(exif_data)
        
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
            "sV": photographic_values['sV'],
            "aV": photographic_values['aV'],
            "tV": photographic_values['tV'],
            "bV": photographic_values['bV'],
            "lampCondition": None,
        }
        
        print(f"✅ Analysis complete for {filename}")
        
        return JSONResponse(content=response)
        
    except Exception as e:
        print(f"❌ Error analyzing image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to analyze image: {str(e)}")


# Vercel serverless function handler
handler = app

