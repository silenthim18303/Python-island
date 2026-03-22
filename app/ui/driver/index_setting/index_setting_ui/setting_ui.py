"""图形设置界面模块"""

from qfluentwidgets import ScrollArea, SettingCardGroup

from app.ui.interfaces.index_setting.index_setting_ui.island_index_setting_ui_ui import (
    Ui_island_index_setting_ui_ui,
)


class SettingUiDriver(ScrollArea, Ui_island_index_setting_ui_ui):
    """图形设置界面驱动类。"""

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self._init_ui()

    def _init_ui(self):
        self.scg_index_setting_ui_main = SettingCardGroup(
            title="图形",
        )
        self.setWidget(self.scg_index_setting_ui_main)
        self.setWidgetResizable(True)
        self.enableTransparentBackground()


# 兼容旧代码
setting_ui_driver = SettingUiDriver