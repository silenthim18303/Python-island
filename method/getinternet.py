import socket
import time

class InternetChecker:
    def __init__(self):
        self.last_check_time = 0
        self.last_status = None
        self.debounce_time = 1  # 1秒防抖
    
    def check_internet(self):
        current_time = time.time()
        
        # 检查是否在防抖时间内
        if current_time - self.last_check_time < self.debounce_time and self.last_status is not None:
            return self.last_status
        
        try:
            # 连接到114DNS
            socket.create_connection(('114.114.114.114', 53), timeout=2)
            self.last_status = "已连接到互联网"
        except (socket.timeout, OSError):
            self.last_status = "未连接到互联网"
        
        self.last_check_time = current_time
        return self.last_status

if __name__ == "__main__":
    checker = InternetChecker()
    print(checker.check_internet())