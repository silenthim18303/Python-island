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
from PySide6.QtWidgets import (QApplication, QSizePolicy, QVBoxLayout, QWidget)

from qfluentwidgets import SingleDirectionScrollArea

class Ui_island_index_setting_general_ui(object):
    def setupUi(self, island_index_setting_general_ui):
        if not island_index_setting_general_ui.objectName():
            island_index_setting_general_ui.setObjectName(u"island_index_setting_general_ui")
        island_index_setting_general_ui.resize(450, 300)
        self.sa_index_setting_general = SingleDirectionScrollArea(island_index_setting_general_ui)
        self.sa_index_setting_general.setObjectName(u"sa_index_setting_general")
        self.sa_index_setting_general.setGeometry(QRect(0, 0, 431, 300))
        self.sa_index_setting_general.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.sa_index_setting_general.setWidgetResizable(True)
        self.scrollAreaWidgetContents = QWidget()
        self.scrollAreaWidgetContents.setObjectName(u"scrollAreaWidgetContents")
        self.scrollAreaWidgetContents.setGeometry(QRect(0, 0, 429, 298))
        self.vl_index_setting_general_main = QVBoxLayout(self.scrollAreaWidgetContents)
        self.vl_index_setting_general_main.setObjectName(u"vl_index_setting_general_main")
        self.sa_index_setting_general.setWidget(self.scrollAreaWidgetContents)

        self.retranslateUi(island_index_setting_general_ui)

        QMetaObject.connectSlotsByName(island_index_setting_general_ui)
    # setupUi

    def retranslateUi(self, island_index_setting_general_ui):
        island_index_setting_general_ui.setWindowTitle(QCoreApplication.translate("island_index_setting_general_ui", u"island_index_setting_general_ui", None))
    # retranslateUi

