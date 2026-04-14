#!/usr/bin/env python3
"""Minimal localhost bridge for Netease web lyrics payloads."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict


def _env_port() -> int:
    raw = os.environ.get("DYMICSHELL_NETEASE_WEB_LYRICS_PORT", "18765").strip()
    try:
        port = int(raw)
    except ValueError:
        port = 18765
    return max(1, min(65535, port))


def _clamp_float(value: Any, default: float = 0.0) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return default
    if parsed != parsed:
        return default
    return parsed


def _clamp_int(value: Any, default: int = 0) -> int:
    try:
        return max(0, int(round(float(value))))
    except (TypeError, ValueError):
        return default


def _normalize_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _normalize_state(payload: Dict[str, Any]) -> Dict[str, Any]:
    progress = _clamp_float(payload.get("progress"), 0.0)
    duration_ms = _clamp_int(payload.get("durationMs", payload.get("duration")), 0)
    position_ms = payload.get("positionMs")
    if position_ms is None and duration_ms > 0:
        position_ms = int(round(progress * duration_ms))

    state = {
        "songId": _normalize_text(payload.get("songId", payload.get("id"))),
        "title": _normalize_text(payload.get("title")),
        "artist": _normalize_text(payload.get("artist")),
        "playbackState": _normalize_text(payload.get("playbackState")) or "stopped",
        "progress": max(0.0, min(1.0, progress)),
        "durationMs": duration_ms,
        "positionMs": _clamp_int(position_ms, 0),
        "rawLyric": _normalize_text(payload.get("rawLyric", payload.get("lyric"))),
        "translatedLyric": _normalize_text(
            payload.get("translatedLyric", payload.get("tlyric"))
        ),
    }
    state["updatedAt"] = int(__import__("time").time() * 1000)
    state["source"] = "netease-web"
    return state


class Bridge:
    def __init__(self) -> None:
        self.latest: Dict[str, Any] = {
            "songId": "",
            "title": "",
            "artist": "",
            "playbackState": "stopped",
            "progress": 0.0,
            "durationMs": 0,
            "positionMs": 0,
            "rawLyric": "",
            "translatedLyric": "",
            "updatedAt": 0,
            "source": "netease-web",
        }

    def update(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        self.latest = _normalize_state(payload)
        print(
            json.dumps(self.latest, ensure_ascii=False, separators=(",", ":")),
            flush=True,
        )
        return self.latest


bridge = Bridge()


class Handler(BaseHTTPRequestHandler):
    server_version = "DymicShellNeteaseBridge/1.0"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        return

    def _send_json(self, code: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode(
            "utf-8"
        )
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path != "/health":
            self._send_json(404, {"ok": False, "error": "not-found"})
            return

        self._send_json(
            200, {"ok": True, "port": self.server.server_port, "latest": bridge.latest}
        )

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/push":
            self._send_json(404, {"ok": False, "error": "not-found"})
            return

        length = _clamp_int(self.headers.get("Content-Length"), 0)
        raw_body = (
            self.rfile.read(length).decode("utf-8", errors="replace")
            if length > 0
            else ""
        )
        try:
            payload = json.loads(raw_body or "{}")
        except json.JSONDecodeError:
            self._send_json(400, {"ok": False, "error": "bad-json"})
            return

        bridge.update(payload if isinstance(payload, dict) else {})
        self._send_json(200, {"ok": True})


def main() -> int:
    port = _env_port()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(
        json.dumps(
            {"ok": True, "ready": True, "port": port},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        flush=True,
    )
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
