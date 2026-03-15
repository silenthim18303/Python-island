import psutil
import datetime
from PySide6.QtCore import QObject, Signal, QTimer
import screen_brightness_control as sbc
from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
from ctypes import cast, POINTER
from comtypes import CLSCTX_ALL

class SystemMonitor(QObject):
    updated = Signal(dict)

    def __init__(self):
        super().__init__()
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_info)
        self.timer.start(1000)

        # Initialize Volume
        try:
            devices = AudioUtilities.GetSpeakers()
            interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
            self.volume = cast(interface, POINTER(IAudioEndpointVolume))
        except Exception as e:
            print(f"Error initializing volume: {e}")
            self.volume = None

    def update_info(self):
        battery = psutil.sensors_battery()
        
        volume_level = 0
        if self.volume:
            volume_level = int(self.volume.GetMasterVolumeLevelScalar() * 100)
            
        brightness = 0
        try:
            brightness = sbc.get_brightness()[0]
        except:
            pass

        info = {
            'percent': battery.percent if battery else 0,
            'power_plugged': battery.power_plugged if battery else False,
            'time': datetime.datetime.now().strftime("%H:%M"),
            'volume': volume_level,
            'brightness': brightness
        }
        self.updated.emit(info)

    def set_volume(self, value):
        if self.volume:
            self.volume.SetMasterVolumeLevelScalar(value / 100, None)

    def set_brightness(self, value):
        try:
            sbc.set_brightness(value)
        except:
            pass
