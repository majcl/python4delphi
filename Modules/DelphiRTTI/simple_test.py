

"""Simple test for DelphiRTTI module."""

from pathlib import Path
import sys

import delphivcl as vcl
import delphifmx as fmx

# import the DelphiRTTI module from specific path
delphirtti_path = Path(__file__).parent / 'pyd' / 'Win64' / 'Debug' / 'DelphiRTTI.pyd'
if not delphirtti_path.exists():
    raise FileNotFoundError(f"DelphiRTTI.pyd not found at {delphirtti_path}")


delphirtti_path = str(delphirtti_path.parent)
if delphirtti_path not in sys.path:
    sys.path.insert(0, delphirtti_path)
    print(f"Adding {delphirtti_path} to sys.path -> {sys.path}\n\n")


import DelphiRTTI as rtti


def rtti_get_type(ev_obj):
    """ Call DelphiRTTI.get_type function on any object, so we can test various scenarios"""

    # Detailed log of the argument and its value, so that we can see what is being passed to the Delphi function
    print(f"[rtti_get_type] Argument: {ev_obj!r} (type: {type(ev_obj).__name__})")
    rtti_type = rtti.get_type(ev_obj)
    # print(f"[rtti_get_type] Result: {rtti_type!r} (type: {type(rtti_type).__name__})")
    # return rtti_type




class DummyClass:
    pass

class DummyFmxForm(fmx.Form):
    pass

class DummyVclForm(vcl.Form):
    pass




rtti_get_type(1)
rtti_get_type(True)
rtti_get_type('Hello, World!')
rtti_get_type(None)

rtti_get_type(DummyClass)
rtti_get_type(DummyClass())

rtti_get_type('System.TObject')
rtti_get_type('Vcl.Forms.TForm')

rtti_get_type(vcl.Object)
rtti_get_type(vcl.Form)
rtti_get_type(vcl.Form(None))
rtti_get_type(DummyVclForm)
rtti_get_type(DummyVclForm(None))


# rtti_get_type('FMX.Forms.TForm')
# rtti_get_type(fmx.Form)
# rtti_get_type(fmx.Form(None))
# rtti_get_type(DummyFmxForm)
# rtti_get_type(DummyFmxForm(None))


# rtti_get_type('System.TButton')
# rtti_get_type(vcl.Button)
# rtti_get_type(vcl.Button(None))

print(' ------------------ DONE -------------------')
