# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

import ctypes
import sys
import argparse
from PyIsland.Display.Island import DynamicIslandWindow


from PyQt5.QtWidgets import QApplication


def parse():
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--debug", action="store_true")
    parser.add_argument("-dn", "--disable-network-monitor", action="store_true")
    parser.add_argument("-db", "--disable-bluetooth-monitor", action="store_true")
    return parser.parse_args()


def main():
    # noinspection PyUnresolvedReferences
    ctypes.windll.shcore.SetProcessDpiAwareness(1)

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    window = DynamicIslandWindow(
        debug=parse().debug,
        disable_nt=parse().disable_network_monitor,
        disable_bt=parse().disable_bluetooth_monitor,
    )
    window.show()

    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
