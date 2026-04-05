import os
import pyautogui
from datetime import datetime
import asyncio
import sys

try:
    from .sendtoast import send_notification
except ImportError:
    # 如果无法导入sendtoast模块，定义一个空函数
    def send_notification(title, message, duration=5, icon_path=None):
        pass

class ScreenshotManager:
    def __init__(self):
        self.is_win11 = self._is_windows_11()
        self.icon_path = self._get_icon_path()
    
    def _is_windows_11(self):
        """检查是否为Windows 11"""
        try:
            ver = sys.getwindowsversion()
            return ver.build >= 22000
        except AttributeError:
            import platform
            try:
                v = platform.version()
                parts = v.split('.')
                build = int(parts[2]) if len(parts) > 2 else 0
                return build >= 22000
            except Exception:
                return False
    
    def _get_icon_path(self):
        """获取通知图标路径"""
        if hasattr(sys, '_MEIPASS'):
            # 打包后的环境
            base = sys._MEIPASS
            icon = os.path.join(base, 'assets',  'image', 'screenshot.png')
            if os.path.exists(icon):
                return icon
        else:
            # 开发环境
            base = os.path.dirname(os.path.abspath(__file__))
            icon = os.path.join(base, '..', 'assets',  'image', 'screenshot.png')
            if os.path.exists(icon):
                return icon
        return None
    
    async def take_screenshot(self):
        """执行截图操作并保存
        
        Returns:
            str: 截图保存路径
        """
        try:
            # 指定保存文件夹
            save_dir = r"C:\pyislandpng"
            
            # 确保文件夹存在
            os.makedirs(save_dir, exist_ok=True)
            
            # 生成文件名
            filename = f"截图_{datetime.now():%Y%m%d_%H%M%S}.png"
            save_path = os.path.join(save_dir, filename)
            
            # 截图保存
            screenshot = pyautogui.screenshot()
            screenshot.save(save_path)
            
            # print("保存成功！路径：")
            # print(save_path)
            
            # 自动打开文件夹
            os.startfile(save_dir)
            
            # 发送成功通知
            send_notification(
                title="截图完成", 
                message=f"截图已保存到：{save_path}",
                icon_path=self.icon_path
            )
            
            return save_path
        except Exception as e:
            print(f"截图失败: {e}")
            # 发送失败通知
            send_notification(
                title="截图异常", 
                message=f"截图过程中出现错误：{str(e)}",
                icon_path=self.icon_path
            )
            return None

# 创建实例
screenshot_manager = ScreenshotManager()

async def take_screenshot():
    """执行截图操作并保存
    
    Returns:
        str: 截图保存路径
    """
    return await screenshot_manager.take_screenshot()

if __name__ == "__main__":
    asyncio.run(take_screenshot())