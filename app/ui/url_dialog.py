"""URL检测对话框组件模块

提供检测到URL时显示的对话框组件，支持单个和多个URL的显示和操作。
"""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
    QPushButton, QScrollArea, QCheckBox, QLayout
)
from PySide6.QtCore import Qt

from app.core.config import (
    MAX_VISIBLE_URLS, URL_ITEM_HEIGHT, MULTI_URL_BTN_TOP_SPACING
)


class UrlDialog(QWidget):
    """URL检测对话框组件，用于显示检测到的URL并提供打开选项。"""

    def __init__(self, parent=None):
        """初始化URL对话框。

        Args:
            parent: 父组件
        """
        super().__init__(parent)
        self._url_checkboxes = {}
        self._init_ui()

    def _init_ui(self):
        """初始化UI组件。"""
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(10, 10, 10, 10)
        self.main_layout.setSpacing(8)

    def build_single_url_page(self, url: str, on_open, on_cancel):
        """构建单个URL页面。

        Args:
            url: URL字符串
            on_open: 打开回调函数
            on_cancel: 取消回调函数

        Returns:
            QWidget: 构建好的页面
        """
        self._clear_layout(self.main_layout)

        title = QLabel("检测到链接")
        title.setObjectName("DialogTitle")
        self.main_layout.addWidget(title)

        url_label = QLabel(url[:45] + "..." if len(url) > 45 else url)
        url_label.setObjectName("UrlLabel")
        url_label.setWordWrap(True)
        self.main_layout.addWidget(url_label)

        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)

        cancel_btn = QPushButton("忽略")
        cancel_btn.setObjectName("DialogButton")
        cancel_btn.clicked.connect(on_cancel)

        open_btn = QPushButton("打开链接")
        open_btn.setObjectName("DialogButton")
        open_btn.clicked.connect(lambda: on_open(url))

        btn_layout.addWidget(cancel_btn)
        btn_layout.addWidget(open_btn)
        self.main_layout.addLayout(btn_layout)

        return self

    def build_multi_url_page(self, urls: list, on_open_selected, on_cancel) -> int:
        """构建多个URL的选择页面。

        Args:
            urls: URL列表
            on_open_selected: 打开选中回调函数
            on_cancel: 取消回调函数

        Returns:
            int: 目标高度
        """
        self._clear_layout(self.main_layout)
        self._url_checkboxes = {}

        title = QLabel(f"检测到 {len(urls)} 个链接")
        title.setObjectName("DialogTitle")
        self.main_layout.addWidget(title)

        visible_count = min(len(urls), MAX_VISIBLE_URLS)
        scroll_height = visible_count * URL_ITEM_HEIGHT + 10

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarAsNeeded if len(urls) > MAX_VISIBLE_URLS else Qt.ScrollBarAlwaysOff
        )
        scroll.setObjectName("UrlScrollArea")
        scroll.setFixedHeight(scroll_height)

        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(0, 0, 0, 0)
        scroll_layout.setSpacing(0)

        for i, url in enumerate(urls[:visible_count]):
            row_widget = QWidget()
            row_layout = QHBoxLayout(row_widget)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(8)

            checkbox = QCheckBox()
            checkbox.setChecked(True)
            checkbox.setFixedWidth(24)

            url_text = url[:35] + "..." if len(url) > 35 else url
            url_label = QLabel(f"{i+1}. {url_text}")
            url_label.setObjectName("UrlLabel")
            url_label.setAlignment(Qt.AlignVCenter)

            row_layout.addWidget(checkbox)
            row_layout.addWidget(url_label)
            scroll_layout.addWidget(row_widget)

            self._url_checkboxes[checkbox] = url

        if len(urls) > visible_count:
            more_label = QLabel(f"...还有 {len(urls) - visible_count} 个")
            more_label.setObjectName("StatusLabel")
            more_label.setMinimumHeight(URL_ITEM_HEIGHT)
            more_label.setAlignment(Qt.AlignVCenter)
            scroll_layout.addWidget(more_label)

        scroll.setWidget(scroll_content)
        self.main_layout.addWidget(scroll)

        self.main_layout.addSpacing(MULTI_URL_BTN_TOP_SPACING)

        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)

        ignore_btn = QPushButton("忽略")
        ignore_btn.setObjectName("DialogButton")
        ignore_btn.clicked.connect(on_cancel)

        open_selected_btn = QPushButton("打开选中")
        open_selected_btn.setObjectName("DialogButton")
        open_selected_btn.clicked.connect(on_open_selected)

        btn_layout.addWidget(ignore_btn)
        btn_layout.addWidget(open_selected_btn)
        self.main_layout.addLayout(btn_layout)

        target_height = 30 + scroll_height + MULTI_URL_BTN_TOP_SPACING + 50 + 20
        return target_height

    def _clear_layout(self, layout: QLayout):
        """递归清空布局。

        Args:
            layout: 要清空的布局
        """
        while layout.count():
            item = layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                continue
            if item.layout():
                self._clear_layout(item.layout())
                continue

    def get_selected_urls(self) -> list:
        """获取选中的URL列表。

        Returns:
            list: 选中的URL列表
        """
        selected_urls = []
        for checkbox, url in self._url_checkboxes.items():
            if checkbox.isChecked():
                selected_urls.append(url)
        return selected_urls
