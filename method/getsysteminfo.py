import psutil


class SystemInfoChecker:
    def check_cpu(self):
        """获取CPU使用率

        Returns:
            float: CPU使用率百分比
        """
        try:
            return psutil.cpu_percent(interval=0.1)
        except Exception:
            return 0.0

    def check_memory(self):
        """获取内存使用情况

        Returns:
            tuple: (used, total, percent)
                used: 已使用内存（MB）
                total: 总内存（MB）
                percent: 内存使用率百分比
        """
        try:
            memory = psutil.virtual_memory()
            used = memory.used / (1024 * 1024)  # 转换为MB
            total = memory.total / (1024 * 1024)  # 转换为MB
            percent = memory.percent
            return used, total, percent
        except Exception:
            return 0.0, 0.0, 0.0