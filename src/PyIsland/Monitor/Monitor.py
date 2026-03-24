# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

import asyncio

from PyQt5.QtCore import QThread


from ..EventBus.Bus import EventManager

from ..Configure import CONFIG_MANAGER
from .NetworkMonitor import NetworkMonitor
from .BlueToothMonitor import BluetoothMonitor
from .KeyBoardMonitor import KeyBoardMonitor




class AsyncMonitorThread(QThread):
    def __init__(
        self,
        disable_nt: bool = False,
        disable_bt: bool = False,
    ):
        super().__init__()
        self.disable_nt = disable_nt
        self.disable_bt = disable_bt
        self.event_manager = EventManager()
        self.config = CONFIG_MANAGER
        self.monitors: list = []
        self._map()

    def _map(self):
        if not self.disable_nt:
            self.monitors.append(NetworkMonitor(self.event_manager, CONFIG_MANAGER))
        if not self.disable_bt:
            self.bt_monitor = BluetoothMonitor(self.event_manager)
            self.bt_monitor.run()
        self.monitors.append(KeyBoardMonitor(self.event_manager))


    def run(self):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        tasks = [loop.create_task(monitor.run()) for monitor in self.monitors]

        try:
            loop.run_until_complete(asyncio.gather(*tasks))
        finally:
            loop.close()
