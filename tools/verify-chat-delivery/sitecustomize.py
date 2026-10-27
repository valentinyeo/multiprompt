import builtins
import io
import os


if os.name == "nt":
    import ctypes
    from ctypes import wintypes
    import msvcrt

    _open = io.open
    _kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    _kernel.CreateFileW.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE)
    _kernel.CreateFileW.restype = wintypes.HANDLE
    _kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
    _kernel.CloseHandle.restype = wintypes.BOOL

    def shared_opener(file, flags):
        handle = _kernel.CreateFileW(os.fsdecode(file), 0x80000000, 1 | 2 | 4, None, 3, 0x80, None)
        if handle == wintypes.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            return msvcrt.open_osfhandle(handle, os.O_RDONLY | os.O_BINARY)
        except BaseException:
            _kernel.CloseHandle(handle)
            raise

    def shared_open(file, mode="r", buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None):
        if (isinstance(file, int) or mode not in ("r", "rt", "rb") or not closefd or opener is not None
                or not os.fsdecode(file).lower().endswith(".jsonl")):
            return _open(file, mode, buffering, encoding, errors, newline, closefd, opener)
        return _open(file, mode, buffering, encoding, errors, newline, True, shared_opener)

    builtins.open = io.open = shared_open
