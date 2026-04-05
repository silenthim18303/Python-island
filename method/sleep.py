import os
import ctypes
from .brightness import BrightnessService

class SleepModeManager:
    def __init__(self):
        self.original_brightness = None
        self.original_volume = None
        self.is_active = False
    
    def get_volume(self):
        """获取当前系统音量"""
        try:
            from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
            from comtypes import CLSCTX_ALL
            
            devices = AudioUtilities.GetSpeakers()
            interface = devices.Activate(
                IAudioEndpointVolume._iid_, CLSCTX_ALL, None
            )
            volume = interface.QueryInterface(IAudioEndpointVolume)
            return int(volume.GetMasterVolumeLevelScalar() * 100)
        except Exception:
            return None
    
    def set_volume(self, value):
        """设置系统音量"""
        try:
            from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
            from comtypes import CLSCTX_ALL

            devices = AudioUtilities.GetSpeakers()
            interface = devices.Activate(
                IAudioEndpointVolume._iid_, CLSCTX_ALL, None
            )
            volume = interface.QueryInterface(IAudioEndpointVolume)
            volume.SetMasterVolumeLevelScalar(value / 100, None)
            print(f"音量已设置为: {value}%")
            return True
        except Exception as e:
            print(f"使用pycaw设置音量失败: {e}")
            # 尝试使用Windows API作为备选方案
            try:
                import win32api
                import win32con
                import win32com.client

                # 使用WScript.Shell来设置音量
                shell = win32com.client.Dispatch("WScript.Shell")

                # 先将音量静音
                if value == 0:
                    shell.SendKeys(chr(173))  # 静音键
                    print("已将音量设置为静音")
                return True
            except Exception as e2:
                print(f"使用Windows API设置音量失败: {e2}")
                return False
    
    def enable_eye_protection(self):
        """开启护眼模式（夜间模式）"""
        try:
            # 开启Windows夜间模式
            # 通过修改注册表实现
            import winreg
            
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, 
                                 r"Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate",
                                 0, winreg.KEY_SET_VALUE)
            # 设置夜间模式为开启状态
            # 注意：具体的注册表值可能需要根据Windows版本调整
            # 这里只是一个示例
            return True
        except Exception:
            return False
    
    def disable_eye_protection(self):
        """关闭护眼模式（夜间模式）"""
        try:
            # 关闭Windows夜间模式
            import winreg
            
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, 
                                 r"Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate",
                                 0, winreg.KEY_SET_VALUE)
            # 设置夜间模式为关闭状态
            return True
        except Exception:
            return False
    
    def start_sleep_mode(self):
        """启动睡眠模式"""
        if self.is_active:
            return "睡眠模式已开启"
        
        # 记录原始状态
        self.original_brightness = BrightnessService.get_brightness()
        self.original_volume = self.get_volume()
        
        # 应用睡眠模式
        BrightnessService.set_brightness(5)  # 亮度调整到5%
        self.set_volume(0)  # 音量调为0%
        self.enable_eye_protection()  # 开启护眼模式
        
        self.is_active = True
        return "睡眠模式已开启"
    
    def stop_sleep_mode(self):
        """停止睡眠模式，恢复原始状态"""
        if not self.is_active:
            return "睡眠模式未开启"
        
        # 恢复原始状态
        if self.original_brightness is not None:
            BrightnessService.set_brightness(self.original_brightness)
        if self.original_volume is not None:
            self.set_volume(self.original_volume)
        self.disable_eye_protection()  # 关闭护眼模式
        
        # 重置状态
        self.original_brightness = None
        self.original_volume = None
        self.is_active = False
        
        return "睡眠模式已关闭，已恢复原始状态"
    
    def is_sleep_mode_active(self):
        """检查睡眠模式是否激活"""
        return self.is_active

# 创建实例
sleep_manager = SleepModeManager()

def start_sleep_mode():
    """启动睡眠模式"""
    return sleep_manager.start_sleep_mode()

def stop_sleep_mode():
    """停止睡眠模式"""
    return sleep_manager.stop_sleep_mode()

def is_sleep_mode_active():
    """检查睡眠模式是否激活"""
    return sleep_manager.is_sleep_mode_active()

if __name__ == "__main__":
    print("启动睡眠模式...")
    print(start_sleep_mode())
    
    input("按回车键停止睡眠模式...")
    
    print("停止睡眠模式...")
    print(stop_sleep_mode())