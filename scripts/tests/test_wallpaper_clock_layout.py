import importlib.util
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "wallpaper_clock_layout.py"
SPEC = importlib.util.spec_from_file_location("wallpaper_clock_layout", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def test_finds_flat_region_anywhere_in_frame():
    gray = []
    for y in range(20):
        row = []
        for x in range(40):
            row.append(32 if x < 20 else (32 if (x + y) % 2 else 220))
        gray.append(row)

    result = MODULE.find_least_busy_region(
        gray, region_width_ratio=0.25, region_height_ratio=0.35,
        margin_ratio=0.05, stride=1,
    )

    assert result["center_x"] < 0.5
    assert result["luminance"] < 0.3
    assert result["variance"] == 0


def test_preserves_crop_aware_normalized_contract():
    gray = [[128 for _ in range(32)] for _ in range(18)]
    result = MODULE.find_least_busy_region(gray)

    assert 0.06 <= result["center_x"] <= 0.94
    assert 0.06 <= result["center_y"] <= 0.94
    assert abs(result["luminance"] - 128 / 255) < 0.001


def test_rejects_malformed_sample_matrix():
    try:
        MODULE.find_least_busy_region([[1], [1, 2]])
    except ValueError as error:
        assert "rectangular" in str(error)
    else:
        raise AssertionError("malformed matrix should be rejected")
