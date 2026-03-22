"""开机自启服务模块

提供开机自启功能的管理，包括：
1. 检查是否已设置开机自启
2. 设置开机自启
3. 移除开机自启
"""

import os
import sys
import winreg
from pathlib import Path


class StartupService:
    """开机自启服务类，管理应用的开机自启设置。"""

    def __init__(self):
        """初始化开机自启服务。"""
        self.app_name = "Pyisland"
        self.reg_key_path = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    def get_executable_path(self):
        """获取应用可执行文件路径。

        Returns:
            str: 应用可执行文件的完整路径
        """
        if getattr(sys, 'frozen', False):
            # 打包后的可执行文件
            return sys.executable
        else:
            # 开发环境
            return str(Path(__file__).parent.parent.parent / "main.py")

    def is_startup_enabled(self):
        """检查是否已设置开机自启。

        Returns:
            bool: 是否已设置开机自启
        """
        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                self.reg_key_path,
                0,
                winreg.KEY_READ
            )
            try:
                winreg.QueryValueEx(key, self.app_name)
                return True
            except FileNotFoundError:
                return False
            finally:
                winreg.CloseKey(key)
        except Exception:
            return False

    def enable_startup(self):
        """设置开机自启。

        Returns:
            bool: 是否设置成功
        """
        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                self.reg_key_path,
                0,
                winreg.KEY_SET_VALUE
            )
            try:
                exe_path = self.get_executable_path()
                winreg.SetValueEx(key, self.app_name, 0, winreg.REG_SZ, exe_path)
                return True
            finally:
                winreg.CloseKey(key)
        except Exception:
            return False

    def disable_startup(self):
        """移除开机自启。

        Returns:
            bool: 是否移除成功
        """
        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                self.reg_key_path,
                0,
                winreg.KEY_SET_VALUE
            )
            try:
                winreg.DeleteValue(key, self.app_name)
                return True
            except FileNotFoundError:
                return True  # 已经不存在，视为成功
            finally:
                winreg.CloseKey(key)
        except Exception:
            return False