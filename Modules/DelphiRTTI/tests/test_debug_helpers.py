"""Tests for DelphiRTTI diagnostic helpers: get_method_names, get_property_names."""
import pytest

from conftest import (
    FMX_COMPONENT_CASES,
    IS_WINDOWS,
    VCL_COMPONENT_CASES,
    _get_component_by_kind,
    rtti,
)

# Skip entire module if debug helpers were not built (optional feature)
if rtti is None or not hasattr(rtti, "get_method_names") or not hasattr(rtti, "get_property_names"):
    pytest.skip(
        "Debug helpers not built (get_method_names/get_property_names missing)",
        allow_module_level=True,
    )


class TestDiagnosticNames:
    """Tests for get_method_names and get_property_names (diagnostic API)."""

    @pytest.mark.skipif(not IS_WINDOWS, reason="VCL only on Windows")
    @pytest.mark.parametrize("case", VCL_COMPONENT_CASES, ids=lambda c: c["expected"])
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_vcl_method_names(self, rtti_module, vcl_module, case, input_kind):
        component = _get_component_by_kind(vcl_module, input_kind, case["class_name"])
        result = rtti_module.get_method_names(component)
        assert isinstance(result, dict), "get_method_names should return a dict"
        assert "all_methods" in result, "dict should have 'all_methods' key"
        names = result["all_methods"]
        assert isinstance(names, list)
        assert len(names) > 0
        assert all(isinstance(n, str) for n in names)
        for expected in case["method_names"]:
            assert expected in names, f"{expected} not in method names for {case['expected']}"

    @pytest.mark.skipif(not IS_WINDOWS, reason="VCL only on Windows")
    @pytest.mark.parametrize("case", VCL_COMPONENT_CASES, ids=lambda c: c["expected"])
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_vcl_property_names(self, rtti_module, vcl_module, case, input_kind):
        component = _get_component_by_kind(vcl_module, input_kind, case["class_name"])
        names = rtti_module.get_property_names(component)
        assert isinstance(names, list)
        assert len(names) > 0
        assert all(isinstance(n, str) for n in names)
        for expected in case["property_names"]:
            assert expected in names, f"{expected} not in property names for {case['expected']}"

    @pytest.mark.parametrize("case", FMX_COMPONENT_CASES, ids=lambda c: c["expected"])
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_fmx_method_names(self, rtti_module, fmx_module, case, input_kind):
        component = _get_component_by_kind(fmx_module, input_kind, case["class_name"])
        result = rtti_module.get_method_names(component)
        assert isinstance(result, dict), "get_method_names should return a dict"
        assert "all_methods" in result, "dict should have 'all_methods' key"
        names = result["all_methods"]
        assert isinstance(names, list)
        assert len(names) > 0
        assert all(isinstance(n, str) for n in names)
        for expected in case["method_names"]:
            assert expected in names, f"{expected} not in method names for {case['expected']}"

    @pytest.mark.parametrize("case", FMX_COMPONENT_CASES, ids=lambda c: c["expected"])
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_fmx_property_names(self, rtti_module, fmx_module, case, input_kind):
        component = _get_component_by_kind(fmx_module, input_kind, case["class_name"])
        names = rtti_module.get_property_names(component)
        assert isinstance(names, list)
        assert len(names) > 0
        assert all(isinstance(n, str) for n in names)
        for expected in case["property_names"]:
            assert expected in names, f"{expected} not in property names for {case['expected']}"

    def test_invalid_argument(self, rtti_module):
        with pytest.raises(TypeError):
            rtti_module.get_method_names(12345)
        with pytest.raises(TypeError):
            rtti_module.get_property_names(12345)
