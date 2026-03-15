import psutil
import asyncio
import threading
from PySide6.QtCore import QObject, Signal, QTimer
from winsdk.windows.devices.enumeration import DeviceInformation, DeviceClass

class NetworkMonitor(QObject):
    wifi_changed = Signal(bool, str) # status, name
    bluetooth_changed = Signal(bool, str) # connected, name

    def __init__(self):
        super().__init__()
        self.last_wifi_status = None
        self.last_bt_devices = set()
        
        # WiFi Timer
        self.wifi_timer = QTimer()
        self.wifi_timer.timeout.connect(self.check_wifi)
        self.wifi_timer.start(5000)

        # BT Thread
        self._loop = asyncio.new_event_loop()
        self._bt_thread = threading.Thread(target=self._run_bt_loop, daemon=True)
        self._bt_thread.start()
        
        # Initial checks
        self.check_wifi()
        asyncio.run_coroutine_threadsafe(self.check_bluetooth(), self._loop)
        
        # Periodic BT check
        self.bt_timer = QTimer()
        self.bt_timer.timeout.connect(lambda: asyncio.run_coroutine_threadsafe(self.check_bluetooth(), self._loop))
        self.bt_timer.start(10000)

    def _run_bt_loop(self):
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()

    def check_wifi(self):
        stats = psutil.net_if_stats()
        wifi_up = False
        wifi_name = "WiFi"
        
        for name, stat in stats.items():
            if "wi-fi" in name.lower() or "wlan" in name.lower():
                wifi_up = stat.isup
                wifi_name = name
                break
        
        if self.last_wifi_status is not None and wifi_up != self.last_wifi_status:
            self.wifi_changed.emit(wifi_up, wifi_name)
        
        self.last_wifi_status = wifi_up

    async def check_bluetooth(self):
        try:
            # Selector for paired/connected devices
            selector = "System.Devices.InterfaceClassGuid:=\"{E0CBF06C-CD8B-4647-BB8A-263B43F0F974}\" AND System.Devices.InterfaceEnabled:=System.StructuredQueryType.Boolean#True"
            devices = await DeviceInformation.find_all_async(selector)
            
            current_devices = {d.name for d in devices if d.name}
            
            # Detect new connections
            new_devices = current_devices - self.last_bt_devices
            for name in new_devices:
                if self.last_bt_devices: # Don't emit on first run
                    self.bluetooth_changed.emit(True, name)
            
            # Detect disconnections
            lost_devices = self.last_bt_devices - current_devices
            for name in lost_devices:
                self.bluetooth_changed.emit(False, name)
                
            self.last_bt_devices = current_devices
        except Exception as e:
            print(f"BT Monitor Error: {e}")
