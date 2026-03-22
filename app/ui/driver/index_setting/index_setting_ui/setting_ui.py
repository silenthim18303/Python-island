"""图形设置界面模块"""

from PySide6.QtWidgets import QWidget

from app.ui.interfaces.index_setting.index_setting_ui.island_index_setting_ui_ui import (
    Ui_island_index_setting_ui_ui,
)


class SettingUiDriver(QWidget, Ui_island_index_setting_ui_ui):
    """图形设置界面驱动类。"""

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self._init_ui()

    def _init_ui(self):
        self.setFixedSize(450, 300)
        # 设置背景色和文本颜色
        self.setStyleSheet("""
            QWidget {
                background-color: #f0f0f0;
                color: #333333;
            }
        """)

    def _init_slots(self):
        pass


# 兼容旧代码
setting_ui_driver = SettingUiDriver