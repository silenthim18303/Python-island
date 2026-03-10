#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音量控制工具模块，用于控制Windows系统音量
"""

import win32api
import win32con
import win32com.client
import pythoncom

# 初始化音量控制变量
volume_initialized = False
volume_object = None
mute_state = False
current_volume = 0.5  # 默认音量50%

# 初始化音量控制

# 尝试使用pycaw库获取真实音量
volume_interface = None

try:
    # 初始化COM
    pythoncom.CoInitialize()
    
    # 尝试获取Core Audio API接口
    try:
        from ctypes import cast, POINTER
        from comtypes import CLSCTX_ALL
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        
        # 获取音频设备
        devices = AudioUtilities.GetSpeakers()
        
        # 获取音频端点（使用EndpointVolume属性）
        endpoint = devices.EndpointVolume
        
        # 获取实际音量和静音状态
        current_volume = endpoint.GetMasterVolumeLevelScalar()
        mute_state = endpoint.GetMute()
        
        print("音量控制初始化成功!")
        volume_initialized = True
    except Exception as e:
        # 如果Core Audio API失败，使用模拟按键方式
        print(f"使用Core Audio API获取音量失败，将使用模拟按键方式: {e}")
        shell = win32com.client.Dispatch("WScript.Shell")
        volume_object = shell
        volume_initialized = True

except Exception as e:
    print(f"初始化音量控制失败: {e}")
    volume_initialized = False
    volume_object = None

def get_volume():
    """
    获取当前系统音量 (0.0 - 1.0)
    """
    global current_volume
    
    # 尝试从Core Audio API获取实际音量
    try:
        from pycaw.pycaw import AudioUtilities
        
        # 获取音频设备和端点
        devices = AudioUtilities.GetSpeakers()
        endpoint = devices.EndpointVolume
        current_volume = endpoint.GetMasterVolumeLevelScalar()
    except Exception as e:
        # 如果获取失败，使用本地记录的音量
        pass
    
    return current_volume

def set_volume(level):
    """
    设置系统音量 (0.0 - 1.0)
    """
    global current_volume
    if not volume_initialized:
        return False
    try:
        # 确保音量在有效范围内
        level = max(0.0, min(1.0, level))
        
        # 计算需要增加或减少的步数
        steps = int(abs(level - current_volume) / 0.05) + 1
        
        if level > current_volume:
            for _ in range(steps):
                win32api.keybd_event(win32con.VK_VOLUME_UP, 0, 0, 0)
                win32api.keybd_event(win32con.VK_VOLUME_UP, 0, win32con.KEYEVENTF_KEYUP, 0)
        else:
            for _ in range(steps):
                win32api.keybd_event(win32con.VK_VOLUME_DOWN, 0, 0, 0)
                win32api.keybd_event(win32con.VK_VOLUME_DOWN, 0, win32con.KEYEVENTF_KEYUP, 0)
        
        current_volume = level
        return True
        
    except Exception as e:
        print(f"设置音量失败: {e}")
        return False

def increase_volume(step=0.05):
    """
    增加系统音量
    """
    global current_volume
    if not volume_initialized:
        return False
    try:
        new_volume = min(1.0, current_volume + step)
        
        # 使用模拟按键方式增加音量
        win32api.keybd_event(win32con.VK_VOLUME_UP, 0, 0, 0)
        win32api.keybd_event(win32con.VK_VOLUME_UP, 0, win32con.KEYEVENTF_KEYUP, 0)
        
        # 更新本地音量记录
        current_volume = new_volume
        return True
    except Exception as e:
        print(f"增加音量失败: {e}")
        return False

def decrease_volume(step=0.05):
    """
    减少系统音量
    """
    global current_volume
    if not volume_initialized:
        return False
    try:
        new_volume = max(0.0, current_volume - step)
        
        # 使用模拟按键方式减少音量
        win32api.keybd_event(win32con.VK_VOLUME_DOWN, 0, 0, 0)
        win32api.keybd_event(win32con.VK_VOLUME_DOWN, 0, win32con.KEYEVENTF_KEYUP, 0)
        
        # 更新本地音量记录
        current_volume = new_volume
        return True
    except Exception as e:
        print(f"减少音量失败: {e}")
        return False

def toggle_mute():
    """
    切换系统静音状态
    """
    global mute_state
    if not volume_initialized:
        return False
    try:
        # 使用模拟按键方式切换静音
        win32api.keybd_event(win32con.VK_VOLUME_MUTE, 0, 0, 0)
        win32api.keybd_event(win32con.VK_VOLUME_MUTE, 0, win32con.KEYEVENTF_KEYUP, 0)
        
        # 更新本地静音记录
        mute_state = not mute_state
        return True
    except Exception as e:
        print(f"切换静音失败: {e}")
        return False

def get_mute():
    """
    获取当前系统静音状态
    """
    global mute_state
    
    # 尝试从Core Audio API获取实际静音状态
    try:
        from pycaw.pycaw import AudioUtilities
        
        # 获取音频设备和端点
        devices = AudioUtilities.GetSpeakers()
        endpoint = devices.EndpointVolume
        mute_state = endpoint.GetMute()
    except Exception as e:
        # 如果获取失败，使用本地记录的静音状态
        pass
    
    return mute_state

def get_volume_percentage():
    """
    获取当前系统音量百分比 (0-100)
    """
    return int(get_volume() * 100)

def set_volume_percentage(percentage):
    """
    设置系统音量百分比 (0-100)
    """
    level = percentage / 100.0
    return set_volume(level)
