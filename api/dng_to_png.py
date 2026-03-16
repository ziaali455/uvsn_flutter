"""
Convert a DNG (or other RAW) file to 16-bit PNG using the same decode pipeline
as the classifier and analyzer: black-level correction + bilinear demosaic,
linear output, no white balance. Preserves all information used for
chromaticity and mean RGB (classifier features: meanRed, meanGreen, meanBlue, r, g).

Usage:
  python dng_to_png.py input.dng [output.png]
  python dng_to_png.py ~/Downloads/compiled_DNG_images_with_names   # convert all DNGs in folder
  python -m api.dng_to_png input.dng

Requires: rawpy, numpy. For 16-bit PNG output: pypng (pip install pypng).
"""

import io
import os
import sys

import numpy as np
import rawpy


def _demosaic_strip(cfa: np.ndarray, pattern: np.ndarray, r_pos: tuple, b_pos: tuple, row_offset: int = 0) -> np.ndarray:
    """
    Demosaic a strip of CFA data using bilinear interpolation.
    Same logic as ImageAnalyzer.demosaic_strip in analyze.py.
    Input: float32 CFA, Output: float32 RGB (H, W, 3).
    """
    height, width = cfa.shape
    rgb = np.zeros((height, width, 3), dtype=np.float32)

    row_phase = row_offset % 2
    r_mask = np.zeros((height, width), dtype=bool)
    g_mask = np.zeros((height, width), dtype=bool)
    b_mask = np.zeros((height, width), dtype=bool)

    for i in range(2):
        for j in range(2):
            channel = pattern[i, j]
            adjusted_i = (i + row_phase) % 2
            if channel == 0:
                r_mask[adjusted_i::2, j::2] = True
            elif channel in (1, 3):
                g_mask[adjusted_i::2, j::2] = True
            elif channel == 2:
                b_mask[adjusted_i::2, j::2] = True

    rgb[:, :, 0] = np.where(r_mask, cfa, 0)
    rgb[:, :, 1] = np.where(g_mask, cfa, 0)
    rgb[:, :, 2] = np.where(b_mask, cfa, 0)

    # Red at non-red positions
    r_ch = rgb[:, :, 0].copy()
    r_h = (np.roll(r_ch, 1, axis=1) + np.roll(r_ch, -1, axis=1)) / 2
    r_v = (np.roll(r_ch, 1, axis=0) + np.roll(r_ch, -1, axis=0)) / 2
    r_d = (
        np.roll(np.roll(r_ch, 1, axis=0), 1, axis=1)
        + np.roll(np.roll(r_ch, 1, axis=0), -1, axis=1)
        + np.roll(np.roll(r_ch, -1, axis=0), 1, axis=1)
        + np.roll(np.roll(r_ch, -1, axis=0), -1, axis=1)
    ) / 4
    row_idx = np.arange(height)[:, np.newaxis] % 2
    adjusted_r_row = (r_pos[0] + row_offset) % 2
    same_row_r = row_idx == adjusted_r_row
    need_r = ~r_mask
    rgb[:, :, 0] = np.where(need_r & b_mask, r_d, rgb[:, :, 0])
    rgb[:, :, 0] = np.where(need_r & ~b_mask & same_row_r, r_h, rgb[:, :, 0])
    rgb[:, :, 0] = np.where(need_r & ~b_mask & ~same_row_r, r_v, rgb[:, :, 0])

    # Blue at non-blue positions
    b_ch = rgb[:, :, 2].copy()
    b_h = (np.roll(b_ch, 1, axis=1) + np.roll(b_ch, -1, axis=1)) / 2
    b_v = (np.roll(b_ch, 1, axis=0) + np.roll(b_ch, -1, axis=0)) / 2
    b_d = (
        np.roll(np.roll(b_ch, 1, axis=0), 1, axis=1)
        + np.roll(np.roll(b_ch, 1, axis=0), -1, axis=1)
        + np.roll(np.roll(b_ch, -1, axis=0), 1, axis=1)
        + np.roll(np.roll(b_ch, -1, axis=0), -1, axis=1)
    ) / 4
    adjusted_b_row = (b_pos[0] + row_offset) % 2
    same_row_b = row_idx == adjusted_b_row
    need_b = ~b_mask
    rgb[:, :, 2] = np.where(need_b & r_mask, b_d, rgb[:, :, 2])
    rgb[:, :, 2] = np.where(need_b & ~r_mask & same_row_b, b_h, rgb[:, :, 2])
    rgb[:, :, 2] = np.where(need_b & ~r_mask & ~same_row_b, b_v, rgb[:, :, 2])

    # Green at red/blue positions
    g_ch = rgb[:, :, 1].copy()
    g_cross = (
        np.roll(g_ch, 1, axis=0)
        + np.roll(g_ch, -1, axis=0)
        + np.roll(g_ch, 1, axis=1)
        + np.roll(g_ch, -1, axis=1)
    ) / 4
    rgb[:, :, 1] = np.where(~g_mask, g_cross, rgb[:, :, 1])

    return rgb


def _matlab_compatible_raw_decode(file_bytes: bytes) -> np.ndarray:
    """
    Decode RAW (DNG, etc.) to float32 RGB using the same pipeline as the
    analyzer: black-level correction + bilinear demosaic. No WB, no gamma.
    """
    with rawpy.imread(io.BytesIO(file_bytes)) as raw:
        cfa = raw.raw_image_visible.astype(np.int32)
        height, width = cfa.shape
        black_levels = np.array(raw.black_level_per_channel, dtype=np.int32)
        pattern = raw.raw_pattern
        r_pos = tuple(np.argwhere(pattern == 0)[0])
        b_pos = tuple(np.argwhere(pattern == 2)[0])

        for i in range(2):
            for j in range(2):
                channel = pattern[i, j]
                cfa[i::2, j::2] -= black_levels[channel]
        cfa = np.maximum(0, cfa)

        rgb_float = _demosaic_strip(cfa.astype(np.float32), pattern, r_pos, b_pos, 0)
        return rgb_float


def _rawpy_fallback(file_bytes: bytes) -> np.ndarray:
    """Same params as analyze.py fallback: 16-bit linear, no WB, raw color."""
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
    return rgb  # already uint16


def dng_to_rgb(file_path: str) -> tuple[np.ndarray, bool]:
    """
    Load DNG (or RAW) and return RGB array (uint16, 0–65535) and whether
    the MATLAB-compatible path was used (True) or rawpy fallback (False).
    """
    with open(file_path, "rb") as f:
        file_bytes = f.read()

    try:
        rgb_float = _matlab_compatible_raw_decode(file_bytes)
        max_val = float(np.max(rgb_float))
        if max_val <= 0:
            max_val = 1.0
        scale = 65535.0 / max_val
        rgb16 = (rgb_float * scale).clip(0, 65535).astype(np.uint16)
        return rgb16, True
    except Exception:
        rgb16 = _rawpy_fallback(file_bytes)
        return rgb16, False


def write_16bit_png(path: str, rgb: np.ndarray) -> None:
    """Write (H, W, 3) uint16 RGB to a 16-bit PNG file."""
    try:
        import png
    except ImportError as e:
        raise RuntimeError(
            "Writing 16-bit PNG requires the pypng package. Install with: pip install pypng"
        ) from e

    height, width = rgb.shape[:2]
    # Use write_array with a single flat array so pypng slices rows itself (avoids
    # row-format issues that cause "Expected 4032 values but got 12096" with write()).
    pixels = rgb.ravel()
    with open(path, "wb") as f:
        w = png.Writer(width=width, height=height, bitdepth=16, planes=3)
        w.write_array(f, pixels)


# Extensions treated as RAW (same as analyze.py)
RAW_EXTENSIONS = (".dng", ".raw", ".cr2", ".nef", ".arw", ".rw2", ".orf", ".pef")


def convert_dng_to_png(dng_path: str, png_path: str | None = None) -> str:
    """
    Convert a DNG file to 16-bit PNG. Uses the same decode as the
    classifier/analyzer so chromaticity and mean RGB are preserved.

    Returns the path of the written PNG.
    """
    if not os.path.isfile(dng_path):
        raise FileNotFoundError(f"Not a file: {dng_path}")

    if png_path is None:
        base, _ = os.path.splitext(dng_path)
        png_path = base + ".png"

    rgb, used_matlab = dng_to_rgb(dng_path)
    write_16bit_png(png_path, rgb)
    method = "MATLAB-compatible decode" if used_matlab else "rawpy postprocess"
    print(f"Wrote 16-bit PNG: {png_path} ({rgb.shape[1]}x{rgb.shape[0]}, {method})")
    return png_path


def convert_folder_to_png(folder_path: str) -> list[str]:
    """
    Convert all DNG/RAW files in a folder to 16-bit PNG (same name, .png).
    Returns list of written PNG paths.
    """
    folder_path = os.path.expanduser(folder_path)
    if not os.path.isdir(folder_path):
        raise NotADirectoryError(f"Not a directory: {folder_path}")

    written = []
    for name in sorted(os.listdir(folder_path)):
        if name.startswith("."):
            continue
        base, ext = os.path.splitext(name)
        if ext.lower() not in RAW_EXTENSIONS:
            continue
        dng_path = os.path.join(folder_path, name)
        if not os.path.isfile(dng_path):
            continue
        png_path = os.path.join(folder_path, base + ".png")
        try:
            convert_dng_to_png(dng_path, png_path)
            written.append(png_path)
        except Exception as e:
            print(f"Skipped {name}: {e}", file=sys.stderr)
    return written


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python dng_to_png.py <input.dng | folder> [output.png]", file=sys.stderr)
        print("  File:  python dng_to_png.py image.dng [out.png]", file=sys.stderr)
        print("  Folder: python dng_to_png.py ~/Downloads/compiled_DNG_images_with_names", file=sys.stderr)
        sys.exit(1)

    path = os.path.expanduser(sys.argv[1])
    png_path = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        if os.path.isdir(path):
            written = convert_folder_to_png(path)
            print(f"Converted {len(written)} file(s).")
        else:
            convert_dng_to_png(path, png_path)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
