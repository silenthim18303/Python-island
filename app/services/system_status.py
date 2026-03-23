"""系统状态服务模块

提供获取系统状态（WiFi、蓝牙、电池、CPU、内存）的功能。
"""

import os
import socket
import subprocess


def _get_psutil():
    """延迟导入 psutil，避免未安装时影响其他功能。"""
    try:
        import psutil
        return psutil
    except ImportError:
        return None


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
        """获取网络连接状态。

        Returns:
            tuple: (status, signal, dns_connected)
        """
        # 简化逻辑，只检测DNS连接状态
        dns_connected = SystemStatusService.check_dns_connection()
        
        # 根据DNS连接状态返回简单的状态信息
        status = "已连接" if dns_connected else "未连接"
        signal = ""

        return status, signal, dns_connected

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
        # 优先获取网络状态，减少网络状态变化的检测延迟
        ssid, signal, dns_connected = SystemStatusService.get_wifi_info()
        wifi_info = (ssid, signal, dns_connected)

        # 电池信息获取较快，次之
        charge, status = SystemStatusService.get_battery_info()
        battery_info = (charge, status)

        # 蓝牙信息获取较慢，放在最后
        bluetooth_devices = SystemStatusService.get_bluetooth_devices()

        return wifi_info, bluetooth_devices, battery_info

    @staticmethod
    def get_cpu_usage() -> float:
        """获取CPU使用率。

        Returns:
            float: CPU使用率百分比（0-100），获取失败返回-1
        """
        psutil = _get_psutil()
        if psutil is None:
            return -1
        try:
            return psutil.cpu_percent(interval=0.1)
        except Exception:
            return -1

    @staticmethod
    def get_memory_usage() -> tuple:
        """获取内存使用信息。

        Returns:
            tuple: (used_gb, total_gb, percent)
                used_gb: 已使用内存（GB）
                total_gb: 总内存（GB）
                percent: 使用百分比
            获取失败时返回 None
        """
        psutil = _get_psutil()
        if psutil is None:
            return None
        try:
            mem = psutil.virtual_memory()
            total_gb = round(mem.total / (1024 ** 3), 1)
            used_gb = round(mem.used / (1024 ** 3), 1)
            percent = mem.percent
            return (used_gb, total_gb, percent)
        except Exception:
            return None
            return None