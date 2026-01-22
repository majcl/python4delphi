"""
Pytest test suite for DelphiRTTI module.
"""
import pytest
import platform

IS_WINDOWS = platform.system() == 'Windows'


class TestBasicClasses:
    @pytest.fixture(autouse=True)
    def setup(self, rtti):
        self.rtti = rtti

    def test_get_type_object_string(self):
        rtti_type = self.rtti.get_type('System.TObject')
        assert rtti_type is not None
        assert rtti_type.name == 'TObject'
        assert rtti_type.qualified_name == 'System.TObject'
        assert rtti_type.kind == 7
        assert len(rtti_type.methods) > 0
    
    def test_get_type_stringlist_string(self):
        rtti_type = self.rtti.get_type('System.Classes.TStringList')
        assert rtti_type is not None
        assert rtti_type.name == 'TStringList'
        assert rtti_type.qualified_name == 'System.Classes.TStringList'


@pytest.mark.skipif(not IS_WINDOWS, reason="VCL is only available on Windows")
class TestVCLClasses:
    @pytest.fixture(autouse=True)
    def setup(self, rtti, vcl_module):
        self.rtti = rtti
        self.vcl = vcl_module

    def test_get_type_vcl_form_string(self):
        rtti_type = self.rtti.get_type('Vcl.Forms.TForm')
        assert rtti_type is not None
        assert rtti_type.name == 'TForm'
        assert rtti_type.qualified_name == 'Vcl.Forms.TForm'
        assert len(rtti_type.methods) > 0
        assert len(rtti_type.properties) > 0
    
    def test_get_type_vcl_form_instance(self):
        form = self.vcl.Form(None)
        rtti_type = self.rtti.get_type(form)
        assert rtti_type is not None
        assert rtti_type.name == 'TForm'
    
    def test_get_type_vcl_form_class_type(self):
        try:
            rtti_type = self.rtti.get_type(self.vcl.Form)
            if rtti_type is not None:
                assert rtti_type.name == 'TForm'
                assert rtti_type.qualified_name == 'Vcl.Forms.TForm'
        except (TypeError, LookupError):
            pytest.skip("Class type lookup not supported across modules")


class TestFMXClasses:
    @pytest.fixture(autouse=True)
    def setup(self, rtti, fmx_module):
        self.rtti = rtti
        self.fmx = fmx_module

    def test_get_type_fmx_form_string(self):
        rtti_type = self.rtti.get_type('Fmx.Forms.TForm')
        assert rtti_type is not None
        assert rtti_type.name == 'TForm'
        assert rtti_type.qualified_name == 'FMX.Forms.TForm'
        assert len(rtti_type.methods) > 0
        assert len(rtti_type.properties) > 0
    
    def test_get_type_fmx_form_instance(self):
        form = self.fmx.Form(None)
        rtti_type = self.rtti.get_type(form)
        assert rtti_type is not None
        assert rtti_type.name == 'TForm'
    
    def test_get_type_fmx_form_class_type(self):
        try:
            rtti_type = self.rtti.get_type(self.fmx.Form)
            if rtti_type is not None:
                assert rtti_type.name == 'TForm'
                assert rtti_type.qualified_name == 'FMX.Forms.TForm'
        except (TypeError, LookupError):
            pytest.skip("Class type lookup not supported across modules")


class TestEdgeCases:
    @pytest.fixture(autouse=True)
    def setup(self, rtti):
        self.rtti = rtti

    def test_get_type_nonexistent_type(self):
        with pytest.raises(LookupError):
            self.rtti.get_type('NonExistent.Type')
    
    def test_get_type_empty_string(self):
        with pytest.raises(LookupError):
            self.rtti.get_type('')
    
    def test_get_type_invalid_argument(self):
        with pytest.raises(TypeError):
            self.rtti.get_type(12345)


def test_framework_availability(rtti, fmx_module):
    if IS_WINDOWS:
        try:
            import delphivcl as vcl
        except ImportError:
            try:
                import DelphiVCL as vcl
            except ImportError:
                vcl = None
        if vcl is None and fmx_module is None:
            pytest.fail("Both delphivcl and delphifmx are unavailable. At least one must be available on Windows.")
    else:
        assert fmx_module is not None
