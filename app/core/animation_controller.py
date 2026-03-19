"""动画控制器模块

负责灵动岛所有动画的协调和控制。
"""

from typing import Callable, Optional
from PySide6.QtCore import QRect

from app.core.config import (
    COLLAPSED_HEIGHT,
    COLLAPSED_WIDTH,
    EXPANDED_HEIGHT,
    EXPANDED_WIDTH,
    HOVER_HEIGHT,
    HOVER_WIDTH,
    TIME_LABEL_HEIGHT,
)
from app.animations.effects import AnimationManager


class AnimationController:
    """动画控制器

    协调所有灵动岛动画，包括展开、收起、悬停、URL展开等。

    Attributes:
        animation_manager: 动画管理器
        container: 容器组件
        controls: 控制面板
        update_mask_callback: 更新遮罩回调
        update_time_callback: 更新时间回调
    """

    def __init__(
        self,
        animation_manager: AnimationManager,
        container,
        controls,
        update_mask_callback: Callable,
        update_time_callback: Callable
    ):
        self.animation_manager = animation_manager
        self.container = container
        self.controls = controls
        self._update_mask = update_mask_callback
        self._update_time = update_time_callback

    def animate_expand(
        self,
        start_rect: QRect,
        current_pos_x: float,
        width: float,
        on_finished: Optional[Callable] = None
    ):
        end_rect = QRect(
            current_pos_x + width / 2 - 180,
            start_rect.y(),
            EXPANDED_WIDTH, EXPANDED_HEIGHT
        )

        def on_value_changed(value):
            self._update_mask()

        def on_animation_finished():
            if on_finished:
                on_finished()

        self.animation_manager.create_expand_animation(
            start_rect, end_rect, on_value_changed, on_animation_finished
        ).start()

        self.controls.show()
        self.container.setFixedSize(EXPANDED_WIDTH, EXPANDED_HEIGHT)

    def animate_collapse(
        self,
        start_rect: QRect,
        current_pos_x: float,
        width: float,
        on_finished: Optional[Callable] = None
    ):
        end_rect = QRect(
            current_pos_x + width / 2 - 90,
            start_rect.y(),
            COLLAPSED_WIDTH, COLLAPSED_HEIGHT
        )

        def on_value_changed(value):
            self._update_mask()

        def on_animation_finished():
            self.container.setFixedSize(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)
            if on_finished:
                on_finished()

        self.animation_manager.create_collapse_animation(
            start_rect, end_rect, on_value_changed, on_animation_finished
        ).start()

        self.controls.hide()

    def animate_hover(
        self,
        start_rect: QRect,
        is_enter: bool,
        screen_width: int,
        on_finished: Optional[Callable] = None
    ):
        target_w = HOVER_WIDTH if is_enter else COLLAPSED_WIDTH
        target_h = HOVER_HEIGHT if is_enter else COLLAPSED_HEIGHT

        screen_center_x = screen_width // 2
        target_x = screen_center_x - target_w // 2
        end_rect = QRect(target_x, start_rect.y(), target_w, target_h)

        def on_value_changed(value):
            self._update_mask()
            self.container.setFixedSize(value.width(), value.height())

        def on_animation_finished():
            if on_finished:
                on_finished()

        self.animation_manager.create_hover_animation(
            start_rect, end_rect, on_value_changed, on_animation_finished
        ).start()

    def animate_height_change(
        self,
        from_height: int,
        to_height: int,
        width: int,
        set_controls_height: Callable
    ):
        def on_value_changed(value):
            self.container.setFixedSize(width, value.height())
            set_controls_height(value.height())
            self._update_mask()

        def on_finished():
            self.container.setFixedSize(width, to_height)
            set_controls_height(to_height)

        self.animation_manager.create_height_animation(
            from_height, to_height, on_value_changed, on_finished
        ).start()

    def animate_url_expand(
        self,
        target_height: int,
        on_show_controls: Optional[Callable] = None,
        on_finished: Optional[Callable] = None
    ):
        def on_value_changed(value):
            if value.width() > 50:
                self.controls.show()
            self._update_mask()
            intermediate_h = self._calculate_intermediate_height(
                value.width(), target_height
            )
            self.container.setFixedSize(value.width(), intermediate_h)

        def on_animation_finished():
            self.controls.show()
            self.container.setFixedSize(EXPANDED_WIDTH, target_height)
            self._update_mask()
            if on_finished:
                on_finished()

        self.animation_manager.create_url_expand_animation(
            target_height, on_value_changed, on_animation_finished
        ).start()

    def animate_connection_expand(
        self,
        message: str,
        icon: str,
        on_show_message: Callable,
        on_finished: Optional[Callable] = None
    ):
        def on_value_changed(value):
            if value.width() > 50:
                self.controls.show()
            self.container.setFixedSize(value.width(), EXPANDED_HEIGHT)

        def on_animation_finished():
            self.controls.show()
            self.container.setFixedSize(EXPANDED_WIDTH, EXPANDED_HEIGHT)
            on_show_message(message, icon)
            if on_finished:
                on_finished()

        self.animation_manager.create_url_expand_animation(
            EXPANDED_HEIGHT, on_value_changed, on_animation_finished
        ).start()

    @staticmethod
    def _calculate_intermediate_height(width: int, target_height: int) -> int:
        return int(TIME_LABEL_HEIGHT + (target_height - TIME_LABEL_HEIGHT) * (width / EXPANDED_WIDTH))

    @staticmethod
    def calculate_controls_height(container_height: int) -> int:
        return max(0, container_height - TIME_LABEL_HEIGHT)
