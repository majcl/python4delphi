"""Tests for DelphiRTTI logger API (set_logger_*, logger_info, output to stdout/stderr/filesystem)."""
import platform
import subprocess
import sys
from pathlib import Path

import pytest


def _platform_dir():
    if platform.system() == "Windows":
        return "Win64" if sys.maxsize > 2**32 else "Win32"
    if platform.system() == "Linux":
        return "Linux64" if sys.maxsize > 2**32 else "Linux32"
    if platform.system() == "Darwin":
        return "OSXARM64" if sys.maxsize > 2**32 else "Darwin32"
    return "64" if sys.maxsize > 2**32 else "32"


def _run_logger_subprocess(output_system, message):
    root = Path(__file__).resolve().parent.parent
    platform_dir = _platform_dir()
    script = (
        "import sys\n"
        "from pathlib import Path\n"
        f"root = Path(r'{root.as_posix()}')\n"
        f"sys.path.insert(0, str(root / 'pyd' / '{platform_dir}' / 'Debug'))\n"
        f"sys.path.insert(0, str(root / 'pyd' / '{platform_dir}' / 'Release'))\n"
        "import DelphiRTTI as rtti\n"
        "rtti.set_logger_level('debug')\n"
        f"rtti.set_logger_output_system('{output_system}')\n"
        "rtti.set_logger_always_flush(True)\n"
        f"rtti.logger_info('{message}')\n"
    )
    return subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )


class TestLogger:
    def test_logger_configuration_and_write(self, rtti_module, tmp_path):
        prev_level = rtti_module.get_logger_level()
        prev_output = rtti_module.get_logger_output_system()
        prev_file = rtti_module.get_logger_output_file()
        prev_flush = rtti_module.get_logger_always_flush()

        log_file = tmp_path / "delphirtti_logger_test.log"
        try:
            rtti_module.set_logger_level("debug")
            assert rtti_module.get_logger_level() == "debug"

            rtti_module.set_logger_always_flush(False)
            assert rtti_module.get_logger_always_flush() is False
            rtti_module.set_logger_always_flush(True)

            rtti_module.set_logger_output_file(str(log_file))
            rtti_module.set_logger_output_system("filesystem")
            assert rtti_module.get_logger_output_system() == "filesystem"
            assert rtti_module.get_logger_output_file() == str(log_file)

            rtti_module.logger_info("logger bridge smoke test")
            text = log_file.read_text(encoding="utf-8", errors="ignore")
            assert "logger bridge smoke test" in text
        finally:
            rtti_module.set_logger_level(prev_level)
            rtti_module.set_logger_always_flush(prev_flush)
            if prev_output == "filesystem" and prev_file:
                rtti_module.set_logger_output_file(prev_file)
                rtti_module.set_logger_output_system(prev_output)
            else:
                rtti_module.set_logger_output_system(prev_output)
                if prev_file:
                    rtti_module.set_logger_output_file(prev_file)

    def test_logger_configuration_validation(self, rtti_module):
        with pytest.raises(ValueError):
            rtti_module.set_logger_level("trace")
        with pytest.raises(ValueError):
            rtti_module.set_logger_output_system("network")

    def test_logger_writes_stdout(self):
        marker = "logger stdout marker"
        result = _run_logger_subprocess("stdout", marker)
        assert result.returncode == 0, result.stderr
        assert marker in result.stdout
        assert marker not in result.stderr

    def test_logger_writes_stderr(self):
        marker = "logger stderr marker"
        result = _run_logger_subprocess("stderr", marker)
        assert result.returncode == 0, result.stderr
        assert marker in result.stderr
