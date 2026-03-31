# 发送Windows系统通知的模块

# 首先需要安装win10toast库
# 命令: pip install win10toast

from win10toast import ToastNotifier

# 创建通知实例
toaster = ToastNotifier()

def send_startup_notification():
    """发送启动通知"""
    # 发送基本通知
    toaster.show_toast(
        "pyisland蟒蛇岛已启动",  # 通知标题
        "请检查桌面上方是否已经出现灵动岛",  # 通知内容
        duration=10,  # 通知显示时间（秒）
        icon_path=None,  # 图标路径，可选
        threaded=True  # 是否在后台线程中显示
    )

def send_notification(title, message, duration=5, icon_path=None):
    """发送自定义通知
    
    Args:
        title (str): 通知标题
        message (str): 通知内容
        duration (int): 通知显示时间（秒）
        icon_path (str): 图标路径，可选
    """
    toaster.show_toast(
        title,
        message,
        duration=duration,
        icon_path=icon_path,
        threaded=True
    )