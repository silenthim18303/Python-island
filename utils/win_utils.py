import ctypes
from ctypes import wintypes

# Windows API Constants
GWL_EXSTYLE = -20
WS_EX_LAYERED = 0x00080000
WS_EX_TRANSPARENT = 0x00000020

class ACCENT_POLICY(ctypes.Structure):
    _fields_ = [
        ("AccentState", ctypes.c_int),
        ("AccentFlags", ctypes.c_int),
        ("GradientColor", ctypes.c_int),
        ("AnimationId", ctypes.c_int),
    ]

class WINDOWCOMPOSITIONATTRIBDATA(ctypes.Structure):
    _fields_ = [
        ("Attribute", ctypes.c_int),
        ("Data", ctypes.POINTER(ACCENT_POLICY)),
        ("SizeOfData", ctypes.c_size_t),
    ]

def set_blur(hwnd, color=0x00000000):
    """
    Enables Acrylic/Blur effect on Windows 10/11.
    color: 0xAABBGGRR
    """
    accent = ACCENT_POLICY()
    accent.AccentState = 3  # ACCENT_ENABLE_BLURBEHIND or 4 for ACYRLIC
    accent.AccentFlags = 2
    accent.GradientColor = color # 0xCCFFFFFF for white tint, etc.

    data = WINDOWCOMPOSITIONATTRIBDATA()
    data.Attribute = 19  # WCA_ACCENT_POLICY
    data.Data = ctypes.pointer(accent)
    data.SizeOfData = ctypes.sizeof(accent)

    ctypes.windll.user32.SetWindowCompositionAttribute(hwnd, ctypes.pointer(data))

def set_mouse_passthrough(hwnd):
    """
    Makes the window transparent to mouse events (clicks pass through it).
    """
    style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT)

def unset_mouse_passthrough(hwnd):
    """
    Restores normal mouse events to the window.
    """
    style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style & ~WS_EX_TRANSPARENT)
