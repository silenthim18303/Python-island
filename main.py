#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
灵动岛风格时钟应用

该应用模拟苹果iOS的灵动岛设计，实现了一个悬停时展开、离开时收缩的时钟窗口。
主要功能：
1. 显示当前时间和日期
2. 鼠标悬停时自动展开，离开时自动收缩
3. 支持鼠标拖动窗口
4. 半透明效果和圆角设计

依赖：
- tkinter: 用于创建GUI界面
- time: 用于获取当前时间
- win32gui, win32con, win32api: 用于Windows窗口样式设置
"""

import tkinter as tk
import time
import win32gui
import win32con
import win32api


class DynamicIslandClock:
    """
    灵动岛时钟类
    实现了一个具有动画效果的时钟窗口，模拟iOS灵动岛的交互方式
    """

    def __init__(self):
        """
        初始化灵动岛时钟
        设置窗口属性、动画参数和初始状态
        """
        # 创建主窗口
        self.root = tk.Tk()
        self.root.title("灵动岛时钟")
        # 禁止窗口大小调整
        self.root.resizable(False, False)
        # 移除窗口边框
        self.root.overrideredirect(True)

        # 设置窗口大小
        self.screen_width = self.root.winfo_screenwidth()
        self.screen_height = self.root.winfo_screenheight()
        self.window_width = round(self.screen_width * 0.12)
        self.window_height = round(self.screen_height * 0.08)
        self.root.geometry(f"{self.window_width}x{self.window_height}")

        # 设置窗口属性：置顶、透明度、透明色
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.55)
        self.root.attributes("-transparentcolor", "#000000")

        # 动画参数
        self.is_expanded = False  # 是否展开状态
        self.target_y = -self.window_height  # 初始缩在上面，露6px
        self.current_y = self.target_y  # 当前Y坐标
        self.animation_speed = 3  # 动画速度
        self.hide_delay = 1200  # 隐藏延迟（毫秒）
        self.hover_timer = None  # 悬停计时器

        # 计算屏幕居中位置
        self.screen_width = self.root.winfo_screenwidth()
        self.center_x = (self.screen_width - self.window_width) // 2
        # 设置初始位置
        self.set_pos(self.current_y)

        # 拖动相关变量
        self.dragging = False
        # 绑定鼠标事件
        self.root.bind("<Button-1>", self.start_drag)
        self.root.bind("<B1-Motion>", self.do_drag)

        # 初始化界面
        self.setup_style()
        self.create_clock_widgets()
        # 设置窗口扩展样式
        self.root.after(100, self.set_window_ex_style)
        # 开始更新时钟
        self.update_clock()

        # 核心：每30毫秒检查鼠标距离 → 自动展开/缩回
        self.root.after(30, self.check_mouse_distance)

    def set_pos(self, y):
        """
        设置窗口位置

        Args:
            y: 窗口的Y坐标
        """
        self.root.geometry(f"{self.window_width}x{self.window_height}+{self.center_x}+{int(y)}")

    def expand(self):
        """
        展开窗口动画
        逐渐将窗口从收缩状态移动到完全展开状态
        """
        if self.current_y < 0:
            self.current_y += self.animation_speed
            # 确保不超过0（完全展开）
            if self.current_y > 0:
                self.current_y = 0
            # 更新位置
            self.set_pos(self.current_y)
            # 继续动画
            self.root.after(12, self.expand)
        else:
            # 动画结束，标记为展开状态
            self.is_expanded = True

    def shrink(self):
        """
        收缩窗口动画
        逐渐将窗口从展开状态移动到收缩状态
        """
        if self.current_y > self.target_y:
            self.current_y -= self.animation_speed
            # 确保不小于目标位置（完全收缩）
            if self.current_y < self.target_y:
                self.current_y = self.target_y
            # 更新位置
            self.set_pos(self.current_y)
            # 继续动画
            self.root.after(8, self.shrink)
        else:
            # 动画结束，标记为收缩状态
            self.is_expanded = False

    def check_mouse_distance(self):
        """
        检查鼠标与窗口的距离
        根据鼠标位置自动展开或收缩窗口
        """
        # 获取当前鼠标位置
        mx, my = win32api.GetCursorPos()

        # 判断鼠标是否在窗口附近
        near = (
                self.center_x < mx < self.center_x + self.window_width
                and my < 5  # 鼠标Y坐标小于80
        )

        if near:
            # 鼠标在附近，取消隐藏计时器并展开窗口
            if self.hover_timer:
                self.root.after_cancel(self.hover_timer)
                self.hover_timer = None
            self.expand()
        else:
            # 鼠标不在附近，如果窗口是展开状态且没有隐藏计时器，则设置隐藏计时器
            if self.is_expanded and not self.hover_timer:
                self.hover_timer = self.root.after(self.hide_delay, self.shrink)

        # 每100毫秒检查一次
        self.root.after(100, self.check_mouse_distance)

    def setup_style(self):
        """
        设置窗口样式
        创建画布并绘制圆角矩形背景
        """
        # 创建画布
        self.canvas = tk.Canvas(self.root, width=self.window_width, height=self.window_height,
                                bg="#000000", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        # 绘制圆角矩形背景
        self.canvas.create_rounded_rectangle(5, 5, self.window_width - 5, self.window_height - 5,
                                             radius=40, fill="#1E1E2E", outline="#383850", width=2)

    def create_clock_widgets(self):
        """
        创建时钟组件
        添加时间和日期标签
        """
        # 创建时间标签
        self.time_label = tk.Label(self.canvas, text="", font=("Microsoft YaHei UI", 24, "bold"),
                                   bg="#1E1E2E", fg="white")
        self.time_label.place(relx=0.5, rely=0.38, anchor="center")

        # 创建日期标签
        self.date_label = tk.Label(self.canvas, text="", font=("Arial", 10),
                                   bg="#1E1E2E", fg="#cccccc")
        self.date_label.place(relx=0.5, rely=0.68, anchor="center")

    def update_clock(self):
        """
        更新时钟显示
        每秒更新一次时间和日期
        """
        # 获取当前时间
        t = time.strftime("%H:%M:%S")
        # 获取当前日期
        d = time.strftime("%Y-%m-%d ")
        # 星期几映射字典
        w = {
            "Monday": "周一", "Tuesday": "周二", "Wednesday": "周三",
            "Thursday": "周四", "Friday": "周五", "Saturday": "周六", "Sunday": "周日"
        }[time.strftime("%A")]  # 根据英文星期获取中文星期
        # 更新时间标签
        self.time_label.config(text=t)
        # 更新日期标签
        self.date_label.config(text=d + w)
        # 每秒更新一次
        self.root.after(1000, self.update_clock)

    def set_window_ex_style(self):
        """
        设置窗口扩展样式
        使窗口具有分层、工具窗口和透明效果
        """
        try:
            # 查找窗口句柄
            hwnd = win32gui.FindWindow(None, "灵动岛时钟")
            if hwnd:
                # 获取窗口扩展样式
                ex = win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE)
                # 设置新的扩展样式
                win32gui.SetWindowLong(hwnd, win32con.GWL_EXSTYLE,
                                       ex | win32con.WS_EX_LAYERED | win32con.WS_EX_TOOLWINDOW | win32con.WS_EX_TRANSPARENT)
                # 设置分层窗口属性
                win32gui.SetLayeredWindowAttributes(hwnd, win32api.RGB(0, 0, 0), 255, win32con.LWA_COLORKEY)
        except:
            # 忽略异常
            pass

    def start_drag(self, event):
        """
        开始拖动窗口

        Args:
            event: 鼠标事件对象
        """
        # 记录鼠标点击位置
        self.dx = event.x
        self.dy = event.y
        # 标记为拖动状态
        self.dragging = True
        # 取消隐藏计时器
        if self.hover_timer:
            self.root.after_cancel(self.hover_timer)
            self.hover_timer = None
        # 展开窗口
        self.expand()

    def do_drag(self, event):
        """
        拖动窗口

        Args:
            event: 鼠标事件对象
        """
        # 计算新位置
        x = self.root.winfo_pointerx() - self.dx
        y = self.root.winfo_pointery() - self.dy
        # 更新中心X坐标和当前Y坐标
        self.center_x = x
        self.current_y = y
        # 设置新位置
        self.set_pos(y)


def create_rounded_rectangle(self, x1, y1, x2, y2, radius=25, **kwargs):
    """
    在Canvas上创建圆角矩形

    Args:
        x1, y1: 左上角坐标
        x2, y2: 右下角坐标
        radius: 圆角半径
        **kwargs: 其他参数

    Returns:
        圆角矩形的ID
    """
    # 计算圆角矩形的顶点坐标
    points = [x1 + radius, y1, x1 + radius, y1, x2 - radius, y1, x2 - radius, y1, x2, y1,
              x2, y1 + radius, x2, y1 + radius, x2, y2 - radius, x2, y2 - radius, x2, y2,
              x2 - radius, y2, x2 - radius, y2, x1 + radius, y2, x1 + radius, y2, x1, y2,
              x1, y2 - radius, x1, y2 - radius, x1, y1 + radius, x1, y1 + radius, x1, y1]
    # 创建多边形并返回ID
    return self.create_polygon(points, **kwargs, smooth=True)


# 为Canvas类添加create_rounded_rectangle方法
tk.Canvas.create_rounded_rectangle = create_rounded_rectangle

if __name__ == "__main__":
    """
    主函数
    创建并运行灵动岛时钟应用
    """
    # 创建应用实例
    app = DynamicIslandClock()
    # 启动主循环
    app.root.mainloop()