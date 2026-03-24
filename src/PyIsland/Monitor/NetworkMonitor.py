import asyncio

from PyIsland.EventBus.Bus import EventManager
from PyIsland.EventBus.EventDefine import EventCode


class NetworkMonitor:
    def __init__(self, event_manager: EventManager, config):
        self.event_manager = event_manager
        self.config = config
        self._net_count = 0
        self._interval = config.CHECK_INTERVAL_NET / 1000  # 预计算间隔（秒）

    @staticmethod
    async def check_dns_async() -> bool:
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

    async def run(self):
        was_connected = True
        while True:
            is_connected = await self.check_dns_async()
            if not was_connected and is_connected and self._net_count > 0:
                self.event_manager.publish(EventCode.NETWORK_RESTORE)

            self._net_count += 1
            was_connected = is_connected
            await asyncio.sleep(self._interval)
