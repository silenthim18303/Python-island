"""核心功能模块

此包包含灵动岛应用的核心功能组件：
- worker: 后台工作线程
- config: 配置常量
"""

from app.core.worker import WorkerThread
from app.core.config import *

__all__ = ['WorkerThread']
