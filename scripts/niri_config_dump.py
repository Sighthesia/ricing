#!/usr/bin/env python3
"""Dump the niri config files this shell needs to read, as JSON.

Why a process instead of `FileView`: the file list is not known until
`config.kdl` has been parsed (its `include` lines), so a reader would have to be
created on demand - and a dynamically created `FileView` cannot be relied on to
return its text synchronously on the frame it is created, which is exactly what
a synchronous include walk needs. One process that does the walk itself has no
such question: it either printed the files or it did not.

Output, on stdout, one JSON object:

    {
      "files": [{"path": "...", "text": "..."}],
      "xkb": {"layout": "us", "variant": "", "options": ""}
    }

Files are listed in niri's own merge order: `config.kdl` first, then each
include in the order it was written, depth first. `binds.kdl` is always
included: it is niri's conventional home for binds and the file the shell writes
its own include beside, so a config that forgot to include it would otherwise
report no shortcuts at all.

A missing or unreadable file is skipped silently. niri runs without a config,
and a helper that warned on every poll would fill the shell's log with noise
about a state that is not an error.
"""

import json
import os
import re
import sys

INCLUDE_RE = re.compile(r'^[ \t]*include[ \t]+"((?:[^"\\]|\\.)*)"', re.MULTILINE)
XKB_BLOCK_RE = re.compile(r"xkb\s*\{([^}]*)\}", re.DOTALL)


def config_dir() -> str:
    home = os.environ.get("HOME") or ""
    if home == "":
        home = os.path.expanduser("~")
    return os.path.join(home, ".config", "niri")


def read_text(path: str):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return None


def unescape(value: str) -> str:
    return value.replace('\\"', '"').replace("\\\\", "\\")


def includes_in(text: str):
    return [unescape(match) for match in INCLUDE_RE.findall(text)]


def resolve(base_file: str, target: str, fallback_dir: str) -> str:
    if target == "":
        return ""
    if target.startswith("/"):
        return os.path.normpath(target)
    base = os.path.dirname(base_file) or fallback_dir
    return os.path.normpath(os.path.join(base, target))


def collect(root_dir: str):
    """Every config file niri reads, in merge order."""
    config_file = os.path.join(root_dir, "config.kdl")
    binds_file = os.path.join(root_dir, "binds.kdl")

    queue = [config_file, binds_file]
    visited = set()
    files = []

    while queue:
        path = queue.pop(0)
        if path == "" or path in visited:
            continue
        visited.add(path)

        text = read_text(path)
        if text is None:
            continue

        files.append({"path": path, "text": text})
        for target in includes_in(text):
            resolved = resolve(path, target, root_dir)
            if resolved and resolved not in visited:
                queue.append(resolved)

    return files


def xkb_settings(files) -> dict:
    """The keyboard layout the key names are read in.

    Only used to LABEL keys ("Super+Space"), never to build a keymap, so the
    first `xkb {}` block that names a layout is enough. Defaults follow niri's
    own defaults.
    """
    settings = {"layout": "", "variant": "", "options": ""}
    for entry in files:
        block = XKB_BLOCK_RE.search(entry.get("text", ""))
        if not block:
            continue
        body = block.group(1)
        for name in ("layout", "variant", "options"):
            match = re.search(
                r'^\s*' + name + r'\s+"((?:[^"\\]|\\.)*)"', body, re.MULTILINE
            )
            if match and settings[name] == "":
                settings[name] = unescape(match.group(1))
        if settings["layout"] != "":
            break
    return settings


def main() -> int:
    root_dir = config_dir()
    files = collect(root_dir)
    json.dump({"files": files, "xkb": xkb_settings(files)}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
