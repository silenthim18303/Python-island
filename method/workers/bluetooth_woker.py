from PySide6.QtCore import QThread, Signal
import time
import asyncio

STATUS_POLL_INTERVAL_SECONDS = 2

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
            except Exception as _e:
                # print(_e)
                payload = {"status": "error", "devices": []}
            self.bluetooth_updated.emit(payload)
            time.sleep(STATUS_POLL_INTERVAL_SECONDS)

    def stop(self) -> None:
        self.running = False
