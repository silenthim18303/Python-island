"""定时器管理器模块

统一管理灵动岛中的所有定时器。
"""

from typing import Callable, Optional, Dict
from PySide6.QtCore import QTimer, QObject


class TimerManager(QObject):
    """定时器管理器

    集中管理所有定时器的创建、启动、停止和销毁。

    Attributes:
        timers: 定时器字典
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._timers: Dict[str, QTimer] = {}

    def create_timer(
        self,
        name: str,
        interval: int,
        callback: Callable,
        single_shot: bool = False,
        auto_start: bool = True
    ) -> QTimer:
        if name in self._timers:
            self.stop_timer(name)
            self._timers[name].deleteLater()

        timer = QTimer(self)
        timer.setInterval(interval)
        timer.setSingleShot(single_shot)
        timer.timeout.connect(callback)

        self._timers[name] = timer

        if auto_start:
            timer.start()

        return timer

    def start_timer(self, name: str) -> bool:
        if name in self._timers:
            self._timers[name].start()
            return True
        return False

    def stop_timer(self, name: str) -> bool:
        if name in self._timers:
            self._timers[name].stop()
            return True
        return False

    def restart_timer(self, name: str) -> bool:
        if name in self._timers:
            self._timers[name].start()
            return True
        return False

    def is_timer_active(self, name: str) -> bool:
        if name in self._timers:
            return self._timers[name].isActive()
        return False

    def get_timer(self, name: str) -> Optional[QTimer]:
        return self._timers.get(name)

    def remove_timer(self, name: str):
        if name in self._timers:
            self._timers[name].stop()
            self._timers[name].deleteLater()
            del self._timers[name]

    def stop_all(self):
        for timer in self._timers.values():
            timer.stop()

    def start_all(self):
        for timer in self._timers.values():
            timer.start()

    def clear_all(self):
        self.stop_all()
        for name in list(self._timers.keys()):
            self.remove_timer(name)

    def create_debounce_timer(
        self,
        name: str,
        delay: int,
        callback: Callable
    ) -> QTimer:
        return self.create_timer(
            name,
            delay,
            callback,
            single_shot=True,
            auto_start=False
        )

    def trigger_debounce(self, name: str):
        if name in self._timers:
            self._timers[name].stop()
            self._timers[name].start()

    def create_auto_close_timer(
        self,
        name: str,
        delay: int,
        callback: Callable
    ) -> QTimer:
        if name in self._timers and self._timers[name].isActive():
            self._timers[name].stop()

        return self.create_timer(
            name,
            delay,
            callback,
            single_shot=True,
            auto_start=True
        )
