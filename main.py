# 导入必要的库
# webview: 创建GUI窗口
# win32gui, win32api, win32con: Windows API接口，用于操作窗口
# json: 用于处理JSON数据
# threading: 用于创建多线程
# time: 用于处理时间相关操作
import webview
import win32gui
import win32api
import win32con
import json
import threading
import time
import socket

# 全局变量
# HWND: 窗口句柄，用于标识和操作窗口
# CONFIG: 配置参数字典，存储窗口相关设置
HWND = None
CONFIG = {
    "window_width": 280,  # 窗口宽度
    "window_height": 90,  # 窗口高度
    "target_y": -100,  # 初始缩回位置（只露6px）
    "current_y": -100,  # 当前窗口Y坐标
    "animation_speed": 3,  # 动画速度
    "hide_delay": 1200,  # 缩回延迟（毫秒）
    "center_x": 0,  # 窗口中心X坐标
    "is_expanded": False,  # 窗口是否展开
    "hover_timer": None,  # 鼠标离开后的定时器
    "dragging": False,  # 是否正在拖动
    "dx": 0,  # 拖动时的X偏移
    "dy": 0,  # 拖动时的Y偏移
    "wifi_connected": False,  # WiFi连接状态
    "wifi_ssid": "",  # 当前连接的WiFi名称
    "wifi_timer": None  # WiFi提示后的自动收缩定时器
}


def get_screen_center_x(width):
    """
    获取屏幕水平居中的X坐标

    参数:
        width: 窗口宽度

    返回:
        屏幕水平居中的X坐标
    """
    # win32api.GetSystemMetrics(0) 获取屏幕宽度
    # 计算方法：(屏幕宽度 - 窗口宽度) // 2
    return (win32api.GetSystemMetrics(0) - width) // 2


def set_window_pos(x, y):
    """
    设置窗口位置

    参数:
        x: 窗口左上角X坐标
        y: 窗口左上角Y坐标
    """
    # 只有当窗口句柄存在时才设置位置
    if HWND:
        # win32gui.SetWindowPos 用于设置窗口位置和大小
        # 参数说明：
        # 1. 窗口句柄
        # 2. 窗口Z序（HWND_TOPMOST表示置顶）
        # 3-4. 窗口左上角坐标
        # 5-6. 窗口宽度和高度
        # 7. 附加标志（SWP_NOZORDER：保持Z序不变，SWP_NOACTIVATE：不激活窗口）
        win32gui.SetWindowPos(
            HWND,
            win32con.HWND_TOPMOST,
            x, y,
            CONFIG["window_width"], CONFIG["window_height"],
            win32con.SWP_NOZORDER | win32con.SWP_NOACTIVATE
        )


def expand_window():
    """
    展开窗口动画
    实现窗口从顶部逐渐滑出的效果
    """
    # 当窗口还未完全展开时（current_y < 0）
    if CONFIG["current_y"] < 0:
        # 增加current_y值，使窗口向下移动
        CONFIG["current_y"] += CONFIG["animation_speed"]
        # 确保窗口不会超出屏幕顶部
        if CONFIG["current_y"] > 0:
            CONFIG["current_y"] = 0
        # 更新窗口位置
        set_window_pos(CONFIG["center_x"], int(CONFIG["current_y"]))
        # 12毫秒后再次调用本函数，实现动画效果
        threading.Timer(0.012, expand_window).start()
    else:
        # 窗口完全展开后，设置is_expanded为True
        CONFIG["is_expanded"] = True


def shrink_window():
    """
    缩回窗口动画
    实现窗口逐渐滑入顶部的效果
    """
    # 当窗口还未完全缩回时（current_y > target_y）
    if CONFIG["current_y"] > CONFIG["target_y"]:
        # 减小current_y值，使窗口向上移动
        CONFIG["current_y"] -= CONFIG["animation_speed"]
        # 确保窗口不会超出目标位置
        if CONFIG["current_y"] < CONFIG["target_y"]:
            CONFIG["current_y"] = CONFIG["target_y"]
        # 更新窗口位置
        set_window_pos(CONFIG["center_x"], int(CONFIG["current_y"]))
        # 12毫秒后再次调用本函数，实现动画效果
        threading.Timer(0.012, shrink_window).start()
    else:
        # 窗口完全缩回后，设置is_expanded为False
        CONFIG["is_expanded"] = False


def check_mouse_distance():
    """
    检查鼠标位置，控制窗口展开/缩回
    当鼠标靠近窗口时展开，远离时延迟缩回
    """
    # 无限循环，持续检测鼠标位置
    while True:
        # 如果窗口句柄不存在，等待30毫秒后继续
        if not HWND:
            time.sleep(0.03)
            continue

        # 获取当前鼠标位置
        mx, my = win32api.GetCursorPos()

        # 判断鼠标是否在窗口上方区域
        # 条件：鼠标X坐标在窗口范围内，且Y坐标小于80（窗口上方区域）
        near = (
                CONFIG["center_x"] < mx < CONFIG["center_x"] + CONFIG["window_width"]
                and my < 1
        )

        if near:
            # 鼠标靠近窗口
            # 如果有缩回定时器，取消它
            if CONFIG["hover_timer"]:
                CONFIG["hover_timer"].cancel()
                CONFIG["hover_timer"] = None
            # 如果窗口未展开，执行展开动画
            if not CONFIG["is_expanded"]:
                expand_window()
        else:
            # 鼠标远离窗口
            # 如果窗口已展开且没有缩回定时器，创建一个延迟缩回定时器
            if CONFIG["is_expanded"] and not CONFIG["hover_timer"]:
                # 创建一个定时器，延迟hide_delay毫秒后执行缩回动画
                CONFIG["hover_timer"] = threading.Timer(CONFIG["hide_delay"] / 1000, shrink_window)
                CONFIG["hover_timer"].start()

        # 每30毫秒检查一次鼠标位置
        time.sleep(0.03)


def set_window_style(hwnd):
    """
    设置Windows窗口样式
    实现无边框、置顶、透明、禁止拖动等效果

    参数:
        hwnd: 窗口句柄
    """
    # 1. 去掉窗口边框
    # 获取当前窗口样式
    style = win32gui.GetWindowLong(hwnd, win32con.GWL_STYLE)
    # 移除标题栏、边框和系统菜单
    style &= ~(win32con.WS_CAPTION | win32con.WS_THICKFRAME | win32con.WS_SYSMENU)
    # 应用新样式
    win32gui.SetWindowLong(hwnd, win32con.GWL_STYLE, style)

    # 2. 设置扩展样式
    # 获取当前扩展样式
    ex_style = win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE)
    # 添加分层窗口、工具窗口和透明样式
    ex_style |= win32con.WS_EX_LAYERED | win32con.WS_EX_TOOLWINDOW | win32con.WS_EX_TRANSPARENT
    # 禁用窗口的文件拖放功能
    ex_style &= ~win32con.WS_EX_ACCEPTFILES
    # 应用新扩展样式
    win32gui.SetWindowLong(hwnd, win32con.GWL_EXSTYLE, ex_style)

    # 3. 强制固定窗口位置
    # 设置窗口位置和大小，同时禁止移动和调整大小
    win32gui.SetWindowPos(
        hwnd,
        win32con.HWND_TOPMOST,
        CONFIG["center_x"], 0,
        CONFIG["window_width"], CONFIG["window_height"],
        win32con.SWP_NOMOVE | win32con.SWP_NOSIZE | win32con.SWP_NOACTIVATE
    )

    # 4. 禁用窗口的鼠标拖动响应
    # 发送WM_SETFOCUS消息，设置焦点
    win32api.SendMessage(hwnd, win32con.WM_SETFOCUS, 0, 0)
    # 发送WM_NCHITTEST消息，禁用鼠标拖动
    win32api.SendMessage(hwnd, win32con.WM_NCHITTEST, 0, 0)


def on_window_created(window):
    """
    窗口创建后的回调函数
    初始化窗口位置、样式等

    参数:
        window: webview窗口对象
    """
    # 声明全局变量HWND
    global HWND

    # 延迟100ms获取句柄，解决webview窗口创建延迟问题
    time.sleep(0.1)

    # 通过窗口标题查找窗口句柄
    HWND = win32gui.FindWindow(None, "灵动岛时钟")

    if HWND:
        # 自动获取当前屏幕宽度，适配不同分辨率
        screen_width = win32api.GetSystemMetrics(0)  # 获取当前屏幕宽度
        # 计算窗口中心X坐标：(屏幕宽度 - 窗口宽度) // 2
        CONFIG["center_x"] = (screen_width - CONFIG["window_width"]) // 2  # 基于实际屏幕宽度计算
        target_y = 0  # 顶端Y坐标固定为0

        # 强制设置窗口位置（顶端中心）
        win32gui.SetWindowPos(
            HWND,
            win32con.HWND_TOPMOST,
            CONFIG["center_x"], target_y,
            CONFIG["window_width"], CONFIG["window_height"],
            win32con.SWP_NOZORDER | win32con.SWP_NOACTIVATE
        )

        # 设置窗口样式
        set_window_style(HWND)

        # 创建并启动鼠标检测线程，用于实现窗口展开/缩回的动画效果
        # daemon=True表示该线程为守护线程，主程序退出时自动退出
        mouse_thread = threading.Thread(target=check_mouse_distance, daemon=True)
        mouse_thread.start()

        # 创建并启动WiFi检测线程，用于检测WiFi连接状态
        wifi_thread = threading.Thread(target=check_wifi_connection, args=(window,), daemon=True)
        wifi_thread.start()


# 前端HTML文件路径
HTML_FILE = "island.html"


def check_wifi_connection(window):
    """
    检查WiFi连接状态
    当检测到WiFi连接时，展开窗口并显示连接提示

    参数:
        window: webview窗口对象
    """
    while True:
        # 检测网络连接
        is_connected = False
        ssid = ""

        try:
            # 尝试连接到114DNS服务器，超时2秒
            socket.create_connection(("114.114.114.114", 53), timeout=2)
            is_connected = True

            # 尝试获取WiFi名称（仅Windows系统）
            try:
                import subprocess
                result = subprocess.check_output(["netsh", "wlan", "show", "interfaces"],
                                                 shell=True, universal_newlines=True)
                for line in result.split('\n'):
                    if "SSID" in line and "BSSID" not in line:
                        ssid = line.split(":")[1].strip()
                        break
            except:
                ssid = "WiFi"

        except:
            is_connected = False

        # 如果WiFi状态发生变化
        if is_connected != CONFIG["wifi_connected"]:
            CONFIG["wifi_connected"] = is_connected
            if is_connected:
                # 连接成功，展开窗口并显示提示
                if not CONFIG["is_expanded"]:
                    expand_window()
                # 发送WiFi连接事件到前端
                if window and hasattr(window, 'evaluate_js'):
                    window.evaluate_js(f"showWifiNotification('{ssid}')")
                # 3秒后自动收缩窗口
                def auto_shrink():
                    if CONFIG["is_expanded"]:
                        shrink_window()

                # 取消之前的定时器（如果有）
                if CONFIG["wifi_timer"]:
                    CONFIG["wifi_timer"].cancel()
                # 创建新的定时器，3秒后收缩窗口
                CONFIG["wifi_timer"] = threading.Timer(3, auto_shrink)
                CONFIG["wifi_timer"].start()

        # 每3秒检查一次
        time.sleep(3)
# 主函数
if __name__ == "__main__":
    # 创建webview窗口
    # 参数说明：
    # title: 窗口标题
    # html: 窗口内容（HTML代码）
    # width: 窗口宽度
    # height: 窗口高度
    # resizable: 是否可调整大小
    # frameless: 是否无边框
    # transparent: 是否透明背景
    window = webview.create_window(
        title="灵动岛时钟",
        url=HTML_FILE,
        width=CONFIG["window_width"],
        height=CONFIG["window_height"],
        resizable=False,
        frameless=True,  # 无边框
        transparent=True  # 透明背景
    )

    # 启动webview，窗口创建后执行on_window_created函数进行初始化
    webview.start(on_window_created, window)