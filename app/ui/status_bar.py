"""状态栏组件模块

提供显示系统状态（WiFi、蓝牙、电池）的状态栏组件。
"""

from PySide6.QtWidgets import QWidget, QHBoxLayout, QLabel

from app.core.config import ICON_INTERNET, ICON_BLUETOOTH, ICON_BATTERY


class StatusBar(QWidget):
    """系统状态栏组件，显示WiFi、蓝牙和电池状态。"""

    def __init__(self, icon_cache: dict, parent=None):
        """初始化状态栏。

        Args:
            icon_cache: 图标缓存字典
            parent: 父组件
        """
        super().__init__(parent)
        self.icon_cache = icon_cache
        self._init_ui()

    def _init_ui(self):
        """初始化UI组件。"""
        self.status_layout = QHBoxLayout(self)
        self.status_layout.setContentsMargins(10, 5, 10, 5)
        self.status_layout.setSpacing(15)

        self.wifi_icon = self._create_icon_label(ICON_INTERNET, "📶")
        self.wifi_label = self._create_status_label("未连接")

        self.bluetooth_icon = self._create_icon_label(ICON_BLUETOOTH, "🔵")
        self.bluetooth_label = self._create_status_label("未连接")

        self.battery_icon = self._create_icon_label(ICON_BATTERY, "🔋")
        self.battery_label = self._create_status_label("未知")

        wifi_layout = self._create_status_group(self.wifi_icon, self.wifi_label)
        bluetooth_layout = self._create_status_group(self.bluetooth_icon, self.bluetooth_label)
        battery_layout = self._create_status_group(self.battery_icon, self.battery_label)

        self.status_layout.addLayout(wifi_layout)
        self.status_layout.addLayout(bluetooth_layout)
        self.status_layout.addLayout(battery_layout)

    def _create_icon_label(self, icon_path: str, fallback_text: str) -> QLabel:
        """创建图标标签。

        Args:
            icon_path: 图标路径
            fallback_text: 备用文本

        Returns:
            QLabel: 图标标签
        """
        icon = QLabel()
        icon.setObjectName("IconLabel")
        if icon_path in self.icon_cache:
            icon.setPixmap(self.icon_cache[icon_path])
        else:
            icon.setText(fallback_text)
        return icon

    def _create_status_label(self, text: str) -> QLabel:
        """创建状态标签。

        Args:
            text: 标签文本

        Returns:
            QLabel: 状态标签
        """
        label = QLabel(text)
        label.setObjectName("StatusLabel")
        return label

    def _create_status_group(self, icon: QLabel, label: QLabel) -> QHBoxLayout:
        """创建状态组合布局。

        Args:
            icon: 图标标签
            label: 状态标签

        Returns:
            QHBoxLayout: 组合布局
        """
        layout = QHBoxLayout()
        layout.setSpacing(5)
        layout.addWidget(icon)
        layout.addWidget(label)
        return layout

    def update_wifi(self, ssid: str, signal: str = ""):
        """更新WiFi状态显示。

        Args:
            ssid: WiFi名称
            signal: 信号强度
        """
        if ssid and ssid != "未连接":
            self.wifi_label.setText(f"{ssid} ({signal})" if signal else ssid)
        else:
            self.wifi_label.setText("未连接")

    def update_bluetooth(self, device_name: str = None, status: str = None):
        """更新蓝牙状态显示。

        Args:
            device_name: 设备名称
            status: 连接状态
        """
        if device_name and status:
            self.bluetooth_label.setText(f"{device_name} ({status})")
        else:
            self.bluetooth_label.setText("未连接")

    def update_battery(self, charge: str = None, status: str = None):
        """更新电池状态显示。

        Args:
            charge: 电量百分比
            status: 电池状态
        """
        if charge:
            self.battery_label.setText(f"{charge}% ({status})" if status else f"{charge}%")
        else:
            self.battery_label.setText("未知")
