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

if os.name == "nt" and os.environ.get("CHAT_MODEL_PROOF") == "1":
    import select
    import selectors
    import socket
    import sys
    import tempfile
    import time
    import types

    if not hasattr(socket, "AF_UNIX"):
        socket.AF_UNIX = 0x7FFE
        _socket = socket.socket

        class FixtureSocket(_socket):
            def __init__(self, family=socket.AF_INET, type=socket.SOCK_STREAM, proto=0, fileno=None):
                self.fixture_unix = family == socket.AF_UNIX
                super().__init__(socket.AF_INET if self.fixture_unix else family, type, proto, fileno)

            def bind(self, address):
                if not self.fixture_unix:
                    return super().bind(address)
                super().bind(("127.0.0.1", 0))
                with open(address, "w", encoding="ascii") as target:
                    target.write(str(self.getsockname()[1]))

            def connect(self, address):
                if self.fixture_unix:
                    with open(address, encoding="ascii") as source:
                        address = ("127.0.0.1", int(source.read()))
                return super().connect(address)

        socket.socket = FixtureSocket

    tempfile.tempdir = os.environ["MP_VERIFY_SOCKET_TEMP"]
    _kill = os.kill
    _kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    _kernel.OpenProcess.restype = wintypes.HANDLE
    _kernel.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
    _kernel.GetExitCodeProcess.restype = wintypes.BOOL

    def safe_kill(pid, sig):
        if sig != 0:
            return _kill(pid, sig)
        process = _kernel.OpenProcess(0x1000, False, pid)
        if not process:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            code = wintypes.DWORD()
            if not _kernel.GetExitCodeProcess(process, ctypes.byref(code)):
                raise ctypes.WinError(ctypes.get_last_error())
            if code.value != 259:
                raise ProcessLookupError(pid)
        finally:
            _kernel.CloseHandle(process)

    os.kill = safe_kill
    fcntl = types.ModuleType("fcntl")
    fcntl.LOCK_EX, fcntl.LOCK_NB, fcntl.LOCK_UN = 2, 4, 8

    def flock(handle, operation):
        descriptor = handle if isinstance(handle, int) else handle.fileno()
        os.lseek(descriptor, 0, os.SEEK_SET)
        mode = msvcrt.LK_UNLCK if operation & fcntl.LOCK_UN else msvcrt.LK_NBLCK if operation & fcntl.LOCK_NB else msvcrt.LK_LOCK
        try:
            msvcrt.locking(descriptor, mode, 1)
        except OSError as error:
            if operation & fcntl.LOCK_NB:
                raise BlockingIOError() from error
            raise

    fcntl.flock = flock
    sys.modules["fcntl"] = fcntl
    _kernel.PeekNamedPipe.argtypes = (wintypes.HANDLE, wintypes.LPVOID, wintypes.DWORD, wintypes.LPVOID, ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID)
    _kernel.PeekNamedPipe.restype = wintypes.BOOL

    class FixtureSelector(selectors._BaseSelectorImpl):
        def select(self, timeout=None):
            deadline = None if timeout is None else time.monotonic() + max(timeout, 0)
            while True:
                keys = list(self.get_map().values())
                sockets = [key for key in keys if isinstance(key.fileobj, socket.socket)]
                ready = []
                if sockets:
                    reads, _, _ = select.select([key.fileobj for key in sockets], [], [], 0)
                    ready.extend((key, selectors.EVENT_READ) for key in sockets if key.fileobj in reads)
                for key in keys:
                    if key in sockets:
                        continue
                    available = wintypes.DWORD()
                    handle = msvcrt.get_osfhandle(key.fd)
                    if _kernel.PeekNamedPipe(handle, None, 0, None, ctypes.byref(available), None):
                        if available.value:
                            ready.append((key, selectors.EVENT_READ))
                    elif ctypes.get_last_error() == 109:
                        ready.append((key, selectors.EVENT_READ))
                    else:
                        raise ctypes.WinError(ctypes.get_last_error())
                if ready or deadline is not None and time.monotonic() >= deadline:
                    return ready
                time.sleep(min(0.05, max(0, deadline - time.monotonic())) if deadline is not None else 0.05)

    selectors.DefaultSelector = FixtureSelector
