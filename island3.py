import sys
import time
import socket
import platform
import subprocess
import ctypes
from collections import deque
from threading import Lock
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QSystemTrayIcon, QMenu, QAction, QStyle
)
from PyQt5.QtCore import (
    Qt, QThread, pyqtSignal, QTimer, QPropertyAnimation, QEasingCurve, QPoint, QRect, pyqtProperty
)
from PyQt5.QtGui import (
    QFont, QColor, QPainter, QBrush, QPen, QRegion, QFontMetrics
)

# ====================== 事件常量定义（四位二进制事件代码） ======================
EVENT_CODES = {
    "NETWORK_RESTORE": 0b0001,    # 1
    "BLUETOOTH_CONNECT": 0b0010,  # 2
    "MOUSE_HOVER": 0b0100,        # 4
    "MOUSE_LEAVE": 0b0101,        # 5
    "TEST_NETWORK": 0b1000,       # 8
    "TEST_BLUETOOTH": 0b1001      # 9
}

# ====================== 事件数据模板（统一渲染属性定义） ======================
EVENT_TEMPLATES = {
    # 网络恢复事件模板
    EVENT_CODES["NETWORK_RESTORE"]: {
        "text": "已恢复网络连接",
        "color": "#4CAF50",
        "icon": "🟢"
    },
    # 蓝牙连接事件模板
    EVENT_CODES["BLUETOOTH_CONNECT"]: {
        "text": "已连接蓝牙设备",
        "color": "#2196F3",
        "icon": "🔵"
    },
    # 测试网络事件（复用网络恢复模板）
    EVENT_CODES["TEST_NETWORK"]: {
        "text": "已恢复网络连接",
        "color": "#4CAF50",
        "icon": "🟢"
    },
    # 测试蓝牙事件（复用蓝牙连接模板）
    EVENT_CODES["TEST_BLUETOOTH"]: {
        "text": "已连接蓝牙设备",
        "color": "#2196F3",
        "icon": "🔵"
    }
}

# ====================== 发布订阅模式 - 事件管理器（无修改） ======================
class EventManager:
    _instance = None
    _lock = Lock()

    def __new__(cls):
        # 单例模式确保全局唯一的事件管理器
        with cls._lock:
            if not cls._instance:
                cls._instance = super().__new__(cls)
                cls._instance.event_queue = deque()  # 事件队列
                cls._instance.queue_lock = Lock()    # 队列线程安全锁
                cls._instance.subscribers = {}       # 订阅者字典 {事件码: [回调函数列表]}
                cls._instance.is_processing = False  # 事件处理中标记（防止并发）
                # 定时器轮询事件队列（10ms检查一次）
                cls._instance.queue_timer = QTimer()
                cls._instance.queue_timer.setInterval(10)
                cls._instance.queue_timer.timeout.connect(cls._instance.process_queue)
                cls._instance.queue_timer.start()
        return cls._instance

    def subscribe(self, event_code, callback):
        """订阅事件：注册事件码对应的处理回调"""
        with self._lock:
            if event_code not in self.subscribers:
                self.subscribers[event_code] = []
            if callback not in self.subscribers[event_code]:
                self.subscribers[event_code].append(callback)

    def publish(self, event_code, data=None):
        """发布事件：将事件码和结构化数据加入队列"""
        # 合并默认模板和自定义数据（自定义数据优先级更高）
        event_data = EVENT_TEMPLATES.get(event_code, {}).copy()
        if data:
            event_data.update(data)
        with self.queue_lock:
            self.event_queue.append((event_code, event_data))

    def process_queue(self):
        """处理事件队列：按顺序执行事件回调，确保同一时间只处理一个事件"""
        if self.is_processing:
            return
        
        with self.queue_lock:
            if not self.event_queue:
                return
            # 取出队列头部事件
            event_code, event_data = self.event_queue.popleft()
        
        self.is_processing = True
        try:
            # 执行所有订阅该事件的回调
            if event_code in self.subscribers:
                for callback in self.subscribers[event_code]:
                    callback(event_data)
        finally:
            self.is_processing = False

# ====================== 监测线程（仅发布带结构化数据的事件） ======================
class NetworkMonitor(QThread):
    def run(self):
        event_manager = EventManager()
        was_connected = True
        while True:
            is_connected = self.check_dns()
            if not was_connected and is_connected:
                # 发布网络恢复事件（使用模板数据，可传自定义数据覆盖）
                event_manager.publish(EVENT_CODES["NETWORK_RESTORE"])
            was_connected = is_connected
            time.sleep(CHECK_INTERVAL_NET / 1000)

    def check_dns(self):
        try:
            socket.create_connection(("114.114.114.114", 53), timeout=2)
            return True
        except OSError:
            return False

class BluetoothMonitor(QThread):
    def run(self):
        event_manager = EventManager()
        last_devices = self.get_connected_devices()
        while True:
            time.sleep(CHECK_INTERVAL_BT / 1000)
            current_devices = self.get_connected_devices()
            new_devices = current_devices - last_devices

            if new_devices:
                for dev in new_devices:
                    # 发布蓝牙连接事件（可传自定义文本，比如具体设备名）
                    event_manager.publish(
                        EVENT_CODES["BLUETOOTH_CONNECT"],
                        {"text": f"已连接蓝牙设备：{dev}"}  # 自定义文本覆盖模板
                    )

            last_devices = current_devices

    def get_connected_devices(self):
        devices = set()
        try:
            ps_command = (
                "Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | "
                "Where-Object { $_.FriendlyName -notmatch 'Enumerator|Adapter|Module|Generic|Intel|Realtek' } | "
                "Select-Object -ExpandProperty FriendlyName"
            )

            si = subprocess.STARTUPINFO()
            si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            si.wShowWindow = subprocess.SW_HIDE

            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", ps_command],
                capture_output=True,
                text=True,
                startupinfo=si,
                creationflags=subprocess.CREATE_NO_WINDOW
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    name = line.strip()
                    if name:
                        devices.add(name)
        except Exception as e:
            print(f"BT Check Error: {e}")
        return devices

# ====================== 胶囊容器（纯展示组件，无修改） ======================
class CapsuleWidget(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._radius = CAPSULE_INIT_RADIUS

    def get_radius(self):
        return self._radius

    def set_radius(self, radius):
        self._radius = radius
        self.update()

    radius = pyqtProperty(int, get_radius, set_radius)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setBrush(QBrush(QColor(0, 0, 0, CAPSULE_BG_ALPHA)))
        painter.setPen(Qt.NoPen)
        rect = self.rect()
        painter.drawRoundedRect(rect, self._radius, self._radius)

# ====================== 动态岛窗口（仅负责渲染，无业务样式硬编码） ======================
# 常量定义（调整常态尺寸 + 文字缩放）
ISLAND_INIT_WIDTH = 140      # 调整：常态宽度放大，确保文字显示完整
ISLAND_INIT_HEIGHT = 50       # 调整：常态高度放大
ISLAND_EXPAND_WIDTH = 300
ISLAND_EXPAND_HEIGHT = 80
SCREEN_OFFSET_Y = 10
NOTIFICATION_DURATION = 3500
ANIMATION_DURATION = 450
CONTENT_ANIMATION_DURATION = 300
CONTENT_ANIMATION_DELAY = 100
CHECK_INTERVAL_NET = 3000
CHECK_INTERVAL_BT = 4000
CAPSULE_INIT_RADIUS = 20
CAPSULE_EXPAND_RADIUS = 35
CAPSULE_BG_ALPHA = 128
CONTENT_FONT_SIZE_INIT = 14   # 调整：常态字体大小
CONTENT_FONT_SIZE_EXPAND = 26 # 调整：展开字体大小（对齐HTML）
NOTIFICATION_FONT_SIZE = 18
CAPSULE_PADDING = 20           # 胶囊内边距（左右各10px）

# 计算缩放比例
SCALE_RATIO = ISLAND_EXPAND_WIDTH / ISLAND_INIT_WIDTH

class DynamicIslandWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.drag_pos = None
        self.is_locked = False
        self.is_click_through = False
        self.is_topmost = False
        self.is_notification_active = False
        self.is_hovered = False
        self.animation_running = False
        self.current_notification_font_size = CONTENT_FONT_SIZE_INIT  # 新增：保存通知动态字体大小

        # 初始化事件管理器并订阅所有事件
        self.event_manager = EventManager()
        self._subscribe_events()

        self.init_ui()
        self.init_tray()
        self.center_top()
        self.init_time_update()
        self.init_monitors()
        self.init_animations()

    def _subscribe_events(self):
        """订阅所有需要处理的事件"""
        # 所有通知类事件统一用同一个渲染处理函数
        notification_events = [
            EVENT_CODES["NETWORK_RESTORE"],
            EVENT_CODES["BLUETOOTH_CONNECT"],
            EVENT_CODES["TEST_NETWORK"],
            EVENT_CODES["TEST_BLUETOOTH"]
        ]
        for event_code in notification_events:
            self.event_manager.subscribe(event_code, self._handle_notification)
        
        # 鼠标交互事件
        self.event_manager.subscribe(EVENT_CODES["MOUSE_HOVER"], self._handle_mouse_hover)
        self.event_manager.subscribe(EVENT_CODES["MOUSE_LEAVE"], self._handle_mouse_leave)

    def init_ui(self):
        self.base_flags = Qt.FramelessWindowHint | Qt.Tool
        self.setWindowFlags(self.base_flags)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.resize(ISLAND_INIT_WIDTH, ISLAND_INIT_HEIGHT)

        self.capsule = CapsuleWidget(self)
        self.capsule.setGeometry(self.rect())
        self.capsule.setAttribute(Qt.WA_TransparentForMouseEvents, True)

        self.content_label = QLabel(self.capsule)
        self.content_label.setAlignment(Qt.AlignCenter)
        self.content_label.setTextInteractionFlags(Qt.NoTextInteraction)
        self.content_label.setStyleSheet(f"""
            QLabel {{
                color: white;
                font-family: "Microsoft YaHei", sans-serif;
                font-weight: 600;
                background: transparent;
            }}
        """)
        self.content_label.setGeometry(self.rect())
        self._set_content_font_size(CONTENT_FONT_SIZE_INIT)
        self.content_label.setWindowOpacity(1)

        self.interactive_zone = QWidget(self)
        self.interactive_zone.setGeometry(0, 0, ISLAND_INIT_WIDTH, 40)
        self.interactive_zone.setMouseTracking(True)
        self.setMouseTracking(True)

    def _set_content_font_size(self, size):
        font = self.content_label.font()
        font.setPointSize(size)
        font.setLetterSpacing(QFont.AbsoluteSpacing, 0)
        self.content_label.setFont(font)

    def _set_notification_font_style(self, color):
        """仅控制通知文字颜色和字间距，字体大小由动画驱动"""
        font = self.content_label.font()
        font.setLetterSpacing(QFont.AbsoluteSpacing, 1)
        self.content_label.setFont(font)
        self.content_label.setStyleSheet(f"""
            QLabel {{
                color: {color};
                font-family: "Microsoft YaHei", sans-serif;
                font-weight: 600;
                background: transparent;
            }}
        """)

    def get_text_width(self, text, font_size):
        """测量指定文字在指定字体大小下的宽度"""
        font = QFont(self.content_label.font())
        font.setPointSize(font_size)
        font.setLetterSpacing(QFont.AbsoluteSpacing, 1)  # 匹配通知的字间距
        metrics = QFontMetrics(font)
        return metrics.horizontalAdvance(text)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.capsule.setGeometry(self.rect())
        self.content_label.setGeometry(self.rect())
        self.interactive_zone.setGeometry(0, 0, self.width(), 40)

    def init_tray(self):
        self.tray_icon = QSystemTrayIcon(self)
        icon = self.style().standardIcon(QStyle.SP_ComputerIcon)
        self.tray_icon.setIcon(icon)
        self.tray_icon.setToolTip("动态岛")

        self.tray_menu = QMenu()

        self.action_topmost = QAction("置顶窗口 (关)", self)
        self.action_topmost.setCheckable(True)
        self.action_topmost.triggered.connect(self.toggle_topmost)
        self.tray_menu.addAction(self.action_topmost)

        self.action_click_through = QAction("点击穿透 (关)", self)
        self.action_click_through.setCheckable(True)
        self.action_click_through.triggered.connect(self.toggle_click_through)
        self.tray_menu.addAction(self.action_click_through)

        self.action_lock = QAction("位置锁定 (关)", self)
        self.action_lock.setCheckable(True)
        self.action_lock.triggered.connect(self.toggle_lock)
        self.tray_menu.addAction(self.action_lock)

        self.tray_menu.addSeparator()

        # 托盘测试按钮：仅发布事件（渲染信息在模板中定义）
        self.action_test_network = QAction("测试网络通知", self)
        self.action_test_network.triggered.connect(
            lambda: self.event_manager.publish(EVENT_CODES["TEST_NETWORK"])
        )
        self.tray_menu.addAction(self.action_test_network)

        self.action_test_bluetooth = QAction("测试蓝牙通知", self)
        self.action_test_bluetooth.triggered.connect(
            lambda: self.event_manager.publish(EVENT_CODES["TEST_BLUETOOTH"])
        )
        self.tray_menu.addAction(self.action_test_bluetooth)

        self.tray_menu.addSeparator()
        action_quit = QAction("退出程序", self)
        action_quit.triggered.connect(QApplication.quit)
        self.tray_menu.addAction(action_quit)

        self.tray_icon.setContextMenu(self.tray_menu)
        self.tray_icon.show()

    def init_time_update(self):
        self.time_timer = QTimer(self)
        self.time_timer.timeout.connect(self.update_time)
        self.time_timer.start(1000)
        self.update_time()

    def init_monitors(self):
        # 启动监测线程（仅发布事件，不直接交互）
        self.net_thread = NetworkMonitor()
        self.net_thread.start()

        self.bt_thread = BluetoothMonitor()
        self.bt_thread.start()

    def init_animations(self):
        self.size_animation = QPropertyAnimation(self, b"geometry")
        easing_curve = QEasingCurve(QEasingCurve.OutBack)
        easing_curve.setOvershoot(1.275)
        self.size_animation.setEasingCurve(easing_curve)
        self.size_animation.setDuration(ANIMATION_DURATION)

        self.radius_animation = QPropertyAnimation(self.capsule, b"radius")
        self.radius_animation.setEasingCurve(easing_curve)
        self.radius_animation.setDuration(ANIMATION_DURATION)

        # 字体大小动画
        self.font_size_animation = QPropertyAnimation(self, b"content_font_size")
        self.font_size_animation.setEasingCurve(easing_curve)
        self.font_size_animation.setDuration(ANIMATION_DURATION)

        self.opacity_animation = QPropertyAnimation(self.content_label, b"windowOpacity")
        self.opacity_animation.setDuration(CONTENT_ANIMATION_DURATION)
        self.opacity_animation.setEasingCurve(QEasingCurve.InOutQuad)

    def get_content_font_size(self):
        return self.content_label.font().pointSize()

    def set_content_font_size(self, size):
        font = self.content_label.font()
        font.setPointSize(size)
        self.content_label.setFont(font)

    content_font_size = pyqtProperty(int, get_content_font_size, set_content_font_size)

    def center_top(self):
        screen = QApplication.primaryScreen().availableGeometry()
        x = (screen.width() - ISLAND_INIT_WIDTH) // 2
        y = screen.top() + SCREEN_OFFSET_Y
        self.move(x, y)

    def update_time(self):
        if not self.is_notification_active:
            now = time.localtime()
            self.content_label.setText(time.strftime("%H:%M:%S", now))

    # ====================== 事件处理函数（纯渲染逻辑） ======================
    def _handle_notification(self, event_data):
        """统一处理所有通知类事件（仅渲染，无业务逻辑）"""
        self.show_notification(event_data)

    def _handle_mouse_hover(self, _):
        """处理鼠标悬停事件"""
        if not self.is_notification_active and not self.is_click_through and not self.animation_running:
            self.is_hovered = True
            self.expand_capsule(animate_font=True)

    def _handle_mouse_leave(self, _):
        """处理鼠标离开事件"""
        if not self.is_notification_active and self.is_hovered and not self.animation_running:
            self.is_hovered = False
            self.shrink_capsule(animate_font=True)

    # ====================== 核心展示逻辑（纯渲染，无业务样式） ======================
    def show_notification(self, event_data):
        """仅根据事件数据渲染通知，无任何硬编码样式"""
        if self.animation_running:
            return
        
        self.animation_running = True

        # 停止所有相关定时器
        for timer_name in ['notification_timer', 'delay_timer', 'reset_delay_timer']:
            if hasattr(self, timer_name):
                getattr(self, timer_name).stop()

        self.is_notification_active = True
        self.content_label.setWindowOpacity(0)

        def show_content():
            # 从事件数据中提取渲染属性（无硬编码）
            icon = event_data.get("icon", "")
            text = event_data.get("text", "")
            color = event_data.get("color", "white")
            full_text = f"{icon} {text}" if icon else text
            
            # 先设置为常态字体大小
            self._set_content_font_size(CONTENT_FONT_SIZE_INIT)
            # 设置通知样式（完全从事件数据读取）
            self._set_notification_font_style(color)
            self.content_label.setText(full_text)
            
            # 动态计算目标字体大小，确保不超出胶囊宽度
            available_width = ISLAND_EXPAND_WIDTH - CAPSULE_PADDING
            target_font_size = CONTENT_FONT_SIZE_EXPAND
            text_width = self.get_text_width(full_text, target_font_size)
            
            if text_width > available_width:
                # 按比例缩小字体
                target_font_size = int(target_font_size * (available_width / text_width))
                # 确保不小于初始字体大小
                target_font_size = max(target_font_size, CONTENT_FONT_SIZE_INIT)
            
            # 保存通知目标字体大小，用于后续收缩动画
            self.current_notification_font_size = target_font_size
            
            # 启用字体动画，传入调整后的目标字体大小
            self.expand_capsule(animate_font=True, target_font_size=target_font_size)
            QTimer.singleShot(CONTENT_ANIMATION_DELAY, lambda: self._animate_content_opacity(0, 1))

        self.delay_timer = QTimer(self)
        self.delay_timer.singleShot(200, show_content)

        def shrink_and_reset():
            # 收缩时启用字体动画，通知文字跟随胶囊一起缩小到常态尺寸
            self.shrink_capsule(
                animate_font=True, 
                start_font_size=self.current_notification_font_size
            )

            def final_reset():
                # 动画完全结束后重置样式、字体和内容
                self.content_label.setStyleSheet(f"""
                    QLabel {{
                        color: white;
                        font-family: "Microsoft YaHei", sans-serif;
                        font-weight: 600;
                        background: transparent;
                    }}
                """)
                self._set_content_font_size(CONTENT_FONT_SIZE_INIT)
                self.is_notification_active = False
                self.update_time()
                self.content_label.setWindowOpacity(1)
                self.animation_running = False

            # 延迟时长与动画时长完全对齐，确保动画结束后再重置
            self.reset_delay_timer = QTimer(self)
            self.reset_delay_timer.singleShot(ANIMATION_DURATION, final_reset)

        # 通知展示结束后执行收缩动画
        self.notification_timer = QTimer(self)
        self.notification_timer.singleShot(NOTIFICATION_DURATION, shrink_and_reset)

    def _animate_content_opacity(self, start, end):
        self.opacity_animation.stop()
        self.opacity_animation.setStartValue(start)
        self.opacity_animation.setEndValue(end)
        self.opacity_animation.start()

    def expand_capsule(self, animate_font=True, target_font_size=None):
        """扩展胶囊，支持自定义目标字体大小"""
        if target_font_size is None:
            target_font_size = CONTENT_FONT_SIZE_EXPAND
            
        self.size_animation.stop()
        self.radius_animation.stop()
        if animate_font:
            self.font_size_animation.stop()
        
        start_geo = self.geometry()
        center_x = start_geo.center().x()
        top_y = start_geo.top()
        
        end_geo = QRect(
            int(center_x - ISLAND_EXPAND_WIDTH / 2),
            top_y,
            ISLAND_EXPAND_WIDTH,
            ISLAND_EXPAND_HEIGHT
        )
        
        self.size_animation.setStartValue(start_geo)
        self.size_animation.setEndValue(end_geo)
        self.size_animation.start()
        
        self.radius_animation.setStartValue(CAPSULE_INIT_RADIUS)
        self.radius_animation.setEndValue(CAPSULE_EXPAND_RADIUS)
        self.radius_animation.start()

        # 字体大小动画，与胶囊动画完全同步
        if animate_font:
            self.font_size_animation.setStartValue(CONTENT_FONT_SIZE_INIT)
            self.font_size_animation.setEndValue(target_font_size)
            self.font_size_animation.start()

    def shrink_capsule(self, animate_font=True, start_font_size=None):
        """收缩胶囊，支持自定义字体动画起始值，保证文字与胶囊同步收缩"""
        if start_font_size is None:
            start_font_size = CONTENT_FONT_SIZE_EXPAND
            
        self.size_animation.stop()
        self.radius_animation.stop()
        if animate_font:
            self.font_size_animation.stop()
        
        start_geo = self.geometry()
        center_x = start_geo.center().x()
        top_y = start_geo.top()
        
        end_geo = QRect(
            int(center_x - ISLAND_INIT_WIDTH / 2),
            top_y,
            ISLAND_INIT_WIDTH,
            ISLAND_INIT_HEIGHT
        )
        
        self.size_animation.setStartValue(start_geo)
        self.size_animation.setEndValue(end_geo)
        self.size_animation.start()
        
        self.radius_animation.setStartValue(CAPSULE_EXPAND_RADIUS)
        self.radius_animation.setEndValue(CAPSULE_INIT_RADIUS)
        self.radius_animation.start()

        # 收缩时字体从通知实际大小平滑过渡到常态尺寸
        if animate_font:
            self.font_size_animation.setStartValue(start_font_size)
            self.font_size_animation.setEndValue(CONTENT_FONT_SIZE_INIT)
            self.font_size_animation.start()

    # ====================== 窗口控制逻辑（无修改） ======================
    def toggle_topmost(self, checked):
        self.is_topmost = checked
        is_visible = self.isVisible()
        
        if checked:
            self.setWindowFlags(self.base_flags | Qt.WindowStaysOnTopHint)
        else:
            self.setWindowFlags(self.base_flags)
        
        self.setAttribute(Qt.WA_TranslucentBackground)
        if is_visible:
            self.show()

        self.action_topmost.setText(f"置顶窗口 ({'开' if checked else '关'})")

    def toggle_click_through(self, checked):
        self.is_click_through = checked
        self.setAttribute(Qt.WA_TransparentForMouseEvents, checked)

        if platform.system() == "Windows":
            self.set_windows_click_through(checked)

        self.action_click_through.setText(f"点击穿透 ({'开' if checked else '关'})")

    def set_windows_click_through(self, enable):
        try:
            hwnd = int(self.winId())
            GWL_EXSTYLE = -20
            WS_EX_TRANSPARENT = 0x00000020
            WS_EX_LAYERED = 0x00080000

            ex_style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)

            if enable:
                ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, 
                                                   ex_style | WS_EX_TRANSPARENT | WS_EX_LAYERED)
            else:
                ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, 
                                                   (ex_style & ~WS_EX_TRANSPARENT) | WS_EX_LAYERED)
        except Exception as e:
            print(f"Windows API Error: {e}")

    def toggle_lock(self, checked):
        self.is_locked = checked
        self.action_lock.setText(f"位置锁定 ({'开' if checked else '关'})")

    # ====================== 鼠标事件（发布到事件队列，无修改） ======================
    def mousePressEvent(self, event):
        if self.is_click_through or self.is_locked:
            return
        if event.button() == Qt.LeftButton:
            self.drag_pos = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if self.is_click_through or self.is_locked:
            return
        if event.buttons() == Qt.LeftButton and self.drag_pos:
            self.move(event.globalPos() - self.drag_pos)
            event.accept()

    def enterEvent(self, event):
        # 发布鼠标悬停事件到队列
        self.event_manager.publish(EVENT_CODES["MOUSE_HOVER"])

    def leaveEvent(self, event):
        # 发布鼠标离开事件到队列
        self.event_manager.publish(EVENT_CODES["MOUSE_LEAVE"])

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setBrush(QBrush(QColor(0, 0, 0, 0)))
        painter.setPen(Qt.NoPen)
        painter.drawRect(self.rect())

if __name__ == "__main__":
    if platform.system() == "Windows":
        ctypes.windll.shcore.SetProcessDpiAwareness(1)

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    
    window = DynamicIslandWindow()
    window.show()
    
    sys.exit(app.exec_())