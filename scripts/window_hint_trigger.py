#!/usr/bin/env python3

import errno
import glob
import os
import selectors
import struct
import sys
import time


EV_KEY = 0x01
KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
KEY_NAME_MAP = {
    "leftmeta": KEY_LEFTMETA,
    "rightmeta": KEY_RIGHTMETA,
    "meta": KEY_LEFTMETA,
    "super": KEY_LEFTMETA,
    "leftsuper": KEY_LEFTMETA,
    "rightsuper": KEY_RIGHTMETA,
}
EVENT_FORMAT = "llHHI"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)
RESCAN_INTERVAL_SECONDS = 1.0


def _stderr(message: str) -> None:
    sys.stderr.write(message + "\n")
    sys.stderr.flush()


def _parse_meta_keys() -> set[int]:
    raw = os.environ.get("AFLOAT_WINDOW_HINT_META_KEYS", "").strip().lower()
    if raw == "":
        return {KEY_LEFTMETA, KEY_RIGHTMETA}

    resolved: set[int] = set()
    for token in raw.replace(";", ",").split(","):
        item = token.strip()
        if item == "":
            continue

        if item in KEY_NAME_MAP:
            resolved.add(KEY_NAME_MAP[item])
            continue

        try:
            resolved.add(int(item))
        except ValueError:
            _stderr(f"[window_hint_trigger] ignoring unknown meta key token: {item}")

    return resolved or {KEY_LEFTMETA, KEY_RIGHTMETA}


def _candidate_devices() -> list[str]:
    raw = os.environ.get("AFLOAT_WINDOW_HINT_INPUT", "").strip()
    if raw != "":
        return [
            path.strip() for path in raw.replace(":", ",").split(",") if path.strip()
        ]

    candidates: list[str] = []
    for pattern in (
        "/dev/input/by-path/*-kbd",
        "/dev/input/by-id/*-kbd",
    ):
        candidates.extend(sorted(glob.glob(pattern)))

    deduped: list[str] = []
    seen: set[str] = set()
    for path in candidates:
        real_path = os.path.realpath(path)
        if real_path in seen:
            continue
        seen.add(real_path)
        deduped.append(real_path)

    return deduped


def _emit(event_name: str) -> None:
    sys.stdout.write(event_name + "\n")
    sys.stdout.flush()


def _read_events(fd: int) -> list[tuple[int, int]]:
    events: list[tuple[int, int]] = []
    while True:
        try:
            chunk = os.read(fd, EVENT_SIZE * 32)
        except BlockingIOError:
            return events
        except OSError as error:
            if error.errno in (errno.EAGAIN, errno.EWOULDBLOCK):
                return events
            raise

        if not chunk:
            raise OSError(errno.ENODEV, "input device closed")

        offset = 0
        while offset + EVENT_SIZE <= len(chunk):
            _, _, event_type, event_code, event_value = struct.unpack_from(
                EVENT_FORMAT, chunk, offset
            )
            offset += EVENT_SIZE
            if event_type == EV_KEY:
                events.append((event_code, event_value))


def main() -> int:
    selector = selectors.DefaultSelector()
    meta_keys = _parse_meta_keys()
    pressed_keys: set[tuple[str, int]] = set()
    open_devices: dict[str, int] = {}
    hold_active = False
    warned_unavailable = False

    def sync_hold_state() -> None:
        nonlocal hold_active
        next_active = len(pressed_keys) > 0
        if next_active == hold_active:
            return
        hold_active = next_active
        _emit("mod-down" if hold_active else "mod-up")

    def remove_device(path: str) -> None:
        fd = open_devices.pop(path, None)
        if fd is None:
            return

        try:
            selector.unregister(fd)
        except Exception:
            pass

        try:
            os.close(fd)
        except OSError:
            pass

        stale = {item for item in pressed_keys if item[0] == path}
        if stale:
            pressed_keys.difference_update(stale)
            sync_hold_state()

    while True:
        candidates = _candidate_devices()
        readable_candidates = 0

        for path in candidates:
            if path in open_devices:
                readable_candidates += 1
                continue

            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            except PermissionError:
                continue
            except FileNotFoundError:
                continue
            except OSError:
                continue

            open_devices[path] = fd
            selector.register(fd, selectors.EVENT_READ, path)
            readable_candidates += 1

        for path in list(open_devices.keys()):
            if path not in candidates:
                remove_device(path)

        if readable_candidates == 0:
            if not warned_unavailable:
                _stderr("[window_hint_trigger] waiting for a readable keyboard device")
                warned_unavailable = True
            time.sleep(RESCAN_INTERVAL_SECONDS)
            continue

        warned_unavailable = False

        ready = selector.select(timeout=RESCAN_INTERVAL_SECONDS)
        for key, _ in ready:
            path = key.data
            fd = key.fd
            try:
                events = _read_events(fd)
            except OSError:
                remove_device(path)
                continue

            for event_code, event_value in events:
                if event_code not in meta_keys:
                    continue

                marker = (path, event_code)
                if event_value == 0:
                    if marker in pressed_keys:
                        pressed_keys.remove(marker)
                        sync_hold_state()
                    continue

                if event_value == 1 and marker not in pressed_keys:
                    pressed_keys.add(marker)
                    sync_hold_state()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
