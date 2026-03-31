import sys
import time
import json
import os
import gc
import asyncio
from PySide6.QtWidgets import (QApplication, QMainWindow, QSystemTrayIcon,
                               QMenu, QStyle)
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtCore import Qt, QUrl, QTimer, QPropertyAnimation, QEasingCurve, QRect, QThread, Signal, QObject, Slot
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEngineSettings, QWebEnginePage
import subprocess

# 导入你的检测工具类 (请确保路径正确)
# try:
from method.getbattery import BatteryChecker
from method.getinternet import InternetChecker
from method.sendtoast import send_startup_notification
import windows_bluetooth_watcher as wbw
# except ImportError:
#     # 防止因缺少自定义模块导致演示代码无法运行
#     class BatteryChecker:
#         def check_battery(self): return "AC", 100


#     class InternetChecker:
#         def check_internet(self): return "已连接"


class StatusWorker(QThread):
    """后台状态检测线程 (保持不变)"""
    status_updated = Signal(dict)

    def __init__(self):
        super().__init__()
        self.battery_checker = BatteryChecker()
        self.internet_checker = InternetChecker()
        self.loop = asyncio.new_event_loop()

    async def get_bt_status(self):
        try:
            listener = wbw.Listener()
            devices = await listener.get_all()
            connected_devices = [d.name for d in devices if d.status == "Connected"]
            return connected_devices if connected_devices else False
        except:
            return False

    def run(self):
        while True:
            bat_status, bat_level = self.battery_checker.check_battery()
            net_status = self.internet_checker.check_internet()
            try:
                bt_active = self.loop.run_until_complete(self.get_bt_status())
            except:
                bt_active = False

            data = {
                "battery": {
                    "level": bat_level if bat_level is not None else 100,
                    "status": bat_status if bat_status else "AC Power"
                },
                "wifi": "online" if "已连接" in net_status else "offline",
                "bluetooth": {
                    "status": "on" if bt_active else "off",
                    "devices": bt_active if isinstance(bt_active, list) else []
                }
            }
            self.status_updated.emit(data)
            time.sleep(3)


class PyIslandBridge(QObject):
    """JavaScript桥接对象，用于前端调用后端方法"""
    
    @Slot(str)
    def openWindowsSettings(self, setting_type):
        """打开Windows设置页面
        
        Args:
            setting_type (str): 设置类型，如 'network', 'bluetooth', 'battery', 'notifications'
        """
        if setting_type == 'network':
            # 打开网络设置
            subprocess.run(['ms-settings:network'])
        elif setting_type == 'bluetooth':
            # 打开蓝牙设置
            subprocess.run(['ms-settings:bluetooth'])
        elif setting_type == 'battery':
            # 打开电池设置
            subprocess.run(['ms-settings:batterysaver'])
        elif setting_type == 'notifications':
            # 打开通知设置
            subprocess.run(['ms-settings:notifications'])


class IslandWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        # 初始窗口属性：置顶、无边框、工具窗口（不在任务栏显示）
        self.base_flags = Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        self.setWindowFlags(self.base_flags)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # --- QWebEngineView 优化配置 ---
        self.web_view = QWebEngineView()
        settings = self.web_view.settings()
        settings.setAttribute(QWebEngineSettings.WebAttribute.PluginsEnabled, False)
        settings.setAttribute(QWebEngineSettings.WebAttribute.ShowScrollBars, False)

        profile = self.web_view.page().profile()
        profile.setHttpCacheType(QWebEngineProfile.HttpCacheType.MemoryHttpCache)
        profile.setHttpCacheMaximumSize(10 * 1024 * 1024)

        # 创建并设置JavaScript桥接对象
        from PySide6.QtWebChannel import QWebChannel
        self.bridge = PyIslandBridge()
        channel = QWebChannel()
        channel.registerObject('pyisland', self.bridge)
        self.web_view.page().setWebChannel(channel)

        self.setCentralWidget(self.web_view)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.page().setBackgroundColor(Qt.transparent)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)

        # 尺寸配置
        self.fixed_width = 320
        self.height_small = 55
        self.height_large = 120
        self.is_expanded = False
        self.last_status = None

        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(400)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)

        # 加载 HTML
        current_dir = os.path.dirname(os.path.abspath(__file__))
        island_html_path = os.path.join(current_dir, "island.html")
        self.web_view.load(QUrl.fromLocalFile(island_html_path))

        # 初始化系统托盘
        self.setup_tray()

        # 定时器与工作线程
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh_time)
        self.timer.start(1000)

        self.worker = StatusWorker()
        self.worker.status_updated.connect(self.update_web_status)
        self.worker.start()

        self.update_geometry(self.height_small, animate=False)
        
        # 发送启动通知
        send_startup_notification()

    def setup_tray(self):
        """配置系统托盘"""
        self.tray = QSystemTrayIcon(self)
        # 使用系统默认图标，实际建议替换为 self.tray.setIcon(QIcon("icon.ico"))
        self.tray.setIcon(self.style().standardIcon(QStyle.SP_ComputerIcon))

        # 创建菜单
        tray_menu = QMenu()

        # 1. 鼠标穿透开关
        self.penetrate_action = QAction("开启鼠标穿透", self, checkable=True)
        self.penetrate_action.triggered.connect(self.set_mouse_penetration)
        tray_menu.addAction(self.penetrate_action)

        tray_menu.addSeparator()

        # 2. 退出
        exit_action = QAction("退出程序", self)
        exit_action.triggered.connect(QApplication.instance().quit)
        tray_menu.addAction(exit_action)

        self.tray.setContextMenu(tray_menu)
        self.tray.setToolTip("Python Island - 灵动岛")
        self.tray.show()

    def set_mouse_penetration(self, enabled):
        """控制窗口点击穿透"""
        if enabled:
            # 增加穿透标志
            self.setWindowFlags(self.base_flags | Qt.WindowTransparentForInput)
            # 开启穿透后，hover事件将失效，强制收起灵动岛
            self.reset_animation()
            self.penetrate_action.setText("关闭鼠标穿透")
        else:
            # 恢复原始标志
            self.setWindowFlags(self.base_flags)
            self.penetrate_action.setText("开启鼠标穿透")

        # 改变 Flags 后必须显式调用 show()，否则窗口会消失
        self.show()

    def update_web_status(self, data):
        """处理状态变化及通知 (保持不变)"""
        if self.last_status is not None:
            if self.last_status.get('wifi') != data.get('wifi'):
                msg = '已连接到互联网' if data.get('wifi') == 'online' else '网络连接已断开'
                self.show_notification('网络连接', msg)
                self.trigger_hover_animation()

            curr_bt = data.get('bluetooth', {})
            last_bt = self.last_status.get('bluetooth', {})
            if last_bt.get('status') != curr_bt.get('status') or last_bt.get('devices') != curr_bt.get('devices'):
                if curr_bt.get('status') == 'on' and curr_bt.get('devices'):
                    devs = curr_bt.get('devices')
                    msg = f'已连接到: {devs[0]}' if len(devs) == 1 else f'已连接 {len(devs)} 个设备'
                    self.show_notification('蓝牙', msg)
                    self.trigger_hover_animation()

        self.last_status = data
        json_str = json.dumps(data)
        self.web_view.page().runJavaScript(f"updateSystemStatus({json_str});")

    def show_notification(self, title, message):
        self.web_view.page().runJavaScript(f"showNotification('{title}', '{message}');")

    def trigger_hover_animation(self):
        # 即使开启穿透，仍然自动触发展开动画
        if not self.is_expanded:
            self.is_expanded = True
            self.update_geometry(self.height_large)
            self.web_view.page().runJavaScript("setWebState(true);")
            QTimer.singleShot(3000, self.reset_animation)

    def refresh_time(self):
        t = time.strftime("%H:%M:%S")
        self.web_view.page().runJavaScript(f"updateTime('{t}');")

    def update_geometry(self, target_h, animate=True):
        screen = QApplication.primaryScreen().geometry()
        target_x = (screen.width() - self.fixed_width) // 2
        target_rect = QRect(target_x, 10, self.fixed_width, target_h)
        if animate:
            self.animation.stop()
            self.animation.setEndValue(target_rect)
            self.animation.start()
        else:
            self.setGeometry(target_rect)

    def enterEvent(self, event):
        # 即使开启穿透，仍然执行展开动画
        self.is_expanded = True
        self.update_geometry(self.height_large)
        self.web_view.page().runJavaScript("setWebState(true);")
        # 确保事件被正确处理
        super().enterEvent(event)

    def leaveEvent(self, event):
        # 即使开启穿透，仍然执行收起动画
        self.reset_animation()
        # 确保事件被正确处理
        super().leaveEvent(event)

    def reset_animation(self):
        if self.is_expanded:
            self.is_expanded = False
            self.update_geometry(self.height_small)
            self.web_view.page().runJavaScript("setWebState(false);")
            gc.collect()
            QTimer.singleShot(500, self.deep_clean_engine)

    def deep_clean_engine(self):
        self.web_view.page().runJavaScript("if(window.gc) { window.gc(); }")


if __name__ == "__main__":
    # 强制软件渲染，解决特定机型驱动冲突
    QApplication.setAttribute(Qt.AA_UseSoftwareOpenGL)

    # 性能与内存限制标志
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = (
        "--disable-gpu-compositing "
        "--renderer-process-limit=1 "
        "--disable-extensions "
        "--no-sandbox "
        "--js-flags='--max-old-space-size=128 --expose-gc'"
    )

    app = QApplication(sys.argv)
    # 统一设置应用退出时不自动关闭（防止主窗口隐藏时退出）
    app.setQuitOnLastWindowClosed(False)

    window = IslandWindow()
    window.show()
    sys.exit(app.exec())