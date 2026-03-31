import os
import sys
import subprocess

# 项目根目录
project_root = os.path.dirname(os.path.abspath(__file__))

# 打包命令
cmd = [
    sys.executable,
    "-m", "PyInstaller",
    "--onefile",  # 生成单个可执行文件
    "--windowed",  # 不显示控制台窗口
    "--uac-admin",  # 添加UAC权限
    "--icon", os.path.join(project_root, "icon", "battery.png"),  # 使用电池图标
    "--add-data", f"{os.path.join(project_root, 'icon')};icon",  # 添加图标文件夹
    "--add-data", f"{os.path.join(project_root, 'island.html')};.",  # 添加HTML文件
    "--add-data", f"{os.path.join(project_root, 'method')};pyislandWeb/method",  # 添加方法文件夹
    "--name", "PyIsland",  # 可执行文件名称
    os.path.join(project_root, "pyisland2.py")  # 入口文件
]

print(f"执行打包命令: {' '.join(cmd)}")

# 执行打包命令
result = subprocess.run(cmd, cwd=project_root)

if result.returncode == 0:
    print("打包成功！")
    print(f"可执行文件路径: {os.path.join(project_root, 'dist', 'PyIsland.exe')}")
else:
    print("打包失败！")
    sys.exit(result.returncode)