"""
Build wheels for delphirtti (Release) and delphirtti-debug (Debug) from
pre-built Delphi binaries in pyd/<Platform>/<Config>.

Builds one wheel per (platform, config) found under pyd/. Each wheel is tagged
for all P4D-supported Python versions (3.8–3.14): the same .pyd is
runtime-compatible with any of them (PythonEngine loads the interpreter DLL
by probing down from the highest known version). The wheel filename uses the
lowest version tag (cp38); the WHEEL file lists all tags so pip can install
on any supported interpreter.

Run from module root with uv:
  uv run --project python_packages python python_packages/build_wheels.py
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

if sys.version_info < (3, 11):
    raise SystemExit("build_wheels.py requires Python 3.11+ (uses stdlib tomllib)")

import tomllib
from pyproject_metadata import StandardMetadata
from wheelfile import MetaData, WheelFile

MODULE_NAME = "DelphiRTTI"

# P4D PythonEngine.PYTHON_KNOWN_VERSIONS: one .pyd works at runtime for 3.8–3.14
SUPPORTED_PYTHON_MIN = (3, 8)
SUPPORTED_PYTHON_MAX = (3, 14)

# pyd/ subdir names that have a standard Python wheel platform tag (Android/iOS skipped)
PYD_PLATFORM_TO_WHEEL: dict[str, tuple[str, str]] = {
    "Win64": ("win_amd64", ".pyd"),
    "Win32": ("win32", ".pyd"),
    "Linux64": ("manylinux_2_17_x86_64", ".so"),
    "Linux32": ("manylinux_2_17_i686", ".so"),
    "OSX64": ("macosx_10_9_x86_64", ".so"),
    "OSXARM64": ("macosx_11_0_arm64", ".so"),
}

# Delphi build: same sequence as AGENTS.md (Win64 + Linux64 only)
RSVARS_DEFAULT = r"C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
DELPHI_BUILDS = [
    ("Debug", "Win64"),
    ("Release", "Win64"),
    ("Debug", "Linux64"),
    ("Release", "Linux64"),
]


def _module_root() -> Path:
    """Resolve Modules/DelphiRTTI (directory that contains pyd/ and python_packages/)."""
    script = Path(__file__).resolve()
    root = script.parent.parent
    if not (root / "pyd").is_dir() or not (root / "python_packages").is_dir():
        raise SystemExit("Could not find module root (expected pyd/ and python_packages/).")
    return root


def _load_metadata(pyproject_path: Path) -> StandardMetadata:
    """Load and validate [project] from a pyproject.toml via pyproject-metadata."""
    with open(pyproject_path, "rb") as f:
        data = tomllib.load(f)
    return StandardMetadata.from_pyproject(data, allow_extra_keys=True)


def _find_binary(pyd_dir: Path, ext: str) -> Path | None:
    """Path to extension file in pyd_dir. Prefer DelphiRTTI.ext; fallback libDelphiRTTI.so."""
    if ext == ".pyd":
        p = pyd_dir / f"{MODULE_NAME}.pyd"
        return p if p.exists() else None
    for name in (f"{MODULE_NAME}.so", f"lib{MODULE_NAME}.so"):
        p = pyd_dir / name
        if p.exists():
            return p
    return None


def _supported_cp_tags() -> list[tuple[str, str]]:
    """All (language_tag, abi_tag) pairs for P4D-supported Python versions (3.8–3.14)."""
    out: list[tuple[str, str]] = []
    for minor in range(SUPPORTED_PYTHON_MIN[1], SUPPORTED_PYTHON_MAX[1] + 1):
        cp = f"cp{SUPPORTED_PYTHON_MIN[0]}{minor}"
        out.append((cp, cp))
    return out


def _wheel_tags_for_platform(platform_wheel: str) -> list[str]:
    """Full wheel tag strings (e.g. cp38-cp38-win_amd64) for this platform, one per supported Python."""
    return [f"{lang}-{abi}-{platform_wheel}" for lang, abi in _supported_cp_tags()]


def run_delphi_build(root: Path) -> bool:
    """Run Delphi build (Win64 + Linux64 per AGENTS.md). Returns True on success. Windows only."""
    if sys.platform != "win32":
        print("Delphi build is only supported on Windows; skipping.", file=sys.stderr)
        return True
    rsvars = Path(RSVARS_DEFAULT)
    if not rsvars.exists():
        print(f"rsvars.bat not found at {rsvars}; set RSBIN or install RAD Studio.", file=sys.stderr)
        return False
    dproj = root / "DelphiRTTI.dproj"
    if not dproj.exists():
        print(f"DelphiRTTI.dproj not found at {dproj}", file=sys.stderr)
        return False
    msbuild_parts = [
        f"msbuild DelphiRTTI.dproj /t:Build /p:Config={cfg} /p:Platform={plat}"
        for cfg, plat in DELPHI_BUILDS
    ]
    script = f"call \"{rsvars}\" && cd /d \"{root}\" && " + " && ".join(msbuild_parts)
    print("Running Delphi build (Win64 + Linux64)...")
    r = subprocess.run(["cmd", "/c", script], cwd=root)
    if r.returncode != 0:
        print("Delphi build failed.", file=sys.stderr)
        return False
    print("Delphi build done.")
    return True


def build_one_wheel(
    root: Path,
    package_dir: str,
    config: str,
    platform_dir: str,
    platform_wheel: str,
    ext: str,
    dist_dir: Path,
) -> None:
    project_path = root / "python_packages" / package_dir / "pyproject.toml"
    meta = _load_metadata(project_path)

    pyd_dir = root / "pyd" / platform_dir / config
    binary_path = _find_binary(pyd_dir, ext)
    if not binary_path:
        print(f"Skip {meta.name}: no binary in {pyd_dir}", file=sys.stderr)
        return

    wheel_name_in_archive = f"{MODULE_NAME}{ext}"
    # Filename uses lowest supported version (cp38); WHEEL will list all 3.8–3.14 tags
    language_tag, abi_tag = _supported_cp_tags()[0]
    all_tags = _wheel_tags_for_platform(platform_wheel)

    with WheelFile(
        dist_dir,
        mode="w",
        distname=meta.name.replace("-", "_"),
        version=str(meta.version),
        language_tag=language_tag,
        abi_tag=abi_tag,
        platform_tag=platform_wheel,
    ) as wf:
        # Put the extension module in archive root so import name stays: import DelphiRTTI
        wf.write(binary_path, arcname=wheel_name_in_archive, resolve=False)

        # METADATA from pyproject.toml [project] via pyproject-metadata (no manual field mapping)
        wf.metadata = MetaData.from_str(str(meta.as_rfc822()))

        # Binary wheel metadata: one wheel valid for all P4D-supported Python versions
        wf.wheeldata.root_is_purelib = False
        wf.wheeldata.generator = "build_wheels.py"
        wf.wheeldata.tags = all_tags
        wheel_path = wf.filename

    print(f"Built {wheel_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build delphirtti and delphirtti-debug wheels")
    parser.add_argument(
        "--no-build-delphi",
        action="store_true",
        help="Do not run Delphi build; use existing pyd/ artifacts",
    )
    args = parser.parse_args()

    root = _module_root()
    if not args.no_build_delphi and not run_delphi_build(root):
        sys.exit(1)

    dist_dir = root / "dist"
    dist_dir.mkdir(parents=True, exist_ok=True)
    pyd_root = root / "pyd"

    for platform_dir in sorted(pyd_root.iterdir()):
        if not platform_dir.is_dir():
            continue
        platform_name = platform_dir.name
        if platform_name not in PYD_PLATFORM_TO_WHEEL:
            continue  # skip Android, iOS, etc.
        platform_wheel, ext = PYD_PLATFORM_TO_WHEEL[platform_name]
        for config, package_dir in [("Release", "delphirtti"), ("Debug", "delphirtti_debug")]:
            build_one_wheel(
                root,
                package_dir,
                config,
                platform_name,
                platform_wheel,
                ext,
                dist_dir,
            )


if __name__ == "__main__":
    main()
