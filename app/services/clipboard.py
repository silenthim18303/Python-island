"""剪贴板服务模块

提供剪贴板监听和URL检测功能。
"""

import re
import webbrowser
from typing import List, Optional

try:
    from PySide6.QtGui import QGuiApplication

    clipboard_available = True
except ImportError:
    clipboard_available = False


class ClipboardService:
    """剪贴板服务，提供剪贴板监听和URL检测功能。"""

    def __init__(self):
        """初始化剪贴板服务。"""
        self._last_clipboard_text = ""
        self._first_check = True

    @staticmethod
    def get_text() -> Optional[str]:
        """获取剪贴板文本内容。

        Returns:
            Optional[str]: 剪贴板文本，如果不可用则返回None
        """
        if not clipboard_available:
            return None
        try:
            clipboard = QGuiApplication.clipboard()
            return clipboard.text()
        except Exception:
            return None

    @staticmethod
    def extract_urls(text: str) -> List[str]:
        """从文本中提取所有URL。

        Args:
            text: 要提取URL的文本

        Returns:
            List[str]: 提取到的URL列表
        """
        if not text:
            return []

        simple_url_pattern = re.compile(
            r"https?://[^\s<>\"{}|\\^`\[\]]+",
            re.IGNORECASE,
        )

        nohttp_url_pattern = re.compile(
            r"\b(?:www\.)[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?"
            r"(?:\.[a-zA-Z]{2,})+(?:/[^\s<>\"{}|\\^`\[\]]*)?",
            re.IGNORECASE,
        )

        urls = simple_url_pattern.findall(text)
        nohttp_urls = nohttp_url_pattern.findall(text)
        all_urls = urls + nohttp_urls

        seen = set()
        unique_urls = []
        for url in all_urls:
            url = url.rstrip(".,;:)")
            if url not in seen:
                seen.add(url)
                unique_urls.append(url)

        return unique_urls

    @staticmethod
    def open_url(url: str) -> bool:
        """使用默认浏览器打开URL。

        Args:
            url: 要打开的URL

        Returns:
            bool: 是否成功打开
        """
        try:
            webbrowser.open(url)
            return True
        except Exception:
            return False

    @staticmethod
    def open_urls(urls: List[str]) -> int:
        """批量打开URL。

        Args:
            urls: URL列表

        Returns:
            int: 成功打开的数量
        """
        count = 0
        for url in urls:
            if ClipboardService.open_url(url):
                count += 1
        return count

    def check_for_new_urls(self) -> tuple:
        """检查剪贴板是否有新的URL。

        Returns:
            tuple: (has_new_urls, urls)
        """
        current_text = self.get_text()
        if not current_text:
            return False, []

        if self._first_check:
            self._last_clipboard_text = current_text
            self._first_check = False
            return False, []

        urls = self.extract_urls(current_text)
        if not urls:
            self._last_clipboard_text = current_text
            return False, []

        if current_text == self._last_clipboard_text:
            return False, []

        self._last_clipboard_text = current_text
        return True, urls

    def reset(self):
        """重置服务状态。"""
        self._last_clipboard_text = ""
        self._first_check = True
