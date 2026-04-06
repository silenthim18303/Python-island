import asyncio
import time

import keyboard
from PySide6.QtCore import QThread, Signal
import importlib
_ss = importlib.import_module("method.screenshot.screenshot_with_key")
ScreenshotOCR = getattr(_ss, "ScreenshotOCR")

STATUS_POLL_INTERVAL_SECONDS = 2

class KeyboardMonitor(QThread):
    bluetooth_updated = Signal(dict)
    MAP = {
        "SCREENSHOT" : {
            "key": "ctrl+shift+z",
            "callback": ScreenshotOCR().capture_and_overlay
        },
    }

    def __init__(self) -> None:
        super().__init__()
        self.running = True
        self.register()

    def run(self) -> None:
        while self.running:
            time.sleep(STATUS_POLL_INTERVAL_SECONDS/10)

    def stop(self) -> None:
        self.running = False

    def register(self):
        for _, action in self.MAP.items():
            keyboard.add_hotkey(action["key"], action["callback"])
