"""Qt配置初始化模块

设置Qt的环境变量，包括WebEngine和日志配置。
"""

import os


def init_qa():
    """初始化Qt环境变量配置。"""
    os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = (
        "--enable-gpu-rasterization "
        "--ignore-gpu-blocklist "
        "--enable-zero-copy "
        "--enable-native-gpu-memory-buffers "
        "--enable-accelerated-video-decode "
        "--disable-gpu-driver-bug-workarounds"
    )
    os.environ["QT_LOGGING_RULES"] = "*.debug=false;*.warning=false;*.critical=false"
    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
