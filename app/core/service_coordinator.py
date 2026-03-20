"""服务协调器模块

协调各个服务的调用和回调处理。
"""

from typing import Tuple, List, Optional, Callable
from app.core.worker import WorkerThread
from app.services.brightness import BrightnessService
from app.services.clipboard import ClipboardService
from app.services.system_status import SystemStatusService


class ServiceCoordinator:
    """服务协调器

    协调亮度服务、剪贴板服务、系统状态服务的调用。

    Attributes:
        brightness_service: 亮度服务
        clipboard_service: 剪贴板服务
        status_service: 系统状态服务
    """

    def __init__(self):
        self.brightness_service = BrightnessService()
        self.clipboard_service = ClipboardService()
        self.status_service = SystemStatusService()

        self._brightness_thread: Optional[WorkerThread] = None
        self._brightness_apply_thread: Optional[WorkerThread] = None
        self._status_thread: Optional[WorkerThread] = None

        self._previous_wifi_status: Optional[Tuple] = None
        self._previous_bluetooth_status: Optional[List] = None
        self._first_status_check = True

    def load_initial_brightness(self, callback: Callable[[Optional[int]], None]):
        if self._brightness_thread and self._brightness_thread.isRunning():
            return

        self._brightness_thread = WorkerThread(BrightnessService.get_brightness)
        self._brightness_thread.finished_signal.connect(callback)
        self._brightness_thread.start()

    def apply_brightness(self, value: int, callback: Optional[Callable] = None):
        if self._brightness_apply_thread and self._brightness_apply_thread.isRunning():
            return

        self._brightness_apply_thread = WorkerThread(
            BrightnessService.set_brightness, value
        )
        if callback:
            self._brightness_apply_thread.finished_signal.connect(callback)
        self._brightness_apply_thread.start()

    def update_system_status(
        self,
        success_callback: Callable[[Tuple], None],
        error_callback: Callable[[str], None]
    ):
        if self._status_thread and self._status_thread.isRunning():
            return

        self._status_thread = WorkerThread(SystemStatusService.get_all_status)
        self._status_thread.finished_signal.connect(success_callback)
        self._status_thread.error_signal.connect(error_callback)
        self._status_thread.start()

    def check_clipboard(self) -> Tuple[bool, List[str]]:
        return self.clipboard_service.check_for_new_urls()

    @staticmethod
    def open_url(url: str):
        ClipboardService.open_url(url)

    @staticmethod
    def open_urls(urls: List[str]):
        ClipboardService.open_urls(urls)

    def process_status_update(
        self,
        result: Tuple
    ) -> Tuple[str, int, str, str, str, int, str]:
        wifi_info, bluetooth_devices, battery_info = result
        ssid, signal, dns_connected = wifi_info
        charge, status = battery_info

        bt_name = ""
        bt_status = ""
        if bluetooth_devices:
            device_name, device_status = bluetooth_devices[0]
            bt_name = device_name
            bt_status = device_status

        return ssid, signal, bt_name, bt_status, charge, status, dns_connected

    def check_status_changes(
        self,
        ssid: str,
        dns_connected: bool,
        bluetooth_devices: List
    ) -> Tuple[Optional[str], Optional[str]]:
        if self._first_status_check:
            self._previous_wifi_status = (ssid, dns_connected)
            self._previous_bluetooth_status = bluetooth_devices
            self._first_status_check = False
            return None, None

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

        wifi_message = None
        bt_message = None

        if wifi_connected != prev_wifi_connected:
            wifi_message = "WiFi已连接" if wifi_connected else "WiFi已断开"
        elif bluetooth_connected != prev_bluetooth_connected:
            bt_message = "蓝牙已连接" if bluetooth_connected else "蓝牙已断开"

        self._previous_wifi_status = current_wifi_status
        self._previous_bluetooth_status = current_bluetooth_status

        return wifi_message, bt_message

    def cleanup(self):
        threads = [
            self._brightness_thread,
            self._brightness_apply_thread,
            self._status_thread
        ]

        for thread in threads:
            if thread and thread.isRunning():
                thread.quit()
                thread.wait()
