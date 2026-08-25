#!/usr/bin/env python3
"""Merge per-scheme theme JSONs into one previews file for the settings panel.

Usage: merge_previews.py <preview_dir> <output_json>

Reads every <scheme>.json in preview_dir and writes {"<scheme>": <theme>, ...}
atomically to output_json.
"""

from __future__ import annotations

import json
import os
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: merge_previews.py <preview_dir> <output_json>", file=sys.stderr)
        return 1

    preview_dir, output = sys.argv[1], sys.argv[2]
    merged: dict = {}
    for name in sorted(os.listdir(preview_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(preview_dir, name)
        try:
            with open(path) as fh:
                merged[os.path.splitext(name)[0]] = json.load(fh)
        except (OSError, json.JSONDecodeError):
            continue

    tmp = output + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(merged, fh)
    os.replace(tmp, output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
