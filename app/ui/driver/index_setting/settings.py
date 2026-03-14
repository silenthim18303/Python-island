"""设置窗口模块

提供应用设置界面，包括各种配置选项。
"""

from qfluentwidgets import MSFluentWindow

from app.ui.interfaces.index_setting.island_index_setting_ui import Ui_island_index_setting_ui


class setting_driver(MSFluentWindow , Ui_island_index_setting_ui):
    """设置对话框，提供应用配置界面。"""

    def __init__(self):
        """初始化设置对话框。

        Args:
            parent: 父窗口
        """
        super().__init__()
        self.setupUi(self)
        
        self.setWindowTitle("Pyisland 设置")
        
        self.__init_ui()
        self.resize(500 , 300)
        self.activateWindow()

    def __init_ui(self):
        self.setFixedSize(500 , 300)
        self.setMicaEffectEnabled(False)
