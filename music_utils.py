#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音乐获取工具模块，支持多种音乐播放器
"""

import win32gui
import win32process
import psutil
import re
import ctypes
from ctypes import wintypes
import time
import threading
from collections import deque

# 系统媒体控制API常量
GMCS_TITLE = 0x1
GMCS_ARTIST = 0x2
GMCS_ALBUMTITLE = 0x4
GMCS_ALBUMART = 0x8
GMCS_DURATION = 0x10
GMCS_ALL = GMCS_TITLE | GMCS_ARTIST | GMCS_ALBUMTITLE | GMCS_ALBUMART | GMCS_DURATION

# 支持的音乐播放器列表
SUPPORTED_PLAYERS = {
    "QQ音乐": {
        "process_name": "QQMusic.exe",
        "window_class": "OrpheusBrowserHost",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",  # 歌曲名 - 艺术家
            r"(.*?)\s+—\s+(.*?)", # 歌曲名 — 艺术家
        ]
    },
    "酷我音乐": {
        "process_name": "KuwoMusic.exe",
        "window_class": "kwplayer_main_window",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",
            r"(.*?)\s+—\s+(.*?)",
        ]
    },
    "网易云音乐": {
        "process_name": "cloudmusic.exe",
        "window_class": "OrpheusBrowserHost",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",
            r"(.*?)\s+—\s+(.*?)",
        ]
    },
    "汽水音乐": {
        "process_name": "QSMusic.exe",
        "window_class": "QSMainWindowClass",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",
            r"(.*?)\s+—\s+(.*?)",
        ]
    },
    "Spotify": {
        "process_name": "Spotify.exe",
        "window_class": "Chrome_WidgetWin_0",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",
            r"(.*?)\s+—\s+(.*?)",
        ]
    },
    "Windows Media Player": {
        "process_name": "wmplayer.exe",
        "window_class": "WMPlayerApp",
        "title_patterns": [
            r"(.*?)\s+-\s+(.*?)",
            r"(.*?)\s+—\s+(.*?)",
        ]
    },
    "系统媒体控制": {
        "process_name": "SystemMediaTransportControls",
        "window_class": "SystemMediaTransportControls",
        "title_patterns": []
    }
}

# 音乐信息缓存
music_cache = deque(maxlen=10)
cache_lock = threading.Lock()

class SystemMediaInfo:
    """系统媒体信息类"""
    
    def __init__(self):
        self.media_session_manager = None
        self._initialize_media_session()
    
    def _initialize_media_session(self):
        """初始化媒体会话管理器"""
        try:
            # 尝试使用Windows媒体控制API
            clsid = wintypes.GUID("{99B5C8F5-51F4-446B-A98B-F6A3A9C5D257}")
            iid = wintypes.GUID("{E93DCF6C-4B07-4E1E-8123-AA16EDC21C33}")
            
            # 创建媒体会话管理器
            ctypes.windll.ole32.CoInitialize(None)
            ctypes.windll.ole32.CoCreateInstance(
                ctypes.byref(clsid), None, 1, ctypes.byref(iid), ctypes.byref(self.media_session_manager)
            )
        except Exception:
            self.media_session_manager = None
    
    def get_system_media_info(self):
        """获取系统媒体信息"""
        if not self.media_session_manager:
            return None, None
        
        try:
            # 获取当前媒体会话
            session = ctypes.c_void_p()
            self.media_session_manager.GetCurrentSession(ctypes.byref(session))
            
            if not session:
                return None, None
            
            # 获取媒体信息
            media_info = ctypes.c_void_p()
            session.GetMediaProperties(ctypes.byref(media_info))
            
            if media_info:
                # 提取标题和艺术家
                title = ctypes.create_unicode_buffer(256)
                artist = ctypes.create_unicode_buffer(256)
                
                media_info.GetString(GMCS_TITLE, title, 256)
                media_info.GetString(GMCS_ARTIST, artist, 256)
                
                return title.value, artist.value
            
            return None, None
        except Exception:
            return None, None
    
    def __del__(self):
        if self.media_session_manager:
            self.media_session_manager.Release()
            ctypes.windll.ole32.CoUninitialize()

def get_active_window_info():
    """
    获取当前活动窗口的信息
    """
    try:
        hwnd = win32gui.GetForegroundWindow()
        window_text = win32gui.GetWindowText(hwnd)
        class_name = win32gui.GetClassName(hwnd)
        
        # 获取进程ID
        _, pid = win32process.GetWindowThreadProcessId(hwnd)
        
        try:
            process = psutil.Process(pid)
            process_name = process.name()
            return {
                "hwnd": hwnd,
                "window_text": window_text,
                "class_name": class_name,
                "pid": pid,
                "process_name": process_name
            }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return None
    except Exception:
        return None

def extract_music_info_from_window_title(title, player_name):
    """
    从窗口标题中提取音乐信息（智能解析）
    """
    if not title:
        return None, None
    
    # 去除播放器名称和无关字符
    title = title.replace(player_name, "").strip()
    
    # 去除常见的播放状态标识
    status_indicators = ["正在播放", "Playing", "▶", "⏸", "⏹", "▷"]
    for indicator in status_indicators:
        title = title.replace(indicator, "").strip()
    
    # 如果播放器有特定的标题模式，优先使用
    if player_name in SUPPORTED_PLAYERS and SUPPORTED_PLAYERS[player_name]["title_patterns"]:
        for pattern in SUPPORTED_PLAYERS[player_name]["title_patterns"]:
            match = re.match(pattern, title)
            if match:
                song = match.group(1).strip()
                artist = match.group(2).strip()
                
                # 验证提取的信息是否有效
                if song and len(song) > 1 and len(song) < 100:
                    return song, artist
    
    # 通用解析逻辑
    patterns = [
        # 格式1: 歌曲名 - 艺术家
        r"^(.*?)\s+[-–—]\s+(.*?)$",
        # 格式2: 艺术家 - 歌曲名
        r"^(.*?)\s+[-–—]\s+(.*?)$",
        # 格式3: 歌曲名 by 艺术家
        r"^(.*?)\s+by\s+(.*?)$",
        # 格式4: 歌曲名（艺术家）
        r"^(.*?)\s*[（(](.*?)[）)]$",
        # 格式5: 只有歌曲名
        r"^(.+)$"
    ]
    
    for pattern in patterns:
        match = re.match(pattern, title)
        if match:
            song = match.group(1).strip()
            artist = match.group(2).strip() if len(match.groups()) > 1 else ""
            
            # 验证提取的信息是否有效
            if song and len(song) > 1 and len(song) < 100:
                return song, artist
    
    # 如果所有模式都不匹配，返回整个标题作为歌曲名
    if len(title) > 1 and len(title) < 100:
        return title, ""
    
    return None, None

def get_current_playing_music():
    """
    获取当前正在播放的音乐信息（多方法尝试）
    """
    # 检查缓存中是否有有效的音乐信息
    with cache_lock:
        if music_cache:
            latest_info = music_cache[-1]
            # 如果缓存信息在5秒内，直接返回
            if time.time() - latest_info["timestamp"] < 5:
                return latest_info["song"], latest_info["artist"]
    
    # 方法1: 尝试系统媒体控制API（最可靠）
    try:
        system_media = SystemMediaInfo()
        song, artist = system_media.get_system_media_info()
        if song and artist:
            _update_cache(song, artist)
            return song, artist
    except Exception:
        pass
    
    # 方法2: 尝试窗口标题解析
    try:
        window_info = get_active_window_info()
        if window_info:
            window_text = window_info["window_text"]
            process_name = window_info["process_name"]
            class_name = window_info["class_name"]
            
            # 检查是否是支持的播放器
            for player_name, player_info in SUPPORTED_PLAYERS.items():
                if process_name == player_info["process_name"] or class_name == player_info["window_class"]:
                    # 从窗口标题中提取音乐信息
                    song, artist = extract_music_info_from_window_title(window_text, player_name)
                    
                    # 检查是否是有效的音乐信息
                    if _is_valid_music_info(song, artist, player_name):
                        _update_cache(song, artist)
                        return song, artist
    except Exception:
        pass
    
    # 方法3: 检查所有运行的音乐播放器
    try:
        running_players = get_all_running_players()
        for player_name in running_players:
            song, artist = get_music_from_specific_player(player_name)
            if _is_valid_music_info(song, artist, player_name):
                _update_cache(song, artist)
                return song, artist
    except Exception:
        pass
    
    return None, None

def _is_valid_music_info(song, artist, player_name):
    """验证音乐信息是否有效"""
    if not song:
        return False
    
    # 过滤掉播放器名称
    if song == player_name or song in player_name:
        return False
    
    # 检查长度是否合理
    if len(song) < 2 or len(song) > 100:
        return False
    
    # 检查是否包含常见的无效字符
    invalid_patterns = [r"^\s*$", r"^[\d\s\-\.]*$"]
    for pattern in invalid_patterns:
        if re.match(pattern, song):
            return False
    
    return True

def _update_cache(song, artist):
    """更新音乐信息缓存"""
    with cache_lock:
        music_cache.append({
            "song": song,
            "artist": artist,
            "timestamp": time.time()
        })

def get_all_running_players():
    """
    获取所有正在运行的支持的音乐播放器
    """
    running_players = []
    
    try:
        # 获取所有运行的进程
        processes = psutil.process_iter()
        
        for process in processes:
            try:
                process_name = process.name()
                
                # 检查是否是支持的播放器
                for player_name, player_info in SUPPORTED_PLAYERS.items():
                    if process_name == player_info["process_name"]:
                        running_players.append(player_name)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except Exception:
        pass
    
    return list(set(running_players))

def get_player_window_by_name(player_name):
    """
    根据播放器名称获取窗口句柄
    """
    if player_name not in SUPPORTED_PLAYERS:
        return None
    
    player_info = SUPPORTED_PLAYERS[player_name]
    target_process = player_info["process_name"]
    target_class = player_info["window_class"]
    
    hwnds = []
    
    def enum_windows_callback(hwnd, _):
        if win32gui.IsWindowVisible(hwnd):
            try:
                _, pid = win32process.GetWindowThreadProcessId(hwnd)
                process = psutil.Process(pid)
                if process.name() == target_process:
                    hwnds.append(hwnd)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return True
    
    win32gui.EnumWindows(enum_windows_callback, None)
    
    for hwnd in hwnds:
        if win32gui.GetClassName(hwnd) == target_class:
            return hwnd
    
    return hwnds[0] if hwnds else None

def get_music_from_specific_player(player_name):
    """
    从特定的音乐播放器获取当前播放的音乐
    """
    if player_name not in SUPPORTED_PLAYERS:
        return None, None
    
    hwnd = get_player_window_by_name(player_name)
    if not hwnd:
        return None, None
    
    window_text = win32gui.GetWindowText(hwnd)
    if not window_text:
        return None, None
    
    return extract_music_info_from_window_title(window_text, player_name)

def get_music_info_with_details():
    """
    获取详细的音乐信息，包括播放器名称
    """
    song, artist = get_current_playing_music()
    if not song:
        return None
    
    # 尝试确定播放器
    player_name = "未知播放器"
    
    # 方法1: 检查活动窗口
    window_info = get_active_window_info()
    if window_info:
        process_name = window_info["process_name"]
        for player, info in SUPPORTED_PLAYERS.items():
            if process_name == info["process_name"]:
                player_name = player
                break
    
    # 方法2: 检查运行中的播放器
    if player_name == "未知播放器":
        running_players = get_all_running_players()
        if running_players:
            player_name = running_players[0]
    
    return {
        "song": song,
        "artist": artist,
        "player": player_name,
        "timestamp": time.time()
    }

def get_music_history():
    """
    获取音乐播放历史
    """
    with cache_lock:
        return list(music_cache)

def is_music_playing():
    """
    检查是否有音乐正在播放
    """
    song, _ = get_current_playing_music()
    return song is not None

def get_playing_duration():
    """
    获取当前音乐已播放时长（基于缓存时间）
    """
    with cache_lock:
        if not music_cache:
            return 0
        
        latest_entry = music_cache[-1]
        return time.time() - latest_entry["timestamp"]

# 测试函数
def test_music_detection():
    """测试音乐检测功能"""
    print("🎵 测试音乐检测功能...")
    
    # 检查运行中的播放器
    running_players = get_all_running_players()
    print(f"运行中的播放器: {running_players}")
    
    # 获取当前播放的音乐
    music_info = get_music_info_with_details()
    if music_info:
        print(f"当前播放: {music_info['song']} - {music_info['artist']}")
        print(f"播放器: {music_info['player']}")
    else:
        print("未检测到正在播放的音乐")
    
    # 显示播放历史
    history = get_music_history()
    if history:
        print(f"播放历史 ({len(history)} 条):")
        for entry in history[-5:]:  # 显示最近5条
            print(f"  - {entry['song']} - {entry['artist']}")

if __name__ == "__main__":
    test_music_detection()
