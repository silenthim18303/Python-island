# 导入必要的库
import webview
import win32gui
import win32api
import win32con
import json
import threading
import time
import socket
import os
import bleak

# 全局变量
HWND = None
NOTIFY_ICON_ID = 1001
WINDOW_PROC = None
CONFIG = {
    "window_width": 280,
    "window_height": 100,
    "target_y": -90,
    "current_y": -90,
    "animation_speed": 2,
    "hide_delay": 1200,
    "center_x": 0,
    "is_expanded": False,
    "hover_timer": None,
    "dragging": False,
    "dx": 0,
    "dy": 0,
    "wifi_connected": False,
    "wifi_ssid": "",
    "wifi_timer": None,
    "bluetooth_connected": False,
    "bluetooth_device": "",
    "bluetooth_timer": None,
    "tray_icon": None
}


def get_screen_center_x(width):
    """获取屏幕水平居中的X坐标"""
    return (win32api.GetSystemMetrics(0) - width) // 2


def set_window_pos(x, y):
    """设置窗口位置"""
    if HWND:
        win32gui.SetWindowPos(
            HWND,
            win32con.HWND_TOPMOST,  # 置于最顶层
            x, y,
            CONFIG["window_width"], CONFIG["window_height"],
            win32con.SWP_NOACTIVATE
        )


def expand_window():
    """展开窗口动画"""
    if CONFIG["current_y"] < 0:
        CONFIG["current_y"] += CONFIG["animation_speed"]
        if CONFIG["current_y"] > 0:
            CONFIG["current_y"] = 0
        set_window_pos(CONFIG["center_x"], int(CONFIG["current_y"]))
        threading.Timer(0.012, expand_window).start()
    else:
        CONFIG["is_expanded"] = True


def shrink_window():
    """缩回窗口动画"""
    if CONFIG["current_y"] > CONFIG["target_y"]:
        CONFIG["current_y"] -= CONFIG["animation_speed"]
        if CONFIG["current_y"] < CONFIG["target_y"]:
            CONFIG["current_y"] = CONFIG["target_y"]
        set_window_pos(CONFIG["center_x"], int(CONFIG["current_y"]))
        threading.Timer(0.012, shrink_window).start()
    else:
        CONFIG["is_expanded"] = False


def check_mouse_distance():
    """检查鼠标位置，控制窗口展开/缩回"""
    while True:
        if not HWND:
            time.sleep(0.03)
            continue

        mx, my = win32api.GetCursorPos()
        near = (
            CONFIG["center_x"] < mx < CONFIG["center_x"] + CONFIG["window_width"]
            and my < 1
        )

        if near:
            if CONFIG["hover_timer"]:
                CONFIG["hover_timer"].cancel()
                CONFIG["hover_timer"] = None
            if not CONFIG["is_expanded"]:
                expand_window()
        else:
            if CONFIG["is_expanded"] and not CONFIG["hover_timer"]:
                CONFIG["hover_timer"] = threading.Timer(CONFIG["hide_delay"] / 1000, shrink_window)
                CONFIG["hover_timer"].start()

        time.sleep(0.03)


def create_tray_icon():
    """创建系统托盘图标"""
    global NOTIFY_ICON_ID
    
    try:
        NIF_ICON = 0x00000002
        NIF_MESSAGE = 0x00000001
        NIF_TIP = 0x00000004
        NIM_ADD = 0x00000000
        
        # 加载默认图标
        hicon = win32gui.LoadIcon(0, win32con.IDI_APPLICATION)
        
        if hicon:
            nid = (
                HWND,
                NOTIFY_ICON_ID,
                NIF_ICON | NIF_MESSAGE | NIF_TIP,
                win32con.WM_USER + 20,
                hicon,
                "灵动岛时钟"
            )
            
            win32gui.Shell_NotifyIcon(NIM_ADD, nid)
            CONFIG["tray_icon"] = nid
            
            # 设置窗口过程来处理托盘消息
            global WINDOW_PROC
            original_window_proc = win32gui.GetWindowLong(HWND, win32con.GWL_WNDPROC)
            
            def window_proc(hwnd, msg, wparam, lparam):
                if msg == win32con.WM_USER + 20:
                    if lparam == win32con.WM_RBUTTONUP:
                        show_tray_menu()
                return win32gui.CallWindowProc(original_window_proc, hwnd, msg, wparam, lparam)
            
            WINDOW_PROC = window_proc
            win32gui.SetWindowLong(HWND, win32con.GWL_WNDPROC, window_proc)
    except Exception as e:
        print(f"创建系统托盘图标失败: {e}")


def show_tray_menu():
    """显示系统托盘右键菜单"""
    try:
        menu = win32gui.CreatePopupMenu()
        MF_STRING = 0x00000000
        
        win32gui.AppendMenu(menu, MF_STRING, 1001, "退出")
        
        pos = win32api.GetCursorPos()
        win32gui.SetForegroundWindow(HWND)
        
        TPM_LEFTALIGN = 0x00000000
        TPM_LEFTBUTTON = 0x00000000
        TPM_BOTTOMALIGN = 0x00000020
        TPM_RETURNCMD = 0x00000100
        
        command = win32gui.TrackPopupMenu(
            menu,
            TPM_LEFTALIGN | TPM_LEFTBUTTON | TPM_BOTTOMALIGN | TPM_RETURNCMD,
            pos[0], pos[1],
            0, HWND, None
        )
        
        if command == 1001:
            destroy_tray_icon()
            if 'window' in globals():
                window.destroy()
            import sys
            sys.exit(0)
        
        win32gui.PostMessage(HWND, win32con.WM_NULL, 0, 0)
    except Exception as e:
        print(f"显示菜单失败: {e}")


def destroy_tray_icon():
    """销毁系统托盘图标"""
    if CONFIG["tray_icon"]:
        NIM_DELETE = 0x00000002
        win32gui.Shell_NotifyIcon(NIM_DELETE, CONFIG["tray_icon"])
        CONFIG["tray_icon"] = None


def set_window_style(hwnd):
    """设置Windows窗口样式"""
    # 去掉窗口边框
    style = win32gui.GetWindowLong(hwnd, win32con.GWL_STYLE)
    style &= ~(win32con.WS_CAPTION | win32con.WS_THICKFRAME | win32con.WS_SYSMENU)
    win32gui.SetWindowLong(hwnd, win32con.GWL_STYLE, style)

    # 设置扩展样式
    ex_style = win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE)
    ex_style |= win32con.WS_EX_LAYERED | win32con.WS_EX_TOOLWINDOW | win32con.WS_EX_TRANSPARENT
    ex_style &= ~win32con.WS_EX_APPWINDOW
    ex_style &= ~win32con.WS_EX_ACCEPTFILES
    win32gui.SetWindowLong(hwnd, win32con.GWL_EXSTYLE, ex_style)


def on_window_created(window):
    """窗口创建后的回调函数"""
    global HWND

    time.sleep(0.1)
    HWND = win32gui.FindWindow(None, "灵动岛时钟")

    if HWND:
        screen_width = win32api.GetSystemMetrics(0)
        CONFIG["center_x"] = (screen_width - CONFIG["window_width"]) // 2

        # 设置窗口初始位置（缩回状态）
        win32gui.SetWindowPos(
            HWND,
            win32con.HWND_TOPMOST,  # 置于最顶层
            CONFIG["center_x"], int(CONFIG["target_y"]),
            CONFIG["window_width"], CONFIG["window_height"],
            win32con.SWP_NOACTIVATE
        )

        # 设置窗口样式
        set_window_style(HWND)

        # 启动鼠标检测线程
        mouse_thread = threading.Thread(target=check_mouse_distance, daemon=True)
        mouse_thread.start()

        # 启动WiFi检测线程
        wifi_thread = threading.Thread(target=check_wifi_connection, args=(window,), daemon=True)
        wifi_thread.start()
        
        # 启动蓝牙检测线程
        bluetooth_thread = threading.Thread(target=check_bluetooth_connection, args=(window,), daemon=True)
        bluetooth_thread.start()
        
        # 创建系统托盘图标
        create_tray_icon()
        
        # 启动菜单命令处理线程
        def handle_menu_commands():
            while True:
                try:
                    win32gui.PumpWaitingMessages()
                    time.sleep(0.01)
                except:
                    break
        
        menu_thread = threading.Thread(target=handle_menu_commands, daemon=True)
        menu_thread.start()


def check_wifi_connection(window):
    """检查WiFi连接状态"""
    while True:
        is_connected = False
        ssid = "WiFi"

        try:
            # 检测网络连接
            socket.create_connection(("114.114.114.114", 53), timeout=2)
            is_connected = True

            # 获取WiFi名称
            import subprocess
            result_bytes = subprocess.check_output(["netsh", "wlan", "show", "interfaces"],
                                                  shell=True, stderr=subprocess.STDOUT)
            
            # 尝试UTF-8解码
            result = result_bytes.decode('utf-8', errors='ignore')
            
            # 查找SSID
            for line in result.split('\n'):
                line_lower = line.lower()
                if "ssid" in line_lower and "bssid" not in line_lower:
                    if ":" in line:
                        ssid = line.split(":")[1].strip()
                        break
                    elif "=" in line:
                        ssid = line.split("=")[1].strip()
                        break
        except:
            is_connected = False

        # 如果WiFi状态发生变化
        if is_connected != CONFIG["wifi_connected"]:
            CONFIG["wifi_connected"] = is_connected
            
            # 无论连接还是断开，都展开窗口显示通知
            if not CONFIG["is_expanded"]:
                expand_window()
                
            if is_connected:
                if window and hasattr(window, 'evaluate_js'):
                    window.evaluate_js(f"showWifiNotification('{ssid}')")
            else:
                if window and hasattr(window, 'evaluate_js'):
                    window.evaluate_js("showWifiNotification('WiFi已断开')")
            
            def auto_shrink():
                if CONFIG["is_expanded"]:
                    shrink_window()

            if CONFIG["wifi_timer"]:
                CONFIG["wifi_timer"].cancel()
            CONFIG["wifi_timer"] = threading.Timer(2.5, auto_shrink)
            CONFIG["wifi_timer"].start()

        time.sleep(3)


def check_bluetooth_connection(window):
    """检查蓝牙连接状态"""
    while True:
        is_bluetooth_on = False

        try:
            # 使用bleak库检测蓝牙状态
            import asyncio
            from bleak import BleakScanner
            
            async def check_bluetooth():
                try:
                    # 尝试扫描蓝牙设备
                    await BleakScanner.discover(timeout=1)
                    return True
                except Exception as e:
                    print(f"bleak扫描异常: {e}")
                    return False
            
            # 运行异步函数
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            is_bluetooth_on = loop.run_until_complete(check_bluetooth())
            loop.close()
            
        except Exception as e:
            # print(f"蓝牙检测异常: {e}")
            is_bluetooth_on = False

        # 打印调试信息
        # print(f"蓝牙检测: 蓝牙开启={is_bluetooth_on}, 配置状态={CONFIG['bluetooth_connected']}")

        # 如果蓝牙状态发生变化
        if is_bluetooth_on != CONFIG["bluetooth_connected"]:
            print(f"蓝牙状态变化: {CONFIG['bluetooth_connected']} -> {is_bluetooth_on}")
            CONFIG["bluetooth_connected"] = is_bluetooth_on
            
            # 无论连接还是断开，都展开窗口显示通知
            if not CONFIG["is_expanded"]:
                expand_window()
                
            if is_bluetooth_on:
                if window and hasattr(window, 'evaluate_js'):
                    # print("显示蓝牙开启通知")
                    window.evaluate_js("showBluetoothNotification('蓝牙已开启')")
            else:
                if window and hasattr(window, 'evaluate_js'):
                    # print("显示蓝牙关闭通知")
                    window.evaluate_js("showBluetoothNotification('蓝牙已断开')")
            
            def auto_shrink():
                if CONFIG["is_expanded"]:
                    shrink_window()

            if CONFIG["bluetooth_timer"]:
                CONFIG["bluetooth_timer"].cancel()
            CONFIG["bluetooth_timer"] = threading.Timer(2.5, auto_shrink)
            CONFIG["bluetooth_timer"].start()

        time.sleep(3)


# 主函数
if __name__ == "__main__":
    window = webview.create_window(
        title="灵动岛时钟",
        url="island.html",
        width=CONFIG["window_width"],
        height=CONFIG["window_height"],
        resizable=False,
        frameless=True,
        transparent=True
    )

    try:
        webview.start(on_window_created, window)
    finally:
        destroy_tray_icon()