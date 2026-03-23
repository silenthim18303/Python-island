"""状态栏组件模块

提供显示系统状态（WiFi、蓝牙、电池）的状态栏组件。
"""

from PySide6.QtWidgets import QHBoxLayout, QLabel, QWidget

from app.core.icons import IslandIcon


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

        self.wifi_icon = self._create_icon_label(IslandIcon.INTERNET, "📶")
        self.wifi_label = self._create_status_label("未连接")

        self.bluetooth_icon = self._create_icon_label(IslandIcon.BLUETOOTH, "🔵")
        self.bluetooth_label = self._create_status_label("未连接")

        self.battery_icon = self._create_icon_label(IslandIcon.BATTERY, "🔋")
        self.battery_label = self._create_status_label("未知")

        wifi_layout = self._create_status_group(self.wifi_icon, self.wifi_label)
        bluetooth_layout = self._create_status_group(self.bluetooth_icon, self.bluetooth_label)
        battery_layout = self._create_status_group(self.battery_icon, self.battery_label)

        self.status_layout.addLayout(wifi_layout)
        self.status_layout.addLayout(bluetooth_layout)
        self.status_layout.addLayout(battery_layout)

    def _create_icon_label(self, icon: IslandIcon, fallback_text: str) -> QLabel:
        """创建图标标签。

        Args:
            icon: 图标枚举
            fallback_text: 备用文本

        Returns:
            QLabel: 图标标签
        """
        label = QLabel()
        label.setObjectName("IconLabel")
        icon_path = icon.path()
        if icon_path in self.icon_cache:
            label.setPixmap(self.icon_cache[icon_path])
        else:
            label.setText(fallback_text)
        return label

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
            ssid: 连接状态
            signal: 信号强度
        """
        # 简化显示，只显示"已连接"和"未连接"
        self.wifi_label.setText(ssid)

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
        if charge or status == "插电":
            self.battery_icon.show()
            self.battery_label.show()
            if status == "插电":
                self.battery_label.setText("插电")
            else:
                self.battery_label.setText(f"{charge}% ({status})" if status else f"{charge}%")
        else:
            self.battery_label.setText("未知")
            self.battery_icon.hide()
            self.battery_label.hide()