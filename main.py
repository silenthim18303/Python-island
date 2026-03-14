"""应用入口模块

此模块是 Pyisland 应用的主入口，负责初始化 Qt 应用并启动现代灵动岛控制中心。

功能：
- 初始化 QApplication 实例
- 创建 ModernIsland 主窗口
- 初始化系统托盘
- 显示灵动岛界面
- 启动应用事件循环
"""
import sys

from PySide6.QtWidgets import QApplication

from app.services.tray import TrayService
from app.ui.settings import SettingsDialog
from app.island import ModernIsland

from app.config._bqa import init_qa


def main():
    """应用主函数。"""
    # *初始化 QA
    init_qa()
    
    app = QApplication(sys.argv)
    
    app.setQuitOnLastWindowClosed(False)
    
    island = ModernIsland()
    
    settings_dialog = SettingsDialog()
    
    tray_service = TrayService()
    
    tray_service.quit_app.connect(app.quit)
    tray_service.open_settings.connect(settings_dialog.show)
    
    tray_service.show()
    
    island.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
