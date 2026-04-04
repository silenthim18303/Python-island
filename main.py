import ctypes
import datetime
import gc
import importlib
import json
import os
import platform
import subprocess
import sys
import threading
import time
import asyncio

# 导入健康提醒模块
try:
    from method.health import start_health_reminders, stop_health_reminders
except ImportError:
    # 防止因缺少模块导致程序无法运行
    def start_health_reminders():
        pass
    
    def stop_health_reminders():
        pass

# 导入健康提醒模块
try:
    from method.health import start_health_reminders, stop_health_reminders
except ImportError:
    # 防止因缺少模块导致程序无法运行
    def start_health_reminders():
        pass
    
    def stop_health_reminders():
        pass

from PySide6.QtCore import QEasingCurve, QObject, QPropertyAnimation, QRect, Qt, QThread, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWebChannel import QWebChannel
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEngineSettings
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QApplication, QMenu, QStyle, QSystemTrayIcon, QVBoxLayout, QWidget

STATUS_POLL_INTERVAL_SECONDS = 2
EXPANDED_CONTENT_DELAY_MS = 360


def apply_native_window_fixes(widget: QWidget) -> None:
    if sys.platform != "win32":
        return
    hwnd = int(widget.winId())
    dwmapi = getattr(ctypes.windll, "dwmapi", None)
    if dwmapi is None:
        return
    nc_rendering_policy_attr = 2
    nc_rendering_disabled = 1
    corner_preference_attr = 33
    corner_do_not_round = 1
    border_color_attr = 34
    border_color_none = 0xFFFFFFFE
    try:
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            nc_rendering_policy_attr,
            ctypes.byref(ctypes.c_int(nc_rendering_disabled)),
            ctypes.sizeof(ctypes.c_int),
        )
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            corner_preference_attr,
            ctypes.byref(ctypes.c_int(corner_do_not_round)),
            ctypes.sizeof(ctypes.c_int),
        )
        dwmapi.DwmSetWindowAttribute(
            hwnd,
            border_color_attr,
            ctypes.byref(ctypes.c_uint(border_color_none)),
            ctypes.sizeof(ctypes.c_uint),
        )
    except Exception:
        pass


class IslandBridge(QObject):
    # 桥接对象：前端通过 QWebChannel 调用这里的方法
    def __init__(self, window: "IslandWindow") -> None:
        super().__init__()
        self.window = window

    @Slot(bool)
    # 前端 hover 状态回调到后端，驱动窗口动画
    def setHovered(self, hovered: bool) -> None:
        self.window.set_hovered(hovered)

    @Slot(str)
    def openWindowsSettings(self, setting_type: str) -> None:
        self.window.open_windows_settings(setting_type)

    @Slot()
    def openExpandedWindow(self) -> None:
        self.window.open_expanded_window()


class ExpandedBridge(QObject):
    brightness_apply_finished = Signal(bool)

    def __init__(self, window: "ExpandedWindow") -> None:
        super().__init__()
        self.window = window
        self.brightness_service = self._load_brightness_service()
        self._pending_brightness = None
        self._brightness_in_flight = False
        self._brightness_timer = QTimer(self)
        self._brightness_timer.setSingleShot(True)
        self._brightness_timer.timeout.connect(self._flush_brightness_change)
        self.brightness_apply_finished.connect(self._on_brightness_apply_finished)

    @staticmethod
    def _load_brightness_service():
        try:
            module = importlib.import_module("method.brightness")
            return getattr(module, "BrightnessService", None)
        except Exception:
            return None

    @Slot()
    def closeExpandedWindow(self) -> None:
        self.window.close_to_main()

    @Slot(result=int)
    def getBrightness(self) -> int:
        if self.brightness_service is None:
            return 50
        try:
            return int(self.brightness_service.get_brightness())
        except Exception:
            return 50

    @Slot(int, result=bool)
    def setBrightness(self, value: int) -> bool:
        if self.brightness_service is None:
            return False
        self._pending_brightness = max(0, min(100, int(value)))
        self._brightness_timer.start(150)
        return True

    def _flush_brightness_change(self) -> None:
        if self.brightness_service is None or self._pending_brightness is None:
            return
        if self._brightness_in_flight:
            self._brightness_timer.start(120)
            return
        value = self._pending_brightness
        self._pending_brightness = None
        self._brightness_in_flight = True
        threading.Thread(
            target=self._apply_brightness_in_background,
            args=(value,),
            daemon=True,
        ).start()

    def _apply_brightness_in_background(self, value: int) -> None:
        success = False
        try:
            success = bool(self.brightness_service.set_brightness(value))
        except Exception:
            success = False
        self.brightness_apply_finished.emit(success)

    def _on_brightness_apply_finished(self, success: bool) -> None:
        self._brightness_in_flight = False
        if self._pending_brightness is not None:
            self._brightness_timer.start(80)


class BluetoothWorker(QThread):
    bluetooth_updated = Signal(dict)

    def __init__(self) -> None:
        super().__init__()
        self.running = True

    @staticmethod
    def _load_bluetooth_getter():
        try:
            module = importlib.import_module("method.getbluetooth")
            getter = getattr(module, "get_bluetooth_devices", None)
            if getter is not None:
                return getter
        except Exception:
            pass

        async def fallback():
            return []

        return fallback

    def run(self) -> None:
        getter = self._load_bluetooth_getter()
        while self.running:
            try:
                devices_raw = asyncio.run(getter())
                devices = []
                connected_count = 0
                for item in devices_raw:
                    name = getattr(item, "name", "")
                    status = str(getattr(item, "status", "Unknown"))
                    if status.lower() == "connected":
                        connected_count += 1
                    devices.append({"name": name, "status": status})
                payload = {
                    "status": "on" if connected_count > 0 else "off",
                    "devices": devices,
                }
            except Exception:
                payload = {"status": "error", "devices": []}
            self.bluetooth_updated.emit(payload)
            time.sleep(STATUS_POLL_INTERVAL_SECONDS)

    def stop(self) -> None:
        self.running = False


class SystemStatusWorker(QThread):
    wifi_updated = Signal(dict)
    battery_updated = Signal(dict)

    def __init__(self) -> None:
        super().__init__()
        self.running = True

    @staticmethod
    def _load_checkers():
        class FallbackInternetChecker:
            def check_internet(self):
                return "未连接到互联网"

        class FallbackBatteryChecker:
            def check_battery(self):
                return "未知", None

        try:
            internet_module = importlib.import_module("method.getinternet")
            internet_checker_cls = getattr(internet_module, "InternetChecker", FallbackInternetChecker)
        except Exception:
            internet_checker_cls = FallbackInternetChecker

        try:
            battery_module = importlib.import_module("method.getbattery")
            battery_checker_cls = getattr(battery_module, "BatteryChecker", FallbackBatteryChecker)
        except Exception:
            battery_checker_cls = FallbackBatteryChecker

        return internet_checker_cls(), battery_checker_cls()

    def run(self) -> None:
        internet_checker, battery_checker = self._load_checkers()
        while self.running:
            try:
                wifi_raw = internet_checker.check_internet()
                wifi_data = {
                    "status": "on" if ("已连接" in str(wifi_raw) or "online" in str(wifi_raw).lower()) else "off",
                    "text": str(wifi_raw),
                }
            except Exception as e:
                wifi_data = {"status": "error", "text": f"检测异常: {e}"}
            self.wifi_updated.emit(wifi_data)

            try:
                bat_status, bat_level = battery_checker.check_battery()
                battery_data = {
                    "status": str(bat_status) if bat_status else "未知",
                    "level": bat_level if bat_level is not None else None,
                }
            except Exception as e:
                battery_data = {"status": "error", "level": None, "error": str(e)}
            self.battery_updated.emit(battery_data)
            time.sleep(STATUS_POLL_INTERVAL_SECONDS)

    def stop(self) -> None:
        self.running = False


class ExpandedWindow(QWidget):
    def __init__(self, main_window: "IslandWindow") -> None:
        super().__init__()
        self.main_window = main_window
        self.target_size = (300, 200)
        self.setWindowFlags(main_window.base_flags)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_NoSystemBackground, True)
        self.setStyleSheet("background: transparent; border: none;")
        self.web_view = QWebEngineView(self)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground, True)
        self.web_view.setStyleSheet("background: transparent; border: none;")
        self.web_view.page().setBackgroundColor(Qt.transparent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.web_view)
        self.bridge = ExpandedBridge(self)
        self.channel = QWebChannel(self.web_view.page())
        self.channel.registerObject("pyisland", self.bridge)
        self.web_view.page().setWebChannel(self.channel)
        island2_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "island2.html")
        self.web_view.load(QUrl.fromLocalFile(island2_path))
        self.web_view.hide()
        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(220)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)
        self.animation.finished.connect(lambda: apply_native_window_fixes(self))
        self.content_timer = QTimer(self)
        self.content_timer.setSingleShot(True)
        self.content_timer.timeout.connect(self._show_web_content)
        self._closing = False
        self._opening = False

    def open_from(self, source_rect: QRect) -> None:
        self._closing = False
        self._opening = True
        self.content_timer.stop()
        target_w, target_h = self.target_size
        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_x = screen_geo.x() + (screen_geo.width() - target_w) // 2
        target_y = max(screen_geo.y() + self.main_window.top_margin, source_rect.y())
        self._target_rect = QRect(target_x, target_y, target_w, target_h)
        start_w = max(source_rect.width(), 120)
        start_h = max(source_rect.height(), 45)
        start_x = self._target_rect.center().x() - start_w // 2
        start_y = self._target_rect.center().y() - start_h // 2
        self.setGeometry(QRect(start_x, start_y, start_w, start_h))
        self.web_view.hide()
        self.show()
        self.raise_()
        self.activateWindow()
        apply_native_window_fixes(self)
        self.content_timer.start(EXPANDED_CONTENT_DELAY_MS)
        QTimer.singleShot(80, self._start_open_animation)

    def _start_open_animation(self) -> None:
        if not self.isVisible() or self._closing:
            return
        self.animation.stop()
        self.animation.setStartValue(self.geometry())
        self.animation.setEndValue(self._target_rect)
        self.animation.start()

    def _show_web_content(self) -> None:
        if not self.isVisible() or self._closing:
            return
        self.web_view.show()
        self.web_view.page().runJavaScript(
            "if (typeof window.playEntrance === 'function') { window.playEntrance(); }"
        )
        self._opening = False

    def close_to_main(self) -> None:
        if self._closing:
            return
        self._closing = True
        self.content_timer.stop()
        self.animation.stop()
        self.web_view.hide()
        QTimer.singleShot(70, self._finish_close_to_main)

    def _finish_close_to_main(self) -> None:
        self.hide()
        # 主窗口已经可见，只需要确保它被置于最顶层并被激活
        self.main_window.raise_()
        self.main_window.activateWindow()
        self.main_window.apply_native_window_fixes()
        self._closing = False

    def focusOutEvent(self, event) -> None:
        super().focusOutEvent(event)
        if not self._opening:
            self.close_to_main()


class IslandWindow(QWidget):
    # 主窗口：透明置顶 + QWebEngine 承载前端页面
    def __init__(self) -> None:
        super().__init__()
        # 小岛默认尺寸 / hover 展开尺寸
        self.small_size = (300, 45)
        self.large_size = (300, 105)
        self.top_margin = 16
        self._hovered = False
        self._native_fixed = False
        self.mouse_passthrough = False

        # 调试窗口原生边框时：去掉 Qt.FramelessWindowHint
        self.base_flags = (
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.NoDropShadowWindowHint
        )
        self.setWindowFlags(self.base_flags)
        # 物理窗体透明化，避免系统背景色
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_NoSystemBackground, True)
        self.setStyleSheet("background: transparent; border: none;")

        # 创建并配置 Web 容器
        self.web_view = QWebEngineView(self)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground, True)
        self.web_view.setAttribute(Qt.WA_NoSystemBackground, True)
        self.web_view.setStyleSheet("background: transparent; border: none;")
        self.web_view.page().setBackgroundColor(Qt.transparent)

        # WebEngine 轻量化配置：减少资源占用
        settings = self.web_view.settings()
        settings.setAttribute(QWebEngineSettings.WebAttribute.PluginsEnabled, False)
        settings.setAttribute(QWebEngineSettings.WebAttribute.ShowScrollBars, False)
        profile = self.web_view.page().profile()
        profile.setHttpCacheType(QWebEngineProfile.HttpCacheType.MemoryHttpCache)
        profile.setHttpCacheMaximumSize(10 * 1024 * 1024)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.web_view)

        # 注册 JS <-> Python 双向桥接
        self.bridge = IslandBridge(self)
        self.channel = QWebChannel(self.web_view.page())
        self.channel.registerObject("pyisland", self.bridge)
        self.web_view.page().setWebChannel(self.channel)
        html_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "island.html")
        self.web_view.load(QUrl.fromLocalFile(html_path))
        self.expanded_window = ExpandedWindow(self)

        self.setup_tray()

        # 顶层窗口几何动画（小岛展开/收起）
        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(240)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)
        # 动画结束后重新应用原生窗口修复
        self.animation.finished.connect(self.apply_native_window_fixes)
        # 动画结束后安排一次延迟清理
        self.animation.finished.connect(self.schedule_cleanup)

        initial_rect = self._target_rect(*self.small_size)
        self.setGeometry(initial_rect)

        # 每秒刷新一次时间文本
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh_time)
        self.timer.start(1000)
        QTimer.singleShot(0, self.refresh_time)

        # 清理定时器：用于动画密集触发时做防抖回收
        self.cleanup_timer = QTimer(self)
        self.cleanup_timer.setSingleShot(True)
        self.cleanup_timer.timeout.connect(self.compact_memory)

        self.bluetooth_worker = BluetoothWorker()
        self.bluetooth_worker.bluetooth_updated.connect(self.update_bluetooth_state)
        self.system_status_worker = SystemStatusWorker()
        self.system_status_worker.wifi_updated.connect(self.update_wifi_state)
        self.system_status_worker.battery_updated.connect(self.update_battery_state)
        QTimer.singleShot(1200, self.start_background_workers)

        # 应用退出时执行收尾清理
        QApplication.instance().aboutToQuit.connect(self.cleanup)

    def showEvent(self, event) -> None:
        super().showEvent(event)
        # 窗口首次显示后应用一次原生窗口修复
        if not self._native_fixed:
            self._native_fixed = True
            self.apply_native_window_fixes()

    def setup_tray(self) -> None:
        self.tray = QSystemTrayIcon(self)
        icon_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "assets",
            "svg",
            "pyisland.svg",
        )
        if os.path.exists(icon_path):
            self.tray.setIcon(QIcon(icon_path))
        else:
            self.tray.setIcon(self.style().standardIcon(QStyle.SP_ComputerIcon))

        tray_menu = QMenu()

        self.passthrough_action = QAction("启用鼠标穿透", self)
        self.passthrough_action.setCheckable(True)
        self.passthrough_action.setChecked(False)
        self.passthrough_action.triggered.connect(self.toggle_mouse_passthrough)
        tray_menu.addAction(self.passthrough_action)

        tray_menu.addSeparator()

        exit_action = QAction("退出程序", self)
        exit_action.triggered.connect(QApplication.instance().quit)
        tray_menu.addAction(exit_action)

        self.tray.setContextMenu(tray_menu)
        self.tray.setToolTip("PyIsland")
        self.tray.show()

    def start_background_workers(self) -> None:
        if hasattr(self, "bluetooth_worker") and not self.bluetooth_worker.isRunning():
            self.bluetooth_worker.start()
        if hasattr(self, "system_status_worker") and not self.system_status_worker.isRunning():
            self.system_status_worker.start()

    def apply_native_window_fixes(self) -> None:
        apply_native_window_fixes(self)

    def _target_rect(self, width: int, height: int) -> QRect:
        # 目标位置：屏幕顶部居中
        screen = QApplication.primaryScreen()
        screen_geo = screen.availableGeometry()
        x = screen_geo.x() + (screen_geo.width() - width) // 2
        y = screen_geo.y() + self.top_margin
        return QRect(x, y, width, height)

    def animate_to(self, width: int, height: int) -> None:
        # 从当前几何到目标几何，平滑过渡
        self.animation.stop()
        self.animation.setStartValue(self.geometry())
        self.animation.setEndValue(self._target_rect(width, height))
        self.animation.start()

    def set_hovered(self, hovered: bool) -> None:
        # 忽略重复状态，避免无效动画
        if self._hovered == hovered:
            return
        self._hovered = hovered
        target = self.large_size if hovered else self.small_size
        self.animate_to(*target)
        self.schedule_cleanup()

    def toggle_mouse_passthrough(self, checked: bool) -> None:
        self.mouse_passthrough = checked
        current_geometry = self.geometry()
        if checked:
            self.setWindowFlags(self.base_flags | Qt.WindowTransparentForInput)
            self.passthrough_action.setText("禁用鼠标穿透")
        else:
            self.setWindowFlags(self.base_flags)
            self.passthrough_action.setText("启用鼠标穿透")
        self.show()
        self.setGeometry(current_geometry)
        self.apply_native_window_fixes()

    @staticmethod
    def _send_win_hotkey(key_vk: int) -> None:
        user32 = ctypes.windll.user32
        keyup = 0x0002
        vk_win = 0x5B
        user32.keybd_event(vk_win, 0, 0, 0)
        user32.keybd_event(key_vk, 0, 0, 0)
        user32.keybd_event(key_vk, 0, keyup, 0)
        user32.keybd_event(vk_win, 0, keyup, 0)

    def open_windows_settings(self, setting_type: str) -> None:
        if setting_type == "notifications":
            try:
                win_ver = platform.release()
                if win_ver == "10":
                    self._send_win_hotkey(0x41)
                elif win_ver == "11":
                    self._send_win_hotkey(0x4E)
                return
            except Exception:
                return

        settings_map = {
            "network": "ms-settings:network",
            "bluetooth": "ms-settings:bluetooth",
            "battery": "ms-settings:batterysaver",
        }
        uri = settings_map.get(setting_type)
        if not uri:
            return
        try:
            subprocess.run(
                ["explorer.exe", uri],
                shell=True,
                check=False,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
        except Exception:
            try:
                os.startfile(uri)
            except Exception:
                pass

    def open_expanded_window(self) -> None:
        if self.expanded_window.isVisible():
            return
        source_rect = self.geometry()
        # 不隐藏初始窗口，而是将其置于展开窗口后面
        self.expanded_window.open_from(source_rect)

    def refresh_time(self) -> None:
        # 每秒推送一次时间到前端
        current_time = datetime.datetime.now().strftime("%H:%M:%S")
        js = f"if (typeof window.updateTime === 'function') window.updateTime({json.dumps(current_time)});"
        self.web_view.page().runJavaScript(js)

    def update_bluetooth_state(self, data: dict) -> None:
        js = (
            f"if (typeof window.updateBluetoothState === 'function') "
            f"window.updateBluetoothState({json.dumps(data, ensure_ascii=False)});"
        )
        self.web_view.page().runJavaScript(js)

    def update_wifi_state(self, data: dict) -> None:
        js = (
            f"if (typeof window.updateWifiState === 'function') "
            f"window.updateWifiState({json.dumps(data, ensure_ascii=False)});"
        )
        self.web_view.page().runJavaScript(js)

    def update_battery_state(self, data: dict) -> None:
        js = (
            f"if (typeof window.updateBatteryState === 'function') "
            f"window.updateBatteryState({json.dumps(data, ensure_ascii=False)});"
        )
        self.web_view.page().runJavaScript(js)

    def schedule_cleanup(self) -> None:
        # 防抖：频繁触发时仅保留最后一次清理
        self.cleanup_timer.start(800)

    def compact_memory(self) -> None:
        # 后端与前端各做一次轻量回收
        gc.collect()
        self.web_view.page().runJavaScript("if (window.gc) { window.gc(); }")

    def cleanup(self) -> None:
        # 退出前停止定时器并做最终清理
        if self.cleanup_timer.isActive():
            self.cleanup_timer.stop()
        if hasattr(self, "bluetooth_worker"):
            self.bluetooth_worker.stop()
            self.bluetooth_worker.wait()
        if hasattr(self, "system_status_worker"):
            self.system_status_worker.stop()
            self.system_status_worker.wait()
        if hasattr(self, "tray"):
            self.tray.hide()
        if hasattr(self, "expanded_window"):
            self.expanded_window.hide()
        # 停止健康提醒
        stop_health_reminders()
        self.compact_memory()


def main() -> int:
    # 启动健康提醒
    start_health_reminders()
    
    # Qt 使用软件渲染，降低某些机型驱动兼容问题
    QApplication.setAttribute(Qt.AA_UseSoftwareOpenGL)
    # Chromium 进程/扩展/内存限制参数
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = (
        "--disable-gpu-compositing "
        "--renderer-process-limit=1 "
        "--disable-extensions "
        "--no-sandbox "
        "--js-flags='--max-old-space-size=128 --expose-gc'"
    )
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    window = IslandWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
