# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

import enum
from ..Configure import CONFIG_MANAGER


class EventCode(enum.IntEnum):
    NETWORK_RESTORE = 0b0001
    NETWORK_DISCONNECT = 0b0010
    BLUETOOTH_CONNECT = 0b0011
    BLUETOOTH_DISCONNECT = 0b0100
    MOUSE_HOVER = 0b0101
    MOUSE_LEAVE = 0b0110
    SUICIDE = 0b1111


def _build_event_templates(reserved):
    templates = {}

    for event in EventCode:
        event_name = event.name
        if event_name in reserved: continue
        parts = event_name.split('_')

        category, state = parts[0], parts[1]
        if category == "BLUETOOTH" and state == "CONNECT":
            state = "RESTORE"
        config = CONFIG_MANAGER.__dict__[category][state]
        templates[event] = {
            "text": config["text"],
            "color": config["color"],
            "icon": config["icon"]
        }

    return templates


_reserved = ["MOUSE_HOVER", "MOUSE_LEAVE", "SUICIDE"]
EVENT_TEMPLATES = _build_event_templates(reserved = _reserved)
