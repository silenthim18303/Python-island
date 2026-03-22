# -*- coding: utf-8 -*-

################################################################################
## Form generated from reading UI file 'island_index_setting_general_ui.ui'
##
## Created by: Qt User Interface Compiler version 6.10.2
##
## WARNING! All changes made in this file will be lost when recompiling UI file!
################################################################################

from PySide6.QtCore import (QCoreApplication, QDate, QDateTime, QLocale,
    QMetaObject, QObject, QPoint, QRect,
    QSize, QTime, QUrl, Qt)
from PySide6.QtGui import (QBrush, QColor, QConicalGradient, QCursor,
    QFont, QFontDatabase, QGradient, QIcon,
    QImage, QKeySequence, QLinearGradient, QPainter,
    QPalette, QPixmap, QRadialGradient, QTransform)
from PySide6.QtWidgets import (QApplication, QCheckBox, QSizePolicy, QWidget)

class Ui_island_index_setting_general_ui(object):
    def setupUi(self, island_index_setting_general_ui):
        if not island_index_setting_general_ui.objectName():
            island_index_setting_general_ui.setObjectName(u"island_index_setting_general_ui")
        island_index_setting_general_ui.resize(450, 300)
        self.startup_checkbox = QCheckBox(island_index_setting_general_ui)
        self.startup_checkbox.setObjectName(u"startup_checkbox")
        self.startup_checkbox.setGeometry(QRect(20, 20, 151, 20))

        self.retranslateUi(island_index_setting_general_ui)

        QMetaObject.connectSlotsByName(island_index_setting_general_ui)
    # setupUi

    def retranslateUi(self, island_index_setting_general_ui):
        island_index_setting_general_ui.setWindowTitle(QCoreApplication.translate("island_index_setting_general_ui", u"island_index_setting_general_ui", None))
        self.startup_checkbox.setText(QCoreApplication.translate("island_index_setting_general_ui", u"开机自启", None))
    # retranslateUi