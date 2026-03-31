import sys
import time
import json
from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtCore import Qt, QUrl, QTimer, QPropertyAnimation, QEasingCurve, QRect, QThread, Signal

# 导入你的检测工具类
from pyislandWeb.method.getbattery import BatteryChecker
from pyislandWeb.method.getinternet import InternetChecker
from pyislandWeb.method.sendtoast import send_notification
# 注意：蓝牙因为涉及 asyncio，我们做一个简单的包装
import asyncio
import windows_bluetooth_watcher as wbw

class StatusWorker(QThread):
    """后台状态检测线程"""
    status_updated = Signal(dict)

    def __init__(self):
        super().__init__()
        self.battery_checker = BatteryChecker()
        self.internet_checker = InternetChecker()

    async def get_bt_status(self):
        try:
            listener = wbw.Listener()
            devices = await listener.get_all()
            # 逻辑：如果有任何设备在线则返回 true
            return any(d.status == "Connected" for d in devices) if devices else False
        except:
            return False

    def run(self):
        while True:
            # 1. 获取电池
            bat_status, bat_level = self.battery_checker.check_battery()
            # 2. 获取网络
            net_status = self.internet_checker.check_internet()
            # 3. 获取蓝牙 (同步方式运行异步代码)
            try:
                bt_active = asyncio.run(self.get_bt_status())
            except:
                bt_active = False

            # 组装数据
            data = {
                "battery": {
                    "level": bat_level if bat_level is not None else 100,
                    "status": bat_status if bat_status else "AC Power"
                },
                    "wifi": "online" if "已连接" in net_status else "offline",
                    "bluetooth": "on" if bt_active else "off"
            }
            self.status_updated.emit(data)
            time.sleep(3)  # 每3秒刷新一次系统状态，节省能耗

class IslandWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)

        self.web_view = QWebEngineView()
        self.setCentralWidget(self.web_view)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.page().setBackgroundColor(Qt.transparent)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)

        # 尺寸
        self.fixed_width = 320
        self.height_small = 55
        self.height_large = 120
        self.is_expanded = False

        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(400)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)

        self.web_view.load(QUrl.fromLocalFile(r"E:\PythonPro\pyislandWeb\island.html"))

        # 启动时间刷新 (1秒)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh_time)
        self.timer.start(1000)

        # 启动状态工作线程
        self.worker = StatusWorker()
        self.worker.status_updated.connect(self.update_web_status)
        self.worker.start()

        self.update_geometry(self.height_small, animate=False)

    def update_web_status(self, data):
        """将系统状态以 JSON 格式发送给前端"""
        json_str = json.dumps(data)
        self.web_view.page().runJavaScript(f"updateSystemStatus({json_str});")

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
        self.is_expanded = True
        self.update_geometry(self.height_large)
        self.web_view.page().runJavaScript("setWebState(true);")

    def leaveEvent(self, event):
        self.is_expanded = False
        self.update_geometry(self.height_small)
        self.web_view.page().runJavaScript("setWebState(false);")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = IslandWindow()
    window.show()
    sys.exit(app.exec())