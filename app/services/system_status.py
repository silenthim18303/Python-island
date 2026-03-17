"""系统状态服务模块

提供获取系统状态（WiFi、蓝牙、电池）的功能。
"""

import socket
import subprocess


class SystemStatusService:
    """系统状态服务，提供WiFi、蓝牙、电池状态查询功能。"""

    @staticmethod
    def check_dns_connection() -> bool:
        """检查DNS连接状态。

        Returns:
            bool: 是否连接
        """
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=2)
            return True
        except Exception:
            return False

    @staticmethod
    def get_wifi_info() -> tuple:
        """获取WiFi信息。

        Returns:
            tuple: (ssid, signal, dns_connected)
        """
        ssid = ""
        signal = ""
        dns_connected = False

        try:
            result = subprocess.run(
                ["netsh", "wlan", "show", "interfaces"],
                capture_output=True,
                text=True,
                check=True,
                encoding="utf-8",
                errors="ignore",
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            output = result.stdout

            for line in output.split("\n"):
                line = line.strip()
                if line.startswith("SSID"):
                    ssid = line.split(":")[1].strip()
                elif line.startswith("Signal"):
                    signal = line.split(":")[1].strip()

            if ssid:
                dns_connected = SystemStatusService.check_dns_connection()
            else:
                ssid = "未连接"
        except Exception:
            ssid = "未连接"

        return ssid, signal, dns_connected

    @staticmethod
    def get_bluetooth_devices() -> list:
        """获取蓝牙设备信息。

        Returns:
            list: 蓝牙设备列表 [(device_name, status), ...]
        """
        devices = []

        try:
            result = subprocess.run(
                ["sc", "query", "bthserv"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="ignore",
                creationflags=subprocess.CREATE_NO_WINDOW,
            )

            output = result.stdout
            if "RUNNING" in output:
                devices.append(("蓝牙", "已开启"))
            else:
                devices.append(("蓝牙", "已关闭"))
        except Exception:
            devices.append(("蓝牙", "未连接"))

        return devices

    @staticmethod
    def get_battery_info() -> tuple:
        """获取电池信息。

        Returns:
            tuple: (charge, status)
        """
        charge = ""
        status = ""

        status_map = {
            1: "放电",
            2: "接通电源",
            3: "完全充电",
            4: "低",
            5: "临界",
            6: "充电",
            7: "充电过高",
            8: "未知",
        }

        try:
            try:
                import wmi

                c = wmi.WMI()
                battery = c.Win32_Battery()[0]
                charge = battery.EstimatedChargeRemaining
                status_code = battery.BatteryStatus
                status = status_map.get(status_code, "未知")
            except ImportError:
                result = subprocess.run(
                    [
                        "wmic",
                        "path",
                        "Win32_Battery",
                        "get",
                        "EstimatedChargeRemaining,BatteryStatus",
                    ],
                    capture_output=True,
                    text=True,
                    check=True,
                    encoding="utf-8",
                    errors="ignore",
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
                output = result.stdout

                lines = output.strip().split("\n")[1:]
                if lines:
                    parts = lines[0].strip().split()
                    if len(parts) >= 2:
                        charge = parts[0]
                        status_code = int(parts[1])
                        status = status_map.get(status_code, "未知")
        except Exception:
            pass

        return str(charge) if charge else "", status

    @staticmethod
    def get_all_status() -> tuple:
        """一次性获取所有状态信息。

        Returns:
            tuple: (wifi_info, bluetooth_devices, battery_info)
        """
        ssid, signal, dns_connected = SystemStatusService.get_wifi_info()
        wifi_info = (ssid, signal, dns_connected)

        bluetooth_devices = SystemStatusService.get_bluetooth_devices()

        charge, status = SystemStatusService.get_battery_info()
        battery_info = (charge, status)

        return wifi_info, bluetooth_devices, battery_info
