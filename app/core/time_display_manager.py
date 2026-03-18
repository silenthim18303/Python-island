"""时间显示管理器模块

负责灵动岛在不同状态下的时间显示逻辑。
"""

from datetime import datetime
from typing import Callable, Optional

from PySide6.QtCore import Qt

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

    def show_date_only(self):
        self.time_label.hide()
        self.date_label.show()

    def show_connection_message(self, message: str, icon: str):
        text = f"{icon} {message}"
        self.date_label.setText(text)
        self.date_label.show()

        if self._position_callback:
            self._position_callback(self.date_label, text, EXPANDED_WIDTH, "DateLabel")

    def hide_all(self):
        self.time_label.hide()
        self.date_label.hide()
