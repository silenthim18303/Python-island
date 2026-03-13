# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

import asyncio
import subprocess

from ..Configure import CONFIG_MANAGER
from .Bus import EventManager
from .EventDefine import EventCode
# noinspection PyUnresolvedReferences
from PyQt5.QtCore import (
    Qt, QThread, QTimer, QPropertyAnimation, QEasingCurve, QRect, pyqtProperty
)


# noinspection PyAttributeOutsideInit
class AsyncMonitorThread(QThread):
    def __init__(self):
        super().__init__()
        self.event_manager = EventManager()

    def run(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)

        self.loop.create_task(self.network_monitor_coro())
        self.loop.create_task(self.bluetooth_monitor_coro())

        self.loop.run_forever()

    async def network_monitor_coro(self):
        was_connected = True
        interval = CONFIG_MANAGER.CHECK_INTERVAL_NET / 1000

        while True:
            is_connected = await self.check_dns_async()
            if not was_connected and is_connected:
                self.publish_to(EventCode.NETWORK_RESTORE)
            was_connected = is_connected
            await asyncio.sleep(interval)

    @staticmethod
    async def check_dns_async():
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection("114.114.114.114", 53),
                timeout=2
            )
            writer.close()
            await writer.wait_closed()
            return True
        except (asyncio.TimeoutError, OSError):
            return False

    async def bluetooth_monitor_coro(self):

        last_devices = await self.get_connected_devices()
        interval = CONFIG_MANAGER.CHECK_INTERVAL_BT / 1000

        while True:
            await asyncio.sleep(interval)
            current_devices = await self.get_connected_devices()
            new_devices = current_devices - last_devices

            if new_devices:
                for dev in new_devices:
                    self.publish_to(
                        EventCode.BLUETOOTH_CONNECT,
                        {"text": f"已连接蓝牙设备: {dev}"}
                    )

            last_devices = current_devices

    @staticmethod
    async def get_connected_devices():
        devices = set()
        try:
            ps_command = (
                "Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | "
                "Where-Object { $_.FriendlyName -notmatch 'Enumerator|Adapter|Module|Generic|Intel|Realtek' } | "
                "Select-Object -ExpandProperty FriendlyName"
            )

            si = subprocess.STARTUPINFO()
            si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            si.wShowWindow = subprocess.SW_HIDE

            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", ps_command],
                capture_output=True,
                text=True,
                startupinfo=si,
                creationflags=subprocess.CREATE_NO_WINDOW
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    name = line.strip()
                    if name:
                        devices.add(name)
        except Exception as e:
            print(f"蓝牙检测错误: {e}")
        return devices

    def publish_to(self, event: EventCode, data: dict = None):
        self.event_manager.publish(
            event, data
        )
