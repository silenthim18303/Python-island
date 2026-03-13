"""Pyisland 应用核心包

此包包含灵动岛应用的核心功能模块：

模块结构：
- island.py：实现灵动岛主窗口，整合所有功能模块
- utils.py：提供系统API调用和辅助功能（保留向后兼容）
- core/：核心功能模块
  - worker.py：后台工作线程
  - config.py：配置常量
- ui/：UI组件模块
  - controls.py：控制面板组件
  - status_bar.py：状态栏组件
  - url_dialog.py：URL检测对话框组件
- services/：服务模块
  - clipboard.py：剪贴板服务
  - system_status.py：系统状态服务
  - brightness.py：亮度控制服务
- animations/：动画效果模块
  - effects.py：展开/收起动画

使用方式：
from app.island import ModernIsland
from app.services.clipboard import ClipboardService
from app.services.system_status import SystemStatusService
from app.services.brightness import BrightnessService
"""

from app.island import ModernIsland
from app.core import WorkerThread
from app.services.clipboard import ClipboardService
from app.services.system_status import SystemStatusService
from app.services.brightness import BrightnessService

__all__ = [
    'ModernIsland',
    'WorkerThread',
    'ClipboardService',
    'SystemStatusService',
    'BrightnessService',
]
