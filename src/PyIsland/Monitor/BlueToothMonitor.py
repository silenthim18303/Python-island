from typing import Set, Any
import windows_bluetooth_watcher as wbw
import pythoncom
import wmi

from ..EventBus.EventDefine import EventCode, EVENT_TEMPLATES
from ..EventBus.Bus import EventManager


def replace_event_placeholder(template: dict, placeholder: str, value: str) -> dict:
    """通用事件模板占位符替换函数（修复原replace无效问题）"""
    new_template = template.copy()
    if "text" in new_template:
        # str不可变，需重新赋值
        new_template["text"] = new_template["text"].replace(placeholder, value)
    return new_template


def init_wmi() -> Any:
    pythoncom.CoInitializeEx(0)
    return wmi.WMI()


def deconstructor_wmi():
    pythoncom.CoUninitialize()


class BluetoothMonitor:
    def __init__(self, event_manager: EventManager):
        self.event_manager = event_manager
        self.listener: wbw.Listener = wbw.Listener()
        self.polling: wbw.features.Polling = wbw.features.Polling(self.listener, 1000)
        self.token = []

    def _handle_new_devices(self, diff: wbw.Diff):
        for device in diff.connected:
            event_data = replace_event_placeholder(
                EVENT_TEMPLATES[EventCode.BLUETOOTH_CONNECT],
                "$device", device.name
            )
            self.event_manager.publish(EventCode.BLUETOOTH_CONNECT, event_data)

    def run(self):
        self.token.append(self.polling.on_type_callback(self._handle_new_devices, wbw.features.EventsType.Connected))
        self.token.append(self.polling.on_type_callback(self._handle_new_devices, wbw.features.EventsType.Disconnected))
        self.polling.start_all()

    def _handle_disconnected_devices(self, diff: wbw.Diff):
        for device in diff.disconnected:
            event_data = replace_event_placeholder(
                EVENT_TEMPLATES[EventCode.BLUETOOTH_CONNECT],
                "$device", device.name
            )
            self.event_manager.publish(EventCode.BLUETOOTH_DISCONNECT, event_data)
