"""工具函数模块（向后兼容）

此模块保留原有的函数接口，但将功能委托给新的服务模块。
建议直接使用 services 模块中的服务类。

已迁移的功能：
- 亮度控制 -> services.brightness.BrightnessService
- 系统状态 -> services.system_status.SystemStatusService
- 剪贴板操作 -> services.clipboard.ClipboardService
"""

from app.services.brightness import BrightnessService
from app.services.system_status import SystemStatusService
from app.services.clipboard import ClipboardService


def get_system_brightness():
    """获取系统当前亮度。

    已迁移到 BrightnessService.get_brightness()
    """
    return BrightnessService.get_brightness()


def set_brightness(value):
    """设置系统亮度。

    已迁移到 BrightnessService.set_brightness()
    """
    return BrightnessService.set_brightness(value)


def get_wifi_info():
    """获取WiFi信息。

    已迁移到 SystemStatusService.get_wifi_info()
    """
    return SystemStatusService.get_wifi_info()


def get_bluetooth_devices():
    """获取蓝牙设备信息。

    已迁移到 SystemStatusService.get_bluetooth_devices()
    """
    return SystemStatusService.get_bluetooth_devices()


def get_battery_info():
    """获取电池信息。

    已迁移到 SystemStatusService.get_battery_info()
    """
    return SystemStatusService.get_battery_info()


def get_all_status():
    """一次性获取所有状态信息。

    已迁移到 SystemStatusService.get_all_status()
    """
    return SystemStatusService.get_all_status()


def get_clipboard_text():
    """获取剪贴板文本内容。

    已迁移到 ClipboardService.get_text()
    """
    return ClipboardService.get_text()


def extract_urls(text):
    """从文本中提取所有URL。

    已迁移到 ClipboardService.extract_urls()
    """
    return ClipboardService.extract_urls(text)


def open_url(url):
    """使用默认浏览器打开URL。

    已迁移到 ClipboardService.open_url()
    """
    return ClipboardService.open_url(url)


def open_urls(urls):
    """批量打开URL。

    已迁移到 ClipboardService.open_urls()
    """
    return ClipboardService.open_urls(urls)
