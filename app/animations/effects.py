"""动画效果模块

提供灵动岛的展开/收起动画效果和圆角遮罩辅助功能。
"""

from PySide6.QtCore import QEasingCurve, QPropertyAnimation, QRect, QSize
from PySide6.QtGui import QPainterPath, QRegion
from PySide6.QtWidgets import QWidget

from app.core.config import (
    COLLAPSE_ANIMATION_DURATION,
    COLLAPSED_HEIGHT,
    COLLAPSED_WIDTH,
    CORNER_RADIUS_MAX,
    CORNER_RADIUS_MIN,
    EXPAND_ANIMATION_DURATION,
    EXPANDED_HEIGHT,
    EXPANDED_WIDTH,
    HEIGHT_CHANGE_ANIMATION_DURATION,
    URL_EXPAND_ANIMATION_DURATION,
)


class AnimationManager:
    """动画管理器，管理灵动岛的展开/收起动画。"""

    def __init__(self, widget: QWidget):
        """初始化动画管理器。

        Args:
            widget: 要应用动画的控件
        """
        self.widget = widget
        self.current_animation = None

    def create_expand_animation(
        self,
        start_rect: QRect,
        end_rect: QRect,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建展开动画。

        Args:
            start_rect: 起始矩形
            end_rect: 结束矩形
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        animation = QPropertyAnimation(self.widget, b"geometry")
        animation.setDuration(EXPAND_ANIMATION_DURATION)
        animation.setEasingCurve(QEasingCurve.InOutCubic)
        animation.setStartValue(start_rect)
        animation.setEndValue(end_rect)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def create_collapse_animation(
        self,
        start_rect: QRect,
        end_rect: QRect,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建收起动画。

        Args:
            start_rect: 起始矩形
            end_rect: 结束矩形
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        animation = QPropertyAnimation(self.widget, b"geometry")
        animation.setDuration(COLLAPSE_ANIMATION_DURATION)
        animation.setEasingCurve(QEasingCurve.InOutCubic)
        animation.setStartValue(start_rect)
        animation.setEndValue(end_rect)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def create_height_animation(
        self,
        from_height: int,
        to_height: int,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建高度变化动画。

        Args:
            from_height: 起始高度
            to_height: 目标高度
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        current_pos = self.widget.pos()
        current_w = self.widget.geometry().width()

        start = QRect(current_pos.x(), current_pos.y(), current_w, from_height)
        end = QRect(current_pos.x(), current_pos.y(), current_w, to_height)

        animation = QPropertyAnimation(self.widget, b"geometry")
        animation.setDuration(HEIGHT_CHANGE_ANIMATION_DURATION)
        animation.setEasingCurve(QEasingCurve.OutCubic)
        animation.setStartValue(start)
        animation.setEndValue(end)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def create_url_expand_animation(
        self,
        target_height: int,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建URL页面展开动画。

        Args:
            target_height: 目标高度
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        current_pos = self.widget.geometry().topLeft()
        current_w = self.widget.rect().width()
        current_h = self.widget.rect().height()

        start = QRect(current_pos.x(), current_pos.y(), current_w, current_h)
        end = QRect(
            current_pos.x(), current_pos.y(), EXPANDED_WIDTH, target_height
        )

        animation = QPropertyAnimation(self.widget, b"geometry")
        animation.setDuration(URL_EXPAND_ANIMATION_DURATION)
        animation.setEasingCurve(QEasingCurve.OutCubic)
        animation.setStartValue(start)
        animation.setEndValue(end)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def create_hover_animation(
        self,
        start_rect: QRect,
        end_rect: QRect,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建悬停动画。

        Args:
            start_rect: 起始矩形
            end_rect: 结束矩形
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        animation = QPropertyAnimation(self.widget, b"geometry")
        animation.setDuration(150)  # Faster duration for hover
        animation.setEasingCurve(QEasingCurve.InOutQuad)
        animation.setStartValue(start_rect)
        animation.setEndValue(end_rect)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def create_size_animation(
        self,
        target_object: QWidget,
        start_size: QSize,
        end_size: QSize,
        on_value_changed=None,
        on_finished=None,
    ) -> QPropertyAnimation:
        """创建尺寸变化动画。

        Args:
            target_object: 要应用动画的控件
            start_size: 起始尺寸
            end_size: 结束尺寸
            on_value_changed: 值变化回调
            on_finished: 动画完成回调

        Returns:
            QPropertyAnimation: 动画对象
        """
        self._cleanup_animation()

        animation = QPropertyAnimation(target_object, b"size")
        animation.setDuration(150)
        animation.setEasingCurve(QEasingCurve.InOutQuad)
        animation.setStartValue(start_size)
        animation.setEndValue(end_size)

        if on_value_changed:
            animation.valueChanged.connect(on_value_changed)
        if on_finished:
            animation.finished.connect(on_finished)

        self.current_animation = animation
        return animation

    def _cleanup_animation(self):
        """清理当前动画。"""
        if self.current_animation:
            self.current_animation.stop()
            self.current_animation.deleteLater()
            self.current_animation = None

    def stop(self):
        """停止当前动画。"""
        self._cleanup_animation()


class RoundedMaskHelper:
    """圆角遮罩辅助类，用于动态更新窗口的圆角遮罩。"""

    @staticmethod
    def update_mask(
        widget: QWidget,
        min_radius: int = CORNER_RADIUS_MIN,
        max_radius: int = CORNER_RADIUS_MAX,
    ):
        """更新窗口的圆角遮罩。

        Args:
            widget: 要更新遮罩的控件
            min_radius: 最小圆角半径
            max_radius: 最大圆角半径
        """
        rect = widget.rect()
        radius = min(rect.width(), rect.height()) // 2
        radius = max(min_radius, min(radius, max_radius))

        path = QPainterPath()
        path.addRoundedRect(rect, radius, radius)
        region = QRegion(path.toFillPolygon().toPolygon())
        widget.setMask(region)

    @staticmethod
    def calculate_radius(
        width: int,
        height: int,
        min_radius: int = CORNER_RADIUS_MIN,
        max_radius: int = CORNER_RADIUS_MAX,
    ) -> int:
        """计算合适的圆角半径。

        Args:
            width: 控件宽度
            height: 控件高度
            min_radius: 最小圆角半径
            max_radius: 最大圆角半径

        Returns:
            int: 计算出的圆角半径
        """
        radius = min(width, height) // 2
        return max(min_radius, min(radius, max_radius))
