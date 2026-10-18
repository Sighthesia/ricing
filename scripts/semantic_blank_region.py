#!/usr/bin/env python3
"""Find "semantic blank" regions in an illustration so a clock can be placed there.

A semantic blank region is *not* a white/unpainted area: it is a stretch of the
picture that no character occupies -- ceiling, walls, floor, furniture -- and it
may well be full of the regular structure those things are made of (plank
seams, beams, lattice, tatami weave).  That is where an overlay (lock-screen
clock, launcher tile, watermark) reads cleanly, because nothing underneath
competes for attention.

Reading the picture
-------------------
Four kinds of measurement feed a per-pixel busyness map, each answering one way
a region can *fail* to be blank or can succeed by being background:

  ink      local density of line art (Sobel) plus fine texture (Laplacian), the
           strongest signal: a character cluster is dense with strokes, a
           ceiling panel is not
  colour   local chroma spread in Lab, because a crowd is many hues and a
           painted wall is one
  saliency spectral-residual saliency -- what stands out from the whole page
  lines    share of the local edges that belong to *long straight segments*
           (Hough).  This both forgives and rewards: a beam seam is ink, but it
           is man-made structure, so it is discounted inside `ink`, and the
           region it lives in earns a "regular pattern" bonus, which grows when
           an autocorrelation of the patch also finds repetition.

Busy pixels become the *character seeds*; the Euclidean distance to the nearest
seed is a depth map, and a window deep inside a blank area (the reference
ceiling sits ~120 px from any character ink) scores far above a window parked
inside a big flat hair or on a table top, which is exactly what a plain
"low variance wins" scan gets wrong.

A window is then scored by the mean blankness under it, plus the pattern bonus
and the depth bonus, minus the fraction of character-class pixels it covers and
minus any overlap with a keep-out box (a detected face, a hand-marked area).
Candidates are ranked, non-maximum suppressed, and written out as an overlay,
one crop per candidate and a JSON report.

Where the four local measurements are blind
-------------------------------------------
They are blind to one shape in particular: **hair**.  A large lock is smooth,
single-hued and usually deep inside the frame, so ink, texture, colour and
saliency all read it as background, and the distance-to-ink map only halves --
a strand drawn across it is thin, and the window still has several clear
centimetres around itself.  Measured on the reference illustration, the hair
window scores 0.88 against the ceiling's 1.04, and it belongs to a character.

So `--segment-model` takes an anime *character* segmentation graph (ISNet, as
exported by skytnt/anime-seg) and asks the question directly: this mask reads
100% character over the same hair window and 0.0% over the ceiling one.
OpenCV runs the ONNX itself, so nothing here needs onnxruntime, and the model is
optional -- `--segment-model auto` downloads and hash-checks it once, and
without it the script falls back to the local measurements alone (which is what
`--face-model`, kept for the same purpose, is a weaker version of).

The window scan itself (searching every position, and the idea of picking the
"least busy region" for a clock) follows end-4's least_busy_region.py in
dots-hyprland:
https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/scripts/images/least_busy_region.py
Everything else -- line-share forgiveness, character seeds, depth, periodicity --
is specific to this file.

Usage
-----
  scripts/semantic_blank_region.py --image artwork.jpg --outdir /tmp/blank
  scripts/semantic_blank_region.py --image artwork.jpg --clock 0.20x0.10 --top 3
  scripts/semantic_blank_region.py --image artwork.jpg --reference crop.png
  scripts/semantic_blank_region.py --image artwork.jpg --segment-model auto
  scripts/semantic_blank_region.py --image artwork.jpg --scales 0.10 0.14 0.18 0.24
  scripts/semantic_blank_region.py --image artwork.jpg --avoid 0.1,0.2,0.2,0.3

`--reference` takes a hand-picked crop of the same artwork -- the region a human
would choose.  It is located in the picture by multi-scale template matching and
every candidate is reported against it (coverage and IoU), which is how the
default weights in this file were chosen.  `--avoid` takes keep-out boxes from
whatever detector you trust; `--face-model` protects a character's calmest
feature (a face) and `--segment-model` the whole character.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

import cv2
import numpy as np

# ---------------------------------------------------------------- tuning ----
# Mix of the busyness terms.  On the reference illustration the chosen ceiling
# panel measures ink 0.17 against 0.62 for the crowd, so ink leads; chroma
# spread separates "one painted panel" from "twenty costumes" behind it.
BUSY_INK = 0.46
BUSY_TEXTURE = 0.20
BUSY_COLOUR = 0.24
BUSY_SALIENCY = 0.10
# Share of a pixel's busyness that long straight structure is allowed to excuse.
LINE_FORGIVENESS = 0.85
# Bonus for a window built from long straight, repeating structure.
PATTERN_BONUS = 0.12
# Bonus for being deep inside a blank area.  Depth is measured against `cap`
# pixels, `cap` being DEPTH_CAP_RATIO x the window's short side: at 0.90 the
# bonus keeps rising until the window is a whole radius clear of any character,
# which is what separates one blank ceiling panel from another.  A smaller cap
# saturates on the first open stretch of background and — measured on the
# reference artwork — left the term unable to tell the ceiling (89 px from any
# ink) from a hair window (43 px) at all.
DEPTH_BONUS = 0.18
DEPTH_CAP_RATIO = 0.90
# Character seeds: busy pixels above this quantile (floored, so a nearly blank
# page does not turn its few marks into a seed carpet).
SEED_QUANTILE = 0.70
SEED_FLOOR = 0.30
# Fraction of a window that character-class pixels may cover before it is
# disqualified; below that the coverage is charged linearly.  The limit is
# tight on purpose: 8% of a window covered by dense ink is already a character
# sleeve or a plate of food, and a 16% allowance let exactly that win.
BUSY_FRACTION_LIMIT = 0.06
BUSY_FRACTION_PENALTY = 2.5
# With a segmentation mask there is no need to infer "character" from texture,
# so it is held to a much tighter limit: one percent of a clock covered by a
# drawn character is already a clock sitting on someone.
CHARACTER_FRACTION_LIMIT = 0.01
CHARACTER_PIXEL = 0.5  # mask probability above which a pixel counts as character
KEEPOUT_PENALTY = 1.5
# Normalisation percentiles of the per-pixel maps.
INK_PCTL = 95.0
COLOUR_PCTL = 95.0
SALIENCY_PCTL = 95.0

# Optional model files, both free-standing onnx that OpenCV loads itself.
# `auto` in --segment-model / --face-model downloads the file into --model-dir,
# checks it against the published size and digest, and reuses it afterwards.
MODELS = {
    "anime-seg": {
        "file": "isnetis.onnx",
        "repo": "skytnt/anime-seg",
        "size": 176069933,
        "sha256": "f15622d853e8260172812b657053460e20806f04b9e05147d49af7bed31a6e99",
        "about": "anime character segmentation (ISNet)",
    },
    "yunet": {
        "file": "face_detection_yunet_2023mar.onnx",
        "repo": "opencv/face_detection_yunet",
        "size": 232589,
        "sha256": "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
        "about": "face detection (YuNet)",
    },
}
MIRRORS = ("https://huggingface.co", "https://hf-mirror.com")
DEFAULT_MODEL_DIR = "~/.cache/afloat/models"


def _odd(value: int) -> int:
    value = int(value)
    return value if value % 2 else value + 1


def _spread(src: np.ndarray, size: int) -> np.ndarray:
    """Mean filter with a square kernel, borders reflected."""
    return cv2.boxFilter(src, -1, (size, size), normalize=True,
                         borderType=cv2.BORDER_REFLECT)


def _scaled(src: np.ndarray, percentile: float) -> np.ndarray:
    """Scale a non-negative map so `percentile` maps to 1.0, clipped to [0,1]."""
    scale = float(np.percentile(src, percentile))
    if scale <= 0:
        return np.zeros_like(src, dtype=np.float32)
    return np.clip(src / scale, 0.0, 1.0).astype(np.float32)


def load_image(path: Path, work_width: int) -> tuple[np.ndarray, float]:
    """Load as RGB float [0,1], downscaled so the long side is `work_width`."""
    raw = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if raw is None:
        raise RuntimeError(f"cannot read image: {path}")
    rgb = cv2.cvtColor(raw, cv2.COLOR_BGR2RGB)
    height, width = rgb.shape[:2]
    scale = work_width / float(max(width, height))
    if scale < 1.0:
        rgb = cv2.resize(rgb, (max(1, round(width * scale)), max(1, round(height * scale))),
                         interpolation=cv2.INTER_AREA)
    return rgb.astype(np.float32) / 255.0, scale


def line_share(img8: np.ndarray) -> np.ndarray:
    """Per-pixel share of edge pixels that belong to a long straight segment.

    A ceiling seam or a lattice bar is nearly all of the local edge energy and
    scores near 1; a lock of hair or a pile of food has plenty of edges but
    almost none of them straight, and scores near 0.
    """
    height, width = img8.shape[:2]
    edges = cv2.Canny(img8, 50, 150)
    minimum = max(8, int(0.03 * max(width, height)))
    segments = cv2.HoughLinesP(edges, 1, np.pi / 180.0, threshold=20,
                               minLineLength=minimum, maxLineGap=3)
    line_mask = np.zeros((height, width), np.uint8)
    if segments is not None:
        segments = np.asarray(segments).reshape(-1, 4)  # (N,1,4) below OpenCV 5
        for x1, y1, x2, y2 in segments:
            cv2.line(line_mask, (int(x1), int(y1)), (int(x2), int(y2)), 255, 3)
    support = _odd(round(0.010 * max(width, height)))
    straight = _spread((line_mask > 0).astype(np.float32), support)
    edges_dense = _spread((edges > 0).astype(np.float32), support)
    return np.clip(straight / (edges_dense + 0.02), 0.0, 1.0).astype(np.float32)


def periodicity_map(img: np.ndarray, win: tuple[int, int], stride: int = 48,
                    min_lag: int = 10, max_lag: int = 110) -> np.ndarray:
    """How strongly a window of `win` repeats itself, sampled on a coarse grid.

    The normalised autocorrelation of the (Hann-windowed) patch is taken, the
    peak outside a small central exclusion disc is kept, and the sparse grid is
    grown back to full resolution.  Regular background -- plank seams, lattice,
    tatami -- peaks; painted characters do not.
    """
    height, width = img.shape[:2]
    w, h = min(win[0], width), min(win[1], height)
    taper = cv2.createHanningWindow((w, h), cv2.CV_32F)
    grid_y = sorted(set(list(range(0, max(1, height - h), stride)) + [height - h]))
    grid_x = sorted(set(list(range(0, max(1, width - w), stride)) + [width - w]))
    small = np.zeros((height // stride + 1, width // stride + 1), np.float32)
    for y in grid_y:
        for x in grid_x:
            patch = img[y:y + h, x:x + w]
            gray = cv2.cvtColor((patch * 255.0).astype(np.uint8), cv2.COLOR_RGB2GRAY)
            gray = (gray.astype(np.float32) - float(gray.mean())) * taper
            spectrum = np.fft.rfft2(gray)
            auto = np.fft.irfft2(spectrum * np.conj(spectrum), s=gray.shape)
            energy = float(auto[0, 0])
            if energy <= 0:
                continue
            auto = np.fft.fftshift(auto) / energy
            cy, cx = np.array(auto.shape) // 2
            ly, lx = min(max_lag, cy - 1), min(max_lag, cx - 1)
            patch_ac = auto[cy - ly:cy + ly + 1, cx - lx:cx + lx + 1]
            dy, dx = np.mgrid[-ly:ly + 1, -lx:lx + 1]
            outside = (np.abs(dy) >= min_lag) | (np.abs(dx) >= min_lag)
            peak = float(patch_ac[outside].max()) if outside.any() else 0.0
            small[y // stride, x // stride] = max(0.0, peak)
    grown = cv2.resize(small, (width, height), interpolation=cv2.INTER_CUBIC)
    return cv2.GaussianBlur(grown, (0, 0), stride / 3.0)


def base_maps(img: np.ndarray) -> dict[str, np.ndarray]:
    """Per-pixel maps that do not depend on the size of the clock window."""
    height, width = img.shape[:2]
    img8 = (np.clip(img, 0.0, 1.0) * 255.0).astype(np.uint8)
    gray = cv2.cvtColor(img8, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    support = _odd(round(0.010 * max(width, height)))  # ~1% of the page

    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    ink = _spread(np.sqrt(gx * gx + gy * gy), support)
    texture = _spread(np.abs(cv2.Laplacian(gray, cv2.CV_32F, ksize=3)), support)

    lab = cv2.cvtColor(img8, cv2.COLOR_RGB2LAB).astype(np.float32)
    a_ch, b_ch = lab[:, :, 1], lab[:, :, 2]
    mean_a, mean_b = _spread(a_ch, support), _spread(b_ch, support)
    var_a = np.maximum(_spread(a_ch * a_ch, support) - mean_a * mean_a, 0.0)
    var_b = np.maximum(_spread(b_ch * b_ch, support) - mean_b * mean_b, 0.0)
    colour = np.sqrt(var_a + var_b)

    small = cv2.resize(gray, (64, 64), interpolation=cv2.INTER_AREA)
    spectrum = np.fft.fft2(small)
    log_amp = np.log(np.abs(spectrum) + 1e-6).astype(np.float32)
    residual = log_amp - cv2.GaussianBlur(log_amp, (0, 0), 3.0)
    sal = np.abs(np.fft.ifft2(np.exp(residual + 1j * np.angle(spectrum)))) ** 2
    sal = cv2.GaussianBlur(sal.astype(np.float32), (0, 0), 4.0)
    saliency = cv2.resize(sal, (width, height), interpolation=cv2.INTER_LINEAR)
    saliency = saliency / (float(saliency.max()) + 1e-9)

    return {
        "luma": gray,
        "ink": _scaled(ink, INK_PCTL),
        "texture": _scaled(texture, INK_PCTL),
        "colour": _scaled(colour, COLOUR_PCTL),
        "saliency": _scaled(saliency, SALIENCY_PCTL),
        "lines": line_share(img8),
    }


def feature_maps(img: np.ndarray, win: tuple[int, int], base: dict | None = None,
                 pattern_stride: int = 48) -> dict[str, np.ndarray]:
    """Busyness inputs plus the regular-structure map, at the requested window size.

    `base` lets a caller that sweeps several clock sizes pay for the per-pixel
    maps once; only the periodicity has to be recomputed per size, because the
    window it looks for repetition over is the clock itself.
    """
    maps = dict(base) if base is not None else base_maps(img)
    repeat = np.clip(periodicity_map(img, win, stride=pattern_stride), 0.0, 1.0)
    # Regular structure = straight edges that also repeat.
    maps["repeat"] = repeat
    maps["pattern"] = np.clip(maps["lines"] * (0.5 + 0.5 * repeat), 0.0, 1.0).astype(np.float32)
    return maps


def busyness(maps: dict[str, np.ndarray]) -> np.ndarray:
    """Per-pixel 0..1 'something is drawn here', with straight structure excused.

    With a segmentation mask the character probability joins the local terms
    before the seeds are taken, so a character counts as drawn no matter how
    flat the drawing of it is -- see "Where the four local measurements are
    blind" in the module docstring.
    """
    busy = (BUSY_INK * maps["ink"] + BUSY_TEXTURE * maps["texture"]
            + BUSY_COLOUR * maps["colour"] + BUSY_SALIENCY * maps["saliency"])
    forgiving = 1.0 - LINE_FORGIVENESS * maps["pattern"]
    busy = np.clip(busy * forgiving, 0.0, 1.0)
    character = maps.get("character")
    if character is not None:
        busy = np.maximum(busy, character)
    return busy.astype(np.float32)


def character_depth(busy: np.ndarray, cap: float) -> np.ndarray:
    """Distance to the nearest character-class pixel, scaled to [0,1] by `cap`."""
    threshold = max(SEED_FLOOR, float(np.quantile(busy, SEED_QUANTILE)))
    seeds = (busy > threshold).astype(np.uint8)
    dist = cv2.distanceTransform(1 - seeds, cv2.DIST_L2, 5)
    return np.clip(dist / max(cap, 1e-6), 0.0, 1.0).astype(np.float32)


class CharacterSegmenter:
    """Anime character segmentation, run by OpenCV's own ONNX importer.

    The graph is fixed-size (1024x1024 in the published export), so the input
    size is read out of OpenCV's own network dump rather than hard-coded, and
    only the graph's declared input/output names are used to feed a page and
    read the mask back.  Nothing here needs onnxruntime.
    """

    def __init__(self, model_path: Path):
        if not model_path.exists():
            raise RuntimeError(f"segmentation model not found: {model_path}")
        try:
            self.net = cv2.dnn.readNetFromONNX(str(model_path))
            graph = self.net.dump()
        except cv2.error as error:
            raise RuntimeError(f"cannot load {model_path.name}: {error}") from error
        self.input, self.output, self.size = self._graph_io(graph)
        if self.size[0] < 32 or self.size[1] < 32:
            raise RuntimeError(f"{model_path.name}: unusable input size {self.size}")

    @staticmethod
    def _graph_io(graph: str) -> tuple[str, str, tuple[int, int]]:
        """Input name, output name and (width, height) from OpenCV's graph dump."""
        shape = r'\[\s*(\d+)\s*x\s*(\d+)\s*x\s*(\d+)\s*x\s*(\d+)\s*\]'
        name = r'\s*"([^"]+)"\s*//[^\[]*'
        inputs = re.search(r"inputs:\s*\[\s*" + name + shape, graph)
        outputs = re.search(r"outputs:\s*\[\s*" + name + shape, graph)
        if inputs is None or outputs is None:
            return "", "", (1024, 1024)  # a dynamic graph: the usual training size
        channels, height, width = inputs.groups()[2:]  # name, batch, then the page
        if int(channels) != 3:
            raise RuntimeError(f"expected a 3-channel input, graph takes {channels}")
        return inputs.group(1), outputs.group(1), (int(width), int(height))

    def mask(self, img: np.ndarray) -> np.ndarray:
        """Per-pixel probability that a drawn character is here, page-sized."""
        height, width = img.shape[:2]
        size = self.size
        shrink = size[0] < width or size[1] < height
        bgr = cv2.cvtColor((np.clip(img, 0.0, 1.0) * 255.0).astype(np.uint8),
                           cv2.COLOR_RGB2BGR)
        probe = cv2.resize(bgr, size, interpolation=cv2.INTER_AREA if shrink
                           else cv2.INTER_CUBIC)
        blob = cv2.dnn.blobFromImage(probe, 1.0 / 255.0, size, (0.5, 0.5, 0.5),
                                     swapRB=True, crop=False)
        if self.input:
            self.net.setInput(blob, self.input)
        else:
            self.net.setInput(blob)
        out = self.net.forward(self.output) if self.output else self.net.forward()
        if isinstance(out, (list, tuple)):
            out = out[0]
        out = np.asarray(out, np.float32)
        while out.ndim > 2:  # drop batch and channel axes
            out = out[0]
        mask = cv2.resize(out, (width, height), interpolation=cv2.INTER_LINEAR)
        return np.clip(mask, 0.0, 1.0).astype(np.float32)


def _download(url: str, part: Path) -> None:
    """Fetch `url` into `part`, by curl when it is installed, urllib otherwise.

    Some mirror edges refuse a bare Python TLS client with "Unknown Client"
    while answering curl normally, and this file is 176 MB when it is the
    segmentation model -- worth the less pretty path.
    """
    part.unlink(missing_ok=True)
    curl = shutil.which("curl")
    if curl:
        done = subprocess.run([curl, "-fsSL", "--retry", "2", "-o", str(part), url],
                              capture_output=True, text=True)
        if done.returncode != 0:
            raise OSError(done.stderr.strip() or f"curl exited with {done.returncode}")
        return
    with urllib.request.urlopen(url, timeout=60) as response, open(part, "wb") as sink:
        shutil.copyfileobj(response, sink, 1 << 20)


def fetch_model(key: str, directory: Path) -> Path:
    """Download one of MODELS into `directory`, checked by size and digest.

    huggingface.co is tried first and hf-mirror.com second, because the mirror
    is the only one of the two that answers from some networks.  The file lands
    as `.part` and is renamed only once it matches, so an interrupted download
    can never be mistaken for a working model.
    """
    spec = MODELS[key]
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / spec["file"]
    if target.exists() and target.stat().st_size == spec["size"]:
        return target
    part = target.with_suffix(target.suffix + ".part")
    failures = []
    for mirror in MIRRORS:
        url = f"{mirror}/{spec['repo']}/resolve/main/{spec['file']}"
        print(f"fetching {spec['about']} ({spec['size'] / 1e6:.1f} MB) from {mirror} ...",
              file=sys.stderr)
        try:
            _download(url, part)
        except (OSError, urllib.error.URLError) as error:
            failures.append(f"{mirror}: {error}")
            continue
        digest = hashlib.sha256()
        with open(part, "rb") as sink:
            while chunk := sink.read(1 << 20):
                digest.update(chunk)
        if digest.hexdigest() != spec["sha256"]:
            failures.append(f"{mirror}: digest mismatch ({digest.hexdigest()[:12]}...)")
            continue
        part.replace(target)
        return target
    part.unlink(missing_ok=True)
    raise RuntimeError(
        f"could not fetch {spec['file']} (" + "; ".join(failures) + ").  Download it by "
        f"hand and pass the path instead, e.g.\n"
        f"  curl -fL -o {target} {MIRRORS[-1]}/{spec['repo']}/resolve/main/{spec['file']}")


def resolve_model(value: str, key: str, directory: Path) -> Path:
    """A model path: the one given, or the cached copy `auto` fetches."""
    if value != "auto":
        return Path(value).expanduser()
    path = directory / MODELS[key]["file"]
    if path.exists() and path.stat().st_size == MODELS[key]["size"]:
        return path
    return fetch_model(key, directory)


def detect_faces(img: np.ndarray, model_path: Path) -> np.ndarray:
    """Face boxes as a 0/1 mask, using OpenCV's YuNet detector.

    YuNet ships with OpenCV 4.5.4+/5.x as `cv2.FaceDetectorYN` but the model
    itself has to be supplied: face_detection_yunet_2023mar.onnx from
    https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet
    It wants BGR, and it misses the small faces of a crowd at working
    resolution, so detection runs on a 2000px copy and the boxes are scaled back.
    """
    height, width = img.shape[:2]
    mask = np.zeros((height, width), np.float32)
    if not hasattr(cv2, "FaceDetectorYN"):
        raise RuntimeError("this OpenCV build has no FaceDetectorYN; "
                           "use --avoid with boxes from your own detector")
    if not model_path.exists():
        raise RuntimeError(f"face model not found: {model_path}")

    scale = 2000.0 / max(width, height)
    probe = img if 0.9 <= scale <= 1.1 else cv2.resize(
        img, (max(1, round(width * scale)), max(1, round(height * scale))),
        interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC)
    probe_h, probe_w = probe.shape[:2]
    detector = cv2.FaceDetectorYN.create(str(model_path), "", (probe_w, probe_h),
                                         score_threshold=0.5)
    bgr = cv2.cvtColor((np.clip(probe, 0.0, 1.0) * 255.0).astype(np.uint8),
                       cv2.COLOR_RGB2BGR)
    _, faces = detector.detect(bgr)
    grow = max(2, int(0.004 * max(width, height)))
    for face in (faces if faces is not None else []):
        x, y, w, h = (float(v) / scale for v in face[:4])
        x0, y0 = int(max(0, x - grow)), int(max(0, y - grow))
        x1, y1 = int(min(width, x + w + grow)), int(min(height, y + h + grow))
        mask[y0:y1, x0:x1] = 1.0
    return mask


def keepout_mask(img: np.ndarray, boxes: list[list[float]]) -> np.ndarray:
    """0/1 mask from normalized [x, y, w, h] boxes the caller wants kept clear."""
    height, width = img.shape[:2]
    mask = np.zeros((height, width), np.float32)
    for x, y, w, h in boxes:
        x0, y0 = max(0, int(x * width)), max(0, int(y * height))
        x1, y1 = min(width, int((x + w) * width)), min(height, int((y + h) * height))
        if x1 > x0 and y1 > y0:
            mask[y0:y1, x0:x1] = 1.0
    return mask


def window_mean(src: np.ndarray, w: int, h: int) -> np.ndarray:
    """Mean of `src` under a w x h window whose TOP-LEFT corner sits at (y, x).

    Summed-area table, so the value at (y, x) is exactly
    `src[y:y+h, x:x+w].mean()` and nowhere the arithmetic can drift by half a
    window.  Positions where a full window does not fit are NaN, which is also
    what keeps a candidate from hanging off the page.
    """
    height, width = src.shape[:2]
    sat = cv2.integral(src.astype(np.float64, copy=False), sdepth=cv2.CV_64F)
    sums = (sat[h:, w:] - sat[:-h, w:] - sat[h:, :-w] + sat[:-h, :-w])
    out = np.full((height, width), np.nan, np.float32)
    out[:height - h + 1, :width - w + 1] = (sums / float(w * h)).astype(np.float32)
    return out


def score_windows(maps: dict[str, np.ndarray], busy: np.ndarray, win: tuple[int, int],
                  margin: float) -> dict[str, np.ndarray]:
    """Score every window position: blankness plus structure, minus characters.

    Returns the raw score (defined wherever a window fits inside the margins) and
    the subset of positions that also pass the busy-pixel, character and keep-out
    limits.
    """
    height, width = busy.shape[:2]
    w, h = max(4, min(win[0], width - 2)), max(4, min(win[1], height - 2))
    depth = character_depth(busy, DEPTH_CAP_RATIO * min(w, h))
    keepout = maps.get("keepout", np.zeros((height, width), np.float32))

    mean_blank = window_mean(1.0 - busy, w, h)
    mean_pattern = window_mean(maps["pattern"], w, h)
    mean_depth = window_mean(depth, w, h)
    busy_px = (busy > max(SEED_FLOOR, float(np.quantile(busy, SEED_QUANTILE)))).astype(np.float32)
    busy_frac = window_mean(busy_px, w, h)
    keepout_frac = window_mean(keepout, w, h)

    # The mask is counted separately from the busy pixels: "there is ink here"
    # and "there is a character here" are different claims, and a window sitting
    # on a character is disqualified well below the detail limit.
    character = maps.get("character")
    if character is None:
        character_frac = np.zeros((height, width), np.float32)
        character_ok = np.ones((height, width), bool)
    else:
        character_frac = window_mean((character > CHARACTER_PIXEL).astype(np.float32), w, h)
        character_ok = character_frac <= CHARACTER_FRACTION_LIMIT

    raw = (mean_blank + PATTERN_BONUS * mean_pattern + DEPTH_BONUS * mean_depth
           - BUSY_FRACTION_PENALTY * busy_frac - KEEPOUT_PENALTY * keepout_frac)

    mx, my = int(width * margin), int(height * margin)
    inside = np.isfinite(mean_blank)  # a full window fits inside the page
    valid = np.zeros((height, width), bool)
    valid[my:max(my + 1, height - my - h + 1), mx:max(mx + 1, width - mx - w + 1)] = True
    valid &= inside
    fits = np.where(valid, raw, np.nan)
    qualified = (valid & (busy_frac <= BUSY_FRACTION_LIMIT) & character_ok
                 & (keepout_frac <= 0.0))
    return {"score": np.where(qualified, raw, np.nan), "raw": fits, "qualified": qualified,
            "blank": mean_blank, "pattern": mean_pattern, "depth": mean_depth,
            "busy_frac": busy_frac, "keepout_frac": keepout_frac, "busy": busy,
            "character_frac": character_frac, "has_character": character is not None,
            "window": np.array([w, h])}


def summarise(x: int, y: int, fields: dict[str, np.ndarray],
              maps: dict[str, np.ndarray]) -> dict:
    """Per-window measurements, so a choice can be argued about instead of trusted."""
    w, h = (int(v) for v in fields["window"])
    height, width = maps["ink"].shape[:2]
    sl = (slice(y, y + h), slice(x, x + w))
    # The ranking field is NaN wherever a window was disqualified; the raw score
    # is the same number there, and reporting it keeps the JSON finite.
    entry = {
        "box_px": [int(x), int(y), int(w), int(h)],
        "centre_norm": [round((x + w / 2) / width, 4), round((y + h / 2) / height, 4)],
        "box_norm": [round(x / width, 4), round(y / height, 4),
                     round(w / width, 4), round(h / height, 4)],
        "score": round(float(fields["raw"][y, x]), 4),
        "blank_mean": round(1.0 - float(fields["busy"][sl].mean()), 4),
        "pattern_mean": round(float(maps["pattern"][sl].mean()), 4),
        "repeat_mean": round(float(maps["repeat"][sl].mean()), 4),
        "depth_mean": round(float(fields["depth"][y, x]), 4),
        "ink_mean": round(float(maps["ink"][sl].mean()), 4),
        "colour_mean": round(float(maps["colour"][sl].mean()), 4),
        "saliency_mean": round(float(maps["saliency"][sl].mean()), 4),
        "luminance": round(float(maps["luma"][sl].mean()), 4),
        "busy_pixels": round(float(fields["busy_frac"][y, x]), 4),
        "busy_peak": round(float(fields["busy"][sl].max()), 4),
        "keepout_pixels": round(float(fields["keepout_frac"][y, x]), 4),
    }
    if fields["has_character"]:
        entry["character_mean"] = round(float(maps["character"][sl].mean()), 4)
        entry["character_pixels"] = round(float(fields["character_frac"][y, x]), 4)
    return entry


def find_candidates(maps: dict[str, np.ndarray], win: tuple[int, int], top: int,
                    margin: float) -> tuple[dict[str, np.ndarray], list[dict]]:
    """Rank the window grid and return the best, non-overlapping candidates.

    Windows that fail the busy-pixel or keep-out limits are skipped; if fewer than
    `top` of those exist, the best remaining windows are added with
    `qualified: false`, because "nothing here is really clean" is an answer the
    caller needs to see rather than an empty list.
    """
    busy = busyness(maps)
    fields = score_windows(maps, busy, win, margin)
    height, width = fields["score"].shape
    w, h = (int(v) for v in fields["window"])

    candidates: list[dict] = []
    suppressed = np.zeros((height, width), bool)
    for pass_qualified in (True, False):
        field = fields["score"] if pass_qualified else fields["raw"]
        while len(candidates) < top:
            masked = np.where(suppressed, np.nan, field)
            if not np.any(np.isfinite(masked)):
                break
            y, x = np.unravel_index(int(np.nanargmax(masked)), masked.shape)
            entry = summarise(int(x), int(y), fields, maps)
            entry["qualified"] = bool(fields["qualified"][y, x])
            candidates.append(entry)
            # Keep the next pick at least half a clock away on either axis.
            x0, x1 = max(0, x - w // 2), min(width, x + w // 2 + w)
            y0, y1 = max(0, y - h // 2), min(height, y + h // 2 + h)
            suppressed[y0:y1, x0:x1] = True
    return fields, candidates


def find_reference_box(img: np.ndarray, reference: np.ndarray) -> dict:
    """Locate a hand-picked crop inside the artwork by multi-scale template match."""
    scene8 = (np.clip(img, 0.0, 1.0) * 255.0).astype(np.uint8)
    scene = cv2.cvtColor(scene8, cv2.COLOR_RGB2GRAY).astype(np.float32)
    ref8 = (np.clip(reference, 0.0, 1.0) * 255.0).astype(np.uint8)
    ref = cv2.cvtColor(ref8, cv2.COLOR_RGB2GRAY).astype(np.float32)
    # A hand crop often comes from another render or an upscale, where flat
    # colour has drifted but edges have not, so match on a band-pass copy.
    band = lambda src: src - cv2.GaussianBlur(src, (0, 0), 2.5)
    scene_hp, ref_hp = band(scene), band(ref)

    height, width = scene.shape
    best = None
    for scale in np.arange(0.35, 2.55, 0.02):
        tpl = cv2.resize(ref_hp, None, fx=scale, fy=scale,
                         interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC)
        if tpl.shape[0] >= height or tpl.shape[1] >= width or min(tpl.shape) < 12:
            continue
        result = cv2.matchTemplate(scene_hp, tpl, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(result)
        if best is None or max_val > best["match"]:
            best = {"match": float(max_val), "scale": float(scale),
                    "box_px": [int(max_loc[0]), int(max_loc[1]), tpl.shape[1], tpl.shape[0]]}
    if best is None:
        raise RuntimeError("reference crop does not fit inside the artwork")
    x, y, w, h = best["box_px"]
    best["box_norm"] = [round(x / width, 4), round(y / height, 4),
                        round(w / width, 4), round(h / height, 4)]
    best["centre_norm"] = [round((x + w / 2) / width, 4), round((y + h / 2) / height, 4)]
    best["match"] = round(best["match"], 4)
    best["scale"] = round(best["scale"], 3)
    return best


def iou(a: list[float], b: list[float]) -> float:
    """Intersection over union of two [x, y, w, h] boxes in the same units."""
    ax0, ay0, ax1, ay1 = a[0], a[1], a[0] + a[2], a[1] + a[3]
    bx0, by0, bx1, by1 = b[0], b[1], b[0] + b[2], b[1] + b[3]
    inter = max(0.0, min(ax1, bx1) - max(ax0, bx0)) * max(0.0, min(ay1, by1) - max(ay0, by0))
    union = a[2] * a[3] + b[2] * b[3] - inter
    return inter / union if union > 0 else 0.0


def coverage(a: list[float], b: list[float]) -> float:
    """Share of box `b` that box `a` covers -- 'did we land in the same area'.

    IoU punishes a placement that sits next to the hand-picked region but not on
    top of it, which is a normal outcome for a large blank area; coverage of the
    reference answers the question actually being asked.
    """
    ax0, ay0, ax1, ay1 = a[0], a[1], a[0] + a[2], a[1] + a[3]
    bx0, by0, bx1, by1 = b[0], b[1], b[0] + b[2], b[1] + b[3]
    inter = max(0.0, min(ax1, bx1) - max(ax0, bx0)) * max(0.0, min(ay1, by1) - max(ay0, by0))
    area = b[2] * b[3]
    return inter / area if area > 0 else 0.0


def render_overlay(img: np.ndarray, fields: dict[str, np.ndarray], candidates: list[dict],
                   reference: dict | None, path: Path,
                   character: np.ndarray | None = None) -> None:
    """Write the illustration with the blankness heat map and the chosen boxes.

    The heat map uses the raw score, so it stays continuous where windows were
    disqualified; those positions are dimmed instead, which keeps "this area is
    calm but not clear of characters" legible at a glance.  With a segmentation
    mask the character silhouette is traced as well, so a rejected window can be
    explained by the drawing itself rather than by the numbers.
    """
    base = (np.clip(img, 0.0, 1.0) * 255.0).astype(np.uint8)
    raw = fields["raw"]
    finite = np.isfinite(raw)
    # Percentiles, not the extremes: one character-covered window can be a whole
    # point below every other, and stretching the ramp to it flattens the range
    # the eye actually needs to compare.
    if finite.any():
        low, high = (float(v) for v in np.percentile(raw[finite], (2, 98)))
    else:
        low, high = 0.0, 1.0
    heat = np.where(finite, (raw - low) / (high - low + 1e-6), low)
    colour = cv2.applyColorMap((heat * 255).astype(np.uint8), cv2.COLORMAP_TURBO)
    blended = cv2.addWeighted(cv2.cvtColor(base, cv2.COLOR_RGB2BGR), 0.45, colour, 0.55, 0)
    outside = ~finite | ~fields["qualified"]
    blended[outside] = (blended[outside] * 0.70).astype(np.uint8)
    if character is not None:
        silhouette = (character > CHARACTER_PIXEL).astype(np.uint8) * 255
        contours, _ = cv2.findContours(silhouette, cv2.RETR_EXTERNAL,
                                       cv2.CHAIN_APPROX_SIMPLE)
        cv2.drawContours(blended, contours, -1, (160, 110, 80), 1)
    for index, candidate in enumerate(candidates):
        x, y, w, h = candidate["box_px"]
        tint = (0, 255, 0) if candidate["qualified"] else (140, 140, 140)
        tint = (0, 200, 255) if index > 0 and candidate["qualified"] else tint
        cv2.rectangle(blended, (x, y), (x + w, y + h), tint, 3)
        label = f"#{index + 1} {candidate['score']:.3f}" + ("" if candidate["qualified"] else " !")
        cv2.putText(blended, label, (x + 6, y + 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, tint, 2)
    if reference is not None:
        x, y, w, h = reference["box_px"]
        cv2.rectangle(blended, (x, y), (x + w, y + h), (255, 80, 255), 2)
        cv2.putText(blended, f"reference {reference['match']:.2f}",
                    (x + 6, max(20, y - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 80, 255), 2)
    cv2.imwrite(str(path), blended)


def write_crop(img: np.ndarray, box: list[int], path: Path, width: int = 720) -> None:
    x, y, w, h = box
    patch = img[y:y + h, x:x + w]
    if patch.size == 0:
        return
    patch = cv2.resize(patch, (width, max(1, round(patch.shape[0] * width / patch.shape[1]))),
                       interpolation=cv2.INTER_AREA)
    cv2.imwrite(str(path), cv2.cvtColor((np.clip(patch, 0, 1) * 255).astype(np.uint8),
                                        cv2.COLOR_RGB2BGR))


def parse_clock(value: str) -> tuple[float, float]:
    """`0.18` or `0.18x0.10` -- window size as a fraction of page width/height."""
    parts = value.lower().replace("x", " ").split()
    if len(parts) == 1:
        return float(parts[0]), float(parts[0])
    if len(parts) == 2:
        return float(parts[0]), float(parts[1])
    raise argparse.ArgumentTypeError("clock size must be WIDTH or WIDTHxHEIGHT")


def parse_box(value: str) -> list[float]:
    """`x,y,w,h` in normalized page coordinates."""
    try:
        x, y, w, h = (float(part) for part in value.replace(" ", "").split(","))
    except ValueError:
        raise argparse.ArgumentTypeError("box must be X,Y,W,H in 0..1") from None
    return [x, y, w, h]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--image", required=True, help="illustration to analyse")
    parser.add_argument("--outdir", default="blank-region-out", help="where to write reports")
    parser.add_argument("--clock", type=parse_clock, default=(0.18, 0.18),
                        help="clock window as WIDTH or WIDTHxHEIGHT of the page (default 0.18x0.18)")
    parser.add_argument("--clock-px", type=int, default=None,
                        help="instead of --clock, give the window width in pixels")
    parser.add_argument("--top", type=int, default=5, help="how many candidates to report")
    parser.add_argument("--margin", type=float, default=0.02,
                        help="keep the window this far from the page edge (default 0.02)")
    parser.add_argument("--work-width", type=int, default=1400,
                        help="long side of the analysis copy (default 1400)")
    parser.add_argument("--reference", default=None,
                        help="hand-picked crop of the same artwork to check against")
    parser.add_argument("--avoid", action="append", type=parse_box, default=None,
                        metavar="X,Y,W,H",
                        help="normalized box to keep clear (faces, a title, a logo); repeatable")
    parser.add_argument("--segment-model", default=None, metavar="PATH",
                        help="anime character segmentation onnx (isnetis.onnx) so a "
                             "character is never mistaken for background; 'auto' fetches it")
    parser.add_argument("--face-model", default=None, metavar="PATH",
                        help="YuNet onnx (face_detection_yunet_2023mar.onnx) to "
                             "auto-detect faces; 'auto' fetches it")
    parser.add_argument("--model-dir", default=DEFAULT_MODEL_DIR,
                        help=f"where 'auto' keeps models (default {DEFAULT_MODEL_DIR})")
    parser.add_argument("--scales", type=float, nargs="*", default=None,
                        help="also report the best window per clock width, e.g. 0.10 0.16 0.22")
    args = parser.parse_args()

    image_path = Path(args.image).expanduser()
    outdir = Path(args.outdir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)

    img, _ = load_image(image_path, args.work_width)
    height, width = img.shape[:2]

    if args.clock_px:
        win = (args.clock_px, args.clock_px)
    else:
        win = (max(8, round(args.clock[0] * width)), max(8, round(args.clock[1] * height)))

    base = base_maps(img)
    model_dir = Path(args.model_dir).expanduser()
    character = None
    if args.segment_model:
        segmenter = CharacterSegmenter(resolve_model(args.segment_model, "anime-seg", model_dir))
        character = segmenter.mask(img)
    keepout = None
    if args.face_model:
        keepout = detect_faces(img, resolve_model(args.face_model, "yunet", model_dir))
    if args.avoid:
        extra = keepout_mask(img, args.avoid)
        keepout = extra if keepout is None else np.maximum(keepout, extra)
    maps = feature_maps(img, win, base)
    if keepout is not None:
        maps["keepout"] = keepout
    if character is not None:
        maps["character"] = character

    fields, candidates = find_candidates(maps, win, args.top, args.margin)
    report: dict = {
        "image": str(image_path),
        "work_size": [width, height],
        "clock_box": [int(v) for v in fields["window"]],
        "clock_norm": [round(fields["window"][0] / width, 4),
                       round(fields["window"][1] / height, 4)],
        "character_mask": character is not None,
        "candidates": candidates,
    }
    if candidates:
        # Drop-in placement for a clock overlay: where to centre it, and the
        # region luminance a theme can pick a text colour from.
        best = candidates[0]
        report["placement"] = {
            "centre_norm": best["centre_norm"],
            "box_norm": best["box_norm"],
            "luminance": best["luminance"],
            "score": best["score"],
            "qualified": best["qualified"],
        }

    busy = fields["busy"]
    if args.reference:
        reference_img, _ = load_image(Path(args.reference).expanduser(), args.work_width)
        reference = find_reference_box(img, reference_img)
        x, y, w, h = reference["box_px"]
        sl = (slice(y, y + h), slice(x, x + w))
        # The hand pick measured by the same yardstick, so any candidate can be
        # compared with it field by field instead of by eye.
        depth = character_depth(busy, DEPTH_CAP_RATIO * min(w, h))
        busy_px = (busy > max(SEED_FLOOR, float(np.quantile(busy, SEED_QUANTILE)))).astype(np.float32)
        reference.update({
            "blank_mean": round(1.0 - float(busy[sl].mean()), 4),
            "pattern_mean": round(float(maps["pattern"][sl].mean()), 4),
            "repeat_mean": round(float(maps["repeat"][sl].mean()), 4),
            "ink_mean": round(float(maps["ink"][sl].mean()), 4),
            "depth_centre": round(float(depth[int(reference["centre_norm"][1] * height),
                                               int(reference["centre_norm"][0] * width)]), 4),
            "busy_pixels": round(float(busy_frac_of(busy_px, reference["box_px"])), 4),
        })
        if character is not None:
            reference["character_mean"] = round(float(character[sl].mean()), 4)
            reference["character_pixels"] = round(
                float((character[sl] > CHARACTER_PIXEL).mean()), 4)
        report["reference"] = reference
        for candidate in candidates:
            candidate["reference_iou"] = round(iou(candidate["box_norm"], reference["box_norm"]), 3)
            candidate["reference_coverage"] = round(
                coverage(candidate["box_norm"], reference["box_norm"]), 3)

    if args.scales:
        sweep = []
        for scale in args.scales:
            size = (max(8, round(scale * width)), max(8, round(scale * width)))
            size_maps = feature_maps(img, size, base)
            if keepout is not None:
                size_maps["keepout"] = keepout
            if character is not None:
                size_maps["character"] = character
            _, best = find_candidates(size_maps, size, 1, args.margin)
            if best:
                sweep.append({"clock": round(scale, 3),
                              "centre_norm": best[0]["centre_norm"],
                              "score": best[0]["score"],
                              "busy_pixels": best[0]["busy_pixels"],
                              "qualified": best[0]["qualified"]})
        report["scale_sweep"] = sweep

    render_overlay(img, fields, candidates, report.get("reference"), outdir / "overlay.png",
                   character)
    write_crop(img, report["reference"]["box_px"], outdir / "reference_region.png") \
        if args.reference else None
    for index, candidate in enumerate(candidates):
        write_crop(img, candidate["box_px"], outdir / f"candidate_{index + 1}.png")
    (outdir / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    print(f"image {image_path.name}  work {width}x{height}  "
          f"clock {int(fields['window'][0])}x{int(fields['window'][1])}px")
    if character is not None:
        covered = float((character > CHARACTER_PIXEL).mean())
        print(f"character mask: {covered * 100:.1f}% of the page, so "
              f"{100 - covered * 100:.1f}% of it could carry a clock")
        if covered < 0.005:
            print("note: the segmentation found almost no character.  It is trained on "
                  "anime line art and under-detects painterly work, so this run is "
                  "leaning on the local measurements alone.", file=sys.stderr)
    if args.reference:
        ref = report["reference"]
        print(f"reference {ref['box_px']} norm {ref['box_norm']} (template match {ref['match']} "
              f"at scale {ref['scale']})  ink {ref['ink_mean']} pattern {ref['pattern_mean']} "
              f"repeat {ref['repeat_mean']} blank {ref['blank_mean']} busy {ref['busy_pixels']}"
              + (f" character {ref['character_pixels']}" if character is not None else ""))
    columns = [f"{'#':>2}", f"{'centre':>14}", f"{'score':>7}", f"{'blank':>6}",
               f"{'depth':>6}", f"{'pattern':>8}", f"{'repeat':>7}", f"{'ink':>6}",
               f"{'busy%':>6}", f"{'peak':>6}"]
    if character is not None:
        columns += [f"{'char%':>6}"]
    columns += [f"{'refCov':>7}", f"{'ok':>3}"]
    print(" ".join(columns))
    for index, candidate in enumerate(candidates):
        cx, cy = candidate["centre_norm"]
        cover = candidate.get("reference_coverage")
        row = [f"{index + 1:>2}", f"{cx:.3f},{cy:.3f}".rjust(14),
               f"{candidate['score']:>7.3f}", f"{candidate['blank_mean']:>6.3f}",
               f"{candidate['depth_mean']:>6.3f}", f"{candidate['pattern_mean']:>8.3f}",
               f"{candidate['repeat_mean']:>7.3f}", f"{candidate['ink_mean']:>6.3f}",
               f"{candidate['busy_pixels'] * 100:>5.1f}%", f"{candidate['busy_peak']:>6.3f}"]
        if character is not None:
            row += [f"{candidate['character_pixels'] * 100:>5.1f}%"]
        row += [f"{'—' if cover is None else f'{cover:.3f}':>7}",
                f"{'yes' if candidate['qualified'] else 'NO':>3}"]
        print(" ".join(row))
    if args.face_model:
        print(f"keep-out: {int(np.count_nonzero(keepout))} px in "
              f"{args.avoid and len(args.avoid) or 0} hand box(es) plus detected faces")
    elif args.avoid:
        print(f"keep-out: {int(np.count_nonzero(keepout))} px in {len(args.avoid)} hand box(es)")
    if report.get("scale_sweep"):
        print("scale sweep (best window per clock width):")
        for row in report["scale_sweep"]:
            score = "n/a" if row["score"] != row["score"] else f"{row['score']:.3f}"
            print(f"  clock {row['clock']:.2f}  centre {row['centre_norm']}  "
                  f"score {score}  busy {row['busy_pixels'] * 100:.1f}%"
                  f"{'' if row['qualified'] else '  (no clean window at this size)'}")
    print(f"wrote {outdir}/overlay.png, {outdir}/report.json and the candidate crops")
    return 0


def busy_frac_of(busy_px: np.ndarray, box: list[int]) -> float:
    x, y, w, h = box
    height, width = busy_px.shape
    x0, y0 = max(0, min(x, width - 1)), max(0, min(y, height - 1))
    x1, y1 = min(width, x0 + w), min(height, y0 + h)
    patch = busy_px[y0:y1, x0:x1]
    return float(patch.mean()) if patch.size else 0.0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"semantic blank region analysis failed: {error}", file=sys.stderr)
        raise SystemExit(1)
