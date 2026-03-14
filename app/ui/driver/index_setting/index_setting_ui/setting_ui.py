
from PySide6.QtWidgets import QWidget

from app.ui.interfaces.index_setting.index_setting_ui.island_index_setting_ui_ui import Ui_island_index_setting_ui_ui

class setting_ui_driver(QWidget , Ui_island_index_setting_ui_ui):
    def __init__(self):

        super().__init__()
        self.setupUi(self)

        self.__init_ui()

    def __init_ui(self):
        self.setFixedSize(450 , 300)

    def __init_slots(self):
        pass