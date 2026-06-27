from capsule_app.main import run
from PySide6.QtCore import QLockFile, QDir
from capsule_app.main import show_toast
import sys

if __name__ == "__main__":
    # 使用 QLockFile 实现单实例应用
    lock_file_path = QDir.tempPath() + "/pyisland.lock"
    lock_file = QLockFile(lock_file_path)

    if not lock_file.tryLock(100):
        # 如果无法锁定文件，说明已有实例在运行
        show_toast("PyIsland 已经在运行了", "请勿重复启动")
        sys.exit(0)  # 退出当前实例
    
    # 如果锁定成功，则正常运行应用
    raise SystemExit(run())
