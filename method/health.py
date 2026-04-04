import threading
import time
import os
import sys
from .sendtoast import send_notification


class HealthReminder:
    """健康提醒类，用于发送久坐提醒等健康相关通知"""
    
    def __init__(self):
        self.reminder_thread = None
        self.running = False
        self.sitting_reminder_interval = 45 * 60  # 45分钟，单位秒
        self.is_win11 = self._is_windows_11()
        self.sit_icon_path = self._get_sit_icon()
    
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
    
    def _get_sit_icon(self):
        """获取久坐提醒的图标路径"""
        if self.is_win11:
            # Windows 11 支持 PNG 图标
            if hasattr(sys, '_MEIPASS'):
                # 打包后的环境
                base = sys._MEIPASS
                icon = os.path.join(base, 'assets', 'image', 'sit.png')
                if os.path.exists(icon):
                    return icon
            else:
                # 开发环境
                base = os.path.dirname(os.path.abspath(__file__))
                icon = os.path.join(base, '..', 'assets', 'image', 'sit.png')
                if os.path.exists(icon):
                    return icon
        
        # Windows 10 或图标不存在时，使用默认 ICO 图标
        if hasattr(sys, '_MEIPASS'):
            # 打包后的环境
            base = sys._MEIPASS
            icon = os.path.join(base, 'assets',  'icon', 'pyisland_64x64.ico')
            if os.path.exists(icon):
                return icon
        else:
            # 开发环境
            base = os.path.dirname(os.path.abspath(__file__))
            icon = os.path.join(base, '..', 'assets',  'icon', 'pyisland_64x64.ico')
            if os.path.exists(icon):
                return icon
        return None
    
    def start_sitting_reminder(self):
        """开始久坐提醒"""
        if self.running:
            return
        
        self.running = True
        self.reminder_thread = threading.Thread(target=self._sitting_reminder_loop)
        self.reminder_thread.daemon = True
        self.reminder_thread.start()
    
    def stop_sitting_reminder(self):
        """停止久坐提醒"""
        self.running = False
        if self.reminder_thread:
            self.reminder_thread.join()
    
    def _sitting_reminder_loop(self):
        """久坐提醒循环"""
        while self.running:
            # 等待指定时间
            time.sleep(self.sitting_reminder_interval)
            
            if self.running:
                # 发送久坐提醒
                send_notification(
                    title="久坐提醒：",
                    message="您已经久坐45分钟了，建议站起来活动一下，缓解疲劳",
                    duration=5,
                    icon_path=self.sit_icon_path
                )


# 创建设计模式的单例实例
health_reminder = HealthReminder()


def start_health_reminders():
    """启动所有健康提醒"""
    health_reminder.start_sitting_reminder()


def stop_health_reminders():
    """停止所有健康提醒"""
    health_reminder.stop_sitting_reminder()