import re
import subprocess
import socket
import webbrowser
from typing import List, Optional

# 尝试导入剪贴板相关库
try:
    from PySide6.QtGui import QGuiApplication
    clipboard_available = True
except ImportError:
    clipboard_available = False

# 尝试导入亮度控制库
try:
    import screen_brightness_control as sbc

    brightness_available = True
except ImportError:
    brightness_available = False

# 尝试导入pycaw库用于音量控制
try:
    from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
    from comtypes import CLSCTX_ALL

    volume_available = True
except ImportError:
    volume_available = False

# 尝试导入Windows API用于模拟按键
try:
    import win32api
    import win32con
    import win32com.client
    import pythoncom
    import win32gui , win32ui

    windows_api_available = True
    volume_initialized = False
    volume_object = None
    mute_state = False
    current_volume = 0.5

    # 初始化音量控制
    try:
        pythoncom.CoInitialize()
        try:
            from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume

            devices = AudioUtilities.GetSpeakers()
            endpoint = devices.EndpointVolume
            current_volume = endpoint.GetMasterVolumeLevelScalar()
            mute_state = endpoint.GetMute()
            volume_initialized = True
        except Exception:
            shell = win32com.client.Dispatch("WScript.Shell")
            volume_object = shell
            volume_initialized = True
    except Exception:
        volume_initialized = False
        volume_object = None
except ImportError:
    windows_api_available = False

# 尝试导入wmi库用于获取Windows系统信息
try:
    import wmi

    wmi_available = True
except ImportError:
    wmi_available = False


def get_system_brightness():
    """获取系统当前亮度。"""
    if brightness_available:
        try:
            brightness = sbc.get_brightness()[0]
            return brightness
        except Exception:
            pass
    return 50


def set_brightness(value):
    """设置系统亮度。"""
    if brightness_available:
        try:
            sbc.set_brightness(value)
        except Exception:
            pass


def get_system_volume():
    """获取系统当前音量。"""
    if volume_available:
        try:
            devices = AudioUtilities.GetSpeakers()
            interface = devices.Activate(
                IAudioEndpointVolume._iid_, CLSCTX_ALL, None
            )
            volume = interface.QueryInterface(IAudioEndpointVolume)
            return int(volume.GetMasterVolumeLevelScalar() * 100)
        except Exception:
            pass

    try:
        cmd = "(Get-SoundVolume).VolumeLevel"
        result = subprocess.run(
            ["powershell", "-Command", cmd],
            capture_output=True, text=True, check=True
        )
        volume = int(result.stdout.strip())
        return max(0, min(100, volume))
    except Exception:
        pass

    if windows_api_available and volume_initialized:
        try:
            return int(current_volume * 100)
        except Exception:
            pass

    return 50


def set_volume(value):
    """设置系统音量。"""
    global current_volume

    if volume_available:
        try:
            devices = AudioUtilities.GetSpeakers()
            interface = devices.Activate(
                IAudioEndpointVolume._iid_, CLSCTX_ALL, None
            )
            volume = interface.QueryInterface(IAudioEndpointVolume)
            volume.SetMasterVolumeLevelScalar(value / 100, None)
            if windows_api_available:
                current_volume = value / 100.0
            return
        except Exception:
            pass

    try:
        cmd = f"Set-SoundVolume -VolumeLevel {value}"
        subprocess.run(
            ["powershell", "-Command", cmd],
            capture_output=True, text=True, check=True
        )
        if windows_api_available:
            current_volume = value / 100.0
        return
    except Exception:
        pass

    if windows_api_available and volume_initialized:
        try:
            if value == 0:
                win32api.keybd_event(win32con.VK_VOLUME_MUTE, 0, 0, 0)
                win32api.keybd_event(
                    win32con.VK_VOLUME_MUTE, 0, win32con.KEYEVENTF_KEYUP, 0
                )
            else:
                win32api.keybd_event(win32con.VK_VOLUME_MUTE, 0, 0, 0)
                win32api.keybd_event(
                    win32con.VK_VOLUME_MUTE, 0, win32con.KEYEVENTF_KEYUP, 0
                )
                steps = min(20, int(value / 5) + 1)
                for _ in range(steps):
                    win32api.keybd_event(win32con.VK_VOLUME_UP, 0, 0, 0)
                    win32api.keybd_event(
                        win32con.VK_VOLUME_UP, 0, win32con.KEYEVENTF_KEYUP, 0
                    )
            current_volume = value / 100.0
            return
        except Exception:
            pass


def check_dns_connection():
    """检查DNS连接状态。"""
    try:
        # 尝试连接Google DNS
        socket.create_connection(("8.8.8.8", 53), timeout=2)
        return True
    except Exception:
        return False


def get_wifi_info():
    """获取WiFi信息。"""
    ssid = ""
    signal = ""
    dns_connected = False
    
    try:
        # 使用netsh命令获取WiFi信息
        result = subprocess.run(
            ["netsh", "wlan", "show", "interfaces"],
            capture_output=True, text=True, check=True, encoding='utf-8', errors='ignore'
        )
        output = result.stdout

        # 解析输出
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith("SSID"):
                ssid = line.split(":")[1].strip()
            elif line.startswith("Signal"):
                signal = line.split(":")[1].strip()

        # 检查DNS连接
        if ssid:
            dns_connected = check_dns_connection()
        else:
            ssid = "未连接"
    except Exception:
        ssid = "未连接"

    return ssid, signal, dns_connected


def get_bluetooth_devices():
    """获取蓝牙设备信息。"""
    devices = []
    
    try:
        # 直接返回蓝牙状态，避免编码问题
        # 检查蓝牙服务是否运行
        result = subprocess.run(
            ["sc", "query", "bthserv"],
            capture_output=True, text=True, encoding='utf-8', errors='ignore'
        )
        
        output = result.stdout
        if "RUNNING" in output:
            # 蓝牙服务正在运行
            devices.append(("蓝牙", "已开启"))
        else:
            # 蓝牙服务未运行
            devices.append(("蓝牙", "已关闭"))
    except Exception:
        # 出现异常，返回未连接状态
        devices.append(("蓝牙", "未连接"))
    
    return devices


def get_battery_info():
    """获取电池信息。"""
    charge = ""
    status = ""

    try:
        if wmi_available:
            # 使用wmi库获取电池信息
            c = wmi.WMI()
            battery = c.Win32_Battery()[0]
            charge = battery.EstimatedChargeRemaining
            status_code = battery.BatteryStatus

            # 映射电池状态代码
            status_map = {
                1: "放电", 2: "接通电源", 3: "完全充电",
                4: "低", 5: "临界", 6: "充电",
                7: "充电过高", 8: "未知"
            }
            status = status_map.get(status_code, "未知")
        else:
            # 使用WMIC命令获取电池信息
            result = subprocess.run(
                ["wmic", "path", "Win32_Battery", "get", "EstimatedChargeRemaining,BatteryStatus"],
                capture_output=True, text=True, check=True, encoding='utf-8', errors='ignore'
            )
            output = result.stdout

            # 解析输出
            lines = output.strip().split('\n')[1:]
            if lines:
                parts = lines[0].strip().split()
                if len(parts) >= 2:
                    charge = parts[0]
                    status_code = int(parts[1])

                    # 映射电池状态代码
                    status_map = {
                        1: "放电", 2: "接通电源", 3: "完全充电",
                        4: "低", 5: "临界", 6: "充电",
                        7: "充电过高", 8: "未知"
                    }
                    status = status_map.get(status_code, "未知")
    except Exception:
        pass

    return str(charge) if charge else "", status


def get_all_status():
    """
    一次性获取所有状态信息（WiFi、蓝牙、电池）。

    返回:
        tuple: (wifi_info, bluetooth_devices, battery_info)
    """
    # 获取WiFi信息
    ssid, signal, dns_connected = get_wifi_info()
    wifi_info = (ssid, signal, dns_connected)

    # 获取蓝牙设备信息
    bluetooth_devices = get_bluetooth_devices()

    # 获取电池信息
    charge, status = get_battery_info()
    battery_info = (charge, status)

    return wifi_info, bluetooth_devices, battery_info

def get_screen_shot(path : str) -> None:
    try:
        vx = win32api.GetSystemMetrics(win32con.SM_XVIRTUALSCREEN)
        vy = win32api.GetSystemMetrics(win32con.SM_YVIRTUALSCREEN)
        vw = win32api.GetSystemMetrics(win32con.SM_CXVIRTUALSCREEN)
        vh = win32api.GetSystemMetrics(win32con.SM_CYVIRTUALSCREEN)

        if vw <= 0 or vh <= 0:
            # TODO 添加错误提示
            pass
        
        hwnd = 0
        hwndDC = win32gui.GetWindowDC(hwnd)
        mfcDC = win32ui.CreateDCFromHandle(hwndDC)
        saveDC = mfcDC.CreateCompatibleDC()

        saveBitMap = win32ui.CreateBitmap()
        saveBitMap.CreateCompatibleBitmap(mfcDC, vw, vh)
        saveDC.SelectObject(saveBitMap)

        saveDC.BitBlt((0, 0), (vw, vh), mfcDC, (vx, vy), win32con.SRCCOPY)

        saveBitMap.SaveBitmapFile(saveDC, path)

        saveDC.DeleteDC()
        _safe_delete_gdi_bitmap(saveBitMap)
        mfcDC.DeleteDC()
        win32gui.ReleaseDC(hwnd, hwndDC)

    except Exception as e:
        # TODO 添加错误提示
        pass
    
def _safe_delete_gdi_bitmap(bitmap) -> None:
    if bitmap is None:
        return

    try:
        delete_obj = getattr(bitmap, "DeleteObject", None)
        if callable(delete_obj):
            delete_obj()
            return
    except Exception:
        # TODO 添加错误提示
        pass

    try:
        get_handle = getattr(bitmap, "GetHandle", None)
        if callable(get_handle):
            hbitmap = get_handle()
            if hbitmap:
                win32gui.DeleteObject(hbitmap)
    except Exception:
        # TODO 添加错误提示
        pass


def get_clipboard_text() -> Optional[str]:
    """获取剪贴板文本内容。"""
    if not clipboard_available:
        return None
    try:
        clipboard = QGuiApplication.clipboard()
        return clipboard.text()
    except Exception:
        return None


def extract_urls(text: str) -> List[str]:
    """从文本中提取所有 URL。"""
    if not text:
        return []

    # URL 正则表达式
    url_pattern = re.compile(
        r'https?://'
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'
        r'localhost|'
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
        r'(?::\d+)?'
        r'(?:/?|[/?]\S+)$',
        re.IGNORECASE
    )

    # 简化版 URL 匹配
    simple_url_pattern = re.compile(
        r'https?://[^\s<>"{}|\\^`\[\]]+',
        re.IGNORECASE
    )

    urls = simple_url_pattern.findall(text)
    # 去重并保持顺序
    seen = set()
    unique_urls = []
    for url in urls:
        url = url.rstrip('.,;:)')  # 移除末尾的标点符号
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)

    return unique_urls


def open_url(url: str) -> bool:
    """使用默认浏览器打开 URL。"""
    try:
        webbrowser.open(url)
        return True
    except Exception:
        return False


def open_urls(urls: List[str]) -> int:
    """批量打开 URL，返回成功打开的数量。"""
    count = 0
    for url in urls:
        if open_url(url):
            count += 1
    return count