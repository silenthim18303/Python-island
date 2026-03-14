"""图标枚举模块

提供应用中使用的图标枚举，参考qfluentwidgets的FluentIcon实现方式。
"""

from enum import Enum
from pathlib import Path


ICONS_CONTROLS_PATH = Path("resources/icons/controls")
ICONS_SYSTEM_PATH = Path("resources/icons/system")


class IslandIconBase:
    """图标基类，提供路径获取方法。"""

    def path(self) -> str:
        """获取图标完整路径。"""
        raise NotImplementedError

    def qicon(self):
        """获取QIcon对象。"""
        from PySide6.QtGui import QIcon
        return QIcon(self.path())


class IslandIcon(IslandIconBase, Enum):
    """灵动岛图标枚举。"""

    LIGHT = ("light", "controls")
    VOLUME = ("volume", "controls")
    TRAY = ("tray", "controls")
    INTERNET = ("internet", "system")
    BLUETOOTH = ("bluetooth", "system")
    BATTERY = ("battery", "system")

    def __init__(self, name: str, category: str):
        self._name = name
        self._category = category

    def path(self) -> str:
        """获取图标完整路径。"""
        if self._category == "controls":
            return str(ICONS_CONTROLS_PATH / f"{self._name}.png")
        return str(ICONS_SYSTEM_PATH / f"{self._name}.png")

    @property
    def name(self) -> str:
        """获取图标名称。"""
        return self._name
