"""Windows-only black-box input driver; no game scripts or editor in the process."""
import ctypes
from ctypes import wintypes
import time


class Window:
    def __init__(self, process, timeout=20):
        self.process = process
        self.api = ctypes.windll.user32
        self.api.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
        self.api.PostMessageW.restype = wintypes.BOOL
        self.api.SetProcessDPIAware()
        self.handle = None
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def visit(handle, _):
            pid = wintypes.DWORD()
            self.api.GetWindowThreadProcessId(handle, ctypes.byref(pid))
            if pid.value == process.pid and self.api.IsWindowVisible(handle): self.handle = handle
            return True
        callback = callback_type(visit)
        deadline = time.monotonic() + timeout
        while not self.handle and time.monotonic() < deadline:
            if process.poll() is not None: raise RuntimeError('Game exited before creating its window')
            self.api.EnumWindows(callback, 0)
            time.sleep(.1)
        if not self.handle: raise RuntimeError('No visible exported game window')

    def rect(self):
        rect = wintypes.RECT()
        self.api.GetClientRect(self.handle, ctypes.byref(rect))
        return rect

    def click(self, x, y, delay=.35):
        rect = self.rect()
        scale = min(rect.right / 1920, rect.bottom / 1080)
        px = round((rect.right - 1920 * scale) / 2 + x * scale)
        py = round((rect.bottom - 1080 * scale) / 2 + y * scale)
        point = (py << 16) | px
        self.api.PostMessageW(self.handle, 0x200, 0, point)
        self.api.PostMessageW(self.handle, 0x201, 1, point)
        time.sleep(.05)
        self.api.PostMessageW(self.handle, 0x202, 0, point)
        time.sleep(delay)
