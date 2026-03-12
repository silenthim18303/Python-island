"""
现代化灵动岛 - Windows上的动态岛式小部件。
"""

import os
from datetime import datetime

from PySide6.QtCore import (
    QThread,
    QEasingCurve,
    QPropertyAnimation,
    QRect,
    Qt,
    QTimer,
    Signal,
)
from PySide6.QtGui import QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSlider,
    QVBoxLayout,
    QWidget,
)

from app.utils import (
    extract_urls,
    get_all_status,
    get_clipboard_text,
    get_system_brightness,
    open_url,
    open_urls,
    set_brightness,
)


class WorkerThread(QThread):
    """后台工作线程，用于执行耗时操作。"""

    finished_signal = Signal(object)
    error_signal = Signal(str)

    def __init__(self, task_func, *args, **kwargs):
        super().__init__()
        self.task_func = task_func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        try:
            result = self.task_func(*self.args, **self.kwargs)
            self.finished_signal.emit(result)
        except Exception as e:
            self.error_signal.emit(str(e))


class ModernIsland(QWidget):
    """带展开式控制面板的现代化灵动岛小部件。"""

    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)

        # 状态与尺寸
        self.is_expanded = False
        self.screen_w = QApplication.primaryScreen().size().width()
        self.col_rect = QRect((self.screen_w - 180) // 2, 20, 180, 40)
        self.exp_rect = QRect((self.screen_w - 360) // 2, 20, 360, 160)
        self.setGeometry(self.col_rect)

        # 拖动相关变量
        self.dragging = False
        self.drag_start_pos = None
        self.window_start_pos = None

        # 监听焦点变化
        QApplication.instance().focusChanged.connect(self.on_focus_changed)

        # 主容器
        self.container = QFrame(self)
        self.container.setObjectName("IslandContainer")
        self.container.setFixedSize(180, 40)

        self.layout = QVBoxLayout(self.container)
        self.layout.setContentsMargins(15, 0, 15, 0)

        # 1. 折叠态内容：时间
        self.time_label = QLabel("")
        self.time_label.setObjectName("TimeLabel")
        self.time_label.setAlignment(Qt.AlignCenter)
        self.layout.addWidget(self.time_label)

        # 2. 展开态内容：控制组
        self.controls = QWidget()
        self.controls.hide()
        self.ctrl_layout = QVBoxLayout(self.controls)
        self.ctrl_layout.setContentsMargins(5, 20, 5, 10)
        self.ctrl_layout.setSpacing(15)

        # 创建亮度控制行
        # 先初始化图标缓存
        self._icon_cache = {}
        self._preload_icons()

        self.bright_row, self.bright_slider, self.bright_val = \
            self.create_ctrl_row("resources/icons/light.png", "亮度")

        # 绑定事件
        self.bright_slider.valueChanged.connect(
            lambda v: self.update_val(self.bright_val, v, "bright")
        )

        # 3. 状态栏
        self.status_bar = QWidget()
        self.status_layout = QHBoxLayout(self.status_bar)
        self.status_layout.setContentsMargins(10, 5, 10, 5)
        self.status_layout.setSpacing(15)

        # WiFi信息
        self.wifi_icon = QLabel()
        self.wifi_icon.setObjectName("IconLabel")
        if "resources/icons/internet.png" in self._icon_cache:
            self.wifi_icon.setPixmap(self._icon_cache["resources/icons/internet.png"])
        else:
            self.wifi_icon.setText("📶")

        self.wifi_label = QLabel("未连接")
        self.wifi_label.setObjectName("StatusLabel")

        # 蓝牙信息
        self.bluetooth_icon = QLabel()
        self.bluetooth_icon.setObjectName("IconLabel")
        if "resources/icons/bluetooth.png" in self._icon_cache:
            self.bluetooth_icon.setPixmap(self._icon_cache["resources/icons/bluetooth.png"])
        else:
            self.bluetooth_icon.setText("🔵")

        self.bluetooth_label = QLabel("未连接")
        self.bluetooth_label.setObjectName("StatusLabel")

        # 电池信息
        self.battery_icon = QLabel()
        self.battery_icon.setObjectName("IconLabel")
        if "resources/icons/battery.png" in self._icon_cache:
            self.battery_icon.setPixmap(self._icon_cache["resources/icons/battery.png"])
        else:
            self.battery_icon.setText("🔋")

        self.battery_label = QLabel("未知")
        self.battery_label.setObjectName("StatusLabel")

        # 创建WiFi组合
        wifi_layout = QHBoxLayout()
        wifi_layout.setSpacing(5)
        wifi_layout.addWidget(self.wifi_icon)
        wifi_layout.addWidget(self.wifi_label)

        # 创建蓝牙组合
        bluetooth_layout = QHBoxLayout()
        bluetooth_layout.setSpacing(5)
        bluetooth_layout.addWidget(self.bluetooth_icon)
        bluetooth_layout.addWidget(self.bluetooth_label)

        # 创建电池组合
        battery_layout = QHBoxLayout()
        battery_layout.setSpacing(5)
        battery_layout.addWidget(self.battery_icon)
        battery_layout.addWidget(self.battery_label)

        self.status_layout.addLayout(wifi_layout)
        self.status_layout.addLayout(bluetooth_layout)
        self.status_layout.addLayout(battery_layout)

        self.ctrl_layout.addLayout(self.bright_row)
        self.ctrl_layout.addWidget(self.status_bar)
        self.layout.addWidget(self.controls)

        # 时间更新定时器
        self.time_timer = QTimer(self)
        self.time_timer.timeout.connect(self.update_time)
        self.time_timer.start(1000)
        self.update_time()

        # 状态栏信息更新定时器
        self.status_timer = QTimer(self)
        self.status_timer.timeout.connect(self._start_status_update)
        self.status_timer.start(5000)
        self._start_status_update()

        # 亮度调节防抖计时器
        self.debounce_timer = QTimer(self)
        self.debounce_timer.setSingleShot(True)
        self.debounce_timer.timeout.connect(self._start_brightness_apply)
        self.current_brightness = 50

        # 剪贴板监听相关
        self._last_clipboard_text = ""
        self._clipboard_timer = QTimer(self)
        self._clipboard_timer.timeout.connect(self._check_clipboard)
        self._clipboard_timer.start(1500)  # 每1.5秒检查一次剪贴板



        # 加载初始值（异步）
        self._start_initial_values_load()
        # 初始化亮度值
        self.current_brightness = 50

        self.load_qss()

    def _preload_icons(self):
        """预加载图标以提高性能。"""
        icon_files = ["resources/icons/light.png", "resources/icons/volume.png",
                     "resources/icons/internet.png", "resources/icons/bluetooth.png",
                     "resources/icons/battery.png"]
        for path in icon_files:
            if os.path.exists(path):
                pixmap = QPixmap(path)
                self._icon_cache[path] = pixmap.scaled(
                    20, 20, Qt.KeepAspectRatio, Qt.SmoothTransformation
                )

    def _start_initial_values_load(self):
        """异步加载初始值。"""
        # 创建线程获取亮度
        self._brightness_thread = WorkerThread(get_system_brightness)
        self._brightness_thread.finished_signal.connect(
            self._on_brightness_loaded
        )
        self._brightness_thread.start()

    def _on_brightness_loaded(self, brightness):
        """亮度加载完成回调。"""
        if brightness is not None:
            brightness = max(0, min(100, brightness))
            self.bright_slider.setValue(brightness)
            self.bright_val.setText(f"{brightness}%")
            self.current_brightness = brightness



    def _start_status_update(self):
        """启动异步状态更新。"""
        if hasattr(self, '_status_thread') and self._status_thread.isRunning():
            return
        self._status_thread = WorkerThread(get_all_status)
        self._status_thread.finished_signal.connect(self._on_status_updated)
        self._status_thread.error_signal.connect(self._on_status_error)
        self._status_thread.start()
    
    def _on_status_error(self, error):
        """状态更新错误回调。"""
        print(f"状态更新失败: {error}")
        # 可以在这里添加错误处理逻辑，例如显示错误通知

    def _on_status_updated(self, result):
        """状态更新完成回调。"""
        wifi_info, bluetooth_devices, battery_info = result

        ssid, signal, dns_connected = wifi_info
        if ssid and ssid != "未连接":
            self.wifi_label.setText(f"{ssid} ({signal})")
            # 检查DNS连接状态并显示通知
            if dns_connected and not hasattr(self, '_wifi_notification_shown'):
                self.show_notification_on_time("已连接到网络", "📶")
                self._wifi_notification_shown = True
        else:
            self.wifi_label.setText("未连接")
            # 重置通知标志
            if hasattr(self, '_wifi_notification_shown'):
                delattr(self, '_wifi_notification_shown')

        if bluetooth_devices:
            device_name, status = bluetooth_devices[0]
            self.bluetooth_label.setText(f"{device_name} ({status})")
            # 检查蓝牙连接状态并显示通知
            if status in ["已开启", "Connected", "已连接"] and not hasattr(self, '_bluetooth_notification_shown'):
                self.show_notification_on_time("蓝牙已连接", "🔵")
                self._bluetooth_notification_shown = True
        else:
            self.bluetooth_label.setText("未连接")
            # 重置通知标志
            if hasattr(self, '_bluetooth_notification_shown'):
                delattr(self, '_bluetooth_notification_shown')

        charge, status = battery_info
        if charge:
            self.battery_label.setText(f"{charge}% ({status})")
        else:
            self.battery_label.setText("未知")

    def create_ctrl_row(self, icon_path, label_text):
        """创建包含图标、标签、滑动条和数值控件的行。"""
        row = QHBoxLayout()
        row.setSpacing(12)

        # 图标（使用缓存或备用符号）
        icon = QLabel()
        icon.setObjectName("IconLabel")

        if icon_path in self._icon_cache:
            icon.setPixmap(self._icon_cache[icon_path])
        elif label_text == "亮度":
            icon.setText("\u0f0a0")
        else:
            icon.setText("\u0f05a")

        # 标签文本
        label = QLabel(label_text)
        label.setObjectName("ValueLabel")
        label.setFixedWidth(30)

        # 现代滑动条
        slider = QSlider(Qt.Horizontal)
        slider.setRange(0, 100)
        slider.setFixedHeight(32)
        slider.setObjectName("CapsuleSlider")
        slider.setFixedWidth(180)

        # 百分比数值
        val_label = QLabel("50%")
        val_label.setFixedWidth(40)
        val_label.setObjectName("ValueLabel")

        row.addWidget(icon)
        row.addWidget(label)
        row.addWidget(slider)
        row.addWidget(val_label)

        return row, slider, val_label

    def update_val(self, label, value, val_type):
        """更新数值标签并触发防抖应用。"""
        label.setText(f"{value}%")
        if val_type == "bright":
            self.current_brightness = value
            self.debounce_timer.stop()
            self.debounce_timer.start(180)

    def _start_brightness_apply(self):
        """异步应用亮度。"""
        if hasattr(self, '_brightness_apply_thread') and \
                self._brightness_apply_thread.isRunning():
            return
        self._brightness_apply_thread = WorkerThread(
            set_brightness, self.current_brightness
        )
        self._brightness_apply_thread.start()



    def mousePressEvent(self, event):
        """处理鼠标按下事件用于拖动。"""
        if event.button() == Qt.LeftButton:
            self.dragging = True
            self.drag_start_pos = event.globalPos()
            self.window_start_pos = self.frameGeometry().topLeft()

    def mouseMoveEvent(self, event):
        """处理鼠标移动事件用于拖动。"""
        if self.dragging:
            delta = event.globalPos() - self.drag_start_pos
            self.move(self.window_start_pos + delta)

    def mouseReleaseEvent(self, event):
        """处理鼠标释放事件 - 点击时切换，结束时停止拖动。"""
        if event.button() == Qt.LeftButton:
            if self.dragging and \
                    (event.globalPos() - self.drag_start_pos).manhattanLength() < 5:
                self.toggle_island()
            self.dragging = False

    def on_focus_changed(self, old_widget, new_widget):
        """失去焦点时自动收缩。"""
        if self.is_expanded:
            current_widget = new_widget
            while current_widget:
                if current_widget == self:
                    return
                current_widget = current_widget.parent()
            self.toggle_island()

    def toggle_island(self):
        """在展开和折叠状态之间切换。"""
        self.ani = QPropertyAnimation(self, b"geometry")
        self.ani.setDuration(450)
        self.ani.setEasingCurve(QEasingCurve.OutQuart)

        current_pos = self.pos()

        if not self.is_expanded:
            new_rect = QRect(
                current_pos.x(), current_pos.y(),
                self.exp_rect.width(), self.exp_rect.height()
            )
            self.ani.setEndValue(new_rect)
            self.time_label.hide()
            self.controls.show()
        else:
            new_rect = QRect(
                current_pos.x(), current_pos.y(),
                self.col_rect.width(), self.col_rect.height()
            )
            self.ani.setEndValue(new_rect)
            self.controls.hide()
            self.time_label.show()

        self.ani.valueChanged.connect(
            lambda g: self.container.setFixedSize(g.width(), g.height())
        )
        self.ani.start()
        self.is_expanded = not self.is_expanded

    def update_time(self):
        """更新时间显示。"""
        current_time = datetime.now().strftime("%H:%M")
        self.time_label.setText(current_time)

    def show_notification_on_time(self, message, icon="📶"):
        """在灵动岛的时间位置显示通知，然后过几秒再恢复时间显示。"""
        # 保存当前时间文本，用于稍后恢复
        if hasattr(self, 'time_label'):
            self._original_time_text = self.time_label.text()
            
            # 暂停时钟更新定时器
            if hasattr(self, 'time_timer'):
                self.time_timer.stop()
            
            # 显示通知内容
            self.time_label.setText(f"{icon} {message}")
            
            # 设置定时器，2秒后恢复时间显示
            self._notification_timer = QTimer(self)
            self._notification_timer.setSingleShot(True)
            self._notification_timer.timeout.connect(self._restore_time_display)
            self._notification_timer.start(2000)  # 2秒后恢复
    
    def _restore_time_display(self):
        """恢复时间显示。"""
        if hasattr(self, 'time_label') and hasattr(self, '_original_time_text'):
            # 恢复时间显示
            self.update_time()  # 直接更新到当前时间
            # 恢复时钟更新定时器
            if hasattr(self, 'time_timer'):
                self.time_timer.start(1000)
            # 清理临时属性
            if hasattr(self, '_original_time_text'):
                delattr(self, '_original_time_text')
            if hasattr(self, '_notification_timer'):
                delattr(self, '_notification_timer')

    def _check_clipboard(self):
        """检查剪贴板是否有新的 URL。"""
        current_text = get_clipboard_text()
        if not current_text or current_text == self._last_clipboard_text:
            return

        self._last_clipboard_text = current_text

        # 提取 URL
        urls = extract_urls(current_text)
        if not urls:
            return

        # 显示通知让用户选择
        self._show_url_notification(urls)

    def _show_url_notification(self, urls: list):
        """显示 URL 通知让用户选择是否打开。"""
        if len(urls) == 1:
            url = urls[0]
            # 不直接显示URL，只显示提示
            self.show_notification_on_time("检测到链接", "🔗")

            # 延迟后显示选择对话框
            QTimer.singleShot(1500, lambda: self._show_single_url_dialog(urls[0]))
        else:
            # 多个 URL，显示选择对话框
            self._show_url_selection_dialog(urls)

    def _show_single_url_dialog(self, url: str):
        """显示单个 URL 的选择对话框。"""
        dialog = QFrame(self)
        dialog.setWindowFlags(Qt.Popup | Qt.FramelessWindowHint)
        dialog.setObjectName("UrlDialog")
        dialog.setFixedSize(320, 120)

        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setSpacing(10)

        # 标题
        title = QLabel("检测到链接")
        title.setObjectName("DialogTitle")
        layout.addWidget(title)

        # URL 显示
        url_label = QLabel(url[:50] + "..." if len(url) > 50 else url)
        url_label.setObjectName("UrlLabel")
        url_label.setWordWrap(True)
        layout.addWidget(url_label)

        # 按钮区域
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)

        cancel_btn = QPushButton("忽略")
        cancel_btn.setObjectName("DialogButton")
        cancel_btn.clicked.connect(dialog.close)

        open_btn = QPushButton("打开链接")
        open_btn.setObjectName("DialogButton")
        open_btn.clicked.connect(lambda: self._open_and_close(url, dialog))

        btn_layout.addWidget(cancel_btn)
        btn_layout.addWidget(open_btn)
        layout.addLayout(btn_layout)

        # 显示在灵动岛下方
        dialog_pos = self.mapToGlobal(self.rect().bottomLeft())
        dialog.move(dialog_pos.x() - 50, dialog_pos.y() + 10)
        dialog.show()

    def _open_and_close(self, url: str, dialog):
        """打开 URL 并关闭对话框。"""
        open_url(url)
        dialog.close()

    def _show_url_selection_dialog(self, urls: list):
        """显示 URL 选择对话框。"""
        # 创建对话框
        dialog = QFrame(self)
        dialog.setWindowFlags(Qt.Popup | Qt.FramelessWindowHint)
        dialog.setObjectName("UrlDialog")
        dialog.setFixedSize(320, min(400, 80 + len(urls) * 50))

        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setSpacing(10)

        # 标题
        title = QLabel(f"检测到 {len(urls)} 个链接")
        title.setObjectName("DialogTitle")
        layout.addWidget(title)

        # URL 列表
        self._url_checkboxes = []
        for url in urls:
            checkbox = QCheckBox(url[:60] + "..." if len(url) > 60 else url)
            checkbox.setChecked(True)
            checkbox._url = url
            self._url_checkboxes.append(checkbox)
            layout.addWidget(checkbox)

        # 按钮区域
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(10)

        cancel_btn = QPushButton("取消")
        cancel_btn.setObjectName("DialogButton")
        cancel_btn.clicked.connect(dialog.close)

        open_btn = QPushButton("打开选中")
        open_btn.setObjectName("DialogButton")
        open_btn.clicked.connect(lambda: self._open_selected_urls(dialog))

        btn_layout.addWidget(cancel_btn)
        btn_layout.addWidget(open_btn)
        layout.addLayout(btn_layout)

        # 显示在灵动岛下方
        dialog_pos = self.mapToGlobal(self.rect().bottomLeft())
        dialog.move(dialog_pos.x() - 50, dialog_pos.y() + 10)
        dialog.show()

    def _open_selected_urls(self, dialog):
        """打开选中的 URL。"""
        for checkbox in self._url_checkboxes:
            if checkbox.isChecked():
                open_url(checkbox._url)
        dialog.close()

    def _open_all_urls(self, urls: list):
        """打开所有 URL。"""
        open_urls(urls)

    def load_qss(self):
        """加载QSS样式表。"""
        with open("resources/styles/style.qss", "r", encoding="utf-8") as f:
            self.setStyleSheet(f.read())