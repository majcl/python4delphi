"""
Pytest configuration for DelphiRTTI tests.
"""
import sys
import os
import pytest
import platform

# Setup path before any imports
script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for config in ['Debug', 'Release']:
    lib_path = os.path.join(script_dir, 'Win64', config)
    if os.path.exists(lib_path) and lib_path not in sys.path:
        sys.path.insert(0, lib_path)
        break

# Import modules
import DelphiRTTI

try:
    import delphivcl as vcl
except ImportError:
    try:
        import DelphiVCL as vcl
    except ImportError:
        vcl = None

try:
    import delphifmx as fmx
except ImportError:
    try:
        import DelphiFMX as fmx
    except ImportError:
        fmx = None

IS_WINDOWS = platform.system() == 'Windows'


@pytest.fixture
def rtti():
    """DelphiRTTI module fixture."""
    return DelphiRTTI


@pytest.fixture
def vcl_module():
    """VCL module fixture."""
    if vcl is None:
        pytest.skip("delphivcl module not available")
    return vcl


@pytest.fixture
def fmx_module():
    """FMX module fixture."""
    if fmx is None:
        pytest.skip("delphifmx module not available")
    return fmx
