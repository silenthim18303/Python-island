import pyperclip
import re
from PySide6.QtCore import QObject, Signal, QTimer

class ClipboardMonitor(QObject):
    link_copied = Signal(str)

    def __init__(self):
        super().__init__()
        self.last_clipboard = ""
        self.timer = QTimer()
        self.timer.timeout.connect(self.check_clipboard)
        self.timer.start(1000)

        # URL regex
        self.url_pattern = re.compile(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+')

    def check_clipboard(self):
        try:
            current_clipboard = pyperclip.paste()
            if current_clipboard != self.last_clipboard:
                self.last_clipboard = current_clipboard
                links = self.url_pattern.findall(current_clipboard)
                if links:
                    self.link_copied.emit(links[0])
        except:
            pass
