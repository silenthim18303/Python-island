"""时间显示管理器模块

负责灵动岛在不同状态下的时间显示逻辑。"""

import os
from datetime import datetime
from typing import Callable, Optional

from PySide6.QtCore import Qt, QRect, QEasingCurve, QPropertyAnimation
from PySide6.QtGui import QFont
from PySide6.QtWidgets import QHBoxLayout, QLabel, QVBoxLayout, QWidget, QFrame

from app.core.config import EXPANDED_WIDTH


class SystemInfoLabel(QFrame):
    """悬停态显示CPU和内存使用率的自定义标签组件。"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._init_ui()

    def _init_ui(self):
        """初始化UI组件。"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(5, 5, 5, 5)
        layout.setSpacing(2)
        layout.setAlignment(Qt.AlignCenter)

        self.time_label = QLabel("")
        self.time_label.setAlignment(Qt.AlignCenter)
        self.time_label.setObjectName("HoverTimeLabel")

        # 使用水平居中布局，左侧和右侧添加 stretch
        self.info_layout = QHBoxLayout()
        self.info_layout.setSpacing(20)
        self.info_layout.setContentsMargins(0, 0, 0, 0)
        self.info_layout.addStretch()
        self.info_layout.setAlignment(Qt.AlignCenter)

        self.cpu_label = QLabel("")
        self.cpu_label.setAlignment(Qt.AlignCenter)
        self.cpu_label.setObjectName("HoverCpuLabel")

        self.memory_label = QLabel("")
        self.memory_label.setAlignment(Qt.AlignCenter)
        self.memory_label.setObjectName("HoverMemoryLabel")

        self.info_layout.addWidget(self.cpu_label)
        self.info_layout.addWidget(self.memory_label)
        self.info_layout.addStretch()

        layout.addWidget(self.time_label)
        layout.addLayout(self.info_layout)

    def update_info(self, time_str: str, cpu_usage: float, memory_usage: tuple):
        """更新显示信息。

        Args:
            time_str: 时间字符串
            cpu_usage: CPU使用率（0-100）
            memory_usage: tuple (used_gb, total_gb, percent)，或 None 表示加载中
        """
        self.time_label.setText(time_str)

        cpu_text = f"CPU: {cpu_usage:.1f}%"
        self.cpu_label.setText(cpu_text)

        if memory_usage is not None:
            used_gb, total_gb, percent = memory_usage
            mem_text = f"内存: {used_gb}/{total_gb}GB ({percent:.1f}%)"
        else:
            mem_text = "内存: 加载中..."
        self.memory_label.setText(mem_text)


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
        self._hover_info_label = None
        self._last_cpu_usage = None
        self._last_memory_usage = None

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

    def update_for_hover(self, cpu_usage: float = None, memory_usage: tuple = None):
        now = datetime.now()
        full_time = now.strftime("%Y-%m-%d %H:%M:%S")

        # 检查数据有效性
        if cpu_usage is None or cpu_usage == -1:
            cpu_usage = self._last_cpu_usage
        if memory_usage is None:
            memory_usage = self._last_memory_usage
        
        # 只有在有有效数据时才更新显示
        if cpu_usage is not None and memory_usage is not None:
            # 保存当前值
            self._last_cpu_usage = cpu_usage
            self._last_memory_usage = memory_usage
            self._update_hover_with_system_info(full_time, cpu_usage, memory_usage)
            # 强制刷新显示
            if self._hover_info_label:
                self._hover_info_label.update()
        elif self._last_cpu_usage is not None and self._last_memory_usage is not None:
            # 有缓存数据，使用缓存
            self._update_hover_with_system_info(full_time, self._last_cpu_usage, self._last_memory_usage)
            if self._hover_info_label:
                self._hover_info_label.update()
        else:
            # 首次进入且没有缓存，显示占位符但使用默认值
            self._show_hover_info_loading(full_time)

    def _show_hover_info_loading(self, time_str: str):
        """显示悬停信息标签（带占位符）。"""
        self.time_label.hide()

        from app.core.config import HOVER_WIDTH, HOVER_HEIGHT
        parent = self.time_label.parent()

        if not self._hover_info_label:
            self._hover_info_label = SystemInfoLabel(parent)
            self._hover_info_label.setObjectName("HoverInfoLabel")
            self._hover_info_label.setFixedSize(HOVER_WIDTH, HOVER_HEIGHT)

        # 计算居中位置
        parent_width = parent.width() if parent.width() > 0 else HOVER_WIDTH
        x = (parent_width - HOVER_WIDTH) // 2
        y = 0
        self._hover_info_label.move(x, y)

        # 显示占位符
        self._hover_info_label.update_info(time_str, 0.0, None)
        self._hover_info_label.show()

    def _update_hover_with_system_info(self, time_str: str, cpu_usage: float, memory_usage: tuple):
        """在悬停态显示时间、CPU和内存信息。

        Args:
            time_str: 时间字符串
            cpu_usage: CPU使用率（0-100）
            memory_usage: tuple (used_gb, total_gb, percent)
        """
        # 隐藏原来的时间标签，使用自定义布局
        self.time_label.hide()

        from app.core.config import HOVER_WIDTH, HOVER_HEIGHT
        parent = self.time_label.parent()

        if not self._hover_info_label:
            self._hover_info_label = SystemInfoLabel(parent)
            self._hover_info_label.setObjectName("HoverInfoLabel")
            self._hover_info_label.setFixedSize(HOVER_WIDTH, HOVER_HEIGHT)

        # 计算居中位置
        parent_width = parent.width() if parent.width() > 0 else HOVER_WIDTH
        x = (parent_width - HOVER_WIDTH) // 2
        y = 0
        self._hover_info_label.move(x, y)

        self._hover_info_label.update_info(time_str, cpu_usage, memory_usage)
        self._hover_info_label.show()

    def _hide_hover_info(self):
        """隐藏悬停信息标签。"""
        if self._hover_info_label:
            self._hover_info_label.hide()

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
        if self._hover_info_label:
            self._hover_info_label.hide()

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
        if self._hover_info_label:
            self._hover_info_label.hide()