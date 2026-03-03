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
import os

# 全局变量
# HWND: 窗口句柄，用于标识和操作窗口
# CONFIG: 配置参数字典，存储窗口相关设置
# NOTIFY_ICON_ID: 系统托盘图标ID
# WINDOW_PROC: 窗口过程函数
HWND = None
NOTIFY_ICON_ID = 1001
WINDOW_PROC = None
CONFIG = {
    "window_width": 280,  # 窗口宽度
    "window_height": 90,  # 窗口高度
    "target_y": -100,  # 初始缩回位置（只露6px）
    "current_y": -100,  # 当前窗口Y坐标
    "animation_speed": 2,  # 动画速度
    "hide_delay": 1200,  # 缩回延迟（毫秒）
    "center_x": 0,  # 窗口中心X坐标
    "is_expanded": False,  # 窗口是否展开
    "hover_timer": None,  # 鼠标离开后的定时器
    "dragging": False,  # 是否正在拖动
    "dx": 0,  # 拖动时的X偏移
    "dy": 0,  # 拖动时的Y偏移
    "wifi_connected": False,  # WiFi连接状态
    "wifi_ssid": "",  # 当前连接的WiFi名称
    "wifi_timer": None,  # WiFi提示后的自动收缩定时器
    "tray_icon": None  # 系统托盘图标
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
        # 5毫秒后再次调用本函数，实现动画效果
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


def create_tray_icon():
    """
    创建系统托盘图标
    """
    global NOTIFY_ICON_ID
    
    try:
        # 定义托盘图标常量
        NIF_ICON = 0x00000002
        NIF_MESSAGE = 0x00000001
        NIF_TIP = 0x00000004
        NIM_ADD = 0x00000000
        
        # 加载图标
        hicon = None
        try:
            # 尝试使用默认图标
            hicon = win32gui.LoadIcon(0, win32con.IDI_APPLICATION)
            print("使用默认系统图标")
        except Exception as e:
            print(f"加载默认图标失败: {e}")
        
        # 如果默认图标也加载失败，尝试其他方式
        if not hicon:
            try:
                # 尝试创建一个简单的图标
                hicon = win32gui.LoadIcon(0, 1)  # 使用第一个系统图标
                print("使用备用系统图标")
            except Exception as e:
                print(f"加载备用图标失败: {e}")
        
        # 只有当成功获取图标时才创建托盘图标
        if hicon:
            # 创建托盘图标数据结构
            nid = (
                HWND,
                NOTIFY_ICON_ID,
                NIF_ICON | NIF_MESSAGE | NIF_TIP,
                win32con.WM_USER + 20,
                hicon,
                "灵动岛时钟"
            )
            
            # 添加托盘图标
            win32gui.Shell_NotifyIcon(NIM_ADD, nid)
            
            # 设置托盘图标
            CONFIG["tray_icon"] = nid
            print("系统托盘图标创建成功")
            
            # 设置窗口过程来处理托盘消息
            global WINDOW_PROC
            original_window_proc = win32gui.GetWindowLong(HWND, win32con.GWL_WNDPROC)
            
            def window_proc(hwnd, msg, wparam, lparam):
                if msg == win32con.WM_USER + 20:
                    if lparam == win32con.WM_RBUTTONUP:
                        # 右键点击，显示菜单
                        show_tray_menu()
                    elif lparam == win32con.WM_LBUTTONDBLCLK:
                        # 左键双击，切换窗口显示
                        pass
                return win32gui.CallWindowProc(original_window_proc, hwnd, msg, wparam, lparam)
            
            WINDOW_PROC = window_proc
            win32gui.SetWindowLong(HWND, win32con.GWL_WNDPROC, window_proc)
        else:
            print("无法创建系统托盘图标，跳过")
    except Exception as e:
        print(f"创建系统托盘图标失败: {e}")
        # 即使托盘图标创建失败，也继续运行程序

def show_tray_menu():
    """
    显示系统托盘右键菜单
    """
    try:
        # 创建菜单
        menu = win32gui.CreatePopupMenu()
        
        # 添加退出菜单项
        # 使用 MF_STRING 标志
        MF_STRING = 0x00000000
        
        # 尝试使用不同的方式添加菜单项
        try:
            # 方法1：直接添加
            win32gui.AppendMenu(menu, MF_STRING, 1001, "exit")
        except:
            # 方法2：使用Unicode
            import ctypes
            from ctypes import wintypes
            
            # 定义AppendMenuW函数
            user32 = ctypes.windll.user32
            user32.AppendMenuW.argtypes = [wintypes.HMENU, wintypes.UINT, wintypes.UINT_PTR, wintypes.LPCWSTR]
            user32.AppendMenuW.restype = wintypes.BOOL
            
            # 使用Unicode字符串
            user32.AppendMenuW(menu, MF_STRING, 1001, "exit")
        
        # 获取鼠标位置
        pos = win32api.GetCursorPos()
        
        # 设置菜单显示位置
        win32gui.SetForegroundWindow(HWND)
        
        # 显示菜单
        TPM_LEFTALIGN = 0x00000000
        TPM_LEFTBUTTON = 0x00000000
        TPM_BOTTOMALIGN = 0x00000020
        TPM_RETURNCMD = 0x00000100
        
        # 显示菜单并获取选择的命令
        command = win32gui.TrackPopupMenu(
            menu,
            TPM_LEFTALIGN | TPM_LEFTBUTTON | TPM_BOTTOMALIGN | TPM_RETURNCMD,
            pos[0], pos[1],
            0, HWND, None
        )
        
        # 处理菜单命令
        if command:
            on_menu_command(command)
        
        # 发送消息以确保菜单能够正常关闭
        win32gui.PostMessage(HWND, win32con.WM_NULL, 0, 0)
    except Exception as e:
        print(f"显示菜单失败: {e}")
        import traceback
        traceback.print_exc()

def on_menu_command(command_id):
    """
    处理菜单命令
    """
    try:
        if command_id == 1001:
            # 退出应用
            import sys
            destroy_tray_icon()
            # 关闭webview窗口
            if 'window' in globals():
                window.destroy()
            sys.exit(0)
    except Exception as e:
        print(f"处理菜单命令失败: {e}")

def destroy_tray_icon():
    """
    销毁系统托盘图标
    """
    if CONFIG["tray_icon"]:
        NIM_DELETE = 0x00000002
        win32gui.Shell_NotifyIcon(NIM_DELETE, CONFIG["tray_icon"])
        CONFIG["tray_icon"] = None

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
    # WS_EX_TOOLWINDOW: 使窗口不在任务栏显示
    # WS_EX_LAYERED: 支持透明效果
    # WS_EX_TRANSPARENT: 使窗口透明
    ex_style |= win32con.WS_EX_LAYERED | win32con.WS_EX_TOOLWINDOW | win32con.WS_EX_TRANSPARENT
    # 确保窗口不在任务栏显示
    ex_style &= ~win32con.WS_EX_APPWINDOW
    # 禁用窗口的文件拖放功能
    ex_style &= ~win32con.WS_EX_ACCEPTFILES
    # 应用新扩展样式
    win32gui.SetWindowLong(hwnd, win32con.GWL_EXSTYLE, ex_style)
    
    # 3. 额外设置：确保窗口不在任务栏显示
    # 通过SetWindowPos再次确认窗口样式
    win32gui.SetWindowPos(
        hwnd,
        win32con.HWND_TOPMOST,
        0, 0, 0, 0,
        win32con.SWP_NOMOVE | win32con.SWP_NOSIZE | win32con.SWP_NOACTIVATE | win32con.SWP_HIDEWINDOW
    )
    # 立即显示窗口
    win32gui.SetWindowPos(
        hwnd,
        win32con.HWND_TOPMOST,
        CONFIG["center_x"], 0,
        CONFIG["window_width"], CONFIG["window_height"],
        win32con.SWP_SHOWWINDOW
    )

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
        
        # 创建系统托盘图标
        create_tray_icon()
        
        # 注册菜单命令处理
        def handle_menu_commands():
            """
            处理Windows消息的线程
            """
            while True:
                try:
                    # 处理Windows消息
                    win32gui.PumpWaitingMessages()
                    time.sleep(0.01)
                except:
                    break
        
        # 启动菜单命令处理线程
        menu_thread = threading.Thread(target=handle_menu_commands, daemon=True)
        menu_thread.start()


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
                # 执行命令获取WiFi接口信息（使用二进制模式）
                result_bytes = subprocess.check_output(["netsh", "wlan", "show", "interfaces"],
                                                      shell=True, 
                                                      stderr=subprocess.STDOUT)
                
                # 尝试多种编码解码
                encodings = ['utf-8', 'gbk', 'gb2312', 'ansi']
                result = None
                for encoding in encodings:
                    try:
                        result = result_bytes.decode(encoding)
                        break
                    except:
                        continue
                
                if result:
                    # 遍历输出行，查找SSID
                    ssid_found = False
                    for line in result.split('\n'):
                        # 尝试匹配不同语言环境下的SSID行
                        line_lower = line.lower()
                        if "ssid" in line_lower and "bssid" not in line_lower:
                            # 尝试多种分割方式
                            if ":" in line:
                                ssid = line.split(":")[1].strip()
                                ssid_found = True
                                break
                            elif "=" in line:
                                ssid = line.split("=")[1].strip()
                                ssid_found = True
                                break
                    
                    # 如果没有找到SSID，设置默认值
                    if not ssid_found:
                        ssid = "WiFi"
                else:
                    ssid = "WiFi"
            except Exception as e:
                # 捕获具体错误，便于调试
                print(f"获取WiFi SSID失败: {e}")
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
                # 创建新的定时器，2.5秒后收缩窗口
                CONFIG["wifi_timer"] = threading.Timer(2.5, auto_shrink)
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

    try:
        # 启动webview，窗口创建后执行on_window_created函数进行初始化
        webview.start(on_window_created, window)
    finally:
        # 程序退出时销毁系统托盘图标
        destroy_tray_icon()