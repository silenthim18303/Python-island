import json
import base64
import binascii
import mimetypes
import os
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

from PySide6.QtCore import QEasingCurve, QAbstractAnimation, QPoint, QPropertyAnimation, QThread, QTimer, Qt, QUrl, Signal
from PySide6.QtGui import QAction, QColor, QDesktopServices, QIcon, QKeySequence, QPalette, QShortcut
from PySide6.QtWebChannel import QWebChannel
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEngineSettings
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon, QVBoxLayout, QWidget

from app.bridge import CapsuleBridge
from app.native import apply_native_window_fixes


def _get_runtime_base_dir() -> Path:
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            return Path(meipass)
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


BASE_DIR = _get_runtime_base_dir()
HTML_FILE = BASE_DIR / "frontend" / "capsule.html"
TRAY_ICON_FILE = BASE_DIR / "img" / "pyisland.ico"
MAX_IMAGE_SIZE_BYTES = 50 * 1024 * 1024
VOSK_MODEL_DIR = BASE_DIR / "vosk" / "vosk-model-small-cn-0.22"


class CapsuleWebView(QWebEngineView):
    def __init__(self, on_files_dropped):
        super().__init__()
        self.on_files_dropped = on_files_dropped
        self.setAcceptDrops(True)

    def dropEvent(self, event):
        urls = event.mimeData().urls()
        local_paths = [url.toLocalFile() for url in urls if url.isLocalFile()]
        super().dropEvent(event)
        if local_paths:
            non_image_paths = []
            for path in local_paths:
                lower = path.lower()
                if lower.endswith((".png", ".jpg", ".jpeg", ".bmp", ".gif", ".webp")):
                    continue
                non_image_paths.append(path)

            if non_image_paths:
                self.on_files_dropped(non_image_paths)


class VoiceRecognitionWorker(QThread):
    result_ready = Signal(str)
    status_changed = Signal(str)
    error_occurred = Signal(str)

    def __init__(self, model_dir: Path):
        super().__init__()
        self.model_dir = model_dir

    def run(self):
        try:
            from vosk import KaldiRecognizer, Model
        except Exception as exc:
            self.error_occurred.emit(f"Vosk 加载失败: {exc}")
            return

        try:
            import pyaudio
        except Exception as exc:
            self.error_occurred.emit(f"PyAudio 加载失败: {exc}")
            return

        if not self.model_dir.exists():
            self.error_occurred.emit(f"未找到 Vosk 模型目录: {self.model_dir}")
            return

        self.status_changed.emit("listening")
        audio = None
        stream = None
        try:
            model = Model(str(self.model_dir))
            recognizer = KaldiRecognizer(model, 16000)

            audio = pyaudio.PyAudio()
            stream = audio.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=16000,
                input=True,
                frames_per_buffer=8000,
            )
            stream.start_stream()

            while not self.isInterruptionRequested():
                chunk = stream.read(4000, exception_on_overflow=False)
                if recognizer.AcceptWaveform(chunk):
                    payload = json.loads(recognizer.Result())
                    text = payload.get("text", "").strip()
                    if text:
                        self.result_ready.emit(text)
        except Exception as exc:
            self.error_occurred.emit(f"语音识别异常: {exc}")
        finally:
            try:
                if stream is not None:
                    stream.stop_stream()
                    stream.close()
            except Exception:
                pass

            try:
                if audio is not None:
                    audio.terminate()
            except Exception:
                pass

            self.status_changed.emit("stopped")

    def stop(self):
        self.requestInterruption()


class CapsuleWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.storage_dir = Path("C:/flash_capsule_temp")
        self.images_dir = self.storage_dir / "images"
        self.todo_text_file = self.storage_dir / "todos.txt"
        self.collapsed_width_ratio = 0.11
        self.collapsed_height_ratio = 0.065
        self.expanded_height_ratio = 0.62
        self.collapsed_size = (300, 78)
        self.expanded_size = (300, 560)
        self.expanded = False
        self._toggle_locked = False
        self.snap_distance = 24
        self._animation = QPropertyAnimation(self, b"geometry")
        self._animation.setDuration(260)
        self._animation.setEasingCurve(QEasingCurve.InOutCubic)
        self._animation.finished.connect(self._on_animation_finished)
        self._dragging = False
        self._drag_start_global = QPoint()
        self._drag_start_pos = QPoint()
        self._voice_worker = None

        self.setWindowTitle("速记胶囊")
        self.setWindowFlags(
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.NoDropShadowWindowHint | Qt.Tool
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_NoSystemBackground)

        self._recalculate_sizes()
        self._build_ui()
        self.resize(*self.collapsed_size)
        self._ensure_storage()
        self._init_tray_icon()
        self._start_cleanup_timer()
        self._register_shortcuts()

    def _init_tray_icon(self):
        self.tray_icon = QSystemTrayIcon(self)
        if TRAY_ICON_FILE.exists():
            self.tray_icon.setIcon(QIcon(str(TRAY_ICON_FILE)))

        self.tray_icon.setToolTip("速记胶囊")

        tray_menu = QMenu(self)
        show_action = QAction("显示", self)
        show_action.triggered.connect(self._show_from_tray)

        hide_action = QAction("隐藏", self)
        hide_action.triggered.connect(self.hide)

        self.startup_action = QAction("开机自启", self)
        self.startup_action.setCheckable(True)
        self.startup_action.setChecked(self._is_startup_enabled())
        self.startup_action.triggered.connect(self._toggle_startup)

        about_action = QAction("关于我们", self)
        about_action.triggered.connect(self._open_official_website)

        exit_action = QAction("退出", self)
        exit_action.triggered.connect(QApplication.instance().quit)

        tray_menu.addAction(show_action)
        tray_menu.addAction(hide_action)
        tray_menu.addAction(self.startup_action)
        tray_menu.addAction(about_action)
        tray_menu.addSeparator()
        tray_menu.addAction(exit_action)

        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.activated.connect(self._on_tray_activated)
        self.tray_icon.show()

    def _on_tray_activated(self, reason):
        if reason not in (QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick):
            return

        self._show_from_tray()

    def _show_from_tray(self):
        self.show()
        self.raise_()
        self.activateWindow()

    def _open_official_website(self):
        QDesktopServices.openUrl(QUrl("https://www.pyisland.com"))

    def _startup_command(self) -> str:
        if getattr(sys, "frozen", False):
            return f'"{sys.executable}"'

        project_root = Path(__file__).resolve().parent.parent
        main_file = project_root / "main.py"
        return f'"{sys.executable}" "{main_file}"'

    def _is_startup_enabled(self) -> bool:
        if sys.platform != "win32":
            return False

        try:
            import winreg

            with winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0,
                winreg.KEY_READ,
            ) as key:
                value, _ = winreg.QueryValueEx(key, "FlashCapsule")
                return value == self._startup_command()
        except Exception:
            return False

    def _set_startup_enabled(self, enabled: bool) -> bool:
        if sys.platform != "win32":
            return False

        try:
            import winreg

            with winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0,
                winreg.KEY_SET_VALUE,
            ) as key:
                if enabled:
                    winreg.SetValueEx(key, "FlashCapsule", 0, winreg.REG_SZ, self._startup_command())
                else:
                    try:
                        winreg.DeleteValue(key, "FlashCapsule")
                    except FileNotFoundError:
                        pass
            return True
        except Exception:
            return False

    def _toggle_startup(self, checked: bool):
        success = self._set_startup_enabled(checked)
        if not success:
            self.startup_action.blockSignals(True)
            self.startup_action.setChecked(self._is_startup_enabled())
            self.startup_action.blockSignals(False)

    def _register_shortcuts(self):
        self._voice_shortcut = QShortcut(QKeySequence("Ctrl+Alt+Y"), self)
        self._voice_shortcut.activated.connect(self._on_voice_shortcut)

    def _on_voice_shortcut(self):
        self.show()
        self.raise_()
        self.activateWindow()

        if self._animation.state() == QAbstractAnimation.Running:
            QTimer.singleShot(120, self._on_voice_shortcut)
            return

        if not self.expanded:
            self.toggle_expand()
            QTimer.singleShot(self._animation.duration() + 40, self._start_voice_after_expand)
            return

        self.start_voice_input()

    def _start_voice_after_expand(self):
        if self._animation.state() == QAbstractAnimation.Running:
            QTimer.singleShot(100, self._start_voice_after_expand)
            return
        if self.expanded:
            self.start_voice_input()

    def _ensure_storage(self):
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.images_dir.mkdir(parents=True, exist_ok=True)

    def _file_url(self, file_path: Path) -> str:
        return QUrl.fromLocalFile(str(file_path.resolve())).toString()

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

    def _persist_image_from_item(self, item: dict):
        file_name = item.get("file")
        if isinstance(file_name, str) and file_name:
            candidate = self.images_dir / file_name
            if candidate.exists():
                return file_name

        src = item.get("src")
        if not isinstance(src, str) or not src:
            return None

        if src.startswith("file://"):
            source_path = Path(QUrl(src).toLocalFile())
            if not source_path.exists() or not source_path.is_file():
                return None
            try:
                if source_path.stat().st_size > MAX_IMAGE_SIZE_BYTES:
                    return None
            except Exception:
                return None

            ext = source_path.suffix.lower() or ".png"
            file_name = f"{uuid.uuid4().hex}{ext}"
            target = self.images_dir / file_name
            try:
                shutil.copy2(source_path, target)
                return file_name
            except Exception:
                return None

        ext, raw = self._decode_data_url(src)
        if raw is None:
            return None

        file_name = f"{uuid.uuid4().hex}{ext}"
        target = self.images_dir / file_name
        target.write_bytes(raw)
        return file_name

    def _recalculate_sizes(self):
        screen = self.screen() or QApplication.primaryScreen()
        if screen is None:
            return

        work_area = screen.availableGeometry()
        screen_w = work_area.width()
        screen_h = work_area.height()

        collapsed_w = int(screen_w * self.collapsed_width_ratio)
        collapsed_h = int(screen_h * self.collapsed_height_ratio)
        expanded_h = int(screen_h * self.expanded_height_ratio)

        collapsed_w = max(180, min(collapsed_w, 360))
        collapsed_h = max(56, min(collapsed_h, 96))
        expanded_h = max(420, min(expanded_h, 900))

        expanded_w = collapsed_w
        self.collapsed_size = (collapsed_w, collapsed_h)
        self.expanded_size = (expanded_w, expanded_h)

    def _build_ui(self):
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        self.setStyleSheet("background: transparent;")

        self.web_view = CapsuleWebView(self._handle_native_file_drop)
        self.web_view.setUrl(QUrl.fromLocalFile(str(HTML_FILE.resolve())))
        self.web_view.setStyleSheet("background: transparent; border: none;")
        self.web_view.setContextMenuPolicy(Qt.NoContextMenu)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        self.web_view.setAttribute(Qt.WA_NoSystemBackground)
        self.web_view.page().setBackgroundColor(QColor(0, 0, 0, 0))
        palette = self.web_view.palette()
        palette.setColor(QPalette.Base, Qt.transparent)
        self.web_view.setPalette(palette)
        self._configure_webengine_for_low_memory()

        self.channel = QWebChannel(self.web_view.page())
        self.bridge = CapsuleBridge(self)
        self.channel.registerObject("capsuleBridge", self.bridge)
        self.web_view.page().setWebChannel(self.channel)

        root_layout.addWidget(self.web_view)

    def _configure_webengine_for_low_memory(self):
        page = self.web_view.page()
        profile = page.profile()

        profile.setHttpCacheType(QWebEngineProfile.NoCache)
        profile.setHttpCacheMaximumSize(0)
        profile.setPersistentCookiesPolicy(QWebEngineProfile.NoPersistentCookies)

        settings = self.web_view.settings()

        def set_attr(name: str, value: bool):
            attr = getattr(QWebEngineSettings, name, None)
            if attr is not None:
                settings.setAttribute(attr, value)

        set_attr("PluginsEnabled", False)
        set_attr("FullScreenSupportEnabled", False)
        set_attr("PdfViewerEnabled", False)
        set_attr("LocalStorageEnabled", False)
        set_attr("DnsPrefetchEnabled", False)
        set_attr("JavascriptCanOpenWindows", False)
        set_attr("JavascriptCanAccessClipboard", False)
        set_attr("JavascriptCanPaste", False)
        set_attr("HyperlinkAuditingEnabled", False)
        set_attr("ScrollAnimatorEnabled", False)
        set_attr("ErrorPageEnabled", False)
        set_attr("WebGLEnabled", False)
        set_attr("Accelerated2dCanvasEnabled", False)

    def _start_cleanup_timer(self):
        self._cleanup_timer = QTimer(self)
        self._cleanup_timer.setInterval(180000)
        self._cleanup_timer.timeout.connect(self._perform_periodic_cleanup)
        self._cleanup_timer.start()

    def _perform_periodic_cleanup(self):
        try:
            profile = self.web_view.page().profile()
            profile.clearHttpCache()
        except Exception:
            pass

        self._cleanup_preview_images()
        self.web_view.page().runJavaScript("window.cleanupCapsuleState && window.cleanupCapsuleState();")

    def _cleanup_preview_images(self):
        if not self.images_dir.exists():
            return

        expire_before = time.time() - 3600
        for image_path in self.images_dir.glob("preview_*"):
            try:
                if image_path.is_file() and image_path.stat().st_mtime < expire_before:
                    image_path.unlink(missing_ok=True)
            except Exception:
                pass

    def _handle_native_file_drop(self, local_paths):
        payload = json.dumps(local_paths, ensure_ascii=False)
        self.web_view.page().runJavaScript(
            f"window.handleNativeFileDrop && window.handleNativeFileDrop({payload});"
        )

    def _emit_voice_result(self, text: str):
        payload = json.dumps(text, ensure_ascii=False)
        self.web_view.page().runJavaScript(f"window.onVoiceResult && window.onVoiceResult({payload});")

    def _emit_voice_status(self, status: str):
        payload = json.dumps(status, ensure_ascii=False)
        self.web_view.page().runJavaScript(f"window.onVoiceStatus && window.onVoiceStatus({payload});")

    def _emit_voice_error(self, message: str):
        payload = json.dumps(message, ensure_ascii=False)
        self.web_view.page().runJavaScript(f"window.onVoiceError && window.onVoiceError({payload});")

    def _on_voice_worker_finished(self):
        self._voice_worker = None

    def start_voice_input(self) -> str:
        if self._voice_worker is not None and self._voice_worker.isRunning():
            return "already_running"

        worker = VoiceRecognitionWorker(VOSK_MODEL_DIR)
        worker.result_ready.connect(self._emit_voice_result)
        worker.status_changed.connect(self._emit_voice_status)
        worker.error_occurred.connect(self._emit_voice_error)
        worker.finished.connect(self._on_voice_worker_finished)
        self._voice_worker = worker
        worker.start()
        return "started"

    def stop_voice_input(self) -> None:
        if self._voice_worker is None:
            return

        self._voice_worker.stop()
        if self._voice_worker.isRunning():
            self._voice_worker.wait(1200)

    def closeEvent(self, event):
        if hasattr(self, "tray_icon"):
            self.tray_icon.hide()
        self.stop_voice_input()
        super().closeEvent(event)

    def _notify_frontend_state(self):
        expanded_js = "true" if self.expanded else "false"
        self.web_view.page().runJavaScript(f"window.setExpandedState && window.setExpandedState({expanded_js});")

    def toggle_expand(self):
        if self._toggle_locked or self._animation.state() == QAbstractAnimation.Running:
            return

        self._toggle_locked = True
        self._recalculate_sizes()
        self.expanded = not self.expanded
        target_size = self.expanded_size if self.expanded else self.collapsed_size
        self._notify_frontend_state()

        start_rect = self.geometry()
        end_rect = start_rect
        end_rect.setWidth(target_size[0])
        end_rect.setHeight(target_size[1])

        self._animation.stop()
        self._animation.setStartValue(start_rect)
        self._animation.setEndValue(end_rect)
        self._animation.start()

    def _on_animation_finished(self):
        self._toggle_locked = False

    def drag_start(self, screen_x, screen_y):
        if self.expanded:
            return
        self._dragging = True
        self._drag_start_global = QPoint(screen_x, screen_y)
        self._drag_start_pos = self.pos()

    def drag_move(self, screen_x, screen_y):
        if not self._dragging:
            return
        delta = QPoint(screen_x, screen_y) - self._drag_start_global
        self.move(self._drag_start_pos + delta)

    def drag_end(self):
        if not self._dragging:
            return
        self._dragging = False
        self._snap_to_screen_edge()

    def _snap_to_screen_edge(self):
        screen = self.screen() or QApplication.primaryScreen()
        if screen is None:
            return

        work_area = screen.availableGeometry()
        x = self.x()
        y = self.y()

        if abs(x - work_area.left()) <= self.snap_distance:
            x = work_area.left()
        elif abs((x + self.width()) - work_area.right()) <= self.snap_distance:
            x = work_area.right() - self.width()

        if abs(y - work_area.top()) <= self.snap_distance:
            y = work_area.top()
        elif abs((y + self.height()) - work_area.bottom()) <= self.snap_distance:
            y = work_area.bottom() - self.height()

        x = max(work_area.left(), min(x, work_area.right() - self.width()))
        y = max(work_area.top(), min(y, work_area.bottom() - self.height()))
        self.move(x, y)

    def showEvent(self, event):
        super().showEvent(event)
        QTimer.singleShot(0, lambda: apply_native_window_fixes(self))

    def load_todos_json(self) -> str:
        self._ensure_storage()
        if not self.todo_text_file.exists():
            return "[]"

        try:
            items = []
            for line in self.todo_text_file.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line:
                    continue

                entry = json.loads(line)
                if not isinstance(entry, dict):
                    continue

                if entry.get("type") == "text":
                    text = entry.get("text", "")
                    if isinstance(text, str):
                        items.append({"type": "text", "text": text})
                elif entry.get("type") == "image":
                    file_name = entry.get("file")
                    if not isinstance(file_name, str) or not file_name:
                        continue
                    image_path = self.images_dir / file_name
                    if image_path.exists():
                        items.append(
                            {
                                "type": "image",
                                "file": file_name,
                                "src": self._file_url(image_path),
                            }
                        )
                elif entry.get("type") == "file":
                    file_path = entry.get("path")
                    if isinstance(file_path, str) and file_path:
                        items.append({"type": "file", "path": file_path})

            return json.dumps(items, ensure_ascii=False)
        except Exception:
            pass

        return "[]"

    def save_todos_json(self, payload: str) -> None:
        self._ensure_storage()
        try:
            data = json.loads(payload)
            if not isinstance(data, list):
                return

            normalized = []
            used_files = set()

            for entry in data:
                if not isinstance(entry, dict):
                    continue

                if entry.get("type") == "text":
                    text = entry.get("text", "")
                    if isinstance(text, str):
                        normalized.append({"type": "text", "text": text})
                elif entry.get("type") == "image":
                    file_name = self._persist_image_from_item(entry)
                    if not file_name:
                        continue
                    used_files.add(file_name)
                    normalized.append({"type": "image", "file": file_name})
                elif entry.get("type") == "file":
                    file_path = entry.get("path")
                    if isinstance(file_path, str) and file_path:
                        normalized.append({"type": "file", "path": file_path})

            lines = [json.dumps(item, ensure_ascii=False) for item in normalized]
            self.todo_text_file.write_text("\n".join(lines), encoding="utf-8")

            for image_path in self.images_dir.iterdir():
                if image_path.is_file() and image_path.name not in used_files:
                    image_path.unlink(missing_ok=True)
        except Exception:
            pass

    def clear_todos(self) -> None:
        try:
            self.todo_text_file.unlink(missing_ok=True)
            for image_path in self.images_dir.iterdir():
                if image_path.is_file():
                    image_path.unlink(missing_ok=True)
        except Exception:
            pass

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
