"""URL检测对话框组件模块

提供检测到URL时显示的对话框组件，支持单个和多个URL的显示和操作。
"""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QHBoxLayout,
    QLabel,
    QLayout,
    QPushButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

from app.core.config import (
    MAX_VISIBLE_URLS,      # 最大可见URL数量
    MULTI_URL_BTN_TOP_SPACING,  # 多URL模式下按钮顶部间距
    URL_ITEM_HEIGHT,       # 单个URL项的高度
)


class UrlDialog(QWidget):
    """URL检测对话框组件，用于显示检测到的URL并提供打开选项。"""

    def __init__(self, parent=None):
        """初始化URL对话框。

        Args:
            parent: 父组件
        """
        super().__init__(parent)
        self._url_checkboxes = {}  # 存储复选框与URL的映射关系
        self._init_ui()

    def _init_ui(self):
        """初始化UI组件。"""
        # 创建主布局
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(10, 10, 10, 10)  # 设置边距
        self.main_layout.setSpacing(8)  # 设置组件间距

    def build_single_url_page(self, url: str, on_open, on_cancel):
        """构建单个URL页面。

        Args:
            url: URL字符串
            on_open: 打开回调函数
            on_cancel: 取消回调函数

        Returns:
            QWidget: 构建好的页面
        """
        # 清空现有布局
        self._clear_layout(self.main_layout)

        # 创建标题标签
        title = QLabel("检测到链接")
        title.setObjectName("DialogTitle")
        self.main_layout.addWidget(title)

        # 创建URL标签，限制显示长度
        url_label = QLabel(url[:45] + "..." if len(url) > 45 else url)
        url_label.setObjectName("UrlLabel")
        url_label.setWordWrap(True)  # 允许自动换行
        self.main_layout.addWidget(url_label)

        # 添加按钮上间距，避免按钮紧贴URL标签
        # self.main_layout.addSpacing(15)

        # 创建按钮布局
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)  # 设置按钮间距

        # 创建忽略按钮
        cancel_btn = QPushButton("忽略")
        cancel_btn.setObjectName("DialogButton")
        cancel_btn.clicked.connect(on_cancel)

        # 创建打开链接按钮
        open_btn = QPushButton("打开链接")
        open_btn.setObjectName("DialogButton")
        open_btn.clicked.connect(lambda: on_open(url))

        # 添加按钮到布局
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
        # 清空现有布局
        self._clear_layout(self.main_layout)
        # 重置复选框映射
        self._url_checkboxes = {}

        # 创建标题标签
        title = QLabel(f"检测到 {len(urls)} 个链接")
        title.setObjectName("DialogTitle")
        self.main_layout.addWidget(title)

        # 计算可见URL数量和滚动区域高度
        visible_count = min(len(urls), MAX_VISIBLE_URLS)
        scroll_height = visible_count * URL_ITEM_HEIGHT + 10

        # 创建滚动区域
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)  # 禁用水平滚动条
        # 根据URL数量决定是否显示垂直滚动条
        scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarAsNeeded if len(urls) > MAX_VISIBLE_URLS else Qt.ScrollBarAlwaysOff
        )
        scroll.setObjectName("UrlScrollArea")
        scroll.setFixedHeight(scroll_height)

        # 创建滚动区域内容
        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(0, 0, 0, 0)  # 无内边距
        scroll_layout.setSpacing(0)  # 无间距

        # 添加URL项
        for i, url in enumerate(urls[:visible_count]):
            # 创建URL行组件
            row_widget = QWidget()
            row_layout = QHBoxLayout(row_widget)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(8)

            # 创建复选框
            checkbox = QCheckBox()
            checkbox.setChecked(True)  # 默认选中
            checkbox.setFixedWidth(24)

            # 创建URL标签，限制显示长度
            url_text = url[:35] + "..." if len(url) > 35 else url
            url_label = QLabel(f"{i+1}. {url_text}")
            url_label.setObjectName("UrlLabel")
            url_label.setAlignment(Qt.AlignVCenter)  # 垂直居中

            # 添加组件到行布局
            row_layout.addWidget(checkbox)
            row_layout.addWidget(url_label)
            scroll_layout.addWidget(row_widget)

            # 存储复选框与URL的映射
            self._url_checkboxes[checkbox] = url

        # 如果URL数量超过最大可见数量，显示更多提示
        if len(urls) > visible_count:
            more_label = QLabel(f"...还有 {len(urls) - visible_count} 个")
            more_label.setObjectName("StatusLabel")
            more_label.setMinimumHeight(URL_ITEM_HEIGHT)
            more_label.setAlignment(Qt.AlignVCenter)
            scroll_layout.addWidget(more_label)

        # 设置滚动区域内容
        scroll.setWidget(scroll_content)
        self.main_layout.addWidget(scroll)

        # 添加按钮上间距
        self.main_layout.addSpacing(MULTI_URL_BTN_TOP_SPACING)

        # 创建按钮布局
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)

        # 创建忽略按钮
        ignore_btn = QPushButton("忽略")
        ignore_btn.setObjectName("DialogButton")
        ignore_btn.clicked.connect(on_cancel)

        # 创建打开选中按钮
        open_selected_btn = QPushButton("打开选中")
        open_selected_btn.setObjectName("DialogButton")
        open_selected_btn.clicked.connect(on_open_selected)

        # 添加按钮到布局
        btn_layout.addWidget(ignore_btn)
        btn_layout.addWidget(open_selected_btn)
        self.main_layout.addLayout(btn_layout)

        # 计算目标高度
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
                item.widget().deleteLater()  # 删除组件
                continue
            if item.layout():
                self._clear_layout(item.layout())  # 递归清空子布局
                continue

    def get_selected_urls(self) -> list:
        """获取选中的URL列表。

        Returns:
            list: 选中的URL列表
        """
        selected_urls = []
        # 遍历所有复选框，收集选中的URL
        for checkbox, url in self._url_checkboxes.items():
            if checkbox.isChecked():
                selected_urls.append(url)
        return selected_urls