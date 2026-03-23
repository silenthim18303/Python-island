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
        self._previous_battery_status: Optional[Tuple] = None
        self._first_status_check = True
        
        # 防抖机制相关
        import time
        self._last_status_change_time = 0
        self._debounce_interval = 3  # 3秒防抖间隔

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

    def update_performance_status(
        self,
        success_callback: Callable[[Tuple], None],
        error_callback: Callable[[str], None]
    ):
        """更新CPU和内存使用率信息。"""
        if self._status_thread and self._status_thread.isRunning():
            return

        def get_performance():
            cpu_usage = SystemStatusService.get_cpu_usage()
            memory_usage = SystemStatusService.get_memory_usage()
            return (cpu_usage, memory_usage)

        self._status_thread = WorkerThread(get_performance)
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
        bluetooth_devices: List,
        battery_status: str
    ) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        if self._first_status_check:
            self._previous_wifi_status = (ssid, dns_connected)
            self._previous_bluetooth_status = bluetooth_devices
            self._previous_battery_status = battery_status
            self._first_status_check = False
            return None, None, None

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

        # 检测电池充电状态变化
        # 跳过插电状态的检测，因为台式机一直是插电状态
        if battery_status == "插电" or self._previous_battery_status == "插电":
            current_battery_charging = False
            prev_battery_charging = False
        else:
            current_battery_charging = battery_status in ["接通电源", "充电"]
            prev_battery_charging = (
                self._previous_battery_status and 
                self._previous_battery_status in ["接通电源", "充电"]
            )

        wifi_message = None
        bt_message = None
        battery_message = None

        # 检查是否有状态变化
        has_change = False
        if wifi_connected != prev_wifi_connected:
            wifi_message = "WiFi已连接" if wifi_connected else "WiFi已断开"
            has_change = True
        elif bluetooth_connected != prev_bluetooth_connected:
            bt_message = "蓝牙已打开" if bluetooth_connected else "蓝牙已关闭"
            has_change = True
        elif current_battery_charging != prev_battery_charging:
            battery_message = "已接入电源" if current_battery_charging else "已断开电源"
            has_change = True

        # 防抖处理
        if has_change:
            import time
            current_time = time.time()
            if current_time - self._last_status_change_time < self._debounce_interval:
                # 在防抖间隔内，不发送通知
                wifi_message = None
                bt_message = None
                battery_message = None
            else:
                # 超过防抖间隔，更新时间戳
                self._last_status_change_time = current_time

        self._previous_wifi_status = current_wifi_status
        self._previous_bluetooth_status = current_bluetooth_status
        self._previous_battery_status = battery_status

        return wifi_message, bt_message, battery_message

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