"""现代化灵动岛主窗口模块

实现灵动岛的主窗口，整合各个功能模块，提供完整的用户界面。
"""

from datetime import datetime

from PySide6.QtCore import QEvent, QRect, Qt, QTimer
from PySide6.QtWidgets import (
    QApplication, QFrame, QHBoxLayout, QLabel,
    QStackedWidget, QVBoxLayout, QWidget,
)

from app.animations.effects import AnimationManager, RoundedMaskHelper
from app.core.config import (
    ALL_ICONS,
    CLIPBOARD_CHECK_INTERVAL,
    COLLAPSED_HEIGHT,
    COLLAPSED_WIDTH,
    CONNECTION_AUTO_CLOSE_DELAY,
    CONTROLS_HEIGHT,
    DEBOUNCE_DELAY,
    EXPANDED_HEIGHT,
    EXPANDED_WIDTH,
    ICON_LIGHT,
    MAX_EXPAND_HEIGHT_RATIO,
    STATUS_UPDATE_INTERVAL,
    STYLES_PATH,
    TIME_LABEL_HEIGHT,
    TIME_UPDATE_INTERVAL,
    URL_AUTO_CLOSE_DELAY,
)
from app.core.worker import WorkerThread
from app.services.brightness import BrightnessService
from app.services.clipboard import ClipboardService
from app.services.system_status import SystemStatusService
from app.services.tray import TrayService
from app.ui.controls import ControlRowFactory
from app.ui.status_bar import StatusBar
from app.ui.url_dialog import UrlDialog


class ModernIsland(QWidget):
    """带展开式控制面板的现代化灵动岛小部件。

    整合各个功能模块，提供时间显示、亮度控制、系统状态显示、
    剪贴板URL检测等功能。

    Attributes:
        is_expanded: 是否处于展开状态
        animation_manager: 动画管理器
        clipboard_service: 剪贴板服务
        status_service: 系统状态服务
        brightness_service: 亮度控制服务
    """

    def __init__(self):
        """初始化灵动岛窗口。"""
        super().__init__()
        self._init_window()
        self._init_services()
        self._init_ui()
        self._init_timers()
        self._load_styles()

    def _init_window(self):
        """初始化窗口属性。"""
        self.setWindowFlags(
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)

        self.is_expanded = False
        self.screen_w = QApplication.primaryScreen().size().width()
        self.screen_h = QApplication.primaryScreen().size().height()
        self.max_expand_h = self.screen_h // MAX_EXPAND_HEIGHT_RATIO

        self.col_rect = QRect(
            (self.screen_w - COLLAPSED_WIDTH) // 2, 20,
            COLLAPSED_WIDTH, COLLAPSED_HEIGHT
        )
        self.exp_rect = QRect(
            (self.screen_w - EXPANDED_WIDTH) // 2, 20,
            EXPANDED_WIDTH, EXPANDED_HEIGHT
        )
        self.setGeometry(self.col_rect)

        self.dragging = False
        self.drag_start_pos = None
        self.window_start_pos = None

        QApplication.instance().focusChanged.connect(self._on_focus_changed)

    def _init_services(self):
        """初始化服务。"""
        self.animation_manager = AnimationManager(self)
        self.clipboard_service = ClipboardService()
        self.status_service = SystemStatusService()
        self.tray_service = TrayService()
        self.brightness_service = BrightnessService()

        self._previous_wifi_status = None
        self._previous_bluetooth_status = None
        self._first_status_check = True
        self.current_brightness = 50

    def _init_ui(self):
        """初始化UI组件。"""
        self.container = QFrame(self)
        self.container.setObjectName("IslandContainer")
        self.container.setFixedSize(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)

        self.layout = QVBoxLayout(self.container)
        self.layout.setContentsMargins(15, 0, 15, 0)

        self._icon_cache = ControlRowFactory.preload_icons(ALL_ICONS)

        self._init_time_labels()
        self._init_status_bar()
        self._init_controls()

        self.layout.addWidget(self.time_label)
        self.layout.addWidget(self.controls)

        self._update_rounded_mask()

    def _init_time_labels(self):
        """初始化时间标签。"""
        self.time_label = QLabel("")
        self.time_label.setObjectName("TimeLabel")
        self.time_label.setAlignment(Qt.AlignCenter)
        self.time_label.setFixedHeight(TIME_LABEL_HEIGHT)

        self.date_label = QLabel("")
        self.date_label.setObjectName("DateLabel")
        self.date_label.setAlignment(Qt.AlignCenter)
        self.date_label.setFixedHeight(TIME_LABEL_HEIGHT)
        self.date_label.hide()
        self.date_label.setParent(self.container)

    def _init_controls(self):
        """初始化控制面板。"""
        self.controls = QStackedWidget()
        self.controls.hide()

        self._init_ctrl_page()
        self._init_url_pages()

        self.controls.setFixedHeight(CONTROLS_HEIGHT)

    def _init_ctrl_page(self):
        """初始化控制面板页面。"""
        self.ctrl_page = QWidget()
        self.ctrl_layout = QVBoxLayout(self.ctrl_page)
        self.ctrl_layout.setContentsMargins(5, 20, 5, 10)
        self.ctrl_layout.setSpacing(15)

        self.bright_row, self.bright_slider, self.bright_val = \
            ControlRowFactory.create(self._icon_cache, ICON_LIGHT, "亮度")

        self.bright_slider.valueChanged.connect(
            lambda v: self._update_brightness_value(v)
        )

        self.ctrl_layout.addLayout(self.bright_row)
        self.ctrl_layout.addWidget(self.status_bar)

        self.controls.addWidget(self.ctrl_page)

    def _init_url_pages(self):
        """初始化URL页面。"""
        self.url_single_page = UrlDialog()
        self.url_multi_page = UrlDialog()

        self.controls.addWidget(self.url_single_page)
        self.controls.addWidget(self.url_multi_page)

    def _init_status_bar(self):
        """初始化状态栏。"""
        self.status_bar = StatusBar(self._icon_cache, self)

    def _init_timers(self):
        """初始化定时器。"""
        self.time_timer = QTimer(self)
        self.time_timer.timeout.connect(self._update_time)
        self.time_timer.start(TIME_UPDATE_INTERVAL)
        self._update_time()

        self.status_timer = QTimer(self)
        self.status_timer.timeout.connect(self._start_status_update)
        self.status_timer.start(STATUS_UPDATE_INTERVAL)

        self.debounce_timer = QTimer(self)
        self.debounce_timer.setSingleShot(True)
        self.debounce_timer.timeout.connect(self._start_brightness_apply)

        self._clipboard_timer = QTimer(self)
        self._clipboard_timer.timeout.connect(self._check_clipboard)
        self._clipboard_timer.start(CLIPBOARD_CHECK_INTERVAL)

        self._start_status_update()
        self._start_initial_values_load()

    def _load_styles(self):
        """加载样式表。"""
        try:
            with open(STYLES_PATH, "r", encoding="utf-8") as f:
                self.setStyleSheet(f.read())
        except Exception:
            pass

    def _start_initial_values_load(self):
        """异步加载初始值。"""
        self._brightness_thread = WorkerThread(
            BrightnessService.get_brightness
        )
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
        self._status_thread = WorkerThread(SystemStatusService.get_all_status)
        self._status_thread.finished_signal.connect(self._on_status_updated)
        self._status_thread.error_signal.connect(self._on_status_error)
        self._status_thread.start()

    def _on_status_error(self, error):
        """状态更新错误回调。"""
        print(f"状态更新失败: {error}")

    def _on_status_updated(self, result):
        """状态更新完成回调。"""
        wifi_info, bluetooth_devices, battery_info = result

        ssid, signal, dns_connected = wifi_info
        self.status_bar.update_wifi(ssid, signal)

        if bluetooth_devices:
            device_name, status = bluetooth_devices[0]
            self.status_bar.update_bluetooth(device_name, status)
        else:
            self.status_bar.update_bluetooth()

        charge, status = battery_info
        self.status_bar.update_battery(charge, status)

        if self._first_status_check:
            self._previous_wifi_status = (ssid, dns_connected)
            self._previous_bluetooth_status = bluetooth_devices
            self._first_status_check = False
            return

        self._check_status_changes(ssid, dns_connected, bluetooth_devices)

    def _check_status_changes(self, ssid, dns_connected, bluetooth_devices):
        """检查状态变化。"""
        current_wifi_status = (ssid, dns_connected)
        current_bluetooth_status = bluetooth_devices

        wifi_connected = ssid and ssid != "未连接" and dns_connected
        prev_wifi_connected = (
            self._previous_wifi_status and
            self._previous_wifi_status[0] and
            self._previous_wifi_status[0] != "未连接" and
            self._previous_wifi_status[1]
        )

        bluetooth_connected = (
            bluetooth_devices and
            bluetooth_devices[0][1] in ["已开启", "Connected", "已连接"]
        )
        prev_bluetooth_connected = (
            self._previous_bluetooth_status and
            self._previous_bluetooth_status[0][1] in ["已开启", "Connected", "已连接"]
        )

        if wifi_connected != prev_wifi_connected:
            message = "WiFi已连接" if wifi_connected else "WiFi已断开"
            self._show_connection_animation(message, "📶")
        elif bluetooth_connected != prev_bluetooth_connected:
            message = "蓝牙已连接" if bluetooth_connected else "蓝牙已断开"
            self._show_connection_animation(message, "🔵")

        self._previous_wifi_status = current_wifi_status
        self._previous_bluetooth_status = current_bluetooth_status

    def _update_brightness_value(self, value):
        """更新亮度值。"""
        self.bright_val.setText(f"{value}%")
        self.current_brightness = value
        self.debounce_timer.stop()
        self.debounce_timer.start(DEBOUNCE_DELAY)

    def _start_brightness_apply(self):
        """异步应用亮度。"""
        if hasattr(self, '_brightness_apply_thread') and \
                self._brightness_apply_thread.isRunning():
            return
        self._brightness_apply_thread = WorkerThread(
            BrightnessService.set_brightness, self.current_brightness
        )
        self._brightness_apply_thread.start()

    def _update_time(self):
        """更新时间显示。"""
        self._update_time_display()

    def _update_time_display(self):
        """根据展开/收起状态更新时间或日期显示。"""
        current_time = datetime.now().strftime("%H:%M")
        current_date = datetime.now().strftime("%m/%d")

        self.time_label.setText(current_time)
        self.date_label.setText(f"{current_date} {current_time}")

        if self.is_expanded:
            temp_label = QLabel(f"{current_date} {current_time}")
            temp_label.setObjectName("DateLabel")
            temp_label.setStyleSheet(self.date_label.styleSheet())
            temp_label.setFont(self.date_label.font())
            temp_label.adjustSize()
            width = temp_label.width()
            x = (EXPANDED_WIDTH - width) // 2
            self.date_label.setFixedWidth(width)
            self.date_label.move(x, 0)

    def _check_clipboard(self):
        """检查剪贴板是否有新的URL。"""
        has_new, urls = self.clipboard_service.check_for_new_urls()
        if has_new:
            self._show_url_notification(urls)

    def _show_url_notification(self, urls: list):
        """显示URL通知。"""
        if len(urls) == 1:
            self.controls.setCurrentWidget(self.url_single_page)
            self.url_single_page.build_single_url_page(
                urls[0],
                self._open_url_and_close,
                self._close_url_page
            )
            target_height = EXPANDED_HEIGHT
        else:
            self.controls.setCurrentWidget(self.url_multi_page)
            target_height = self.url_multi_page.build_multi_url_page(
                urls,
                self._open_selected_and_close,
                self._close_url_page
            )
            target_height = min(target_height, self.max_expand_h)

        self._expand_to_url_page(target_height)

        if hasattr(self, '_url_auto_close_timer') and \
                self._url_auto_close_timer.isActive():
            self._url_auto_close_timer.stop()

        self._url_auto_close_timer = QTimer(self)
        self._url_auto_close_timer.setSingleShot(True)
        self._url_auto_close_timer.timeout.connect(self._close_url_page)
        self._url_auto_close_timer.start(URL_AUTO_CLOSE_DELAY)

    def _expand_to_url_page(self, target_height: int = EXPANDED_HEIGHT):
        """展开灵动岛到URL页面。"""
        if self.is_expanded:
            current_h = self.geometry().height()
            if current_h != target_height:
                self._animate_height_change(current_h, target_height)
            return

        self._do_expand_and_show_url(target_height)

    def _animate_height_change(self, from_h: int, to_h: int):
        """动态调整高度的动画。"""
        current_pos = self.pos()
        current_w = self.geometry().width()

        def on_value_changed(value):
            self.container.setFixedSize(current_w, value.height())
            self._set_controls_height(value.height())
            self._update_rounded_mask()

        def on_finished():
            self.container.setFixedSize(current_w, to_h)
            self._set_controls_height(to_h)

        self.animation_manager.create_height_animation(
            from_h, to_h, on_value_changed, on_finished
        ).start()

    def _set_controls_height(self, container_h: int):
        """根据容器高度同步设置controls高度。"""
        controls_h = max(0, int(container_h) - TIME_LABEL_HEIGHT)
        self.controls.setFixedHeight(controls_h)

    def _do_expand_and_show_url(self, target_height: int = EXPANDED_HEIGHT):
        """执行展开动画并显示链接页面。"""
        current_pos = self.geometry().topLeft()
        current_w = self.rect().width()
        current_h = self.rect().height()
        center_x = current_pos.x() + current_w // 2

        self.time_label.hide()
        self.date_label.show()
        self._update_time_display()

        def on_value_changed(value):
            if value.width() > 50:
                self.controls.show()
            self.container.setFixedSize(
                value.width(),
                TIME_LABEL_HEIGHT + (target_height - TIME_LABEL_HEIGHT) * (value.width() / EXPANDED_WIDTH)
            )
            self._set_controls_height(
                TIME_LABEL_HEIGHT + (target_height - TIME_LABEL_HEIGHT) * (value.width() / EXPANDED_WIDTH)
            )
            self._update_rounded_mask()

        def on_finished():
            self.controls.show()
            self.container.setFixedSize(EXPANDED_WIDTH, target_height)
            self._set_controls_height(target_height)

        self.animation_manager.create_url_expand_animation(
            target_height, on_value_changed, on_finished
        ).start()
        self.is_expanded = True

    def _close_url_page(self):
        """关闭链接页面。"""
        self.controls.setCurrentWidget(self.ctrl_page)
        self.controls.setFixedHeight(CONTROLS_HEIGHT)
        if self.is_expanded:
            self.toggle_island()

    def _open_url_and_close(self, url: str):
        """打开URL并收起灵动岛。"""
        ClipboardService.open_url(url)
        self._close_url_page()

    def _open_selected_and_close(self):
        """打开选中的URL并收起灵动岛。"""
        selected_urls = self.url_multi_page.get_selected_urls()
        if selected_urls:
            ClipboardService.open_urls(selected_urls)
        self._close_url_page()

    def _show_connection_animation(self, message, icon="📶"):
        """显示连接状态变化的动画提示。"""
        self.time_timer.stop()

        if not self.is_expanded:
            self._do_expand_and_show_connection(message, icon)
        else:
            self._update_connection_display(message, icon)

        if hasattr(self, '_connection_auto_close_timer') and \
                self._connection_auto_close_timer.isActive():
            self._connection_auto_close_timer.stop()

        self._connection_auto_close_timer = QTimer(self)
        self._connection_auto_close_timer.setSingleShot(True)
        self._connection_auto_close_timer.timeout.connect(
            self._close_connection_page
        )
        self._connection_auto_close_timer.start(CONNECTION_AUTO_CLOSE_DELAY)

    def _do_expand_and_show_connection(self, message, icon="📶"):
        """执行展开动画并显示连接状态。"""
        current_pos = self.geometry().topLeft()
        current_w = self.rect().width()
        current_h = self.rect().height()
        center_x = current_pos.x() + current_w // 2

        self.time_label.hide()
        self.date_label.hide()

        def on_value_changed(value):
            if value.width() > 50:
                self.controls.show()
            self.container.setFixedSize(value.width(), EXPANDED_HEIGHT)
            self._set_controls_height(EXPANDED_HEIGHT)
            self._update_rounded_mask()

        def on_finished():
            self.controls.show()
            self.container.setFixedSize(EXPANDED_WIDTH, EXPANDED_HEIGHT)
            self._set_controls_height(EXPANDED_HEIGHT)
            self._update_connection_display(message, icon)

        self.animation_manager.create_url_expand_animation(
            EXPANDED_HEIGHT, on_value_changed, on_finished
        ).start()
        self.is_expanded = True

    def _update_connection_display(self, message, icon="📶"):
        """更新连接状态显示。"""
        self.controls.setCurrentWidget(self.ctrl_page)
        self.time_label.hide()
        self.date_label.setText(f"{icon} {message}")
        self.date_label.show()

        temp_label = QLabel(f"{icon} {message}")
        temp_label.setObjectName("DateLabel")
        temp_label.setStyleSheet(self.date_label.styleSheet())
        temp_label.setFont(self.date_label.font())
        temp_label.adjustSize()
        width = temp_label.width()
        x = (EXPANDED_WIDTH - width) // 2
        self.date_label.setFixedWidth(width)
        self.date_label.move(x, 0)

    def _close_connection_page(self):
        """关闭连接状态页面。"""
        if self.is_expanded:
            self.toggle_island()

        self.time_timer.start(TIME_UPDATE_INTERVAL)
        self._update_time()

    def _update_rounded_mask(self):
        """动态更新窗口的圆角遮罩。"""
        RoundedMaskHelper.update_mask(self)

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
        """处理鼠标释放事件。"""
        if event.button() == Qt.LeftButton:
            if self.dragging and \
                    (event.globalPos() - self.drag_start_pos).manhattanLength() < 5:
                self.toggle_island()
            self.dragging = False

    def _on_focus_changed(self, old_widget, new_widget):
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
        current_pos = self.pos()

        if not self.is_expanded:
            self._do_expand(current_pos)
        else:
            self._do_collapse(current_pos)

    def _do_expand(self, current_pos):
        """执行展开动画。"""
        self.is_expanded = True

        self.time_label.hide()
        self.date_label.hide()

        start = self.geometry()
        end = QRect(
            current_pos.x() + self.rect().width() / 2 - 180,
            current_pos.y(),
            EXPANDED_WIDTH, EXPANDED_HEIGHT
        )

        def on_value_changed(value):
            self._update_rounded_mask()

        def on_finished():
            self.date_label.show()
            self._update_time_display()

        self.animation_manager.create_expand_animation(
            start, end, on_value_changed, on_finished
        ).start()

        self.controls.show()
        self.container.setFixedSize(EXPANDED_WIDTH, EXPANDED_HEIGHT)

    def _do_collapse(self, current_pos):
        """执行收起动画。"""
        self.is_expanded = False

        self.date_label.hide()
        self.time_label.hide()

        start = self.geometry()
        end = QRect(
            current_pos.x() + self.rect().width() / 2 - 90,
            current_pos.y(),
            COLLAPSED_WIDTH, COLLAPSED_HEIGHT
        )

        def on_value_changed(value):
            self._update_rounded_mask()

        def on_finished():
            self.time_label.show()
            self._update_time_display()
            self.container.setFixedSize(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)

        self.animation_manager.create_collapse_animation(
            start, end, on_value_changed, on_finished
        ).start()

        self.controls.setCurrentWidget(self.ctrl_page)
        self.controls.hide()

    def eventFilter(self, obj, event):
        """事件过滤器。"""
        if event.type() == QEvent.Close and obj == getattr(self, '_url_dialog', None):
            self._url_dialog = None
            return True
        return super().eventFilter(obj, event)
