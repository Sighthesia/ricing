#!/usr/bin/env python3
"""Find a low-texture region for the lock-screen clock.

The window scan is adapted from end-4/dots-hyprland's least_busy_region.py:
https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/scripts/images/least_busy_region.py
This version keeps the scan dependency-light and returns normalized coordinates
plus the selected region luminance for Afloat's QML lock surface.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse


def _local_path(value: str) -> Path:
    parsed = urlparse(str(value))
    if parsed.scheme == "file":
        return Path(unquote(parsed.path))
    return Path(value).expanduser()


def _read_gray(path: Path, screen_width: int, screen_height: int,
               sample_width: int = 96, sample_height: int = 54) -> list[list[int]]:
    """Render the wallpaper with PreserveAspectCrop semantics and sample gray pixels."""
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        raise RuntimeError("ImageMagick is required for wallpaper analysis")
    if screen_width <= 0 or screen_height <= 0:
        raise ValueError("screen dimensions must be positive")

    screen = f"{screen_width}x{screen_height}"
    sample = f"{sample_width}x{sample_height}!"
    command = [
        tool, str(path), "-auto-orient", "-resize", screen + "^",
        "-gravity", "center", "-extent", screen, "-resize", sample,
        "-colorspace", "Gray", "-depth", "8", "gray:-",
    ]
    result = subprocess.run(command, capture_output=True, check=True)
    expected = sample_width * sample_height
    if len(result.stdout) < expected:
        raise RuntimeError("ImageMagick returned an incomplete grayscale image")
    return [
        list(result.stdout[row * sample_width:(row + 1) * sample_width])
        for row in range(sample_height)
    ]


def _integral(gray: list[list[int]]) -> tuple[list[list[float]], list[list[float]]]:
    height = len(gray)
    width = len(gray[0]) if height else 0
    sums = [[0.0] * (width + 1) for _ in range(height + 1)]
    squares = [[0.0] * (width + 1) for _ in range(height + 1)]
    for y, row in enumerate(gray, 1):
        row_sum = 0.0
        row_square = 0.0
        for x, value in enumerate(row, 1):
            row_sum += value
            row_square += value * value
            sums[y][x] = sums[y - 1][x] + row_sum
            squares[y][x] = squares[y - 1][x] + row_square
    return sums, squares


def _window_sum(table: list[list[float]], x: int, y: int, width: int, height: int) -> float:
    x2 = x + width
    y2 = y + height
    return table[y2][x2] - table[y][x2] - table[y2][x] + table[y][x]


def find_least_busy_region(
    gray: list[list[int]],
    region_width_ratio: float = 0.38,
    region_height_ratio: float = 0.24,
    margin_ratio: float = 0.06,
    stride: int = 2,
) -> dict[str, float]:
    """Return the normalized center and luminance of the lowest-variance window."""
    height = len(gray)
    width = len(gray[0]) if height else 0
    if width == 0 or height == 0 or any(len(row) != width for row in gray):
        raise ValueError("gray image must be a non-empty rectangular matrix")

    margin_x = max(0, min(int(width * margin_ratio), (width - 1) // 2))
    margin_y = max(0, min(int(height * margin_ratio), (height - 1) // 2))
    region_width = max(2, min(width - 2 * margin_x, round(width * region_width_ratio)))
    region_height = max(2, min(height - 2 * margin_y, round(height * region_height_ratio)))
    x_end = max(margin_x, width - margin_x - region_width)
    y_end = max(margin_y, height - margin_y - region_height)
    stride = max(1, int(stride))
    sums, squares = _integral(gray)
    area = region_width * region_height
    best: tuple[float, int, int, float] | None = None

    for y in range(margin_y, y_end + 1, stride):
        for x in range(margin_x, x_end + 1, stride):
            total = _window_sum(sums, x, y, region_width, region_height)
            square_total = _window_sum(squares, x, y, region_width, region_height)
            mean = total / area
            variance = max(0.0, square_total / area - mean * mean)
            candidate = (variance, y, x, mean)
            if best is None or candidate < best:
                best = candidate

    assert best is not None
    _, y, x, mean = best
    return {
        "center_x": (x + region_width / 2) / width,
        "center_y": (y + region_height / 2) / height,
        "luminance": mean / 255.0,
        "variance": best[0] / (255.0 * 255.0),
    }


def analyze(path: str, screen_width: int, screen_height: int) -> dict[str, float | bool]:
    gray = _read_gray(_local_path(path), screen_width, screen_height)
    result = find_least_busy_region(gray)
    result["ok"] = True
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True)
    parser.add_argument("--screen-width", required=True, type=int)
    parser.add_argument("--screen-height", required=True, type=int)
    args = parser.parse_args()
    try:
        print(json.dumps(analyze(args.image, args.screen_width, args.screen_height)))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"wallpaper clock analysis failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
