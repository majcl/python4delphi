"""Pytest configuration for DelphiRTTI tests."""
import gc
import importlib
import platform
import sys
from pathlib import Path

import pytest

SCRIPT_DIR = Path(__file__).resolve().parent.parent
IS_WINDOWS = platform.system() == "Windows"


def _platform_dir():
    is_64_bit = sys.maxsize > 2**32
    system_name = platform.system().lower()
    if system_name == "windows":
        return "Win64" if is_64_bit else "Win32"
    if system_name == "linux":
        return "Linux64" if is_64_bit else "Linux32"
    if system_name == "darwin":
        return "OSXARM64" if is_64_bit else "Darwin32"
    return "64" if is_64_bit else "32"


def _add_library_paths():
    platform_dir = _platform_dir()
    discovered = []
    for root in (SCRIPT_DIR / "pyd", SCRIPT_DIR):
        for config in ("Debug", "Release"):
            candidate = root / platform_dir / config
            if candidate.exists():
                candidate_str = str(candidate)
                if candidate_str not in sys.path:
                    sys.path.insert(0, candidate_str)
                discovered.append(candidate_str)
    return discovered


def _import_first_available(names):
    for name in names:
        try:
            return importlib.import_module(name)
        except ImportError:
            continue
    return None


DISCOVERED_LIBRARY_PATHS = _add_library_paths()
rtti = _import_first_available(("DelphiRTTI",))
vcl = _import_first_available(("delphivcl", "DelphiVCL"))
fmx = _import_first_available(("delphifmx", "DelphiFMX"))


def _paths_text():
    return ", ".join(DISCOVERED_LIBRARY_PATHS) if DISCOVERED_LIBRARY_PATHS else "none"


def pytest_configure(config):
    if rtti is None:
        raise pytest.UsageError(
            "FATAL: DelphiRTTI module not found. "
            f"Detected library paths: {_paths_text()}"
        )
    if not hasattr(rtti, "get_type_rtti"):
        raise pytest.UsageError(
            "FATAL: DelphiRTTI.get_type_rtti is missing. "
            f"Detected library paths: {_paths_text()}"
        )
    if IS_WINDOWS:
        if vcl is None:
            raise pytest.UsageError("FATAL: On Windows, delphivcl is required.")
        if fmx is None:
            raise pytest.UsageError("FATAL: On Windows, delphifmx is required.")
    elif fmx is None:
        raise pytest.UsageError("FATAL: On non-Windows platforms, delphifmx is required.")

    config.option.assertmode = "plain"


@pytest.fixture
def rtti_module():
    yield rtti
    gc.collect()


@pytest.fixture
def vcl_module():
    yield vcl
    gc.collect()


@pytest.fixture
def fmx_module():
    yield fmx
    gc.collect()


