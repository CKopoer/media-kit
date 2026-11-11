"""Exercise the production EGL surface lifecycle without a Windows/GPU SDK."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent


def method(source, signature):
    start = source.index(signature)
    brace = source.index("{", start)
    end, depth = brace + 1, 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end] + "\n"


class WindowsEGLSurfaceTest(unittest.TestCase):
    def test_producer_surface_stays_writable_during_creation_resize_and_cleanup(self):
        compiler = shutil.which("clang++") or shutil.which("g++")
        if not compiler:
            self.skipTest("A C++17 compiler is needed for the EGL lifecycle test")
        source = (ROOT / "media_kit_video/windows/angle_surface_manager.cc").read_text()
        signatures = (
            "void ANGLESurfaceManager::MakeCurrent(",
            "void ANGLESurfaceManager::CleanUp(",
            "bool ANGLESurfaceManager::CreateAndBindEGLSurface(",
        )
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            (output / "egl_surface_methods.inc").write_text(
                "\n".join(method(source, name) for name in signatures), encoding="utf-8")
            binary = output / "egl-surface-test.exe"
            subprocess.run([
                compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                "-Wno-unused-function", "-I", str(output),
                str(ROOT / "native/tests/windows_egl_surface_test.cc"),
                "-o", str(binary),
            ], check=True, timeout=60)
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
