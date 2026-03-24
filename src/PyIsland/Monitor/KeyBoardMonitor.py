import keyboard
import asyncio

from PyIsland.EventBus.Bus import EventManager
from PyIsland.Pluging.Screenshot import ScreenshotOCR


class  KeyBoardMonitor:
    Screenshotter = ScreenshotOCR()
    MAP = {
        "SCREENSHOT" : {
            "key": "ctrl+shift+z",
            "callback": Screenshotter.capture_and_overlay
        },
    }
    def __init__(self, event_manager: EventManager):
        self.event_manager = event_manager
        self.register()

    def register(self):
        for _, action in self.MAP.items():
            keyboard.add_hotkey(action["key"], action["callback"])

    @staticmethod
    async def run():
        while True:
            await asyncio.sleep(0.2)
