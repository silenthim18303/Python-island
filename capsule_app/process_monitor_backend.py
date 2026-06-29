import threading
from PySide6.QtCore import QObject, Signal, QTimer


class ProcessMonitorBackend(QObject):
    """进程监控后端，检测eIsland相关进程是否运行，并推送给前端"""
    
    # 进程状态更新信号
    process_status_updated = Signal(bool)
    
    def __init__(self, web_view=None):
        super().__init__()
        self.web_view = web_view
        self.is_eisland_running = False
        self.scanning = False
        
        # 定时器，每30秒扫描一次进程列表
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self._start_scan_thread)
        self.refresh_timer.start(30000)  # 30秒刷新一次
        
        # 监听状态更新，推送至前端
        self.process_status_updated.connect(self._push_to_frontend)
        
        # 首次扫描，延迟3秒执行
        QTimer.singleShot(3000, self._start_scan_thread)
    
    def set_web_view(self, web_view):
        """设置web_view引用"""
        self.web_view = web_view
    
    def _start_scan_thread(self):
        """在独立线程中启动进程扫描，避免阻塞Qt主线程"""
        if self.scanning:
            return
        thread = threading.Thread(target=self._scan_processes, daemon=True)
        thread.start()
    
    def _scan_processes(self):
        """扫描系统进程，检查是否包含eIsland的进程"""
        self.scanning = True
        try:
            is_running = self._check_eisland_process()
            if is_running != self.is_eisland_running:
                self.is_eisland_running = is_running
                self.process_status_updated.emit(is_running)
                print(f"[ProcessMonitor] eIsland进程状态更新: {'运行中' if is_running else '未运行'}")
        except Exception as e:
            print(f"[ProcessMonitor] 扫描进程失败: {e}")
        finally:
            self.scanning = False
    
    def _check_eisland_process(self):
        """调用PowerShell检查是否存在包含eIsland的进程"""
        try:
            # 延迟导入模块
            import subprocess
            
            # PowerShell命令：获取所有进程名，检查是否包含eIsland（不区分大小写）
            powershell_command = """
            Get-Process | Where-Object { $_.Name -match 'eIsland|cisland' } | Select-Object -First 1 | ConvertTo-Json
            """
            # 在Windows上隐藏PowerShell窗口，避免弹出黑框
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
            
            result = subprocess.run(
                ["powershell", "-Command", powershell_command],
                capture_output=True,
                text=True,
                encoding='gbk',
                errors='replace',
                startupinfo=startupinfo
            )
            
            # 如果命令执行成功且有输出，说明进程存在
            if result.returncode == 0 and result.stdout and result.stdout.strip() and result.stdout.strip() != 'null':
                return True
            return False
            
        except Exception as e:
            print(f"[ProcessMonitor] 检查进程失败: {e}")
            return False
    
    def _push_to_frontend(self, is_running):
        """将进程状态推送给前端"""
        if self.web_view and self.web_view.page():
            try:
                js_code = f"window.handleEIslandStatusUpdate && window.handleEIslandStatusUpdate({str(is_running).lower()});"
                self.web_view.page().runJavaScript(js_code)
                print(f"[ProcessMonitor] 已将eIsland状态推送给前端: {is_running}")
            except Exception as e:
                print(f"[ProcessMonitor] 推送状态到前端失败: {e}")
    
    def stop(self):
        """停止后台任务"""
        self.refresh_timer.stop()
