"""Run the real render initializer against fake mpv and ANGLE implementations."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent


class VideoInitializationTest(unittest.TestCase):
    def test_renderer_selection_and_failed_initialization_cleanup(self):
        compiler = shutil.which("clang++") or shutil.which("g++")
        if not compiler:
            self.skipTest("A C++17 compiler is needed for the standalone unit test")
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "video-initialization-test.exe"
            subprocess.run(
                [compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                 "-I", str(ROOT / "media_kit_video/windows"),
                 str(ROOT / "native/tests/windows_video_initialization_test.cc"),
                 "-o", str(binary)],
                check=True, timeout=60,
            )
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
