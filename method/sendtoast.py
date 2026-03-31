# 发送Windows系统通知的示例

# 首先需要安装win10toast库
# 命令: pip install win10toast

from win10toast import ToastNotifier

# 创建通知实例
toaster = ToastNotifier()

def send_notification():
    # 发送基本通知
    toaster.show_toast(
        "pyisland蟒蛇岛已启动",  # 通知标题
        "请检查桌面上方是否已经出现灵动岛",  # 通知内容
        duration=10,  # 通知显示时间（秒）
        icon_path=None,  # 图标路径，可选
        threaded=True  # 是否在后台线程中显示
    )

def send_notification2():
    # 发送带图标的通知
    toaster.show_toast(
        "带图标通知",
        "这是一条带有图标的通知",
        duration=5,
        icon_path="path/to/icon.ico"  # 替换为实际的图标路径
    )

send_notification2()

print("通知已发送")