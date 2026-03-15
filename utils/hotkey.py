import keyboard
from PySide6.QtCore import QObject, Signal

class HotkeyMonitor(QObject):
    hotkey_pressed = Signal()

    def __init__(self, hotkey="alt+o"):
        super().__init__()
        try:
            keyboard.add_hotkey(hotkey, self._on_pressed)
        except Exception as e:
            print(f"Hotkey Error: {e}")

    def _on_pressed(self):
        self.hotkey_pressed.emit()
