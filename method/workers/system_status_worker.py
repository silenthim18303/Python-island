from PySide6.QtCore import QThread, Signal
import importlib
import asyncio
import time

STATUS_POLL_INTERVAL_SECONDS = 2

class SystemStatusWorker(QThread):
    wifi_updated = Signal(dict)
    battery_updated = Signal(dict)

    def __init__(self) -> None:
        super().__init__()
        self.running = True

    @staticmethod
    def _load_checkers():
        class FallbackInternetChecker:
            async def check_internet(self):
                return "未连接到互联网"

        class FallbackBatteryChecker:
            async def check_battery(self):
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
                # 异步调用check_internet方法
                wifi_raw = asyncio.run(internet_checker.check_internet())
                wifi_data = {
                    "status": "on" if ("已连接" in str(wifi_raw) or "online" in str(wifi_raw).lower()) else "off",
                    "text": str(wifi_raw),
                }
            except Exception as e:
                wifi_data = {"status": "error", "text": f"检测异常: {e}"}
            self.wifi_updated.emit(wifi_data)

            try:
                # 异步调用check_battery方法
                bat_status, bat_level = asyncio.run(battery_checker.check_battery())
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

