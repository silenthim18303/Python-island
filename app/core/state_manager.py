"""灵动岛状态管理器模块

管理灵动岛的各种状态及其转换逻辑。
"""

from enum import Enum, auto
from typing import Optional, Callable, Dict, Any


class IslandState(Enum):
    """灵动岛状态枚举"""
    COLLAPSED = auto()
    HOVERING = auto()
    EXPANDED = auto()
    URL_DISPLAY = auto()
    CONNECTION_DISPLAY = auto()


class IslandStateManager:
    """灵动岛状态管理器

    管理状态转换、状态验证和状态变更通知。

    Attributes:
        current_state: 当前状态
        previous_state: 前一个状态
        state_change_callbacks: 状态变更回调字典
    """

    def __init__(self):
        self.current_state = IslandState.COLLAPSED
        self.previous_state: Optional[IslandState] = None
        self.state_change_callbacks: Dict[IslandState, list] = {
            state: [] for state in IslandState
        }
        self._state_data: Dict[str, Any] = {}

    def set_state(self, new_state: IslandState, **kwargs) -> bool:
        if not self._can_transition_to(new_state):
            return False

        self.previous_state = self.current_state
        self.current_state = new_state
        self._state_data.update(kwargs)

        self._notify_state_change(new_state)
        return True

    def _can_transition_to(self, new_state: IslandState) -> bool:
        valid_transitions = {
            IslandState.COLLAPSED: [
                IslandState.HOVERING,
                IslandState.EXPANDED,
                IslandState.URL_DISPLAY,
                IslandState.CONNECTION_DISPLAY
            ],
            IslandState.HOVERING: [
                IslandState.COLLAPSED,
                IslandState.EXPANDED
            ],
            IslandState.EXPANDED: [
                IslandState.COLLAPSED,
                IslandState.URL_DISPLAY,
                IslandState.CONNECTION_DISPLAY
            ],
            IslandState.URL_DISPLAY: [
                IslandState.COLLAPSED,
                IslandState.EXPANDED
            ],
            IslandState.CONNECTION_DISPLAY: [
                IslandState.COLLAPSED,
                IslandState.EXPANDED
            ]
        }

        return new_state in valid_transitions.get(self.current_state, [])

    def register_callback(self, state: IslandState, callback: Callable):
        if callback not in self.state_change_callbacks[state]:
            self.state_change_callbacks[state].append(callback)

    def unregister_callback(self, state: IslandState, callback: Callable):
        if callback in self.state_change_callbacks[state]:
            self.state_change_callbacks[state].remove(callback)

    def _notify_state_change(self, state: IslandState):
        for callback in self.state_change_callbacks[state]:
            callback(self._state_data)

    def get_state_data(self, key: str, default: Any = None) -> Any:
        return self._state_data.get(key, default)

    def clear_state_data(self):
        self._state_data.clear()

    def is_expanded(self) -> bool:
        return self.current_state in [
            IslandState.EXPANDED,
            IslandState.URL_DISPLAY,
            IslandState.CONNECTION_DISPLAY
        ]

    def is_hovering(self) -> bool:
        return self.current_state == IslandState.HOVERING

    def is_collapsed(self) -> bool:
        return self.current_state == IslandState.COLLAPSED

    def get_previous_state(self) -> Optional[IslandState]:
        return self.previous_state
