"""Pytest test suite for DelphiRTTI module."""
import platform

import pytest

IS_WINDOWS = platform.system() == "Windows"

VCL_COMPONENT_CASES = [
    {
        "class_name": "Form",
        "expected": "TForm",
        "method_names": ("ShowModal", "Show", "SetBounds"),
        "property_names": ("Caption", "Name", "Enabled"),
    },
    {
        "class_name": "Button",
        "expected": "TButton",
        "method_names": ("Click", "SetFocus", "Create"),
        "property_names": ("Caption", "Name", "Enabled"),
    },
    {
        "class_name": "Timer",
        "expected": "TTimer",
        "method_names": ("Create", "SetInterval"),
        "property_names": ("Enabled", "Interval", "Name"),
    },
]

FMX_COMPONENT_CASES = [
    {
        "class_name": "Form",
        "expected": "TForm",
        "method_names": ("ShowModal", "Show", "SetBounds"),
        "property_names": ("Caption", "Name", "Enabled"),
    },
    {
        "class_name": "Button",
        "expected": "TButton",
        "method_names": ("Click", "SetFocus", "Create"),
        "property_names": ("Text", "Name", "Enabled"),
    },
    {
        "class_name": "Timer",
        "expected": "TTimer",
        "method_names": ("Create", "SetInterval"),
        "property_names": ("Enabled", "Interval", "Name"),
    },
]


def _name(obj):
    return obj.Name


def _get_methods(rtti_type):
    return rtti_type.GetMethods() or []


def _get_properties(rtti_type):
    return rtti_type.GetProperties() or []


def _get_attributes(rtti_obj):
    return rtti_obj.GetAttributes() or []


def _get_parameters(method):
    return method.GetParameters() or []


def _find_by_name(items, expected_name):
    expected_name = expected_name.lower()
    for item in items:
        if _name(item).lower() == expected_name:
            return item
    return None


def _get_component_class(module, class_name):
    cls = getattr(module, class_name, None)
    if cls is not None:
        return cls
    pytest.fail(f"Required component class not found: {class_name}", pytrace=False)


def _new_component(module, class_name):
    cls = _get_component_class(module, class_name)
    try:
        return cls(None)
    except Exception:
        app = getattr(module, "Application", None)
        if app is not None:
            return cls(app)
        raise


def _assert_type_details(rtti_type):
    assert isinstance(rtti_type.Name, str) and rtti_type.Name
    unit_name = getattr(rtti_type, "DeclaringUnitName", None)
    if unit_name is None and hasattr(rtti_type, "UnitName"):
        try:
            unit_name = rtti_type.UnitName()
        except TypeError:
            unit_name = rtti_type.UnitName
    if unit_name is not None:
        assert isinstance(unit_name, str)
    assert rtti_type.TypeKind is not None
    assert isinstance(_get_attributes(rtti_type), list)


def _assert_parameter_details(parameter):
    assert isinstance(parameter.Name, str) and parameter.Name
    assert parameter.Flags is not None
    assert isinstance(_get_attributes(parameter), list)
    if parameter.ParamType is not None:
        _assert_type_details(parameter.ParamType)


def _assert_method_details(method, require_arguments=False):
    assert isinstance(method.Name, str) and method.Name
    assert method.Visibility is not None
    assert method.MethodKind is not None
    assert isinstance(method.IsClassMethod, bool)
    assert isinstance(method.IsStatic, bool)
    assert method.CallingConvention is not None
    assert isinstance(_get_attributes(method), list)

    parameters = _get_parameters(method)
    assert isinstance(parameters, list)
    if require_arguments:
        assert len(parameters) > 0
    for parameter in parameters[:2]:
        _assert_parameter_details(parameter)

    if method.ReturnType is not None:
        _assert_type_details(method.ReturnType)


def _assert_property_details(prop):
    assert isinstance(prop.Name, str) and prop.Name
    assert prop.Visibility is not None
    assert isinstance(prop.IsReadable, bool)
    assert isinstance(prop.IsWritable, bool)
    assert isinstance(_get_attributes(prop), list)
    if prop.PropertyType is not None:
        nested_type = prop.PropertyType
        _assert_type_details(nested_type)
        nested_methods = _get_methods(nested_type)
        nested_properties = _get_properties(nested_type)
        assert isinstance(nested_methods, list)
        assert isinstance(nested_properties, list)
        if nested_properties:
            assert isinstance(nested_properties[0].Name, str) and nested_properties[0].Name


def _assert_component_rtti(rtti_type, preferred_methods, preferred_properties):
    _assert_type_details(rtti_type)

    methods = _get_methods(rtti_type)
    properties = _get_properties(rtti_type)
    assert len(methods) > 0
    assert len(properties) > 0

    chosen_method = None
    for name in preferred_methods:
        chosen_method = _find_by_name(methods, name)
        if chosen_method is not None:
            break
    if chosen_method is None:
        chosen_method = methods[0]
    _assert_method_details(chosen_method)

    # Explicitly validate arguments on a method that has parameters.
    method_with_arguments = next((m for m in methods if len(_get_parameters(m)) > 0), None)
    if method_with_arguments is not None:
        _assert_method_details(method_with_arguments, require_arguments=True)

    chosen_property = None
    for name in preferred_properties:
        chosen_property = _find_by_name(properties, name)
        if chosen_property is not None:
            break
    if chosen_property is None:
        chosen_property = properties[0]
    _assert_property_details(chosen_property)

def _get_component_by_kind(module, kind, class_name):
    if kind == "instance":
        return _new_component(module, class_name)
    else:
        return _get_component_class(module, class_name)


@pytest.mark.skipif(not IS_WINDOWS, reason="VCL is checked only on Windows")
class TestVCL:
    @pytest.mark.parametrize("case", VCL_COMPONENT_CASES, ids=lambda c: f'basic-{c["expected"]}')
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_basic_lookup(self, rtti_module, vcl_module, case, input_kind):
        value = _get_component_by_kind(vcl_module, input_kind, case["class_name"])

        rtti_type = rtti_module.get_type_rtti(value)
        assert _name(rtti_type) == case["expected"]
        _assert_type_details(rtti_type)

    @pytest.mark.parametrize("case", VCL_COMPONENT_CASES, ids=lambda c: f'extended-{c["expected"]}')
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_component_rtti(self, rtti_module, vcl_module, case, input_kind):
        component = _get_component_by_kind(vcl_module, input_kind, case["class_name"])
        rtti_type = rtti_module.get_type_rtti(component)
        assert _name(rtti_type) == case["expected"]
        _assert_component_rtti(rtti_type, case["method_names"], case["property_names"])


class TestFMX:
    @pytest.mark.parametrize("case", FMX_COMPONENT_CASES, ids=lambda c: f'basic-{c["expected"]}')
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_basic_lookup(self, rtti_module, fmx_module, case, input_kind):
        value = _get_component_by_kind(fmx_module, input_kind, case["class_name"])

        rtti_type = rtti_module.get_type_rtti(value)
        assert _name(rtti_type) == case["expected"]
        _assert_type_details(rtti_type)

    @pytest.mark.parametrize("case", FMX_COMPONENT_CASES, ids=lambda c: f'extended-{c["expected"]}')
    @pytest.mark.parametrize("input_kind", ("instance", "class"))
    def test_component_rtti(self, rtti_module, fmx_module, case, input_kind):
        component = _get_component_by_kind(fmx_module, input_kind, case["class_name"])
        rtti_type = rtti_module.get_type_rtti(component)
        assert _name(rtti_type) == case["expected"]
        _assert_component_rtti(rtti_type, case["method_names"], case["property_names"])


class TestEdgeCases:
    def test_invalid_argument(self, rtti_module):
        with pytest.raises(TypeError):
            rtti_module.get_type_rtti(12345)
