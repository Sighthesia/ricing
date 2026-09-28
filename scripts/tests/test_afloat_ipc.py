import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "afloat-ipc"


@pytest.fixture
def fake_qs(tmp_path):
    executable = tmp_path / "qs"
    executable.write_text(
        f"#!{sys.executable}\n"
        "import json, os, sys\n"
        "print(json.dumps({'args': sys.argv[1:], "
        "'selftest': os.environ.get('AFLOAT_LOCK_SELFTEST'), "
        "'watcher': os.environ.get('QS_DISABLE_FILE_WATCHER')}))\n"
    )
    executable.chmod(0o755)
    env = dict(os.environ, PATH=f"{tmp_path}:{os.environ['PATH']}")
    env.pop("AFLOAT_LOCK_SELFTEST", None)
    env.pop("QS_DISABLE_FILE_WATCHER", None)
    return env


def test_lock_test_routes_to_main_instance(fake_qs):
    result = subprocess.run(
        [str(SCRIPT), "lock", "test"], env=fake_qs,
        capture_output=True, text=True, check=True, timeout=5,
    )
    payload = json.loads(result.stdout)
    assert payload["args"] == ["ipc", "-p", str(ROOT), "call", "lock", "test"]
    assert payload["selftest"] is None
    assert payload["watcher"] is None


@pytest.mark.parametrize("args", [
    ["lock", "lock"],
    ["lock", "unlock"],
    ["launcher", "toggle"],
])
def test_normal_ipc_remains_unchanged(fake_qs, args):
    result = subprocess.run(
        [str(SCRIPT), *args], env=fake_qs,
        capture_output=True, text=True, check=True, timeout=5,
    )
    payload = json.loads(result.stdout)
    assert payload["args"] == ["ipc", "-p", str(ROOT), "call", *args]
    assert payload["selftest"] is None
    assert payload["watcher"] is None
