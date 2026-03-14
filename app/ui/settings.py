"""设置窗口模块

提供应用设置界面，包括各种配置选项。
"""

from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel
from PySide6.QtCore import Qt


class SettingsDialog(QDialog):
    """设置对话框，提供应用配置界面。"""

    def __init__(self, parent=None):
        """初始化设置对话框。

        Args:
            parent: 父窗口
        """
        super().__init__(parent)
        self.setWindowTitle("Pyisland 设置")
        self.setFixedSize(400, 300)
        
        self._init_ui()

    def _init_ui(self):
        """初始化UI组件。"""
        layout = QVBoxLayout(self)
        
        self.label = QLabel("设置窗口")
        self.label.setAlignment(Qt.AlignCenter)
        
        layout.addWidget(self.label)
