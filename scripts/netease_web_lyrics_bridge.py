#!/usr/bin/env python3
"""Minimal localhost bridge for NetEase web lyrics payloads."""

from __future__ import annotations

import json
import os
import signal
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


def _env_port() -> int:
    raw = os.environ.get("AFLOAT_NETEASE_WEB_LYRICS_PORT", "18765").strip()
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
        "artUrl": _normalize_text(payload.get("artUrl", payload.get("coverUrl", payload.get("trackArtUrl")))),
        "playbackState": _normalize_text(payload.get("playbackState")) or "stopped",
        "progress": max(0.0, min(1.0, progress)),
        "durationMs": duration_ms,
        "positionMs": _clamp_int(position_ms, 0),
        "rawLyric": _normalize_text(payload.get("rawLyric", payload.get("lyric"))),
        "translatedLyric": _normalize_text(payload.get("translatedLyric", payload.get("tlyric"))),
    }
    state["updatedAt"] = int(time.time() * 1000)
    state["source"] = "netease-web"
    return state


class Bridge:
    def __init__(self) -> None:
        self.latest: Dict[str, Any] = {
            "songId": "",
            "title": "",
            "artist": "",
            "artUrl": "",
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
        print(json.dumps(self.latest, ensure_ascii=False, separators=(",", ":")), flush=True)
        return self.latest


bridge = Bridge()


class Handler(BaseHTTPRequestHandler):
    server_version = "AfloatNeteaseBridge/1.0"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        return

    def _send_json(self, code: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
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

        self._send_json(200, {"ok": True, "port": self.server.server_port, "latest": bridge.latest})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/push":
            self._send_json(404, {"ok": False, "error": "not-found"})
            return

        length = _clamp_int(self.headers.get("Content-Length"), 0)
        raw_body = self.rfile.read(length).decode("utf-8", errors="replace") if length > 0 else ""
        try:
            payload = json.loads(raw_body or "{}")
        except json.JSONDecodeError:
            self._send_json(400, {"ok": False, "error": "bad-json"})
            return

        bridge.update(payload if isinstance(payload, dict) else {})
        self._send_json(200, {"ok": True})


def _pidfile_path() -> Path:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/afloat-{os.getuid()}"
    return Path(runtime_dir) / "afloat" / "netease_web_lyrics_bridge.pid"


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _process_is_bridge(pid: int) -> bool:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    return "netease_web_lyrics_bridge.py" in raw.decode("utf-8", errors="replace")


def _terminate_stale_instance() -> None:
    # A previous shell session can orphan its bridge, which keeps holding the
    # port forever. Take over by terminating it before binding.
    pidfile = _pidfile_path()
    try:
        stale_pid = int(pidfile.read_text().strip())
    except (OSError, ValueError):
        return

    if stale_pid == os.getpid() or not _process_is_bridge(stale_pid):
        pidfile.unlink(missing_ok=True)
        return

    try:
        os.kill(stale_pid, signal.SIGTERM)
    except OSError:
        return

    for _ in range(20):
        if not _pid_alive(stale_pid):
            break
        time.sleep(0.1)

    if _pid_alive(stale_pid):
        try:
            os.kill(stale_pid, signal.SIGKILL)
        except OSError:
            pass
        time.sleep(0.2)


def _write_pidfile() -> None:
    pidfile = _pidfile_path()
    try:
        pidfile.parent.mkdir(parents=True, exist_ok=True)
        pidfile.write_text(str(os.getpid()))
    except OSError:
        pass


def _remove_pidfile() -> None:
    try:
        _pidfile_path().unlink(missing_ok=True)
    except OSError:
        pass


def _listening_socket_inode(port: int) -> Optional[str]:
    # Find the inode of the socket listening on <port> via /proc/net/tcp,
    # so an orphan without a pidfile can still be identified and taken over.
    target_hex = f"{port:04X}"
    for path in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            lines = Path(path).read_text().splitlines()[1:]
        except OSError:
            continue
        for line in lines:
            fields = line.split()
            if len(fields) < 10:
                continue
            local_address, state, inode = fields[1], fields[3], fields[9]
            if local_address.split(":")[-1].upper() == target_hex and state == "0A":
                return inode
    return None


def _port_owner_pid(port: int) -> Optional[int]:
    inode = _listening_socket_inode(port)
    if inode is None:
        return None

    proc_dir = Path("/proc")
    for entry in proc_dir.iterdir():
        if not entry.name.isdigit():
            continue
        fd_dir = entry / "fd"
        try:
            fds = list(fd_dir.iterdir())
        except OSError:
            continue
        for fd in fds:
            try:
                link = os.readlink(fd)
            except OSError:
                continue
            if link == f"socket:[{inode}]":
                return int(entry.name)
    return None


def _terminate_port_owner(port: int) -> None:
    owner_pid = _port_owner_pid(port)
    if owner_pid is None or owner_pid == os.getpid():
        return

    print(
        json.dumps({"ok": True, "action": "takeover", "stalePid": owner_pid, "port": port}),
        flush=True,
    )
    try:
        os.kill(owner_pid, signal.SIGTERM)
    except OSError:
        return

    for _ in range(20):
        if not _pid_alive(owner_pid):
            return
        time.sleep(0.1)

    try:
        os.kill(owner_pid, signal.SIGKILL)
    except OSError:
        pass
    time.sleep(0.2)


def _create_server(port: int, attempts: int = 25, delay_s: float = 0.2) -> Tuple[Optional[ThreadingHTTPServer], Optional[OSError]]:
    # Retry briefly; if the port stays held, terminate the listener so this
    # session's bridge always wins (the shell needs its own stdout stream).
    last_error: Optional[OSError] = None
    for attempt in range(attempts):
        try:
            return ThreadingHTTPServer(("127.0.0.1", port), Handler), None
        except OSError as error:
            last_error = error
            if attempt == 1:
                _terminate_port_owner(port)
            time.sleep(delay_s)
    return None, last_error


def main() -> int:
    port = _env_port()
    _terminate_stale_instance()
    server, bind_error = _create_server(port)
    if server is None:
        print(
            json.dumps({"ok": False, "error": "bind-failed", "port": port, "detail": str(bind_error)}),
            flush=True,
        )
        return 1

    _write_pidfile()
    print(json.dumps({"ok": True, "ready": True, "port": port}, ensure_ascii=False, separators=(",", ":")), flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        _remove_pidfile()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
