import json
import os
import subprocess
import sys

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QDesktopServices


class BrowserBackend(QObject):

    def __init__(self, parent=None):
        super().__init__(parent)

    @staticmethod
    def _is_safe_url(url):
        if not isinstance(url, str) or not url:
            return False
        lowered = url.strip().lower()
        return lowered.startswith(('http://', 'https://', 'mailto:', 'tel:'))

    @Slot(str, result=str)
    def openUrl(self, url):
        raw = url.strip() if isinstance(url, str) else ''
        if not self._is_safe_url(raw):
            return json.dumps({'ok': False, 'error': 'only http/https/mailto/tel are allowed'}, ensure_ascii=False)

        try:
            target = QUrl(raw, QUrl.TolerantMode)
            if not target.isValid():
                return json.dumps({'ok': False, 'error': 'invalid url'}, ensure_ascii=False)
            opened = QDesktopServices.openUrl(target)
            if opened:
                return json.dumps({'ok': True, 'url': raw}, ensure_ascii=False)
        except Exception:
            pass

        try:
            if sys.platform.startswith('win'):
                os.startfile(raw)
                return json.dumps({'ok': True, 'url': raw}, ensure_ascii=False)
            if sys.platform == 'darwin':
                subprocess.Popen(['open', raw])
                return json.dumps({'ok': True, 'url': raw}, ensure_ascii=False)
            subprocess.Popen(['xdg-open', raw])
            return json.dumps({'ok': True, 'url': raw}, ensure_ascii=False)
        except Exception:
            return json.dumps({'ok': False, 'error': 'failed to open browser'}, ensure_ascii=False)

    @Slot(str, result=str)
    def copyUrl(self, url):
        raw = url.strip() if isinstance(url, str) else ''
        if not raw:
            return json.dumps({'ok': False, 'error': 'empty url'}, ensure_ascii=False)

        try:
            from PySide6.QtGui import QGuiApplication

            clipboard = QGuiApplication.clipboard()
            if clipboard is None:
                return json.dumps({'ok': False, 'error': 'clipboard unavailable'}, ensure_ascii=False)
            clipboard.setText(raw)
            return json.dumps({'ok': True, 'url': raw}, ensure_ascii=False)
        except Exception:
            return json.dumps({'ok': False, 'error': 'copy failed'}, ensure_ascii=False)
