"""设置窗口模块

提供应用设置界面，包括各种配置选项。
"""

from PySide6.QtGui import QColor, QIcon

from app.core.config import get_resource_path
from qfluentwidgets import FluentIcon, MSFluentWindow, Theme, setTheme

from app.ui.driver.index_setting.index_setting_general.setting_general import (
    setting_general_driver,
)
from app.ui.driver.index_setting.index_setting_ui.setting_ui import (
    setting_ui_driver,
)
from app.ui.interfaces.index_setting.island_index_setting_ui import (
    Ui_island_index_setting_ui,
)


class SettingDriver(MSFluentWindow, Ui_island_index_setting_ui):
    """设置对话框，提供应用配置界面。"""

    def __init__(self):
        """初始化设置对话框。

        Args:
            parent: 父窗口
        """
        super().__init__()
        self.setupUi(self)

        self.setWindowTitle("Pyisland 设置")
        self._init_ui()
        self._init_navigations()
        self.activateWindow()

    def _init_ui(self):
        self.setMicaEffectEnabled(True)
        self.setWindowIcon(QIcon(get_resource_path("resources/icons/favicon.ico")))
        setTheme(Theme.AUTO)

    def _init_navigations(self):
        self.island_index_setting_general_interface = setting_general_driver()
        self.addSubInterface(
            self.island_index_setting_general_interface,
            FluentIcon.APPLICATION,
            "通用",
            isTransparent = True
        )
        self.island_index_setting_ui_interface = setting_ui_driver()
        self.addSubInterface(
            self.island_index_setting_ui_interface,
            FluentIcon.SETTING,
            "图形",
            isTransparent = True
        )


# 兼容旧代码
setting_driver = SettingDriver