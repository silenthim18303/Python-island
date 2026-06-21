import json
from pathlib import Path

from PySide6.QtCore import QTimer, Qt, QUrl
from PySide6.QtGui import QColor
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QApplication, QMainWindow

from capsule_app.file_transfer_backend import FileTransferBackend


PROJECT_ROOT = Path(__file__).resolve().parent.parent
FRONTEND_DIST_INDEX = PROJECT_ROOT / "pyisland_sideV" / "dist" / "index.html"


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
            self.on_files_dropped(local_paths)


class SidePanelWidget(QMainWindow):
    """侧边面板窗口，负责加载前端界面和本地持久化存储。"""

    def __init__(self):
        super().__init__()
        self.storage_dir = Path.home() / "pyisland_side"
        self.storage_dir.mkdir(parents=True, exist_ok=True)

        self.web_view = None
        self.web_profile = None
        self.web_page = None
        self.web_channel = None
        self.file_transfer_backend = None

        self._init_window()
        self._init_web_engine()

    def _init_window(self):
        """初始化窗口属性和尺寸位置。"""
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        # 确保窗口显示在最前面
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
        from PySide6.QtWebChannel import QWebChannel
        from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineProfile, QWebEngineSettings

        self.web_view = SidePanelWebView(self._handle_native_file_drop, self)
        profile_dir = self.storage_dir / "webengine_profile"
        cache_dir = profile_dir / "cache"
        cache_dir.mkdir(parents=True, exist_ok=True)

        self.web_profile = QWebEngineProfile("pyisland_side_panel", self)
        self.web_profile.setPersistentStoragePath(str(profile_dir))
        self.web_profile.setCachePath(str(cache_dir))
        self.web_profile.setPersistentCookiesPolicy(QWebEngineProfile.ForcePersistentCookies)

        self.web_page = QWebEnginePage(self.web_profile, self.web_view)
        self.web_view.setPage(self.web_page)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self._configure_webengine_for_low_memory(QWebEngineProfile, QWebEngineSettings)
        self.web_view.page().setBackgroundColor(QColor(0, 0, 0, 0))
        self.setCentralWidget(self.web_view)
        self.web_view.resize(self.size())

        self.web_channel = QWebChannel(self.web_view.page())
        self.file_transfer_backend = FileTransferBackend(self)
        self.web_channel.registerObject("fileTransferBackend", self.file_transfer_backend)
        self.web_view.page().setWebChannel(self.web_channel)

        self.web_view.loadFinished.connect(self._play_frontend_entrance_animation)
        self.web_view.load(QUrl.fromLocalFile(str(FRONTEND_DIST_INDEX)))
        print(f"[SidePanelWidget] 使用本地持久化目录：{profile_dir}")
        print(f"[SidePanelWidget] 文件中转目录：{self.file_transfer_backend.transferDirectory()}")

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
