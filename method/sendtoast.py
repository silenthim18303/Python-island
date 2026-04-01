# 发送Windows系统通知的模块，兼容Win10/Win11

import logging
import sys
import os

_notifier = None
_notifier_type = None


def _is_windows_11():
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


_is_win11 = _is_windows_11()


def _init_notifier():
    global _notifier, _notifier_type
    if _notifier is not None:
        return

    if _is_win11:
        try:
            from win11toast import notify
            _notifier = notify
            _notifier_type = 'win11'
            logging.info("sendtoast: 使用 win11toast")
            return
        except Exception as e:
            logging.warning(f"sendtoast: win11toast 初始化失败: {e}")

    try:
        from win10toast import ToastNotifier
        _notifier = ToastNotifier()
        _notifier_type = 'win10'
        logging.info("sendtoast: 使用 win10toast")
    except Exception as e:
        _notifier = None
        _notifier_type = None
        logging.warning(f"sendtoast: win10toast 也初始化失败: {e}")


def send_startup_notification():
    """发送启动通知"""
    _init_notifier()
    if _notifier_type == 'win11':
        _notifier(
            title="pyisland蟒蛇岛已启动",
            body="请检查桌面上方是否已经出现灵动岛",
            duration='long',
            icon=_get_default_icon(),
        )
    elif _notifier_type == 'win10':
        _notifier.show_toast(
            "pyisland蟒蛇岛已启动",
            "请检查桌面上方是否已经出现灵动岛",
            duration=10,
            icon_path=_get_default_icon(),
            threaded=True
        )
    else:
        logging.warning("sendtoast: 未找到可用的通知库，通知未发送")


def send_notification(title, message, duration=5, icon_path=None):
    """发送自定义通知

    Args:
        title (str): 通知标题
        message (str): 通知内容
        duration (int): 通知显示时间（秒）
        icon_path (str): 图标路径，可选
    """
    _init_notifier()
    icon = icon_path if icon_path else _get_default_icon()
    dur = 'long' if duration >= 5 else 'short'

    if _notifier_type == 'win11':
        _notifier(
            title=title,
            body=message,
            duration=dur,
            icon=icon,
        )
    elif _notifier_type == 'win10':
        _notifier.show_toast(
            title,
            message,
            duration=duration,
            icon_path=icon,
            threaded=True
        )
    else:
        logging.warning("sendtoast: 未找到可用的通知库，通知未发送")


def _get_default_icon():
    """获取默认图标路径"""
    import sys
    if hasattr(sys, '_MEIPASS'):
        # 打包后的环境
        base = sys._MEIPASS
        ico = os.path.join(base, 'assets', 'public', 'icon', 'pyisland.ico')
        if os.path.exists(ico):
            return ico
        ico2 = os.path.join(base, 'assets', 'public', 'icon', 'pyisland_64x64.ico')
        if os.path.exists(ico2):
            return ico2
    else:
        # 开发环境
        base = os.path.dirname(os.path.abspath(__file__))
        ico = os.path.join(base, '..', 'assets', 'public', 'icon', 'pyisland.ico')
        if os.path.exists(ico):
            return ico
        ico2 = os.path.join(base, '..', 'assets', 'public', 'icon', 'pyisland_64x64.ico')
        if os.path.exists(ico2):
            return ico2
    return None