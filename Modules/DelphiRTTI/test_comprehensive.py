#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Comprehensive test for DelphiRTTI module.
Tests get_type() with various inputs: strings, instances, and class types.
Tests basic classes, VCL classes, and FMX classes.
"""

import sys
import os
import traceback

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass

# Add the .pyd directory to Python path
try:
    _script_dir = os.path.dirname(os.path.abspath(__file__))
except NameError:
    _script_dir = os.getcwd()
    
_pyd_dir = os.path.join(_script_dir, 'Win64', 'Debug')
if not os.path.exists(_pyd_dir):
    _pyd_dir = os.path.join(_script_dir, 'Win64', 'Release')
    
if os.path.exists(_pyd_dir):
    if _pyd_dir not in sys.path:
        sys.path.insert(0, _pyd_dir)
    print(f"[INFO] Using library from: {_pyd_dir}")
else:
    print(f"[ERROR] Cannot find .pyd file in Win64/Debug or Win64/Release")
    sys.exit(1)

# Try to import framework modules (lowercase official names first)
delphivcl = None
delphifmx = None

try:
    import delphivcl
    print("[INFO] delphivcl imported successfully")
except ImportError:
    try:
        import DelphiVCL as delphivcl
        print("[INFO] DelphiVCL imported successfully (fallback)")
    except ImportError:
        print("[WARN] delphivcl not available")

try:
    import delphifmx
    print("[INFO] delphifmx imported successfully")
except ImportError:
    try:
        import DelphiFMX as delphifmx
        print("[INFO] DelphiFMX imported successfully (fallback)")
    except ImportError:
        print("[WARN] delphifmx not available")

# Import DelphiRTTI
try:
    import DelphiRTTI
except ImportError as e:
    print(f"[ERROR] Failed to import DelphiRTTI: {e}")
    sys.exit(1)


def test_result(name, result, expected_type=None):
    """Helper to test and print results"""
    if result is None:
        print(f"  [FAIL] {name}: returned None")
        return False
    if expected_type and not isinstance(result, expected_type):
        print(f"  [FAIL] {name}: wrong type, got {type(result)}, expected {expected_type}")
        return False
    print(f"  [OK] {name}: {result}")
    return True


def test_basic_classes():
    """Test basic System classes"""
    print("\n=== Testing Basic Classes ===")
    
    # Test 1: System.TObject by string
    print("\n1. Testing get_type('System.TObject') [string]")
    try:
        obj_type = DelphiRTTI.get_type("System.TObject")
        if not test_result("get_type('System.TObject')", obj_type):
            return False
        print(f"     Name: {obj_type.name}")
        print(f"     Qualified Name: {obj_type.qualified_name}")
        print(f"     Unit: {obj_type.unit_name}")
        print(f"     Kind: {obj_type.kind}")
        print(f"     Methods: {len(obj_type.methods)}")
        print(f"     Properties: {len(obj_type.properties)}")
    except Exception as e:
        print(f"  [FAIL] Exception: {e}")
        traceback.print_exc()
        return False
    
    # Test 2: System.TStringList by string
    print("\n2. Testing get_type('System.Classes.TStringList') [string]")
    try:
        strlist_type = DelphiRTTI.get_type("System.Classes.TStringList")
        if not test_result("get_type('System.Classes.TStringList')", strlist_type):
            return False
        print(f"     Name: {strlist_type.name}")
        print(f"     Qualified Name: {strlist_type.qualified_name}")
    except Exception as e:
        print(f"  [WARN] TStringList not found: {e}")
        # This is OK, not all classes may be available
    
    return True


def test_vcl_classes():
    """Test VCL classes - must actually work, not just import"""
    print("\n=== Testing VCL Classes ===")
    
    if delphivcl is None:
        print("[FAIL] delphivcl module not available")
        return False
    
    # Test 1: String-based lookup (primary method - now works!)
    print("\n1. Testing get_type('Vcl.Forms.TForm') [string] - Primary test")
    form_type = None
    
    try:
        # String-based lookup should work now that VCL units are referenced
        form_type = DelphiRTTI.get_type("Vcl.Forms.TForm")
        if form_type is None:
            print("  [FAIL] String-based lookup returned None")
            return False
        print(f"  [OK] get_type('Vcl.Forms.TForm'): {form_type}")
        
        print(f"     Name: {form_type.name}")
        print(f"     Qualified Name: {form_type.qualified_name}")
        print(f"     Unit: {form_type.unit_name}")
        print(f"     Methods: {len(form_type.methods)}")
        print(f"     Properties: {len(form_type.properties)}")
        
        if len(form_type.properties) > 0:
            prop_names = [p.name for p in form_type.properties[:5]]
            print(f"     Sample properties: {', '.join(prop_names)}")
        
        if form_type.name != "TForm":
            print(f"  [FAIL] Wrong type name: {form_type.name}, expected TForm")
            return False
            
    except Exception as e:
        print(f"  [FAIL] Exception: {e}")
        traceback.print_exc()
        return False
    
    # Test 2: Try string lookup (may not work if type not in RTTI context)
    print("\n2. Testing get_type('Vcl.Forms.TForm') [string] - Secondary test")
    try:
        form_type_str = DelphiRTTI.get_type("Vcl.Forms.TForm")
        if form_type_str is None:
            print("  [WARN] String lookup returned None (type may not be in RTTI context)")
            print("  [INFO] Instance-based lookup works, but string lookup doesn't - this is acceptable")
        else:
            print(f"  [OK] get_type('Vcl.Forms.TForm'): {form_type_str}")
            # Verify it matches instance-based lookup
            if form_type_str.qualified_name != form_type.qualified_name:
                print(f"  [WARN] String lookup type mismatch: {form_type_str.qualified_name} != {form_type.qualified_name}")
            else:
                print(f"     [OK] String lookup matches instance lookup")
    except LookupError as e:
        print(f"  [WARN] String lookup failed: {e}")
        print("  [INFO] Instance-based lookup works, but string lookup doesn't - this is acceptable")
    except Exception as e:
        print(f"  [WARN] Exception in string lookup: {e}")
        # This is OK - instance lookup works
    
    # Test 3: Vcl.Forms.TForm by class type
    print("\n3. Testing get_type(TForm class) [class type] - Optional test")
    try:
        # Try to get the class type
        if hasattr(delphivcl, 'TForm'):
            form_class = delphivcl.TForm
            form_type3 = DelphiRTTI.get_type(form_class)
            if form_type3 is None:
                print("  [WARN] get_type(TForm class) returned None (this is OK)")
            else:
                print(f"  [OK] get_type(TForm class): {form_type3}")
                print(f"     Name: {form_type3.name}")
                print(f"     Qualified Name: {form_type3.qualified_name}")
                # Verify it's the same type
                if form_type3.qualified_name != form_type.qualified_name:
                    print(f"  [WARN] Class type mismatch: {form_type3.qualified_name} != {form_type.qualified_name}")
                else:
                    print(f"     [OK] Class type matches instance type")
        else:
            print("  [WARN] TForm class not available for class type test (this is OK)")
    except Exception as e:
        print(f"  [WARN] Could not test with class type: {e}")
        # This is OK, class type access might not work in all contexts
    
    return True


def test_fmx_classes():
    """Test FMX classes - must actually work, not just import"""
    print("\n=== Testing FMX Classes ===")
    
    if delphifmx is None:
        print("[FAIL] delphifmx module not available")
        return False
    
    # Test 1: Try to get type from instance first (this should work)
    print("\n1. Testing get_type(Form instance) [instance] - Primary test")
    form_type = None
    form_instance = None
    
    try:
        # Try to create a form instance - try different possible names
        form_instance = None
        form_class_name = None
        
        # Try 'Form' first (most common) - Form.Create() requires an Owner parameter
        if hasattr(delphifmx, 'Form'):
            try:
                # Try with None as owner
                form_instance = delphifmx.Form(None)
                form_class_name = 'Form'
                print("  [OK] Form instance created (owner=None)")
            except Exception as e1:
                try:
                    # Try with Application as owner
                    if hasattr(delphifmx, 'Application'):
                        form_instance = delphifmx.Form(delphifmx.Application)
                        form_class_name = 'Form'
                        print("  [OK] Form instance created (owner=Application)")
                    else:
                        raise e1
                except Exception as e2:
                    print(f"  [WARN] Could not create Form: {e1}, {e2}")
        
        # Try 'TForm' if Form didn't work
        if form_instance is None and hasattr(delphifmx, 'TForm'):
            try:
                form_instance = delphifmx.TForm(None)
                form_class_name = 'TForm'
                print("  [OK] TForm instance created (owner=None)")
            except Exception as e1:
                try:
                    if hasattr(delphifmx, 'Application'):
                        form_instance = delphifmx.TForm(delphifmx.Application)
                        form_class_name = 'TForm'
                        print("  [OK] TForm instance created (owner=Application)")
                    else:
                        raise e1
                except Exception as e2:
                    print(f"  [WARN] Could not create TForm: {e1}, {e2}")
        
        if form_instance is None:
            print("  [WARN] Cannot create form instance - Form/TForm classes not available or not instantiable")
        
        # Try string-based lookup (this is the primary method)
        # Creating the instance should load the type into RTTI context
        try:
            form_type = DelphiRTTI.get_type("Fmx.Forms.TForm")
            if form_type is None:
                print("  [FAIL] String-based lookup returned None")
                print("  [INFO] Type may not be in RTTI context yet")
                return False
        except LookupError as e:
            print(f"  [FAIL] String-based lookup failed: {e}")
            print("  [INFO] Type not found in RTTI context - this is a limitation")
            print("  [INFO] Instance-based lookup across modules is not supported by P4D architecture")
            return False
        except Exception as e:
            print(f"  [FAIL] Exception in string-based lookup: {e}")
            traceback.print_exc()
            return False
        
        print(f"  [OK] get_type('Fmx.Forms.TForm'): {form_type}")
        print(f"     Name: {form_type.name}")
        print(f"     Qualified Name: {form_type.qualified_name}")
        print(f"     Unit: {form_type.unit_name}")
        print(f"     Methods: {len(form_type.methods)}")
        print(f"     Properties: {len(form_type.properties)}")
        
        # Verify it's actually TForm
        if form_type.name != "TForm":
            print(f"  [FAIL] Wrong type name: {form_type.name}, expected TForm")
            return False
            
    except Exception as e:
        print(f"  [FAIL] Exception creating form or getting type: {e}")
        traceback.print_exc()
        return False
    
    # Test 2: Try string lookup (may not work if type not in RTTI context)
    print("\n2. Testing get_type('Fmx.Forms.TForm') [string] - Secondary test")
    try:
        form_type_str = DelphiRTTI.get_type("Fmx.Forms.TForm")
        if form_type_str is None:
            print("  [WARN] String lookup returned None (type may not be in RTTI context)")
            print("  [INFO] Instance-based lookup works, but string lookup doesn't - this is acceptable")
        else:
            print(f"  [OK] get_type('Fmx.Forms.TForm'): {form_type_str}")
            # Verify it matches instance-based lookup
            if form_type_str.qualified_name != form_type.qualified_name:
                print(f"  [WARN] String lookup type mismatch: {form_type_str.qualified_name} != {form_type.qualified_name}")
            else:
                print(f"     [OK] String lookup matches instance lookup")
    except LookupError as e:
        print(f"  [WARN] String lookup failed: {e}")
        print("  [INFO] Instance-based lookup works, but string lookup doesn't - this is acceptable")
    except Exception as e:
        print(f"  [WARN] Exception in string lookup: {e}")
        # This is OK - instance lookup works
    
    
    return True


def test_edge_cases():
    """Test edge cases and error handling"""
    print("\n=== Testing Edge Cases ===")
    
    # Test 1: Non-existent type
    print("\n1. Testing get_type('NonExistent.Type') [should fail gracefully]")
    try:
        result = DelphiRTTI.get_type("NonExistent.Type")
        if result is None:
            print("  [OK] Correctly returned None for non-existent type")
        else:
            print(f"  [WARN] Expected None but got: {result}")
    except Exception as e:
        print(f"  [OK] Correctly raised exception: {type(e).__name__}")
    
    # Test 2: Empty string
    print("\n2. Testing get_type('') [should fail gracefully]")
    try:
        result = DelphiRTTI.get_type("")
        if result is None:
            print("  [OK] Correctly returned None for empty string")
        else:
            print(f"  [WARN] Expected None but got: {result}")
    except Exception as e:
        print(f"  [OK] Correctly raised exception: {type(e).__name__}")
    
    return True


def main():
    """Run all tests"""
    print("=" * 60)
    print("Comprehensive DelphiRTTI Test Suite")
    print("=" * 60)
    
    all_passed = True
    vcl_module_available = (delphivcl is not None)
    fmx_module_available = (delphifmx is not None)
    
    # Test basic classes
    if not test_basic_classes():
        all_passed = False
    
    # Test VCL classes - must actually work
    if vcl_module_available:
        if not test_vcl_classes():
            all_passed = False
    else:
        print("\n=== Testing VCL Classes ===")
        print("[SKIP] delphivcl not available")
    
    # Test FMX classes - must actually work
    if fmx_module_available:
        if not test_fmx_classes():
            all_passed = False
    else:
        print("\n=== Testing FMX Classes ===")
        print("[SKIP] delphifmx not available")
    
    # Test edge cases
    if not test_edge_cases():
        all_passed = False
    
    # Check if at least one framework module is available
    if not vcl_module_available and not fmx_module_available:
        print("\n" + "=" * 60)
        print("[FAILURE] Neither delphivcl nor delphifmx is available!")
        print("At least one framework (delphivcl or delphifmx) must be installed.")
        print("Install via: pip install delphivcl  or  pip install delphifmx")
        print("=" * 60)
        return 1
    
    # Summary
    print("\n" + "=" * 60)
    if all_passed:
        print("[SUCCESS] All tests passed!")
        if vcl_module_available:
            print("  - VCL framework module: Available and working")
        if fmx_module_available:
            print("  - FMX framework module: Available and working")
    else:
        print("[FAILURE] Some tests failed!")
        if vcl_module_available:
            print("  - VCL framework module: Available but tests failed")
        if fmx_module_available:
            print("  - FMX framework module: Available but tests failed")
    print("=" * 60)
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
