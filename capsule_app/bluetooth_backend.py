import threading
import json
import subprocess
from PySide6.QtCore import QObject, Signal, QTimer


class BluetoothBackend(QObject):
    """蓝牙后端，使用PowerShell获取Windows系统已连接的蓝牙设备列表，并推送给前端"""
    
    # 设备列表更新信号，主线程中处理
    devices_updated = Signal(list)
    
    def __init__(self, web_view=None):
        super().__init__()
        self.web_view = web_view  # 持有web_view引用，用于向前端推送数据
        self.connected_devices = []
        self.scanning = False
        
        # 定时器，定期刷新蓝牙设备列表
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self._start_scan_thread)
        self.refresh_timer.start(5000)  # 每5秒刷新一次
        
        # 监听设备更新信号，推送至前端
        self.devices_updated.connect(self._push_to_frontend)
        
        # 首次扫描
        QTimer.singleShot(1000, self._start_scan_thread)
    
    def set_web_view(self, web_view):
        """设置web_view，用于向前端推送数据"""
        self.web_view = web_view
    
    def _start_scan_thread(self):
        """在独立线程中启动蓝牙扫描，避免阻塞Qt主线程"""
        if self.scanning:
            return
        thread = threading.Thread(target=self._scan_connected_devices, daemon=True)
        thread.start()
    
    def _scan_connected_devices(self):
        """使用PowerShell扫描已连接的蓝牙设备"""
        self.scanning = True
        try:
            devices_list = self._get_connected_bluetooth_devices()
            if devices_list:
                self._update_devices(devices_list)
            else:
                # 未找到已连接的设备，使用模拟数据
                print("[Bluetooth] 未发现已连接的蓝牙设备，使用模拟数据")
                self._return_mock_data()
        except Exception as e:
            print(f"[Bluetooth] 扫描蓝牙设备失败: {e}")
            self._return_mock_data()
        finally:
            self.scanning = False
    
    def _get_connected_bluetooth_devices(self):
        """调用PowerShell获取已连接的蓝牙设备，延迟导入所有 heavy 模块"""
        try:
            # 延迟导入，避免启动时加载
            import subprocess
            import json
            import re
            
            # PowerShell命令：获取已连接的蓝牙设备
            powershell_command = """
            Get-PnpDevice -Class Bluetooth | Where-Object { $_.Status -eq 'OK' } | Select-Object FriendlyName, DeviceId | ConvertTo-Json
            """
            # 在Windows上隐藏PowerShell窗口，避免弹出黑框
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
            
            # subprocess.run本身是阻塞的，但我们已经在独立线程中运行，不会阻塞主线程
            result = subprocess.run(
                ["powershell", "-Command", powershell_command],
                capture_output=True,
                text=True,
                encoding='gbk',
                errors='replace',
                startupinfo=startupinfo
            )
            
            if result.returncode != 0:
                print(f"[Bluetooth] PowerShell命令执行失败: {result.stderr}")
                return []
            
            if not result.stdout or not result.stdout.strip():
                print("[Bluetooth] PowerShell返回空输出")
                return []
            try:
                devices = json.loads(result.stdout)
            except json.JSONDecodeError as e:
                print(f"[Bluetooth] JSON解析失败: {e}, 输出内容: {result.stdout[:200]}...")
                return []
            if not isinstance(devices, list):
                devices = [devices] if devices else []
            
            # 过滤掉系统蓝牙适配器，只显示真正的蓝牙设备
            filter_patterns = [
                r'Microsoft.*枚举器',
                r'蓝牙枚举器',
                r'LE.*枚举器',
                r'Bluetooth.*Adapter',
                r'Microsoft.*Bluetooth',
                r'英特尔® 无线蓝牙',
                r'Intel Wireless Bluetooth',
                r'Avrcp',
                r'传输',
                r'Device',
                r'无线',
                r'通用属性',
                r'通用访问',
                r'区域网',
                r'推送',
                r'访问'
            ]
            combined_filter = re.compile('|'.join(filter_patterns), re.IGNORECASE)
            
            devices_list = []
            for idx, device in enumerate(devices):
                name = device.get('FriendlyName', '未知设备')
                # 过滤系统设备
                if combined_filter.search(name):
                    continue
                # 跳过空名称
                if not name or name == '未知设备':
                    continue
                device_id = device.get('DeviceId', f'unknown_{idx}')
                # 模拟电量，后续可以扩展获取真实电量
                battery_value = 85 + (len(devices_list) * 7) % 15  # 85%-100%之间
                devices_list.append({
                    "id": device_id,
                    "name": name,
                    "battery": f"{battery_value}%",
                    "batteryValue": battery_value
                })
            
            return devices_list
            
        except Exception as e:
            print(f"[Bluetooth] 解析PowerShell输出失败: {e}")
            return []
    
    def _update_devices(self, devices):
        """更新设备列表并发出信号"""
        if devices != self.connected_devices:
            self.connected_devices = devices
            print(f"[Bluetooth] 更新蓝牙设备列表: {len(devices)} 个设备已连接")
            for d in devices:
                print(f"  - {d['name']} ({d['id']})")
            self.devices_updated.emit(devices)
    
    def _return_mock_data(self):
        """返回模拟数据，用于蓝牙不可用的情况"""
        mock_devices = [
            {
                "id": "test1",
                "name": "Pyisland_sideV似乎没能找到已连接的设备",
                "battery": "66%",
                "batteryValue": 66
            }
        ]
        self._update_devices(mock_devices)
    
    def _push_to_frontend(self, devices):
        """将设备列表推送给前端"""
        if self.web_view and self.web_view.page():
            try:
                payload = json.dumps(devices, ensure_ascii=False)
                js_code = f"window.handleBluetoothDevicesUpdate && window.handleBluetoothDevicesUpdate({payload});"
                self.web_view.page().runJavaScript(js_code)
                print(f"[Bluetooth] 已将设备列表推送给前端: {payload}")
            except Exception as e:
                print(f"[Bluetooth] 推送数据到前端失败: {e}")
    
    def stop(self):
        """停止后台任务"""
        self.refresh_timer.stop()