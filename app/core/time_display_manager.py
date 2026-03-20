"""时间显示管理器模块

负责灵动岛在不同状态下的时间显示逻辑。"""

import os
from datetime import datetime
from typing import Callable, Optional

from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
from PySide6.QtWidgets import QHBoxLayout, QLabel

from app.core.config import EXPANDED_WIDTH


class TimeDisplayManager:
    """时间显示管理器

    管理灵动岛在不同状态下的时间显示。

    Attributes:
        time_label: 时间标签
        date_label: 日期标签
        position_callback: 标签位置回调
    """

    def __init__(
        self,
        time_label,
        date_label,
        position_callback: Optional[Callable] = None
    ):
        self.time_label = time_label
        self.date_label = date_label
        self._position_callback = position_callback
        self._connection_label = None
        self._icon_label = None

    def update_for_expanded(self):
        now = datetime.now()
        current_date = now.strftime("%m/%d")
        weekday_map = {
            0: "周一", 1: "周二", 2: "周三", 3: "周四",
            4: "周五", 5: "周六", 6: "周日"
        }
        current_weekday = weekday_map[now.weekday()]
        current_time = now.strftime("%H:%M")

        text = f"{current_date} {current_weekday} {current_time}"
        self.date_label.setText(text)

        if self._position_callback:
            self._position_callback(self.date_label, text, EXPANDED_WIDTH, "DateLabel")

    def update_for_hover(self):
        now = datetime.now()
        full_time = now.strftime("%Y-%m-%d %H:%M:%S")
        self.time_label.setText(full_time)
        self.time_label.setAlignment(Qt.AlignCenter)

    def update_for_collapsed(self):
        now = datetime.now()
        current_time = now.strftime("%H:%M")
        self.time_label.setText(current_time)

    def update(self, is_expanded: bool, is_hovering: bool):
        if is_expanded:
            self.update_for_expanded()
        elif is_hovering:
            self.update_for_hover()
        else:
            self.update_for_collapsed()

    def show_time_only(self):
        self.time_label.show()
        self.date_label.hide()
        if self._connection_label:
            self._connection_label.hide()
        if self._icon_label:
            self._icon_label.hide()

    def show_date_only(self):
        self.time_label.hide()
        self.date_label.show()

    def _load_icon(self, icon_name: str):
        """加载图标
        
        Args:
            icon_name: 图标名称
            
        Returns:
            QPixmap: 图标像素图
        """
        icon_path = os.path.join(
            os.path.dirname(__file__),
            "..", "..", "resources", "icons", "system",
            f"{icon_name}.png"
        )
        if os.path.exists(icon_path):
            return QPixmap(icon_path)
        return None

    def show_connection_message(self, message: str, icon: str, width=None, height=None):
        """显示连接消息
        
        Args:
            message: 消息文本
            icon: 图标名称
            width: 容器宽度
            height: 容器高度
        """
        from app.core.config import EXPANDED_WIDTH, HOVER_HEIGHT
        target_width = width or EXPANDED_WIDTH
        target_height = height or HOVER_HEIGHT
        
        # 隐藏日期标签
        self.date_label.hide()
        
        # 如果连接标签不存在，创建它
        if not self._connection_label:
            parent = self.time_label.parent()
            self._connection_label = QLabel(parent)
            self._connection_label.setObjectName("ConnectionLabel")
            self._connection_label.setAlignment(Qt.AlignCenter)
            
            # 添加字体设置
            font = self._connection_label.font()
            font.setPointSize(12)  # 设置字体大小
            from PySide6.QtGui import QFont
            font.setWeight(QFont.Weight.Bold)  # 设置字体粗细
            self._connection_label.setFont(font)
            
            # 创建图标标签
            self._icon_label = QLabel(parent)
            self._icon_label.setAlignment(Qt.AlignCenter)
        
        # 加载图标
        pixmap = self._load_icon(icon)
        if pixmap:
            # 调整图标大小
            icon_size = 20
            pixmap = pixmap.scaled(icon_size, icon_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self._icon_label.setPixmap(pixmap)
            self._icon_label.show()
        else:
            self._icon_label.hide()
        
        # 设置消息文本
        self._connection_label.setText(message)
        self._connection_label.adjustSize()
        self._connection_label.show()
        
        # 计算位置
        total_width = 0
        icon_width = 0
        
        if self._icon_label.isVisible():
            # 强制调整图标大小
            self._icon_label.setFixedSize(20, 20)
            icon_width = 20
            total_width += icon_width + 8  # 8px 间距
        
        # 强制调整文本标签大小
        self._connection_label.adjustSize()
        text_width = self._connection_label.width()
        total_width += text_width
        
        x = (target_width - total_width) // 2
        y = (target_height - self._connection_label.height()) // 2
        
        # 定位图标和文本
        if self._icon_label.isVisible():
            self._icon_label.move(x, y)
            self._connection_label.move(x + icon_width + 8, y)
        else:
            self._connection_label.move(x, y)

    def hide_all(self):
        self.time_label.hide()
        self.date_label.hide()
        if self._connection_label:
            self._connection_label.hide()
        if self._icon_label:
            self._icon_label.hide()