import sys
import threading
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication


PROJECT_ROOT = Path(__file__).resolve().parent.parent
APP_ICON_CANDIDATES = [
    PROJECT_ROOT / "img" / "PyislandLogo.ico",
    PROJECT_ROOT / "img" / "PyislandLogo.png",
    PROJECT_ROOT / "img" / "PyislandLogo.svg",
]


def _show_toast(title, message, duration=3):
    """显示系统 Toast 通知。"""
    icon_path = None
    for candidate in APP_ICON_CANDIDATES:
        if candidate.suffix.lower() == ".ico" and candidate.exists():
            icon_path = str(candidate)
            break

    try:
        from win11toast import toast

        toast(title, message, icon=icon_path or "")
        print(f"[Toast] 已通过 win11toast 发送通知: {title} - {message} (图标: {icon_path or '无'})")
        return
    except ImportError:
        pass
    except Exception as e:
        print(f"[Toast] win11toast 发送失败: {e}")

    try:
        from win10toast import ToastNotifier

        toaster = ToastNotifier()
        toaster.show_toast(
            title,
            message,
            icon_path=icon_path,
            duration=duration,
            threaded=True,
        )
        print(f"[Toast] 已通过 win10toast 发送通知: {title} - {message} (图标: {icon_path or '无'})")
    except ImportError:
        print(f"[Toast] 未安装 win11toast / win10toast，跳过通知: {message}")
    except Exception as e:
        print(f"[Toast] win10toast 发送失败: {e}")


def _load_app_icon():
    for icon_path in APP_ICON_CANDIDATES:
        if icon_path.exists():
            return QIcon(str(icon_path))
    return QIcon()


def run():
    from capsule_app.capsule_window import CapsuleWidget

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setQuitOnLastWindowClosed(False)

    app_icon = _load_app_icon()
    if not app_icon.isNull():
        app.setWindowIcon(app_icon)

    widget = CapsuleWidget()
    widget.show()

    # 延迟发送启动通知，避免窗口初始化冲突
    # 使用 threading.Thread 确保 toast 不会阻塞 Qt 主事件循环
    def show_toast_thread():
        _show_toast(
            "Pyisland_sideV",
            "Pyisland_sideV正在启动，当屏幕左侧出现蓝色胶囊时，单击或拖动蓝色胶囊可打开侧边栏"
        )

    QTimer.singleShot(500, lambda: threading.Thread(target=show_toast_thread, daemon=True).start())

    return app.exec()
