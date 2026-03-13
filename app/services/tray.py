"""托盘服务模块

提供系统托盘功能，包括：
1. 托盘图标显示
2. 托盘菜单管理
3. 设置窗口控制
"""

import os
from PySide6.QtWidgets import QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction
from PySide6.QtCore import Signal, QObject

DEFAULT_TRAY_ICON = "resources/icons/controls/tray.png"


class TrayService(QObject):
    """托盘服务类，管理系统托盘图标和菜单。

    提供系统托盘功能，允许用户通过托盘图标控制应用。

    Signals:
        quit_app: 退出应用信号
        open_settings: 打开设置信号
    """

    quit_app = Signal()
    open_settings = Signal()

    def __init__(self, icon_path: str = None, parent=None):
        """初始化托盘服务。

        Args:
            icon_path: 托盘图标路径，默认为 resources/icons/controls/tray.png
            parent: 父对象
        """
        super().__init__(parent)
        self.icon_path = icon_path or DEFAULT_TRAY_ICON
        self._tray_icon = None
        self._tray_menu = None

        self._create_tray_icon()
        self._create_menu()
        self._connect_signals()

    def _create_tray_icon(self):
        """创建托盘图标。"""
        icon = QIcon(self.icon_path)
        self._tray_icon = QSystemTrayIcon(icon, self)
        self._tray_icon.setToolTip("Pyisland - 现代灵动岛")

    def _create_menu(self):
        """创建托盘菜单。"""
        self._tray_menu = QMenu()

        self._settings_action = QAction("设置", self)
        self._quit_action = QAction("退出", self)

        self._tray_menu.addAction(self._settings_action)
        self._tray_menu.addSeparator()
        self._tray_menu.addAction(self._quit_action)

        self._tray_icon.setContextMenu(self._tray_menu)

    def _connect_signals(self):
        """连接菜单动作信号。"""
        self._settings_action.triggered.connect(self._on_settings)
        self._quit_action.triggered.connect(self._on_quit)
        self._tray_icon.activated.connect(self._on_activated)

    def _on_settings(self):
        """打开设置。"""
        self.open_settings.emit()

    def _on_quit(self):
        """退出应用。"""
        self.quit_app.emit()

    def _on_activated(self, reason):
        """托盘图标被激活时的处理。

        Args:
            reason: 激活原因
        """
        if reason == QSystemTrayIcon.DoubleClick or reason == QSystemTrayIcon.Trigger:
            self._on_settings()

    def show(self):
        """显示托盘图标。"""
        if self._tray_icon:
            self._tray_icon.show()

    def hide(self):
        """隐藏托盘图标。"""
        if self._tray_icon:
            self._tray_icon.hide()

    def set_visible(self, visible: bool):
        """设置托盘图标可见性。

        Args:
            visible: 是否可见
        """
        if visible:
            self.show()
        else:
            self.hide()

    def update_tooltip(self, text: str):
        """更新托盘提示文本。

        Args:
            text: 提示文本
        """
        if self._tray_icon:
            self._tray_icon.setToolTip(text)

    def show_message(self, title: str, message: str, 
                     icon=QSystemTrayIcon.Information, msecs=3000):
        """显示托盘消息。

        Args:
            title: 消息标题
            message: 消息内容
            icon: 消息图标类型
            msecs: 显示时长（毫秒）
        """
        if self._tray_icon:
            self._tray_icon.showMessage(title, message, icon, msecs)
