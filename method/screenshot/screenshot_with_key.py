import tkinter as tk
from PIL import Image, ImageTk
import mss
# import pytesseract
import keyboard
import time
import win32clipboard
from io import BytesIO
from rich import print as rprint


class ScreenshotOCR:
    def __init__(self):
        self.root = None
        self.canvas = None
        self.full_img = None          # 原始全屏截图
        self.bg_photo = None          # 背景图像（变暗后）
        self.patch_photo = None        # 当前选区的截图（用于预览）
        self.start_x = 0
        self.start_y = 0
        self.rect_id = None            # 选区矩形画布 ID
        self.patch_id = None           # 预览图像画布 ID

    def run(self):
        # for test
        # rprint("[INFO] START")
        # rprint(" - CAPTURE KEY: Ctrl + Shift + S")
        # rprint(" - CANCEL: ESC")
        while True:
            try:
                keyboard.wait("ctrl + shift + z")
                self.capture_and_overlay()
                time.sleep(0.3)
            except KeyboardInterrupt:
                # rprint("[INFO] EXIT")
                break
            except Exception as _e:
                # rprint(f"[ERR ] Unexpected Error: {_e}")
                time.sleep(1)

    def capture_and_overlay(self):
        with mss.mss() as sct:
            monitor = sct.monitors[1]
            sct_img = sct.grab(monitor)
            self.full_img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")

        # rprint("[INFO] SWITCH TO CAPTURE MODE")
        self.show_overlay()

    def show_overlay(self):
        self.root = tk.Tk()
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.config(cursor="crosshair")

        self.canvas = tk.Canvas(self.root, highlightthickness=0, bg="black")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # 变暗背景
        dark_overlay = Image.new("RGB", self.full_img.size, (0, 0, 0))
        darkened_img = Image.blend(self.full_img, dark_overlay, alpha=0.4)
        self.bg_photo = ImageTk.PhotoImage(darkened_img)
        self.canvas.create_image(0, 0, image=self.bg_photo, anchor="nw")

        # 绑定事件
        self.canvas.bind("<Button-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("<Button-2>", lambda e: self.root.destroy())

        self.root.mainloop()

    def on_press(self, event):
        """鼠标按下：记录起始坐标"""
        self.start_x = event.x
        self.start_y = event.y

    def on_drag(self, event):
        """鼠标拖动：绘制矩形和预览选区"""
        # 删除之前绘制的图形
        if self.rect_id is not None:
            self.canvas.delete(self.rect_id)
        if self.patch_id is not None:
            self.canvas.delete(self.patch_id)

        x1 = min(self.start_x, event.x)
        y1 = min(self.start_y, event.y)
        x2 = max(self.start_x, event.x)
        y2 = max(self.start_y, event.y)

        # 绘制绿色矩形框
        self.rect_id = self.canvas.create_rectangle(x1, y1, x2, y2, outline="#00ff00", width=3)

        # 如果选区足够大，显示预览截图
        if x2 - x1 > 15 and y2 - y1 > 15:
            crop = self.full_img.crop((x1, y1, x2, y2))
            self.patch_photo = ImageTk.PhotoImage(crop)
            self.patch_id = self.canvas.create_image(x1, y1, image=self.patch_photo, anchor="nw")
        else:
            self.patch_photo = None

    def on_release(self, event):
        x1 = min(self.start_x, event.x)
        y1 = min(self.start_y, event.y)
        x2 = max(self.start_x, event.x)
        y2 = max(self.start_y, event.y)

        # 检查选区是否过小
        if x2 - x1 < 20 or y2 - y1 < 20:
            # rprint("[ERR ] Area So Small")
            self.root.destroy()
            return

        crop_img = self.full_img.crop((x1, y1, x2, y2))

        # rprint("[INFO] Screenshot Result")
        try:
            # text = pytesseract.image_to_string(crop_img, lang="chi_sim+eng")
            # rprint("<|TEXT_START|>")
            # text = text.strip() if text.strip() else "[WARN] No Text Capture"
            # rprint(text)
            self.to_clipboard(crop_img, "") # text)
            # rprint("<|TEXT_END|>")
        except Exception as _e:
            pass
            # rprint(f"[ERR ] SCREENSHOT ERROR: {_e}")

        self.root.destroy()

    @staticmethod
    def to_clipboard(image, text):

        win32clipboard.OpenClipboard()
        win32clipboard.EmptyClipboard()

        win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT, text)

        output = BytesIO()
        image.save(output, format='BMP')
        data = output.getvalue()[14:]
        output.close()
        win32clipboard.SetClipboardData(win32clipboard.CF_DIB, data)

        win32clipboard.CloseClipboard()