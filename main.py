
"""应用入口模块

此模块是 Pyisland 应用的主入口，负责初始化 Qt 应用并启动现代灵动岛控制中心。

功能：
- 初始化 QApplication 实例
- 创建 ModernIsland 主窗口
- 显示灵动岛界面
- 启动应用事件循环
"""
import sys

from PySide6.QtWidgets import QApplication

from app.island import ModernIsland


if __name__ == "__main__":
    # 初始化 Qt 应用
    app = QApplication(sys.argv)
    # 创建灵动岛主窗口
    island = ModernIsland()
    # 显示灵动岛界面
    island.show()
    # 启动应用事件循环
    sys.exit(app.exec())