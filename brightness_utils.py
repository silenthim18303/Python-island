#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
屏幕亮度控制工具模块，用于控制Windows系统屏幕亮度
"""

import pythoncom
pythoncom.CoInitialize()

# 初始化亮度控制变量
brightness_initialized = False
brightness_object = None
current_brightness = 50  # 默认亮度50%

# 初始化亮度控制
try:
    # 尝试使用wmi库获取真实亮度
    try:
        import wmi
        
        # 连接WMI服务
        c = wmi.WMI(namespace='wmi')
        
        # 获取亮度控制对象
        brightness_objects = c.WmiMonitorBrightnessMethods()
        
        if brightness_objects:
            brightness_object = brightness_objects[0]
            
            # 获取当前亮度
            brightness_info = c.WmiMonitorBrightness()[0]
            current_brightness = brightness_info.CurrentBrightness
            
            print("亮度控制初始化成功!")
            brightness_initialized = True
        else:
            print("未找到亮度控制对象")
            brightness_initialized = False
            
    except Exception as e:
        # 如果WMI失败，使用模拟方式
        print(f"使用WMI获取亮度失败，将使用模拟方式: {e}")
        brightness_initialized = True

except Exception as e:
    print(f"初始化亮度控制失败: {e}")
    brightness_initialized = False
    brightness_object = None

def get_brightness():
    """
    获取当前系统屏幕亮度 (0-100)
    """
    global current_brightness
    
    # 尝试从WMI获取实际亮度
    try:
        import wmi
        
        # 连接WMI服务
        c = wmi.WMI(namespace='wmi')
        
        # 获取亮度信息
        brightness_info = c.WmiMonitorBrightness()[0]
        current_brightness = brightness_info.CurrentBrightness
    except Exception as e:
        # 如果获取失败，使用本地记录的亮度
        pass
    
    return current_brightness

def set_brightness(level):
    """
    设置系统屏幕亮度 (0-100)
    """
    global current_brightness
    if not brightness_initialized:
        return False
    try:
        # 确保亮度在有效范围内
        level = max(0, min(100, level))
        
        # 尝试使用WMI设置亮度
        try:
            import wmi
            
            # 连接WMI服务
            c = wmi.WMI(namespace='wmi')
            
            # 获取亮度控制对象
            brightness_objects = c.WmiMonitorBrightnessMethods()
            
            if brightness_objects:
                # 设置亮度
                brightness_objects[0].WmiSetBrightness(level, 0)
                
                # 更新本地记录的亮度
                current_brightness = level
                return True
        except Exception as e:
            print(f"使用WMI设置亮度失败: {e}")
            
    except Exception as e:
        print(f"设置亮度失败: {e}")
        return False
    
    return False

def increase_brightness(step=10):
    """
    增加系统屏幕亮度
    """
    global current_brightness
    if not brightness_initialized:
        return False
    try:
        new_brightness = min(100, current_brightness + step)
        return set_brightness(new_brightness)
    except Exception as e:
        print(f"增加亮度失败: {e}")
        return False

def decrease_brightness(step=10):
    """
    减少系统屏幕亮度
    """
    global current_brightness
    if not brightness_initialized:
        return False
    try:
        new_brightness = max(0, current_brightness - step)
        return set_brightness(new_brightness)
    except Exception as e:
        print(f"减少亮度失败: {e}")
        return False