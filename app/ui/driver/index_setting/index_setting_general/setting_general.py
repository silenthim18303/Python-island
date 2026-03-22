"""通用设置界面模块"""

from qfluentwidgets import FluentIcon, ScrollArea, SettingCardGroup, SwitchSettingCard

from app.services.startup import StartupService
from app.ui.interfaces.index_setting.index_setting_general.island_index_setting_general_ui import (
    Ui_island_index_setting_general_ui,
)


class SettingGeneralDriver(ScrollArea, Ui_island_index_setting_general_ui):
    """通用设置界面驱动类。"""

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self._startup_service = StartupService()
        self._init_ui()

    def _init_ui(self):
        self.startup_card = SwitchSettingCard(
            icon=FluentIcon.POWER_BUTTON,
            title="开机自启",
            content="开机时自动启动 Pyisland",
        )
        self.startup_card.switchButton.setChecked(
            self._startup_service.is_startup_enabled()
        )
        self.scg_index_setting_general_main = SettingCardGroup(
            title="通用",
        )
        self.scg_index_setting_general_main.addSettingCard(self.startup_card)
        self.startup_card.checkedChanged.connect(self._on_startup_changed)
        self.setWidget(self.scg_index_setting_general_main)
        self.setWidgetResizable(True)
        self.enableTransparentBackground()

    def _on_startup_changed(self, is_checked: bool):
        if is_checked:
            self._startup_service.enable_startup()
        else:
            self._startup_service.disable_startup()


# 兼容旧代码
setting_general_driver = SettingGeneralDriver
