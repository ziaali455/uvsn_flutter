#!/usr/bin/env python3
"""
Simple test script for the Python API
Run this to test the API locally before deployment
"""

import requests
import sys
from pathlib import Path

def test_health_check():
    """Test the health check endpoint"""
    print("Testing health check endpoint...")
    try:
        response = requests.get("http://localhost:3000/")
        if response.status_code == 200:
            print("✅ Health check passed")
            print(f"   Response: {response.json()}")
            return True
        else:
            print(f"❌ Health check failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_analyze_image(image_path):
    """Test the analyze endpoint with an image"""
    print(f"\nTesting analyze endpoint with {image_path}...")
    
    if not Path(image_path).exists():
        print(f"❌ Image file not found: {image_path}")
        return False
    
    try:
        with open(image_path, 'rb') as f:
            files = {'file': (Path(image_path).name, f, 'image/jpeg')}
            response = requests.post("http://localhost:3000/api/analyze", files=files)
        
        if response.status_code == 200:
            print("✅ Analysis passed")
            data = response.json()
            print(f"   File: {data['fileName']}")
            print(f"   Mean RGB: R={data['meanRed']:.2f}, G={data['meanGreen']:.2f}, B={data['meanBlue']:.2f}")
            print(f"   Chromaticity: r={data['meanRChromaticity']:.4f}, g={data['meanGChromaticity']:.4f}")
            print(f"   Format: {data['imageFormat']}, Size: {data['fileSize']}")
            if data['sV'] is not None:
                print(f"   Photographic: S_v={data['sV']:.2f}, A_v={data['aV']:.2f}, T_v={data['tV']:.2f}, B_v={data['bV']:.2f}")
            return True
        else:
            print(f"❌ Analysis failed with status {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("UVSN Image Analyzer - Python API Test")
    print("=" * 60)
    print("\nMake sure the server is running:")
    print("  uvicorn analyze:app --reload --port 3000\n")
    
    # Test health check
    if not test_health_check():
        print("\n❌ Server is not running or not responding")
        sys.exit(1)
    
    # Test with an image if provided
    if len(sys.argv) > 1:
        image_path = sys.argv[1]
        if not test_analyze_image(image_path):
            sys.exit(1)
    else:
        print("\n💡 To test image analysis, run:")
        print("   python test_local.py /path/to/image.jpg")
    
    print("\n✅ All tests passed!")

