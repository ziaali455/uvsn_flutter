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


class NumpyImageWrapper:
    """
    Wrapper class that makes a numpy array behave like a PIL Image
    This preserves 16-bit data that PIL would otherwise convert to 8-bit
    """
    def __init__(self, array: np.ndarray):
        self._array = array
        self._mode = 'RGB16' if array.dtype == np.uint16 else 'RGB'
    
    @property
    def size(self):
        """Returns (width, height) like PIL"""
        return (self._array.shape[1], self._array.shape[0])
    
    @property
    def mode(self):
        return self._mode
    
    def convert(self, mode):
        """Dummy convert - we're already RGB"""
        return self
    
    def __array__(self):
        """Allow np.array(wrapper) to work"""
        return self._array

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
    def parse_lamp_from_filename(filename: str) -> Optional[str]:
        """
        Parse lamp type from filename.
        
        Supports two formats:
        1. New format: 'IMG####_lamp_type_name.DNG' -> everything after first underscore
           Example: 'IMG0001_222u.DNG' -> '222u'
           Example: 'IMG2032304_title_of_lamp.DNG' -> 'title of lamp'
        2. Old format: 'XXXXXX_LAMP_XX.DNG' -> lamp is second part
           Example: '250415_222u_01.DNG' -> '222u'
        """
        try:
            # Remove extension
            name_without_ext = filename.rsplit('.', 1)[0]
            parts = name_without_ext.split('_')
            
            if len(parts) >= 2:
                # Check if first part looks like IMG#### (new format)
                if parts[0].upper().startswith('IMG'):
                    # New format: IMG####_lamp_type_name -> everything after first underscore
                    # Join remaining parts with spaces (underscores become spaces)
                    lamp_code = ' '.join(parts[1:])
                else:
                    # Old format: XXXXXX_LAMP_XX -> lamp is second part
                    lamp_code = parts[1]
                
                print(f"Parsed lamp code from filename: '{lamp_code}'")
                return lamp_code
            else:
                print(f"Filename doesn't have enough parts for lamp parsing: {filename}")
                return None
        except Exception as e:
            print(f"Error parsing lamp from filename: {e}")
            return None
    
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
    def matlab_compatible_streaming_analysis(file_bytes: bytes) -> Dict[str, Any]:
        """
        MATLAB-compatible RAW analysis with STREAMING to minimize memory.
        
        Instead of creating the full RGB array, we:
        1. Keep CFA as int32 (not float64) 
        2. Demosaic in strips (100 rows at a time)
        3. Calculate statistics on-the-fly
        
        Returns statistics directly, never materializing full RGB.
        """
        with rawpy.imread(io.BytesIO(file_bytes)) as raw:
            # Get raw CFA data as int32 (saves memory vs float64)
            cfa_full = raw.raw_image_visible.astype(np.int32)
            height, width = cfa_full.shape
            print(f"Raw CFA: {width}x{height}, dtype: int32")
            
            # Get black levels and pattern
            black_levels = np.array(raw.black_level_per_channel, dtype=np.int32)
            pattern = raw.raw_pattern
            print(f"Black levels: {black_levels}, Pattern:\n{pattern}")
            
            # Find pattern positions
            r_pos = tuple(np.argwhere(pattern == 0)[0])
            b_pos = tuple(np.argwhere(pattern == 2)[0])
            
            # Apply black level correction in-place
            for i in range(2):
                for j in range(2):
                    channel = pattern[i, j]
                    cfa_full[i::2, j::2] -= black_levels[channel]
            
            # Clamp to 0
            cfa_full = np.maximum(0, cfa_full)
            print(f"After black level: {cfa_full.min()} - {cfa_full.max()}")
            
            # Statistics accumulators
            sum_r, sum_g, sum_b = 0.0, 0.0, 0.0
            sum_r_chrom, sum_g_chrom = 0.0, 0.0
            sum_r_chrom_sq, sum_g_chrom_sq = 0.0, 0.0
            max_r, max_g, max_b = 0.0, 0.0, 0.0
            n_pixels = 0
            n_chrom = 0
            
            # Process in strips (100 rows at a time with 2-row overlap for demosaic)
            strip_height = 100
            
            for strip_start in range(0, height, strip_height):
                # Get strip with padding for demosaic (need 1 row above and below)
                pad_top = 1 if strip_start > 0 else 0
                pad_bottom = 1 if strip_start + strip_height < height else 0
                
                actual_start = strip_start - pad_top
                actual_end = min(strip_start + strip_height + pad_bottom, height)
                
                # Extract and demosaic this strip
                # CRITICAL: pass actual_start so demosaic knows the pattern offset!
                cfa_strip = cfa_full[actual_start:actual_end, :].astype(np.float32)
                rgb_strip = ImageAnalyzer.demosaic_strip(cfa_strip, pattern, r_pos, b_pos, actual_start)
                
                # Remove padding rows from result
                if pad_top:
                    rgb_strip = rgb_strip[1:, :, :]
                if pad_bottom and actual_end < height:
                    rgb_strip = rgb_strip[:-1, :, :]
                
                # Accumulate statistics from this strip
                r = rgb_strip[:, :, 0]
                g = rgb_strip[:, :, 1]
                b = rgb_strip[:, :, 2]
                
                # RGB sums and max
                sum_r += np.sum(r)
                sum_g += np.sum(g)
                sum_b += np.sum(b)
                max_r = max(max_r, np.max(r))
                max_g = max(max_g, np.max(g))
                max_b = max(max_b, np.max(b))
                n_pixels += r.size
                
                # Chromaticity
                rgb_sum = r + g + b
                valid = rgb_sum > 0
                if np.any(valid):
                    r_chrom = r[valid] / rgb_sum[valid]
                    g_chrom = g[valid] / rgb_sum[valid]
                    sum_r_chrom += np.sum(r_chrom)
                    sum_g_chrom += np.sum(g_chrom)
                    sum_r_chrom_sq += np.sum(r_chrom * r_chrom)
                    sum_g_chrom_sq += np.sum(g_chrom * g_chrom)
                    n_chrom += np.sum(valid)
                
                # Free strip memory
                del cfa_strip, rgb_strip, r, g, b, rgb_sum
                gc.collect()
            
            # Free CFA memory
            del cfa_full
            gc.collect()
            
            # Calculate final statistics
            mean_r = sum_r / n_pixels
            mean_g = sum_g / n_pixels
            mean_b = sum_b / n_pixels
            
            if n_chrom > 0:
                mean_r_chrom = sum_r_chrom / n_chrom
                mean_g_chrom = sum_g_chrom / n_chrom
                var_r = (sum_r_chrom_sq / n_chrom) - (mean_r_chrom ** 2)
                var_g = (sum_g_chrom_sq / n_chrom) - (mean_g_chrom ** 2)
                std_r_chrom = np.sqrt(max(0, var_r))
                std_g_chrom = np.sqrt(max(0, var_g))
            else:
                mean_r_chrom = mean_g_chrom = std_r_chrom = std_g_chrom = 0.0
            
            print(f"✅ Streaming analysis complete: {n_pixels} pixels")
            print(f"Mean RGB: {mean_r:.2f}, {mean_g:.2f}, {mean_b:.2f}")
            print(f"Chromaticity: r={mean_r_chrom:.6f}, g={mean_g_chrom:.6f}")
            
            return {
                'width': int(width),
                'height': int(height),
                'mean_rgb': {'red': float(mean_r), 'green': float(mean_g), 'blue': float(mean_b)},
                'chromaticity': {
                    'meanRChromaticity': float(mean_r_chrom),
                    'meanGChromaticity': float(mean_g_chrom),
                    'stdRChromaticity': float(std_r_chrom),
                    'stdGChromaticity': float(std_g_chrom),
                    'maxRed': float(max_r),
                    'maxGreen': float(max_g),
                    'maxBlue': float(max_b),
                }
            }
    
    @staticmethod
    def demosaic_strip(cfa: np.ndarray, pattern: np.ndarray, r_pos: tuple, b_pos: tuple, row_offset: int = 0) -> np.ndarray:
        """
        Demosaic a strip of CFA data using bilinear interpolation.
        Input: float32 CFA strip, Output: float32 RGB strip
        
        row_offset: the starting row in the original image (for correct pattern alignment)
        """
        height, width = cfa.shape
        rgb = np.zeros((height, width, 3), dtype=np.float32)
        
        # Create masks for this strip with correct pattern alignment
        # The pattern repeats every 2 rows, so we need to account for where this strip starts
        r_mask = np.zeros((height, width), dtype=bool)
        g_mask = np.zeros((height, width), dtype=bool)
        b_mask = np.zeros((height, width), dtype=bool)
        
        # Adjust pattern indices based on row_offset
        row_phase = row_offset % 2  # 0 or 1
        
        for i in range(2):
            for j in range(2):
                channel = pattern[i, j]
                # Adjust row start based on offset: if row_offset is odd, shift pattern by 1
                adjusted_i = (i + row_phase) % 2
                if channel == 0:
                    r_mask[adjusted_i::2, j::2] = True
                elif channel == 1 or channel == 3:
                    g_mask[adjusted_i::2, j::2] = True
                elif channel == 2:
                    b_mask[adjusted_i::2, j::2] = True
        
        # Place known values
        rgb[:, :, 0] = np.where(r_mask, cfa, 0)
        rgb[:, :, 1] = np.where(g_mask, cfa, 0)
        rgb[:, :, 2] = np.where(b_mask, cfa, 0)
        
        # Simple bilinear interpolation using shifts (memory efficient)
        # For Red at non-red positions
        r_ch = rgb[:, :, 0]
        r_h = (np.roll(r_ch, 1, axis=1) + np.roll(r_ch, -1, axis=1)) / 2
        r_v = (np.roll(r_ch, 1, axis=0) + np.roll(r_ch, -1, axis=0)) / 2
        r_d = (np.roll(np.roll(r_ch, 1, axis=0), 1, axis=1) + 
               np.roll(np.roll(r_ch, 1, axis=0), -1, axis=1) +
               np.roll(np.roll(r_ch, -1, axis=0), 1, axis=1) + 
               np.roll(np.roll(r_ch, -1, axis=0), -1, axis=1)) / 4
        
        row_idx = np.arange(height)[:, np.newaxis] % 2
        # Adjust r_pos and b_pos for the row offset
        adjusted_r_row = (r_pos[0] + row_offset) % 2
        same_row_r = (row_idx == adjusted_r_row)
        
        need_r = ~r_mask
        rgb[:, :, 0] = np.where(need_r & b_mask, r_d, rgb[:, :, 0])
        rgb[:, :, 0] = np.where(need_r & ~b_mask & same_row_r, r_h, rgb[:, :, 0])
        rgb[:, :, 0] = np.where(need_r & ~b_mask & ~same_row_r, r_v, rgb[:, :, 0])
        del r_ch, r_h, r_v, r_d
        
        # For Blue at non-blue positions
        b_ch = rgb[:, :, 2]
        b_h = (np.roll(b_ch, 1, axis=1) + np.roll(b_ch, -1, axis=1)) / 2
        b_v = (np.roll(b_ch, 1, axis=0) + np.roll(b_ch, -1, axis=0)) / 2
        b_d = (np.roll(np.roll(b_ch, 1, axis=0), 1, axis=1) + 
               np.roll(np.roll(b_ch, 1, axis=0), -1, axis=1) +
               np.roll(np.roll(b_ch, -1, axis=0), 1, axis=1) + 
               np.roll(np.roll(b_ch, -1, axis=0), -1, axis=1)) / 4
        
        adjusted_b_row = (b_pos[0] + row_offset) % 2
        same_row_b = (row_idx == adjusted_b_row)
        need_b = ~b_mask
        rgb[:, :, 2] = np.where(need_b & r_mask, b_d, rgb[:, :, 2])
        rgb[:, :, 2] = np.where(need_b & ~r_mask & same_row_b, b_h, rgb[:, :, 2])
        rgb[:, :, 2] = np.where(need_b & ~r_mask & ~same_row_b, b_v, rgb[:, :, 2])
        del b_ch, b_h, b_v, b_d
        
        # For Green at red/blue positions
        g_ch = rgb[:, :, 1]
        g_cross = (np.roll(g_ch, 1, axis=0) + np.roll(g_ch, -1, axis=0) +
                   np.roll(g_ch, 1, axis=1) + np.roll(g_ch, -1, axis=1)) / 4
        rgb[:, :, 1] = np.where(~g_mask, g_cross, rgb[:, :, 1])
        del g_ch, g_cross
        
        return rgb
    
    @staticmethod
    def decode_image(file_bytes: bytes, filename: str) -> Image.Image:
        """
        Decode image with fallbacks for RAW formats
        Replicates _decodeImageWithFallbacks from Flutter
        
        IMPORTANT: RAW files (DNG, CR2, etc.) are processed FIRST with MATLAB-compatible
        decoder to get true sensor data, NOT the embedded JPEG preview!
        """
        # Check if this is a RAW file - process with MATLAB-compatible decoder FIRST
        # (PIL would read the embedded JPEG thumbnail, not the actual sensor data!)
        raw_extensions = ('.dng', '.raw', '.cr2', '.nef', '.arw', '.rw2', '.orf', '.pef')
        if filename.lower().endswith(raw_extensions):
            try:
                print(f"=== RAW file detected: {filename} ===")
                print(f"=== Using MATLAB-compatible RAW decode (not JPEG preview) ===")
                rgb = ImageAnalyzer.matlab_compatible_raw_decode(file_bytes)
                print(f"✅ SUCCESS: MATLAB-compatible RAW decode")
                print(f"RGB array shape: {rgb.shape}, dtype: {rgb.dtype}")
                print(f"RGB value range: {rgb.min()} - {rgb.max()}")
                return NumpyImageWrapper(rgb)
            except Exception as e:
                print(f"❌ MATLAB-compatible RAW decoder failed: {e}")
                # Fallback to rawpy postprocess (still better than JPEG preview)
                try:
                    print(f"=== Falling back to rawpy postprocess ===")
                    with rawpy.imread(io.BytesIO(file_bytes)) as raw:
                        rgb = raw.postprocess(
                            output_bps=16,
                            use_camera_wb=False,
                            use_auto_wb=False,
                            no_auto_bright=True,
                            output_color=rawpy.ColorSpace.raw,
                            gamma=(1, 1),
                            half_size=False,
                        )
                        print(f"✅ SUCCESS: rawpy postprocess fallback")
                        return NumpyImageWrapper(rgb)
                except Exception as e2:
                    print(f"❌ rawpy fallback also failed: {e2}")
                    raise Exception(f"Failed to decode RAW file: {e}, fallback: {e2}")
        
        # For non-RAW files, use PIL (standard image formats)
        try:
            img = Image.open(io.BytesIO(file_bytes))
            print(f"✅ SUCCESS: PIL decoder worked for {filename}")
            print(f"Image dimensions: {img.size}, mode: {img.mode}")
            return img
        except Exception as e:
            print(f"❌ PIL decoder failed: {e}")
        
        raise Exception(f"Failed to decode image - format may not be supported or file may be corrupted")
    
    @staticmethod
    def calculate_mean_rgb(img) -> Dict[str, float]:
        """
        Calculate mean RGB values - MEMORY OPTIMIZED
        Supports PIL Image, NumpyImageWrapper, and both 8-bit and 16-bit images
        Processes every pixel but uses row-by-row streaming to minimize RAM
        """
        # Get image as numpy array (works for both PIL and NumpyImageWrapper)
        if isinstance(img, NumpyImageWrapper):
            img_array = np.array(img)
        else:
            # PIL Image - convert to RGB if needed
            if img.mode == 'I;16':
                img = img.convert('RGB')
            elif img.mode not in ('RGB', 'I;16B', 'RGB16'):
                img = img.convert('RGB')
            img_array = np.array(img)
        
        height, width = img_array.shape[:2]
        total_pixels = height * width
        
        # Detect bit depth from array dtype
        bit_depth = 16 if img_array.dtype == np.uint16 else 8
        
        print(f"Image dimensions: {width}x{height} ({total_pixels} total pixels)")
        print(f"🎨 Bit depth: {bit_depth}-bit (dtype: {img_array.dtype})")
        print(f"🧠 Using memory-optimized row-by-row processing")
        
        # Process row by row to minimize memory usage
        sum_red = 0.0
        sum_green = 0.0
        sum_blue = 0.0
        
        # Process each row (keeps only one row as float64 at a time)
        for y in range(height):
            row = img_array[y].astype(np.float64)  # Convert one row at a time
            sum_red += np.sum(row[:, 0])
            sum_green += np.sum(row[:, 1])
            sum_blue += np.sum(row[:, 2])
        
        del img_array  # Free memory immediately
        
        mean_red = sum_red / total_pixels
        mean_green = sum_green / total_pixels
        mean_blue = sum_blue / total_pixels
        
        print(f"✅ COMPLETED: Processed all {total_pixels} pixels ({bit_depth}-bit)")
        print(f"Mean RGB: R={mean_red:.2f}, G={mean_green:.2f}, B={mean_blue:.2f}")
        
        return {
            'red': float(mean_red),
            'green': float(mean_green),
            'blue': float(mean_blue)
        }
    
    @staticmethod
    def calculate_chromaticity_values(img) -> Dict[str, float]:
        """
        Calculate chromaticity values - MATLAB COMPATIBLE
        
        Matches MATLAB's behavior:
        - chromaticity_x = R / (R+G+B)
        - chromaticity_y = G / (R+G+B)  
        - mean(mean(chromaticity)) for mean
        - std(chromaticity(:)) for standard deviation
        
        Uses one-pass algorithm for memory efficiency:
        - mean = sum(x) / n
        - std = sqrt(sum(x^2)/n - mean^2)
        """
        # Get image as numpy array (works for both PIL and NumpyImageWrapper)
        if isinstance(img, NumpyImageWrapper):
            img_array = np.array(img)
        else:
            # PIL Image - convert to RGB if needed
            if img.mode == 'I;16':
                img = img.convert('RGB')
            elif img.mode not in ('RGB', 'I;16B', 'RGB16'):
                img = img.convert('RGB')
            img_array = np.array(img)
        
        height, width = img_array.shape[:2]
        total_pixels = height * width
        
        # Detect bit depth from array dtype
        bit_depth = 16 if img_array.dtype == np.uint16 else 8
        
        print(f"Chromaticity analysis for {width}x{height} ({total_pixels} pixels)")
        print(f"🎨 Bit depth: {bit_depth}-bit (dtype: {img_array.dtype})")
        print(f"🧠 Using MATLAB-compatible one-pass algorithm")
        
        # One-pass statistics accumulators
        sum_r_chrom = 0.0
        sum_g_chrom = 0.0
        sum_r_chrom_sq = 0.0
        sum_g_chrom_sq = 0.0
        n = 0  # Count of valid chromaticity samples
        
        max_red = 0.0
        max_green = 0.0
        max_blue = 0.0
        
        # Process row by row (memory efficient)
        for y in range(height):
            # Convert single row to float64 for precision
            row = img_array[y].astype(np.float64)
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
            
            # Calculate chromaticity for this row (MATLAB style)
            # MATLAB: chromaticity_x = R ./ (R+G+B)
            rgb_sum = r + g + b
            
            # Only exclude true division-by-zero (R+G+B=0), match MATLAB behavior
            valid_mask = rgb_sum > 0
            
            if np.any(valid_mask):
                r_valid = r[valid_mask]
                g_valid = g[valid_mask]
                rgb_sum_valid = rgb_sum[valid_mask]
                
                r_chrom = r_valid / rgb_sum_valid
                g_chrom = g_valid / rgb_sum_valid
                
                # Accumulate sums (vectorized - fast!)
                sum_r_chrom += np.sum(r_chrom)
                sum_g_chrom += np.sum(g_chrom)
                sum_r_chrom_sq += np.sum(r_chrom * r_chrom)
                sum_g_chrom_sq += np.sum(g_chrom * g_chrom)
                n += len(r_chrom)
        
        del img_array  # Free memory immediately
        
        # Calculate final statistics (MATLAB style)
        if n > 0:
            mean_r = sum_r_chrom / n
            mean_g = sum_g_chrom / n
            # Variance = E[X^2] - E[X]^2
            var_r = (sum_r_chrom_sq / n) - (mean_r * mean_r)
            var_g = (sum_g_chrom_sq / n) - (mean_g * mean_g)
            # Clamp to 0 to handle numerical precision issues
            std_r = np.sqrt(max(0, var_r))
            std_g = np.sqrt(max(0, var_g))
        else:
            mean_r = mean_g = std_r = std_g = 0.0
        
        print(f"✅ COMPLETED: Chromaticity analysis finished ({bit_depth}-bit)")
        print(f"Max RGB values: R={max_red}, G={max_green}, B={max_blue}")
        print(f"Valid chromaticity samples: {n} / {total_pixels}")
        print(f"Chromaticity means: R={mean_r:.6f}, G={mean_g:.6f}")
        print(f"Chromaticity std devs: R={std_r:.6f}, G={std_g:.6f}")
        
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
    
    RAW files use streaming analysis (never materializes full RGB array)
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
        
        # Check if RAW file - use streaming analysis (memory efficient)
        raw_extensions = ('.dng', '.raw', '.cr2', '.nef', '.arw', '.rw2', '.orf', '.pef')
        is_raw = filename.lower().endswith(raw_extensions)
        
        if is_raw:
            print(f"🎯 RAW file detected - using streaming MATLAB-compatible analysis")
            # Streaming analysis - never materializes full RGB array
            analysis = ImageAnalyzer.matlab_compatible_streaming_analysis(file_bytes)
            
            img_width = analysis['width']
            img_height = analysis['height']
            rgb_values = analysis['mean_rgb']
            chromaticity_values = analysis['chromaticity']
            
            # Free file_bytes memory
            del file_bytes
            file_bytes = None
            gc.collect()
            print(f"🧹 Freed file bytes from memory")
        else:
            # Standard image processing for non-RAW files
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
        
        # Parse lamp type from filename (MATLAB logic: parts = split(fileName, '_'); lamp = parts{2})
        parsed_lamp = PhotograpicCalculations.parse_lamp_from_filename(filename)
        
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
            "lampCondition": parsed_lamp,  # Auto-parsed from filename
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

