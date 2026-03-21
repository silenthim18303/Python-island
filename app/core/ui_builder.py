"""UI构建器模块

负责灵动岛UI组件的构建和初始化。
"""

from typing import Tuple, Dict, Any
from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFrame, QHBoxLayout, QLabel,
    QStackedWidget, QVBoxLayout, QWidget, QSlider
)

from app.core.config import (
    COLLAPSED_WIDTH,
    COLLAPSED_HEIGHT,
    CONTROLS_HEIGHT,
    EXPANDED_WIDTH,
    TIME_LABEL_HEIGHT,
)
from app.core.icons import IslandIcon
from app.ui.controls import ControlRowFactory
from app.ui.status_bar import StatusBar
from app.ui.url_dialog import UrlDialog


class IslandUIBuilder:
    """灵动岛UI构建器

    负责创建和配置所有UI组件。

    Attributes:
        container: 主容器
        time_label: 时间标签
        date_label: 日期标签
        controls: 控制面板堆栈
        status_bar: 状态栏
        bright_slider: 亮度滑块
        bright_val: 亮度值标签
    """

    def __init__(self, parent: QWidget):
        self._parent = parent
        self._icon_cache: Dict[IslandIcon, Any] = {}

    def build(self) -> Tuple[QFrame, QLabel, QLabel, QStackedWidget, StatusBar, QSlider, QLabel]:
        self._icon_cache = ControlRowFactory.preload_icons(list(IslandIcon))

        container = self._create_container()
        time_label, date_label = self._create_time_labels()
        controls, status_bar, bright_slider, bright_val = self._create_controls()

        layout = QVBoxLayout(container)
        layout.setContentsMargins(15, 0, 15, 0)
        layout.addWidget(time_label)
        layout.addWidget(controls)

        return container, time_label, date_label, controls, status_bar, bright_slider, bright_val

    def _create_container(self) -> QFrame:
        container = QFrame(self._parent)
        container.setObjectName("IslandContainer")
        container.setFixedSize(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)
        container.setMouseTracking(True)
        return container

    def _create_time_labels(self) -> Tuple[QLabel, QLabel]:
        time_label = QLabel("")
        time_label.setObjectName("TimeLabel")
        time_label.setAlignment(Qt.AlignCenter)
        time_label.setFixedHeight(TIME_LABEL_HEIGHT)

        date_label = QLabel("")
        date_label.setObjectName("DateLabel")
        date_label.setAlignment(Qt.AlignCenter)
        date_label.setFixedHeight(TIME_LABEL_HEIGHT)
        date_label.hide()
        date_label.setParent(self._parent)

        return time_label, date_label

    def _create_controls(self) -> Tuple[QStackedWidget, StatusBar, QSlider, QLabel]:
        controls = QStackedWidget()
        controls.hide()
        controls.setFixedHeight(CONTROLS_HEIGHT)

        ctrl_page, status_bar, bright_slider, bright_val = self._create_ctrl_page()
        url_single_page, url_multi_page = self._create_url_pages()

        controls.addWidget(ctrl_page)
        controls.addWidget(url_single_page)
        controls.addWidget(url_multi_page)

        return controls, status_bar, bright_slider, bright_val

    def _create_ctrl_page(self) -> Tuple[QWidget, StatusBar, QSlider, QLabel]:
        ctrl_page = QWidget()
        ctrl_layout = QVBoxLayout(ctrl_page)
        #减少顶部边距
        ctrl_layout.setContentsMargins(5, 20, 5, 10)
        ctrl_layout.setSpacing(15)

        bright_row, bright_slider, bright_val = \
            ControlRowFactory.create(self._icon_cache, IslandIcon.LIGHT, "亮度")

        status_bar = StatusBar(self._icon_cache, self._parent)

        ctrl_layout.addLayout(bright_row)
        ctrl_layout.addWidget(status_bar)

        return ctrl_page, status_bar, bright_slider, bright_val

    def _create_url_pages(self) -> Tuple[UrlDialog, UrlDialog]:
        url_single_page = UrlDialog()
        url_multi_page = UrlDialog()
        return url_single_page, url_multi_page

    @staticmethod
    def calculate_label_width(label: QLabel, text: str, object_name: str = None) -> int:
        temp_label = QLabel(text)
        if object_name:
            temp_label.setObjectName(object_name)
            temp_label.setStyleSheet(label.styleSheet())
            temp_label.setFont(label.font())
        temp_label.adjustSize()
        return temp_label.width()

    @staticmethod
    def position_label_center(label: QLabel, text: str, container_width: int, object_name: str = None, container_height: int = None):
        width = IslandUIBuilder.calculate_label_width(label, text, object_name)
        x = (container_width - width) // 2
        
        # 垂直居中
        y = 0
        if container_height:
            label_height = label.height()
            y = (container_height - label_height) // 2
        
        label.setFixedWidth(width)
        label.move(x, y)

    def get_icon_cache(self) -> Dict[IslandIcon, Any]:
        return self._icon_cache