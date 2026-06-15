import importlib.util
import os
from pathlib import Path
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "netease_web_lyrics_bridge.py"


def load_module():
    spec = importlib.util.spec_from_file_location("afloat_netease_web_lyrics_bridge", MODULE_PATH)
    if spec is None or spec.loader is None:
        return None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BRIDGE_MODULE = load_module() if MODULE_PATH.exists() else None


class BridgeModuleTests(unittest.TestCase):
    def test_bridge_module_exists(self):
        self.assertTrue(MODULE_PATH.exists())

    def test_env_port_clamps_invalid_values(self):
        self.assertIsNotNone(BRIDGE_MODULE)

        with mock.patch.dict(os.environ, {"AFLOAT_NETEASE_WEB_LYRICS_PORT": "999999"}, clear=False):
            self.assertEqual(BRIDGE_MODULE._env_port(), 65535)

    def test_normalize_state_backfills_position_from_progress(self):
        self.assertIsNotNone(BRIDGE_MODULE)

        state = BRIDGE_MODULE._normalize_state({
            "songId": 123,
            "title": "Song",
            "artist": "Artist",
            "playbackState": "playing",
            "progress": 0.5,
            "durationMs": 240000,
            "rawLyric": "[00:01.00]Line one",
            "translatedLyric": "[00:01.00]Line one translated",
        })

        self.assertEqual(state["songId"], "123")
        self.assertEqual(state["positionMs"], 120000)
        self.assertEqual(state["durationMs"], 240000)
        self.assertEqual(state["progress"], 0.5)
        self.assertEqual(state["playbackState"], "playing")

    def test_normalize_state_preserves_art_url(self):
        self.assertIsNotNone(BRIDGE_MODULE)

        state = BRIDGE_MODULE._normalize_state({
            "title": "Song",
            "artist": "Artist",
            "artUrl": " file:///tmp/cover.jpg ",
        })

        self.assertEqual(state["artUrl"], "file:///tmp/cover.jpg")


if __name__ == "__main__":
    unittest.main()
