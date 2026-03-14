"""通用设置界面模块"""

from PySide6.QtWidgets import QWidget

from app.ui.interfaces.index_setting.index_setting_general.island_index_setting_general_ui import (
    Ui_island_index_setting_general_ui,
)


class SettingGeneralDriver(QWidget, Ui_island_index_setting_general_ui):
    """通用设置界面驱动类。"""

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self._init_ui()

    def _init_ui(self):
        self.setFixedSize(450, 300)

    def _init_slots(self):
        pass


# 兼容旧代码
setting_general_driver = SettingGeneralDriver
