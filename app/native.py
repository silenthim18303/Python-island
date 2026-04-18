import ctypes
import sys

from PySide6.QtWidgets import QWidget


def apply_native_window_fixes(widget: QWidget) -> None:
    if sys.platform != "win32":
        return

    try:
        hwnd = int(widget.winId())
        dwmapi = getattr(ctypes.windll, "dwmapi", None)
        if dwmapi is None:
            return

        nc_rendering_policy_attr = 2
        nc_rendering_disabled = 1
        corner_preference_attr = 33
        corner_do_not_round = 1
        border_color_attr = 34
        border_color_none = 0xFFFFFFFE

        dwmapi.DwmSetWindowAttribute(
            hwnd,
            nc_rendering_policy_attr,
            ctypes.byref(ctypes.c_int(nc_rendering_disabled)),
            ctypes.sizeof(ctypes.c_int),
        )
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            corner_preference_attr,
            ctypes.byref(ctypes.c_int(corner_do_not_round)),
            ctypes.sizeof(ctypes.c_int),
        )
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            border_color_attr,
            ctypes.byref(ctypes.c_uint(border_color_none)),
            ctypes.sizeof(ctypes.c_uint),
        )
    except Exception:
        pass
