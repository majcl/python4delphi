"""Pytest configuration for DelphiRTTI tests."""
import gc
import importlib
import platform
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT_DIR = Path(__file__).resolve().parent.parent
IS_WINDOWS = platform.system() == "Windows"
rtti = None
vcl = None
fmx = None


def _platform_dir():
    if platform.system() == "Windows":
        return "Win64" if sys.maxsize > 2**32 else "Win32"
    if platform.system() == "Linux":
        return "Linux64" if sys.maxsize > 2**32 else "Linux32"
    if platform.system() == "Darwin":
        return "OSXARM64" if sys.maxsize > 2**32 else "Darwin32"
    return "64" if sys.maxsize > 2**32 else "32"


def _add_library_paths(mode):
    discovered = []
    configs = ("Debug", "Release") if mode == "both" else (mode.capitalize(),)
    platform_dir = _platform_dir()
    for root in (SCRIPT_DIR / "pyd", SCRIPT_DIR):
        for cfg in configs:
            path = root / platform_dir / cfg
            if path.exists():
                path_str = str(path)
                if path_str not in sys.path:
                    sys.path.insert(0, path_str)
                discovered.append(path_str)
    return discovered


def _import_first_available(names):
    for name in names:
        try:
            return importlib.import_module(name)
        except ImportError:
            pass
    return None


def pytest_addoption(parser):
    parser.addoption(
        "--library-config",
        action="store",
        default="both",
        choices=("both", "debug", "release"),
    )


def _strip_library_config_args(args):
    out = []
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
            continue
        if arg == "--library-config":
            skip_next = True
            continue
        if arg.startswith("--library-config="):
            continue
        out.append(arg)
    return out


def pytest_cmdline_main(config):
    mode = config.getoption("--library-config")
    if mode != "both":
        return None

    base_args = _strip_library_config_args(list(config.invocation_params.args))
    debug_rc = subprocess.call(
        [sys.executable, "-m", "pytest", *base_args, "--library-config=debug"],
        cwd=str(SCRIPT_DIR),
    )
    release_rc = subprocess.call(
        [sys.executable, "-m", "pytest", *base_args, "--library-config=release"],
        cwd=str(SCRIPT_DIR),
    )
    return 0 if (debug_rc == 0 and release_rc == 0) else 1


def pytest_configure(config):
    global rtti, vcl, fmx
    config.option.assertmode = "plain"

    mode = config.getoption("--library-config")
    discovered = _add_library_paths("both" if mode == "both" else mode)
    rtti = _import_first_available(("DelphiRTTI",))
    vcl = _import_first_available(("delphivcl", "DelphiVCL"))
    fmx = _import_first_available(("delphifmx", "DelphiFMX"))

    paths_text = ", ".join(discovered) if discovered else "none"
    if rtti is None:
        raise pytest.UsageError(
            f"FATAL: DelphiRTTI module not found. Detected library paths: {paths_text}"
        )
    if not hasattr(rtti, "get_type_rtti"):
        raise pytest.UsageError(
            "FATAL: DelphiRTTI.get_type_rtti is missing. "
            f"Detected library paths: {paths_text}"
        )
    for diag_fn in ("get_method_names", "get_property_names"):
        if not hasattr(rtti, diag_fn):
            raise pytest.UsageError(
                f"FATAL: DelphiRTTI.{diag_fn} is missing. "
                f"Detected library paths: {paths_text}"
            )
    if vcl is None and IS_WINDOWS:
        raise pytest.UsageError("FATAL: On Windows, delphivcl is required.")
    if fmx is None:
        raise pytest.UsageError("FATAL: delphifmx is required.")


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


