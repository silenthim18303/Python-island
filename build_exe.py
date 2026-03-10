#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
动态岛应用程序打包脚本
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def check_pyinstaller():
    """检查PyInstaller是否已安装"""
    try:
        import PyInstaller
        print("✅ PyInstaller 已安装")
        return True
    except ImportError:
        print("❌ PyInstaller 未安装，正在安装...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
            print("✅ PyInstaller 安装成功")
            return True
        except subprocess.CalledProcessError:
            print("❌ PyInstaller 安装失败")
            return False

def clean_build_folders():
    """清理构建文件夹"""
    folders_to_clean = ['build', 'dist', '__pycache__']
    
    for folder in folders_to_clean:
        if os.path.exists(folder):
            try:
                shutil.rmtree(folder)
                print(f"✅ 已清理文件夹: {folder}")
            except Exception as e:
                print(f"⚠️ 清理文件夹 {folder} 时出错: {e}")

def build_executable():
    """构建可执行文件"""
    print("🚀 开始构建动态岛应用程序...")
    
    # 使用PyInstaller构建
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "dynamic_island.spec",
        "--noconfirm",  # 不确认覆盖
        "--clean"  # 清理临时文件
    ]
    
    try:
        print("📦 正在打包应用程序...")
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.getcwd())
        
        if result.returncode == 0:
            print("✅ 应用程序打包成功!")
            
            # 检查生成的可执行文件
            exe_path = os.path.join("dist", "dynamic_island.exe")
            if os.path.exists(exe_path):
                file_size = os.path.getsize(exe_path) / (1024 * 1024)  # MB
                print(f"📁 生成的可执行文件: {exe_path}")
                print(f"📊 文件大小: {file_size:.2f} MB")
                return True
            else:
                print("❌ 未找到生成的可执行文件")
                return False
        else:
            print("❌ 打包失败!")
            print("错误信息:")
            print(result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ 打包过程中出现错误: {e}")
        return False

def create_standalone_folder():
    """创建独立的发布文件夹"""
    print("📂 创建独立发布文件夹...")
    
    release_folder = "DynamicIsland_Release"
    
    # 清理旧的发布文件夹
    if os.path.exists(release_folder):
        shutil.rmtree(release_folder)
    
    # 创建发布文件夹
    os.makedirs(release_folder)
    
    # 复制可执行文件
    exe_src = os.path.join("dist", "dynamic_island.exe")
    exe_dst = os.path.join(release_folder, "dynamic_island.exe")
    
    if os.path.exists(exe_src):
        shutil.copy2(exe_src, exe_dst)
        print("✅ 已复制可执行文件")
    
    # 复制资源文件夹
    folders_to_copy = ["images", "recordings"]
    
    for folder in folders_to_copy:
        src_path = folder
        dst_path = os.path.join(release_folder, folder)
        
        if os.path.exists(src_path):
            shutil.copytree(src_path, dst_path)
            print(f"✅ 已复制资源文件夹: {folder}")
    
    # 创建说明文件
    readme_content = """动态岛应用程序使用说明

功能特性:
- 悬浮窗口显示系统信息
- 手势识别控制
- 屏幕录制功能
- 音乐控制
- 音量调节
- 亮度控制

使用方法:
1. 双击运行 dynamic_island.exe
2. 右键点击悬浮窗口可打开功能菜单
3. 手势识别功能需要在菜单中手动开启

注意事项:
- 首次运行可能需要几秒钟初始化
- 手势识别需要摄像头支持
- 屏幕录制功能需要足够的磁盘空间


"""
    
    with open(os.path.join(release_folder, "使用说明.txt"), "w", encoding="utf-8") as f:
        f.write(readme_content)
    
    print("✅ 已创建使用说明文件")
    print(f"📁 发布文件夹已创建: {release_folder}")
    
    return release_folder

def main():
    """主函数"""
    print("=" * 50)
    print("应用程序打包工具")
    print("=" * 50)
    
    # 检查当前目录
    current_dir = os.getcwd()
    print(f"📁 当前工作目录: {current_dir}")
    
    # 检查主程序文件是否存在
    if not os.path.exists("dynamic_island.py"):
        print("❌ 未找到 dynamic_island.py 文件")
        return
    
    # 检查PyInstaller
    if not check_pyinstaller():
        return
    
    # 清理构建文件夹
    clean_build_folders()
    
    # 构建可执行文件
    if build_executable():
        # 创建独立发布文件夹
        release_folder = create_standalone_folder()
        
        print("\n🎉 打包完成!")
        print("=" * 50)
        print(f"📂 发布文件夹: {release_folder}")
        print("📋 包含内容:")
        print("  - dynamic_island.exe (主程序)")
        print("  - images/ (图片资源)")
        print("  - recordings/ (录制文件夹)")
        print("  - 使用说明.txt (使用说明)")
        print("=" * 50)
        print("💡 提示: 可以将整个发布文件夹复制到其他电脑上运行")
    else:
        print("\n❌ 打包失败，请检查错误信息")

if __name__ == "__main__":
    main()