import json
import base64
import binascii
import mimetypes
import os
import shutil
import subprocess
import uuid
from pathlib import Path

from PySide6.QtCore import QTimer, Qt, QUrl
from PySide6.QtGui import QColor
from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineProfile, QWebEngineSettings
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QApplication, QMainWindow

# 导入蓝牙后端
from capsule_app.bluetooth_backend import BluetoothBackend
# 导入进程监控后端
from capsule_app.process_monitor_backend import ProcessMonitorBackend

PROJECT_ROOT = Path(__file__).resolve().parent.parent
FRONTEND_DIST_INDEX = PROJECT_ROOT / "pyisland_sideV" / "dist" / "index.html"
MAX_IMAGE_SIZE_BYTES = 50 * 1024 * 1024


class CustomWebEnginePage(QWebEnginePage):
    """自定义 WebEnginePage，用于拦截前端的自定义协议请求，实现极简通信。"""
    def __init__(self, profile, parent=None):
        super().__init__(profile, parent)
        self.window = parent

    def acceptNavigationRequest(self, url, _type, isMainFrame):
        scheme = url.scheme()
        if scheme == "pyisland":
            host = url.host()
            query = url.query()
            
            # 解析 query 参数 (例如: path=C:/test.txt)
            params = {}
            for pair in query.split('&'):
                if '=' in pair:
                    k, v = pair.split('=', 1)
                    params[k] = QUrl.fromPercentEncoding(v.encode('utf-8'))

            if host == "open_file":
                path = params.get("path")
                if path:
                    self.window.open_file_location(path)
            elif host == "open_image":
                src = params.get("src")
                if src:
                    self.window.open_image_source(src)
            elif host == "open_url":
                url_to_open = params.get("url")
                if url_to_open:
                    from PySide6.QtGui import QDesktopServices
                    QDesktopServices.openUrl(QUrl(url_to_open))
            
            # 拦截请求，不进行实际跳转
            return False
            
        return super().acceptNavigationRequest(url, _type, isMainFrame)


class SidePanelWebView(QWebEngineView):
    """支持原生文件拖拽的 WebView。"""

    def __init__(self, on_files_dropped, parent=None):
        super().__init__(parent)
        self.on_files_dropped = on_files_dropped
        self.setAcceptDrops(True)

    def dropEvent(self, event):
        urls = event.mimeData().urls()
        local_paths = [url.toLocalFile() for url in urls if url.isLocalFile()]
        super().dropEvent(event)
        if local_paths and self.on_files_dropped is not None:
            non_image_paths = []
            for path in local_paths:
                lower = path.lower()
                if lower.endswith((".png", ".jpg", ".jpeg", ".bmp", ".gif", ".webp")):
                    continue
                non_image_paths.append(path)

            if non_image_paths:
                self.on_files_dropped(non_image_paths)


class SidePanelWidget(QMainWindow):
    """侧边面板窗口，负责加载前端界面和本地持久化存储。"""

    def __init__(self):
        super().__init__()
        self.storage_dir = Path.home() / "pyisland_side"
        self.images_dir = self.storage_dir / "images"
        self.todo_text_file = self.storage_dir / "todos.txt"
        
        self._ensure_storage()

        self.web_view = None
        self.web_profile = None
        self.web_page = None

        self._init_window()
        self._init_web_engine()

    def _ensure_storage(self):
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.images_dir.mkdir(parents=True, exist_ok=True)

    def _init_window(self):
        """初始化窗口属性和尺寸位置。"""
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.raise_()
        self.activateWindow()

        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_width = int(screen_geo.width() * 0.25)
        target_height = int(screen_geo.height() * 0.9)
        self.setFixedSize(target_width, target_height)

        left_margin = int(screen_geo.width() * 0.01)
        target_x = screen_geo.left() + left_margin
        target_y = screen_geo.top() + (screen_geo.height() - target_height) // 2
        self.move(target_x, target_y)

    def _init_web_engine(self):
        """初始化 WebEngineView，并启用本地持久化存储。"""
        self.web_view = SidePanelWebView(self._handle_native_file_drop, self)
        profile_dir = self.storage_dir / "webengine_profile"
        cache_dir = profile_dir / "cache"
        cache_dir.mkdir(parents=True, exist_ok=True)

        self.web_profile = QWebEngineProfile("pyisland_side_panel", self)
        self.web_profile.setPersistentStoragePath(str(profile_dir))
        self.web_profile.setCachePath(str(cache_dir))
        self.web_profile.setPersistentCookiesPolicy(QWebEngineProfile.ForcePersistentCookies)

        # 使用自定义的 Page 类
        self.web_page = CustomWebEnginePage(self.web_profile, self)
        self.web_view.setPage(self.web_page)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self._configure_webengine_for_low_memory(QWebEngineProfile, QWebEngineSettings)
        self.web_view.page().setBackgroundColor(QColor(0, 0, 0, 0))
        self.setCentralWidget(self.web_view)
        self.web_view.resize(self.size())

        self.web_view.loadFinished.connect(self._on_web_view_load_finished)
        self.web_view.load(QUrl.fromLocalFile(str(FRONTEND_DIST_INDEX)))
        print(f"[SidePanelWidget] 使用本地持久化目录：{profile_dir}")
        
        # 初始化蓝牙后端
        self.bluetooth_backend = BluetoothBackend()
        # 初始化进程监控后端
        self.process_monitor = ProcessMonitorBackend()

    def _configure_webengine_for_low_memory(self, profile_cls, settings_cls):
        """关闭当前侧边栏不需要的 WebEngine 功能，降低资源占用。"""
        if self.web_view is None:
            return

        page = self.web_view.page()
        profile = page.profile()
        profile.setHttpCacheType(profile_cls.NoCache)
        profile.setHttpCacheMaximumSize(0)
        profile.setPersistentCookiesPolicy(profile_cls.NoPersistentCookies)

        settings = self.web_view.settings()

        def set_attr(name, value):
            attr = getattr(settings_cls, name, None)
            if attr is not None:
                settings.setAttribute(attr, value)

        set_attr("LocalStorageEnabled", True)
        set_attr("LocalContentCanAccessFileUrls", True)
        set_attr("LocalContentCanAccessRemoteUrls", True)
        set_attr("PluginsEnabled", False)
        set_attr("FullScreenSupportEnabled", False)
        set_attr("PdfViewerEnabled", False)
        set_attr("DnsPrefetchEnabled", False)
        set_attr("JavascriptCanOpenWindows", False)
        set_attr("JavascriptCanAccessClipboard", False)
        set_attr("JavascriptCanPaste", False)
        set_attr("HyperlinkAuditingEnabled", False)
        set_attr("ScrollAnimatorEnabled", False)
        set_attr("ErrorPageEnabled", False)
        set_attr("WebGLEnabled", False)
        set_attr("Accelerated2dCanvasEnabled", False)

    def showEvent(self, event):
        """窗口每次显示时重播前端入场动画。"""
        super().showEvent(event)
        QTimer.singleShot(0, self._play_frontend_entrance_animation)

    def hideEvent(self, event):
        """窗口隐藏后，让前端进入下一次入场动画的准备状态。"""
        super().hideEvent(event)
        QTimer.singleShot(0, self._prepare_frontend_entrance_animation)

    def _prepare_frontend_entrance_animation(self, *_args):
        """通知前端准备下一次入场动画。"""
        if self.web_view is None:
            return
        self.web_view.page().runJavaScript(
            "window.prepareEntranceAnimation && window.prepareEntranceAnimation();"
        )

    def _on_web_view_load_finished(self, success):
        """web_view加载完成后的回调"""
        if success:
            # 播放入场动画
            self._play_frontend_entrance_animation()
            # 给蓝牙后端设置web_view，开始推送数据
            self.bluetooth_backend.set_web_view(self.web_view)
            # 给进程监控后端设置web_view，开始推送状态
            self.process_monitor.set_web_view(self.web_view)
    
    def _play_frontend_entrance_animation(self, *_args):
        """通知前端播放入场动画。"""
        if self.web_view is None:
            return
        self.web_view.page().runJavaScript(
            "window.playEntranceAnimation && window.playEntranceAnimation();"
        )

    def _handle_native_file_drop(self, local_paths):
        """将桌面原生拖拽的本地路径转给前端。"""
        if self.web_view is None:
            return
        payload = json.dumps(local_paths, ensure_ascii=False)
        self.web_view.page().runJavaScript(
            f"window.handleNativeFileDrop && window.handleNativeFileDrop({payload});"
        )

    # --- 系统交互逻辑 ---

    def _decode_data_url(self, data_url: str):
        if not data_url.startswith("data:image/") or "," not in data_url:
            return None, None

        header, encoded = data_url.split(",", 1)
        if ";base64" not in header:
            return None, None

        mime = header.split(";")[0].replace("data:", "", 1)
        ext = mimetypes.guess_extension(mime) or ".png"
        if ext == ".jpe":
            ext = ".jpg"

        try:
            raw = base64.b64decode(encoded)
        except (ValueError, binascii.Error):
            return None, None

        if len(raw) > MAX_IMAGE_SIZE_BYTES:
            return None, None

        return ext, raw

    def open_image_source(self, source: str) -> None:
        if not source:
            return

        file_path = None

        if source.startswith("file://"):
            file_path = Path(QUrl(source).toLocalFile())
        elif source.startswith("data:image/"):
            ext, raw = self._decode_data_url(source)
            if raw is not None:
                file_name = f"preview_{uuid.uuid4().hex}{ext}"
                target = self.images_dir / file_name
                target.write_bytes(raw)
                file_path = target

        if file_path is None or not file_path.exists():
            return

        try:
            os.startfile(str(file_path))
        except Exception:
            pass

    def open_file_location(self, file_path: str) -> None:
        if not file_path:
            return

        normalized = file_path.strip().strip('"')
        if normalized.startswith("file://"):
            normalized = QUrl(normalized).toLocalFile()

        target = Path(normalized)
        if target.is_file():
            try:
                subprocess.Popen(["explorer", "/select,", str(target)])
            except Exception:
                pass
            return

        if target.is_dir():
            try:
                subprocess.Popen(["explorer", str(target)])
            except Exception:
                pass

    def closeEvent(self, event):
        """窗口关闭时清理资源"""
        if hasattr(self, 'bluetooth_backend'):
            self.bluetooth_backend.stop()
        if hasattr(self, 'process_monitor'):
            self.process_monitor.stop()
        super().closeEvent(event)
