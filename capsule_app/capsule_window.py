from pathlib import Path

from PySide6.QtCore import QEasingCurve, QPoint, QPropertyAnimation, QTimer, Qt, QUrl
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QApplication, QMainWindow, QMenu, QSystemTrayIcon


PROJECT_ROOT = Path(__file__).resolve().parent.parent
WIDGET_HTML_PATH = PROJECT_ROOT / "widget.html"
ICON_CANDIDATES = [
    PROJECT_ROOT / "img" / "PyislandLogo.ico",
    PROJECT_ROOT / "img" / "PyislandLogo.png",
    PROJECT_ROOT / "img" / "PyislandLogo.svg",
]


class CapsuleWidget(QMainWindow):
    """
    胶囊状悬浮窗口组件。

    功能特性：
    - 无边框透明背景
    - 支持鼠标拖动
    - 自动边缘吸附
    - 空闲时减淡
    - 点击打开侧边面板
    """

    def __init__(self):
        super().__init__()
        self.drag_position = None
        self.edge_sensitivity = 5
        self.auto_hidden = False
        self.web_view = None
        self._web_engine_loaded = False
        self._idle_timer = None
        self._is_dimmed = False
        self._press_pos = None
        self._click_threshold = 3
        self._side_panel = None
        self._snap_anim = None
        self._tray_icon = None

        self._init_ui()
        self._init_system_tray()

    def _init_ui(self):
        """初始化用户界面。"""
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        app_icon = self._load_app_icon()
        if not app_icon.isNull():
            self.setWindowIcon(app_icon)

        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_height = screen_geo.height() // 8
        target_width = target_height // 4
        self.setFixedSize(target_width, target_height)

        self.center_window()
        self.snap_to_left_half_on_startup()
        QTimer.singleShot(0, self._init_web_engine)
        self._init_idle_timer()

    def _load_app_icon(self):
        """按优先级加载应用图标。"""
        for icon_path in ICON_CANDIDATES:
            if icon_path.exists():
                return QIcon(str(icon_path))
        return QIcon()

    def _init_system_tray(self):
        """初始化系统托盘图标与菜单。"""
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return

        self._tray_icon = QSystemTrayIcon(self)
        tray_icon = self.windowIcon()
        if tray_icon.isNull():
            tray_icon = self._load_app_icon()
        if not tray_icon.isNull():
            self._tray_icon.setIcon(tray_icon)

        self._tray_icon.setToolTip("Pyisland")

        tray_menu = QMenu(self)
        show_action = QAction("显示主界面", self)
        show_action.triggered.connect(self._show_from_tray)

        hide_action = QAction("隐藏主界面", self)
        hide_action.triggered.connect(self._hide_to_tray)

        exit_action = QAction("退出", self)
        exit_action.triggered.connect(self._exit_application)

        tray_menu.addAction(show_action)
        tray_menu.addAction(hide_action)
        tray_menu.addSeparator()
        tray_menu.addAction(exit_action)

        self._tray_icon.setContextMenu(tray_menu)
        self._tray_icon.activated.connect(self._on_tray_activated)
        self._tray_icon.show()

    def _on_tray_activated(self, reason):
        """双击或单击托盘图标时显示主界面。"""
        if reason not in (QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick):
            return
        self._show_from_tray()

    def _show_from_tray(self):
        """从系统托盘恢复主界面。"""
        self.show()
        self.raise_()
        self.activateWindow()

    def _hide_to_tray(self):
        """隐藏主界面和侧边面板，仅保留系统托盘。"""
        if self._side_panel is not None and self._side_panel.isVisible():
            self._side_panel.hide()
        self.hide()

    def _exit_application(self):
        """从系统托盘退出整个应用。"""
        if self._tray_icon is not None:
            self._tray_icon.hide()
        app = QApplication.instance()
        if app is not None:
            app.quit()

    def _init_idle_timer(self):
        """初始化空闲检测计时器。"""
        if self._idle_timer is None:
            self._idle_timer = QTimer(self)
            self._idle_timer.setSingleShot(True)
            self._idle_timer.setInterval(10000)
            self._idle_timer.timeout.connect(self._on_idle_timeout)
        self._idle_timer.start()

    def _reset_idle_timer(self):
        """有用户活动时重置空闲计时器。"""
        if self._is_dimmed:
            self._set_dim_state(False)
            self._is_dimmed = False
        if self._idle_timer is not None:
            self._idle_timer.start()

    def _on_idle_timeout(self):
        """空闲超时后将胶囊减淡。"""
        if not self._is_dimmed:
            self._set_dim_state(True)
            self._is_dimmed = True

    def _set_dim_state(self, dimmed):
        """调用前端 JS 设置减淡状态。"""
        if not self._web_engine_loaded or self.web_view is None:
            return
        js_code = "window.setCapsuleDim && window.setCapsuleDim(%s);" % ("true" if dimmed else "false")
        self.web_view.page().runJavaScript(js_code)

    def _init_web_engine(self):
        """延迟初始化 WebEngineView。"""
        if self._web_engine_loaded:
            return

        from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEngineSettings
        from PySide6.QtWebEngineWidgets import QWebEngineView

        self.web_view = QWebEngineView(self)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self.web_view.page().setBackgroundColor(Qt.transparent)
        self._configure_webengine_for_low_memory(QWebEngineProfile, QWebEngineSettings)
        self.setCentralWidget(self.web_view)
        self.web_view.resize(self.size())
        self.web_view.show()
        self.web_view.load(QUrl.fromLocalFile(str(WIDGET_HTML_PATH)))

        self._web_engine_loaded = True

    def _configure_webengine_for_low_memory(self, profile_cls, settings_cls):
        """关闭当前场景不需要的 WebEngine 功能，降低资源占用。"""
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

    def center_window(self):
        """将窗口居中显示。"""
        geometry = self.frameGeometry()
        center = QApplication.primaryScreen().availableGeometry().center()
        geometry.moveCenter(center)
        self.move(geometry.topLeft())

    def mousePressEvent(self, event):
        """处理鼠标按下事件。"""
        self._reset_idle_timer()
        if event.button() == Qt.LeftButton:
            global_pos = event.globalPosition().toPoint()
            self.drag_position = global_pos - self.frameGeometry().topLeft()
            self._press_pos = global_pos
            event.accept()

    def mouseMoveEvent(self, event):
        """处理鼠标移动事件，实现窗口拖动。"""
        self._reset_idle_timer()
        if event.buttons() == Qt.LeftButton and self.drag_position is not None:
            global_pos = event.globalPosition().toPoint()
            new_pos = global_pos - self.drag_position
            self.move(new_pos)
            event.accept()
            self.check_edge_snap()

    def mouseReleaseEvent(self, event):
        """处理鼠标释放事件。"""
        self._reset_idle_timer()
        if event.button() != Qt.LeftButton:
            return

        global_pos = event.globalPosition().toPoint()
        is_click = False
        if self._press_pos is not None:
            dx = global_pos.x() - self._press_pos.x()
            dy = global_pos.y() - self._press_pos.y()
            is_click = abs(dx) <= self._click_threshold and abs(dy) <= self._click_threshold
        self._press_pos = None

        screen_width = QApplication.primaryScreen().availableGeometry().width()
        current_x = self.x() + self.width()

        if current_x > screen_width * 0.4 or is_click:
            self.toggle_side_panel()

        self.auto_snap_to_edge()
        self.drag_position = None
        event.accept()

    def check_edge_snap(self):
        """拖动到左侧边缘时进入半隐藏状态。"""
        screen_left = QApplication.primaryScreen().availableGeometry().left()
        if self.x() <= screen_left + self.edge_sensitivity:
            target_x = int(screen_left - self.width() // 2)
            self.move(target_x, self.y())
            self.auto_hidden = True
        else:
            self.auto_hidden = False

    def auto_snap_to_edge(self):
        """自动吸附到左边缘。"""
        self.animate_to_left_half()
        self.auto_hidden = True

    def snap_to_left_half_on_startup(self):
        """启动时直接定位到左边缘半隐藏位置。"""
        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_x = screen_geo.left() - self.width() // 2
        self.move(target_x, self.y())

    def animate_to_left_half(self, y=None, duration=220):
        """平滑动画移动到左边缘半隐藏位置。"""
        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_x = int(screen_geo.left() - self.width() // 2)
        target_y = self.y() if y is None else y
        target_pos = QPoint(target_x, target_y)

        anim = QPropertyAnimation(self, b"pos", self)
        anim.setDuration(duration)
        anim.setEasingCurve(QEasingCurve.OutCubic)
        anim.setStartValue(self.pos())
        anim.setEndValue(target_pos)
        self._snap_anim = anim
        anim.start()

    def toggle_side_panel(self):
        """切换侧边面板显示状态。"""
        try:
            if self._side_panel is None:
                from capsule_app.side_panel_window import SidePanelWidget

                self._side_panel = SidePanelWidget()
                self._side_panel.destroyed.connect(self._clear_side_panel_reference)

            if self._side_panel.isVisible():
                self._side_panel.hide()
                return

            self._side_panel.show()
            self._side_panel.raise_()
            self._side_panel.activateWindow()
        except RuntimeError:
            self._side_panel = None
            self.toggle_side_panel()
        except Exception as exc:
            print(f"[toggle_side_panel] 切换侧边面板时出错: {exc}")
            self._side_panel = None

    def _clear_side_panel_reference(self, *_args):
        """侧边面板销毁后清空引用。"""
        self._side_panel = None

    def closeEvent(self, event):
        """关闭时清理托盘图标。"""
        if self._tray_icon is not None:
            self._tray_icon.hide()
        super().closeEvent(event)
