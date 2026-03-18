"""事件处理器模块

负责处理灵动岛的鼠标和焦点事件。
"""

from typing import Callable, Optional
from PySide6.QtCore import Qt, QPoint
from PySide6.QtGui import QCursor


class EventHandler:
    """事件处理器

    处理鼠标拖动、点击和焦点变化事件。

    Attributes:
        is_dragging: 是否正在拖动
        drag_start_pos: 拖动起始位置
        window_start_pos: 窗口起始位置
        toggle_callback: 切换状态回调
        is_expanded_callback: 判断是否展开的回调
    """

    def __init__(
        self,
        toggle_callback: Callable,
        is_expanded_callback: Callable
    ):
        self.is_dragging = False
        self.drag_start_pos: Optional[QPoint] = None
        self.window_start_pos: Optional[QPoint] = None
        self._toggle = toggle_callback
        self._is_expanded = is_expanded_callback

    def handle_mouse_press(self, event, get_window_pos: Callable) -> bool:
        if event.button() == Qt.LeftButton:
            self.is_dragging = True
            self.drag_start_pos = event.globalPos()
            self.window_start_pos = get_window_pos()
            return True
        return False

    def handle_mouse_move(self, event, move_window: Callable) -> bool:
        if self.is_dragging:
            delta = event.globalPos() - self.drag_start_pos
            new_pos = self.window_start_pos + delta
            move_window(new_pos)
            return True
        return False

    def handle_mouse_release(self, event, get_window_rect: Callable) -> bool:
        if event.button() == Qt.LeftButton:
            should_toggle = (
                self.is_dragging and
                (event.globalPos() - self.drag_start_pos).manhattanLength() < 5
            )
            self.is_dragging = False

            if should_toggle:
                self._toggle()
                return True
        return False

    def handle_focus_change(
        self,
        old_widget,
        new_widget,
        get_self_widget: Callable
    ):
        if self._is_expanded():
            current_widget = new_widget
            self_widget = get_self_widget()

            while current_widget:
                if current_widget == self_widget:
                    return
                current_widget = current_widget.parent()

            self._toggle()

    def handle_enter_event(
        self,
        is_collapsed: bool,
        start_hover_callback: Callable
    ):
        if is_collapsed:
            start_hover_callback(True)

    def handle_leave_event(
        self,
        is_collapsed: bool,
        start_hover_callback: Callable
    ):
        if is_collapsed:
            start_hover_callback(False)

    def is_mouse_outside(self, widget, cursor_pos: QPoint) -> bool:
        return not widget.rect().contains(widget.mapFromGlobal(cursor_pos))
