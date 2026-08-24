import importlib.util
import os
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "beat_tracker_bridge.py"


def load_module():
    spec = importlib.util.spec_from_file_location("afloat_beat_tracker_bridge", MODULE_PATH)
    if spec is None or spec.loader is None:
        return None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_record_command_honors_env_override():
    module = load_module()
    assert module is not None

    with mock.patch.dict(os.environ, {"AFLOAT_BEAT_RECORD_CMD": "my-record --raw -"}):
        assert module._record_command() == ["my-record", "--raw", "-"]


def test_record_command_uses_pw_record_by_default():
    module = load_module()
    assert module is not None

    env = {k: v for k, v in os.environ.items() if k != "AFLOAT_BEAT_RECORD_CMD"}
    with mock.patch.dict(os.environ, env, clear=True), \
            mock.patch.object(module.shutil, "which", return_value="/usr/bin/pw-record"):
        command = module._record_command()

    assert command[0] == "/usr/bin/pw-record"
    assert "@DEFAULT_MONITOR@" in command
    assert "44100" in command


def test_record_command_fails_without_pw_record():
    module = load_module()
    assert module is not None

    env = {k: v for k, v in os.environ.items() if k != "AFLOAT_BEAT_RECORD_CMD"}
    with mock.patch.dict(os.environ, env, clear=True), \
            mock.patch.object(module.shutil, "which", return_value=None):
        try:
            module._record_command()
        except RuntimeError:
            pass
        else:
            raise AssertionError("expected RuntimeError when pw-record missing")
