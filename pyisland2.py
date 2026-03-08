import sys
import os
import socket
import time
import subprocess  # 用于执行 Powershell
from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineSettings, QWebEngineProfile
from PySide6.QtCore import Qt, QUrl, QThread, Signal, QTimer

ISLAND_WIDTH = 300
ISLAND_HEIGHT = 150
SCREEN_OFFSET_Y = 10



def get_resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


# --- 网络监测线程 (保持不变) ---
class NetworkMonitor(QThread):
    connection_restored = Signal(str)

    def run(self):
        was_connected = True
        while True:
            is_connected = self.check_dns()
            if not was_connected and is_connected:
                self.connection_restored.emit("已恢复网络连接")
            was_connected = is_connected
            time.sleep(3)

    def check_dns(self):
        try:
            socket.create_connection(("114.114.114.114", 53), timeout=2)
            return True
        except OSError:
            return False


# --- 新增：蓝牙监测线程 ---
class BluetoothMonitor(QThread):
    device_connected = Signal(str)

    def run(self):
        # 初始设备集合
        last_devices = self.get_connected_devices()

        while True:
            time.sleep(4)  # 蓝牙检测稍微慢一点，避免CPU占用过高
            current_devices = self.get_connected_devices()

            # 计算差集：在当前列表中但不在上次列表中的，就是新连接的设备
            new_devices = current_devices - last_devices

            if new_devices:
                for dev in new_devices:
                    print(f"Bluetooth connected: {dev}")
                    self.device_connected.emit(f"已连接蓝牙设备")

            # 更新列表
            last_devices = current_devices

    def get_connected_devices(self):
        """
        使用 PowerShell 获取当前状态为 OK 的蓝牙设备
        """
        devices = set()
        try:
            # 构造 Powershell 命令：获取 Class 为 Bluetooth 且 Status 为 OK 的设备
            # 过滤掉一些底层驱动名称，只保留用户设备名称
            ps_command = (
                "Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | "
                "Where-Object { $_.FriendlyName -notmatch 'Enumerator|Adapter|Module|Generic|Intel|Realtek' } | "
                "Select-Object -ExpandProperty FriendlyName"
            )

            # 配置不显示黑色窗口
            si = subprocess.STARTUPINFO()
            si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            si.wShowWindow = subprocess.SW_HIDE  # 隐藏窗口

            # 执行命令
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", ps_command],
                capture_output=True,
                text=True,
                startupinfo=si,
                creationflags=subprocess.CREATE_NO_WINDOW  # 双重保险防止弹窗
            )

            if result.returncode == 0:
                # 按行分割并去除空行
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    name = line.strip()
                    if name:
                        devices.add(name)
        except Exception as e:
            print(f"BT Check Error: {e}")

        return devices


class TransparentWebPage(QWebEnginePage):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setBackgroundColor(Qt.transparent)


class DynamicIslandWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.center_top()

        # self.gc_timer = QTimer(self)
        # self.gc_timer.timeout.connect(self.force_release_memory)
        # self.gc_timer.start(60000)  # 每分钟清理一次


        # 1. 启动网络监听
        self.net_thread = NetworkMonitor()
        self.net_thread.connection_restored.connect(lambda msg: self.run_js(f'showNetworkNotification("{msg}");'))
        self.net_thread.start()

        # 2. 启动蓝牙监听
        self.bt_thread = BluetoothMonitor()
        self.bt_thread.device_connected.connect(lambda msg: self.run_js(f'showBluetoothNotification("{msg}");'))
        self.bt_thread.start()

    def init_ui(self):
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.resize(ISLAND_WIDTH, ISLAND_HEIGHT)

        self.browser = QWebEngineView(self)

        settings = self.browser.settings()
        # 禁用图标数据库（减少磁盘IO和内存）
        settings.setAttribute(QWebEngineSettings.LocalContentCanAccessRemoteUrls, False)
        # 限制内存缓存
        self.browser.page().profile().setHttpCacheType(QWebEngineProfile.NoCache)

        page = TransparentWebPage(self.browser)
        self.browser.setPage(page)
        self.browser.page().settings().setAttribute(QWebEngineSettings.ShowScrollBars, False)

        html_path = get_resource_path("island.html")
        self.browser.setUrl(QUrl.fromLocalFile(os.path.abspath(html_path)))
        self.setCentralWidget(self.browser)

    def center_top(self):
        screen = QApplication.primaryScreen()
        rect = screen.availableGeometry()
        x = (rect.width() - ISLAND_WIDTH) // 2
        y = rect.top() + SCREEN_OFFSET_Y
        self.move(x, y)

    def run_js(self, code):
        self.browser.page().runJavaScript(code)



if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = DynamicIslandWindow()
    window.show()
    sys.exit(app.exec())


