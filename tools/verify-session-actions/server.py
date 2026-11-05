import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import sys

if os.environ.get('GITHUB_ACTIONS') != 'true' or os.name != 'nt':
    raise RuntimeError('Hosted Windows only')
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.CreateEventW.argtypes = (wintypes.LPVOID, wintypes.BOOL, wintypes.BOOL, wintypes.LPCWSTR)
kernel.CreateEventW.restype = wintypes.HANDLE
kernel.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
event = kernel.CreateEventW(None, True, False, sys.argv[1])
if not event:
    raise ctypes.WinError(ctypes.get_last_error())
try:
    Path(sys.argv[2]).write_text(json.dumps(dict(pid=os.getpid(), ready=True)), encoding='utf-8')
    if kernel.WaitForSingleObject(event, 1800000) != 0:
        raise RuntimeError('Synthetic agent stop timed out')
finally:
    kernel.CloseHandle(event)
