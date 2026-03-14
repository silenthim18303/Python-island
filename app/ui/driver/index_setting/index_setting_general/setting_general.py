
from PySide6.QtWidgets import QWidget

from app.ui.interfaces.index_setting.index_setting_general.island_index_setting_general_ui import Ui_island_index_setting_general_ui

class setting_general_driver(QWidget , Ui_island_index_setting_general_ui):
    def __init__(self):

        super().__init__()
        self.setupUi(self)

        self.__init_ui()

    def __init_ui(self):
        self.setFixedSize(450 , 300)

    def __init_slots(self):
        pass