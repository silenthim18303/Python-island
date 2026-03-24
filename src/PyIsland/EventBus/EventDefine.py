# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

import enum
from PyIsland.Configure import CONFIG_MANAGER


class EventCode(enum.IntEnum):
    NETWORK_RESTORE      = 0b0001 # 1
    NETWORK_DISCONNECT   = 0b0010 # 2
    BLUETOOTH_CONNECT    = 0b0011 # 3
    BLUETOOTH_DISCONNECT = 0b0100 # 4
    MOUSE_HOVER = 0b0101 # 5
    MOUSE_LEAVE = 0b0110 # 6
    SCREENSHOT_START  = 0b0111 # 7
    SCREENSHOT_CANCEL = 0b1000 # 8
    SUICIDE = 0b1111 # 15


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


_reserved = ["MOUSE_HOVER", "MOUSE_LEAVE", "SUICIDE", "SCREENSHOT_START", "SCREENSHOT_CANCEL"]
EVENT_TEMPLATES = _build_event_templates(reserved = _reserved)
