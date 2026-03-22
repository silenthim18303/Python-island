"""通用设置界面模块"""

from PySide6.QtWidgets import QWidget

from app.services.startup import StartupService
from app.ui.interfaces.index_setting.index_setting_general.island_index_setting_general_ui import (
    Ui_island_index_setting_general_ui,
)


class SettingGeneralDriver(QWidget, Ui_island_index_setting_general_ui):
    """通用设置界面驱动类。"""

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self._startup_service = StartupService()
        self._init_ui()
        self._init_slots()

    def _init_ui(self):
        self.setFixedSize(450, 300)
        # 设置背景色和文本颜色
        self.setStyleSheet("""
            QWidget {
                background-color: #f0f0f0;
                color: #333333;
            }
            QCheckBox {
                color: #333333;
            }
        """)
        # 初始化开机自启选项状态
        self.startup_checkbox.setChecked(self._startup_service.is_startup_enabled())

    def _init_slots(self):
        # 连接开机自启选项的信号
        self.startup_checkbox.stateChanged.connect(self._on_startup_changed)

    def _on_startup_changed(self, state):
        """处理开机自启选项变化。

        Args:
            state: 复选框状态
        """
        if state == 2:  # 选中
            self._startup_service.enable_startup()
        else:  # 未选中
            self._startup_service.disable_startup()


# 兼容旧代码
setting_general_driver = SettingGeneralDriver