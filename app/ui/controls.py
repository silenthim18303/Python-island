"""控制面板组件模块

提供创建控制行（亮度、音量等）的工厂类和组件。
"""

import os
from PySide6.QtWidgets import QHBoxLayout, QLabel, QSlider
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap

from app.core.config import ICON_SIZE, SLIDER_WIDTH, SLIDER_HEIGHT


class ControlRowFactory:
    """控制行工厂类，用于创建包含图标、标签、滑动条和数值的控件行。"""

    @staticmethod
    def create(icon_cache: dict, icon_path: str, label_text: str):
        """创建控制行。

        Args:
            icon_cache: 图标缓存字典
            icon_path: 图标文件路径
            label_text: 标签文本

        Returns:
            tuple: (row_layout, slider, value_label)
        """
        row = QHBoxLayout()
        row.setSpacing(12)

        icon = QLabel()
        icon.setObjectName("IconLabel")

        if icon_path in icon_cache:
            icon.setPixmap(icon_cache[icon_path])
        elif label_text == "亮度":
            icon.setText("\u0f0a0")
        else:
            icon.setText("\u0f05a")

        label = QLabel(label_text)
        label.setObjectName("ValueLabel")
        label.setFixedWidth(30)

        slider = QSlider(Qt.Horizontal)
        slider.setRange(0, 100)
        slider.setFixedHeight(SLIDER_HEIGHT)
        slider.setObjectName("CapsuleSlider")
        slider.setFixedWidth(SLIDER_WIDTH)

        val_label = QLabel("50%")
        val_label.setFixedWidth(40)
        val_label.setObjectName("ValueLabel")

        row.addWidget(icon)
        row.addWidget(label)
        row.addWidget(slider)
        row.addWidget(val_label)

        return row, slider, val_label

    @staticmethod
    def preload_icons(icon_paths: list) -> dict:
        """预加载图标到缓存。

        Args:
            icon_paths: 图标路径列表

        Returns:
            dict: 图标缓存字典
        """
        icon_cache = {}
        for path in icon_paths:
            if os.path.exists(path):
                pixmap = QPixmap(path)
                icon_cache[path] = pixmap.scaled(
                    ICON_SIZE, ICON_SIZE,
                    Qt.KeepAspectRatio, Qt.SmoothTransformation
                )
        return icon_cache
