"""系统状态服务模块

提供获取系统状态（WiFi、蓝牙、电池）的功能。
"""

import os
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
            # 尝试使用Windows蓝牙命令行工具检测
            try:
                # 使用PowerShell命令检测蓝牙状态
                result = subprocess.run(
                    ["powershell", "Get-BluetoothRadio | Select-Object -Property Status"],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="ignore",
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
                
                output = result.stdout
                
                if "On" in output:
                    devices.append(("蓝牙", "已开启"))
                elif "Off" in output:
                    devices.append(("蓝牙", "已关闭"))
                else:
                    # 如果PowerShell命令失败，尝试使用bleak
                    try:
                        import asyncio
                        from bleak import BleakScanner
                        
                        async def check_bluetooth():
                            try:
                                # 尝试扫描蓝牙设备
                                await BleakScanner.discover(timeout=1)
                                return True
                            except Exception:
                                return False
                        
                        # 运行异步函数
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        is_bluetooth_on = loop.run_until_complete(check_bluetooth())
                        loop.close()
                        
                        if is_bluetooth_on:
                            devices.append(("蓝牙", "已开启"))
                        else:
                            # 尝试使用devcon命令检测蓝牙设备状态
                            try:
                                # 查找devcon.exe路径
                                devcon_paths = [
                                    "C:\\Windows\\System32\\devcon.exe",
                                    "C:\\Windows\\SysWOW64\\devcon.exe"
                                ]
                                devcon_exe = None
                                for path in devcon_paths:
                                    if os.path.exists(path):
                                        devcon_exe = path
                                        break
                                
                                if devcon_exe:
                                    # 列出蓝牙设备
                                    result = subprocess.run(
                                        [devcon_exe, "status", "*Bluetooth*"],
                                        capture_output=True,
                                        text=True,
                                        encoding="utf-8",
                                        errors="ignore",
                                        creationflags=subprocess.CREATE_NO_WINDOW,
                                    )
                                    
                                    output = result.stdout
                                    
                                    if "运行中" in output or "Running" in output:
                                        devices.append(("蓝牙", "已开启"))
                                    else:
                                        devices.append(("蓝牙", "已关闭"))
                                else:
                                    # 如果所有方法都失败，使用WMI作为最后尝试
                                    try:
                                        import wmi
                                        
                                        c = wmi.WMI()
                                        # 查找蓝牙适配器
                                        bluetooth_adapters = c.Win32_PnPEntity()
                                        has_bluetooth = False
                                        
                                        for adapter in bluetooth_adapters:
                                            if adapter.Caption and "Bluetooth" in adapter.Caption:
                                                has_bluetooth = True
                                                break
                                        
                                        if has_bluetooth:
                                            # 检查蓝牙服务状态
                                            service_result = subprocess.run(
                                                ["sc", "query", "bthserv"],
                                                capture_output=True,
                                                text=True,
                                                encoding="utf-8",
                                                errors="ignore",
                                                creationflags=subprocess.CREATE_NO_WINDOW,
                                            )
                                            
                                            if "RUNNING" in service_result.stdout:
                                                devices.append(("蓝牙", "已开启"))
                                            else:
                                                devices.append(("蓝牙", "已关闭"))
                                        else:
                                            devices.append(("蓝牙", "未连接"))
                                    except ImportError:
                                        # 如果所有方法都不可用，基于服务状态判断
                                        service_result = subprocess.run(
                                            ["sc", "query", "bthserv"],
                                            capture_output=True,
                                            text=True,
                                            encoding="utf-8",
                                            errors="ignore",
                                            creationflags=subprocess.CREATE_NO_WINDOW,
                                        )
                                        
                                        if "RUNNING" in service_result.stdout:
                                            devices.append(("蓝牙", "已开启"))
                                        else:
                                            devices.append(("蓝牙", "已关闭"))
                            except Exception:
                                pass
                    except ImportError:
                        # 回退到其他方法
                        try:
                            import wmi
                            
                            c = wmi.WMI()
                            # 查找蓝牙适配器
                            bluetooth_adapters = c.Win32_PnPEntity()
                            has_bluetooth = False
                            
                            for adapter in bluetooth_adapters:
                                if adapter.Caption and "Bluetooth" in adapter.Caption:
                                    has_bluetooth = True
                                    break
                            
                            if has_bluetooth:
                                # 检查蓝牙服务状态
                                service_result = subprocess.run(
                                    ["sc", "query", "bthserv"],
                                    capture_output=True,
                                    text=True,
                                    encoding="utf-8",
                                    errors="ignore",
                                    creationflags=subprocess.CREATE_NO_WINDOW,
                                )
                                
                                if "RUNNING" in service_result.stdout:
                                    devices.append(("蓝牙", "已开启"))
                                else:
                                    devices.append(("蓝牙", "已关闭"))
                            else:
                                devices.append(("蓝牙", "未连接"))
                        except ImportError:
                            # 如果所有方法都不可用，基于服务状态判断
                            service_result = subprocess.run(
                                ["sc", "query", "bthserv"],
                                capture_output=True,
                                text=True,
                                encoding="utf-8",
                                errors="ignore",
                                creationflags=subprocess.CREATE_NO_WINDOW,
                            )
                            
                            if "RUNNING" in service_result.stdout:
                                devices.append(("蓝牙", "已开启"))
                            else:
                                devices.append(("蓝牙", "已关闭"))
            except Exception:
                # 回退到其他方法
                try:
                    import wmi
                    
                    c = wmi.WMI()
                    # 查找蓝牙适配器
                    bluetooth_adapters = c.Win32_PnPEntity()
                    has_bluetooth = False
                    
                    for adapter in bluetooth_adapters:
                        if adapter.Caption and "Bluetooth" in adapter.Caption:
                            has_bluetooth = True
                            break
                    
                    if has_bluetooth:
                        # 检查蓝牙服务状态
                        service_result = subprocess.run(
                            ["sc", "query", "bthserv"],
                            capture_output=True,
                            text=True,
                            encoding="utf-8",
                            errors="ignore",
                            creationflags=subprocess.CREATE_NO_WINDOW,
                        )
                        
                        if "RUNNING" in service_result.stdout:
                            devices.append(("蓝牙", "已开启"))
                        else:
                            devices.append(("蓝牙", "已关闭"))
                    else:
                        devices.append(("蓝牙", "未连接"))
                except ImportError:
                    # 如果所有方法都不可用，基于服务状态判断
                    service_result = subprocess.run(
                        ["sc", "query", "bthserv"],
                        capture_output=True,
                        text=True,
                        encoding="utf-8",
                        errors="ignore",
                        creationflags=subprocess.CREATE_NO_WINDOW,
                    )
                    
                    if "RUNNING" in service_result.stdout:
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
                batteries = c.Win32_Battery()
                if batteries:
                    battery = batteries[0]
                    charge = battery.EstimatedChargeRemaining
                    status_code = battery.BatteryStatus
                    status = status_map.get(status_code, "未知")
                else:
                    # 没有电池，可能是台式机
                    status = "插电"
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
                    encoding="utf-8",
                    errors="ignore",
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
                output = result.stdout

                lines = output.strip().split("\n")[1:]
                if lines and lines[0].strip():
                    parts = lines[0].strip().split()
                    if len(parts) >= 2:
                        charge = parts[0]
                        status_code = int(parts[1])
                        status = status_map.get(status_code, "未知")
                else:
                    # 没有电池信息，可能是台式机
                    status = "插电"
        except Exception:
            # 发生异常，可能是没有电池
            status = "插电"

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