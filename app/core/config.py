"""配置常量模块

定义应用中使用的各种配置常量，包括：
- 窗口尺寸配置
- 资源路径配置
- 定时器间隔配置
- 动画时长配置
"""

import sys
import os


def get_resource_path(relative_path: str) -> str:
    if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(base_path, relative_path)


# 窗口尺寸配置
COLLAPSED_WIDTH = 180
COLLAPSED_HEIGHT = 40
EXPANDED_WIDTH = 360
EXPANDED_HEIGHT = 160

# Hover 尺寸
HOVER_WIDTH = 300
HOVER_HEIGHT = 60

# 控件尺寸配置
CONTROLS_HEIGHT = 120
TIME_LABEL_HEIGHT = 40

# 图标和滑动条配置
ICON_SIZE = 20
SLIDER_WIDTH = 180
SLIDER_HEIGHT = 32

# 资源路径配置
STYLES_PATH = get_resource_path("resources/styles/style.qss")

# 定时器间隔配置（毫秒）
TIME_UPDATE_INTERVAL = 1000
STATUS_UPDATE_INTERVAL = 1000  # 减少到1秒，加快网络状态检测
CLIPBOARD_CHECK_INTERVAL = 1500
DEBOUNCE_DELAY = 180

# 延迟配置（毫秒）
URL_AUTO_CLOSE_DELAY = 5000
CONNECTION_AUTO_CLOSE_DELAY = 1000
NOTIFICATION_DISPLAY_TIME = 2000

# 动画时长配置（毫秒）
EXPAND_ANIMATION_DURATION = 200
COLLAPSE_ANIMATION_DURATION = 350
HEIGHT_CHANGE_ANIMATION_DURATION = 150
URL_EXPAND_ANIMATION_DURATION = 250
DRAG_IDLE_RETURN_DELAY = 1000

# 其他配置
MAX_EXPAND_HEIGHT_RATIO = 3
MAX_VISIBLE_URLS = 6
URL_ITEM_HEIGHT = 32
MULTI_URL_BTN_TOP_SPACING = 35

# 圆角半径配置
CORNER_RADIUS_MIN = 10
CORNER_RADIUS_MAX = 20

# 顶部吸附配置
SNAP_THRESHOLD = 40        # 距离屏幕顶部多少像素内触发吸附
VISIBLE_TOP_BORDER = 5     # 吸附后露出的顶部黑色边框高度（像素）
DOCK_ANIMATION_DURATION = 300