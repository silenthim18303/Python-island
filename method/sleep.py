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
        # 由于win32api获取音量比较复杂，这里返回None
        # 实际使用中，我们主要关注的是静音功能
        return None
    
    def set_volume(self, value):
        """设置系统音量"""
        try:
            import win32api
            WM_APPCOMMAND = 0x319
            
            if value == 0:
                # 音量最小（静音）
                APPCOMMAND_VOLUME_MIN = 0x09
                win32api.SendMessage(-1, WM_APPCOMMAND, 0x30292, APPCOMMAND_VOLUME_MIN * 0x10000)
            else:
                # 对于非静音值，我们可以尝试增加音量
                # 这里使用多次发送音量增加命令来模拟设置音量
                APPCOMMAND_VOLUME_UP = 0x0A
                # 发送多次音量增加命令
                for i in range(min(value // 10, 10)):
                    win32api.SendMessage(-1, WM_APPCOMMAND, 0x30292, APPCOMMAND_VOLUME_UP * 0x10000)
            return True
        except Exception:
            # 尝试使用WScript.Shell作为备选方案
            try:
                import win32com.client
                # 使用WScript.Shell来设置音量
                shell = win32com.client.Dispatch("WScript.Shell")
                
                if value == 0:
                    # 发送静音键
                    shell.SendKeys(chr(173))  # 静音键
                else:
                    # 发送音量增加键
                    for i in range(min(value // 10, 10)):
                        shell.SendKeys(chr(175))  # 音量增加键
                return True
            except Exception:
                return False
    
    def enable_eye_protection(self):
        """开启护眼模式（夜间模式）"""
        # 移除护眼模式功能，因为当前实现不起效果
        return True
    
    def disable_eye_protection(self):
        """关闭护眼模式（夜间模式）"""
        # 移除护眼模式功能，因为当前实现不起效果
        return True
    
    def start_sleep_mode(self):
        """启动睡眠模式"""
        if self.is_active:
            return "睡眠模式已开启"
        
        # 记录原始状态
        # 使用BrightnessService获取当前亮度值
        self.original_brightness = BrightnessService.get_brightness()
        self.original_volume = self.get_volume()
        
        # 应用睡眠模式
        # 使用BrightnessService设置亮度为5%
        BrightnessService.set_brightness(5)
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
            # 使用BrightnessService恢复原始亮度
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