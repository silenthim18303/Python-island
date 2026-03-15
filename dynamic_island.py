from PySide6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QApplication, QSystemTrayIcon, QMenu, QSlider, QPushButton, QFrame, QSizePolicy
from PySide6.QtCore import Qt, QSize, QPropertyAnimation, QEasingCurve, QRect, QTimer, Property, QPointF
from PySide6.QtGui import QPainter, QColor, QFont, QIcon, QAction, QCursor, QLinearGradient, QBrush, QPen, QRegion, QPainterPath
import sys
import webbrowser
import datetime
import random
from utils.win_utils import set_mouse_passthrough, unset_mouse_passthrough, set_blur
from utils.system_info import SystemMonitor
from utils.media_control import MediaMonitor
from utils.clipboard import ClipboardMonitor
from utils.hotkey import HotkeyMonitor
from utils.network import NetworkMonitor
from utils.recorder import ScreenRecorder

class MusicVisualizer(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(24)
        self.bars = 12
        self.bar_values = [random.uniform(0.2, 0.8) for _ in range(self.bars)]
        self.target_values = [random.uniform(0.2, 0.8) for _ in range(self.bars)]
        
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_animation)
        self.timer.start(50)
        
        self.is_active = False
        self.color = QColor(255, 255, 255, 180)

    def set_active(self, active):
        self.is_active = active
        if active:
            self.timer.start(50)
        else:
            self.timer.stop()
            self.update()

    def update_animation(self):
        for i in range(self.bars):
            # Smoothly transition to target
            self.bar_values[i] += (self.target_values[i] - self.bar_values[i]) * 0.3
            if abs(self.bar_values[i] - self.target_values[i]) < 0.05:
                self.target_values[i] = random.uniform(0.1, 0.9)
        self.update()

    def paintEvent(self, event):
        if not self.is_active:
            return
            
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        w = self.width()
        h = self.height()
        bar_w = 3
        spacing = 4
        total_w = (bar_w + spacing) * self.bars - spacing
        start_x = (w - total_w) // 2
        
        painter.setPen(Qt.NoPen)
        painter.setBrush(self.color)
        
        for i in range(self.bars):
            val = self.bar_values[i]
            bar_h = h * val
            y = (h - bar_h) / 2
            painter.drawRoundedRect(start_x + i * (bar_w + spacing), y, bar_w, bar_h, 1.5, 1.5)

class RecordingIndicator(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(24)
        self.layout = QHBoxLayout(self)
        self.layout.setContentsMargins(5, 0, 5, 0)
        self.layout.setSpacing(8)
        
        # Pulsing Red Dot
        self.dot = QWidget()
        self.dot.setFixedSize(8, 8)
        self.dot.setStyleSheet("background-color: #FF6B6B; border-radius: 4px;")
        
        self.timer_label = QLabel("00:00")
        self.timer_label.setStyleSheet("color: white; font-size: 14px; font-weight: bold; font-family: 'SF Pro Display'; background: transparent;")
        
        self.layout.addStretch()
        self.layout.addWidget(self.dot)
        self.layout.addWidget(self.timer_label)
        self.layout.addStretch()
        
        # Animation for dot
        self.opacity_effect = QPropertyAnimation(self.dot, b"windowOpacity") # This won't work on QWidget without extra setup, use custom paint
        self.pulse_timer = QTimer(self)
        self.pulse_timer.timeout.connect(self.update_pulse)
        self.pulse_timer.start(800)
        self.dot_opacity = 1.0
        self.fade_out = True

    def update_pulse(self):
        if self.fade_out:
            self.dot_opacity -= 0.2
            if self.dot_opacity <= 0.3:
                self.fade_out = False
        else:
            self.dot_opacity += 0.2
            if self.dot_opacity >= 1.0:
                self.fade_out = True
        self.dot.setStyleSheet(f"background-color: rgba(255, 107, 107, {self.dot_opacity}); border-radius: 4px;")

    def set_time(self, seconds):
        mins = seconds // 60
        secs = seconds % 60
        self.timer_label.setText(f"{mins:02d}:{secs:02d}")

class DynamicIsland(QWidget):
    # --- Internationalization ---
    I18N = {
        "zh": {
            "wifi_connected": "📶 {} 已连接",
            "wifi_disconnected": "📶 {} 已断开",
            "bt_connected": "ᛒ {} 已连接",
            "bt_disconnected": "ᛒ {} 已断开",
            "no_music": "未在播放",
            "record_start": "⚪ 停止录制",
            "record_stop": "⭕ 开始录制",
            "no_link": "无复制链接",
            "link_opened": "🔗 已打开复制链接"
        },
        "en": {
            "wifi_connected": "📶 {} Connected",
            "wifi_disconnected": "📶 {} Disconnected",
            "bt_connected": "ᛒ {} Connected",
            "bt_disconnected": "ᛒ {} Disconnected",
            "no_music": "Not Playing",
            "record_start": "⚪ Stop",
            "record_stop": "⭕ Start",
            "no_link": "No link copied",
            "link_opened": "🔗 Link Opened"
        }
    }

    # --- Configuration ---
    CONFIG = {
        "language": "zh", # "zh" or "en"
        "notification_duration": 4000, # ms
        "show_visualizer": True,
        "visualizer_color": QColor("#FFE66D"), # Yellow accent
        "glass_opacity": 180, # ~70% (255 * 0.7)
        "animation_duration": 300, # 300ms ease-out
        "expand_width": 360,
        "collapsed_height": 40,
        "main_color": "#FF6B6B",      # Dopamine Main
        "secondary_color": "#4ECDC4", # Dopamine Secondary
        "accent_color": "#FFE66D",    # Dopamine Accent
    }

    def __init__(self):
        super().__init__()
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # Apply Acrylic Blur (Disabled temporarily to fix square corners)
        # self.hwnd = int(self.winId())
        # set_blur(self.hwnd, 0x00000000) 
        self.current_edge = "top" # "top", "left", "right"
        self.is_dragging = False
        self.drag_pos = None

        # Dimensions
        self.expanded_width = 360
        self.expanded_height = 280
        self.collapsed_width = 160
        self.collapsed_height = 40
        
        # Vertical Dimensions (for Left/Right)
        self.v_expanded_width = 240
        self.v_expanded_height = 400
        self.v_collapsed_width = 40
        self.v_collapsed_height = 160

        self.is_expanded = False
        self.is_music_playing = False
        self.is_recording = False
        self.recording_seconds = 0
        self.recording_timer = QTimer(self)
        self.recording_timer.timeout.connect(self.update_recording_time)
        self.last_link = ""

        # Mouse Detection Parameters
        self.detection_margin = 30
        
        # UI Components
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(16, 16, 16, 16) # 16px Padding
        self.main_layout.setSpacing(12)
        
        # --- Collapsed View ---
        self.collapsed_widget = QWidget()
        self.collapsed_layout = QHBoxLayout(self.collapsed_widget)
        self.collapsed_layout.setContentsMargins(0, 0, 0, 0)
        self.collapsed_layout.setSpacing(10)
        
        self.time_label = QLabel()
        self.time_label.setAlignment(Qt.AlignCenter)
        self.time_label.setStyleSheet("color: white; font-size: 14px; font-weight: bold; font-family: 'SF Pro Display', 'Segoe UI Variable Display', 'Segoe UI'; background: transparent;")
        
        self.music_viz_collapsed = MusicVisualizer()
        self.music_viz_collapsed.color = self.CONFIG["visualizer_color"]
        self.music_viz_collapsed.hide()
        
        self.notification_label_collapsed = QLabel()
        self.notification_label_collapsed.setAlignment(Qt.AlignCenter)
        self.notification_label_collapsed.setStyleSheet("color: white; font-family: 'Segoe UI Variable Display', 'Segoe UI Variable', 'Segoe UI'; font-size: 14px; font-weight: bold; background: transparent;")
        self.notification_label_collapsed.hide()
        
        self.recording_indicator_collapsed = RecordingIndicator()
        self.recording_indicator_collapsed.hide()
        
        self.collapsed_layout.addWidget(self.time_label)
        self.collapsed_layout.addWidget(self.music_viz_collapsed)
        self.collapsed_layout.addWidget(self.notification_label_collapsed)
        self.collapsed_layout.addWidget(self.recording_indicator_collapsed)
        
        self.main_layout.addWidget(self.collapsed_widget)

        # --- Expanded View ---
        self.expanded_widget = QWidget()
        self.expanded_layout = QVBoxLayout(self.expanded_widget)
        self.expanded_layout.setContentsMargins(0, 0, 0, 0)
        self.expanded_layout.setSpacing(16)
        self.expanded_widget.hide()

        # Date Section
        self.date_label = QLabel()
        self.date_label.setAlignment(Qt.AlignCenter)
        self.date_label.setStyleSheet("color: white; font-family: 'Segoe UI Variable Display', 'Segoe UI Variable', 'Segoe UI'; font-size: 14px; font-weight: bold; background: transparent;")
        self.expanded_layout.addWidget(self.date_label)

        # Info row (Network & Clipboard)
        self.info_layout = QVBoxLayout()
        self.info_layout.setSpacing(8)
        
        self.net_label = QLabel("")
        self.net_label.setAlignment(Qt.AlignCenter)
        self.net_label.setStyleSheet("color: white; font-family: 'Segoe UI Variable Display', 'Segoe UI Variable', 'Segoe UI'; font-size: 14px; font-weight: bold; background: transparent;")
        self.info_layout.addWidget(self.net_label)

        self.clip_label = QLabel(self.tr("no_link"))
        self.clip_label.setAlignment(Qt.AlignCenter)
        self.clip_label.setStyleSheet(f"color: {self.CONFIG['accent_color']}; font-size: 14px; font-weight: bold; background: transparent;")
        self.clip_label.setWordWrap(True)
        self.info_layout.addWidget(self.clip_label)
        self.expanded_layout.addLayout(self.info_layout)

        # Media Section
        self.media_widget = QFrame()
        self.media_widget.setStyleSheet(f"""
            QFrame {{
                background: rgba(255, 255, 255, 0.1);
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.15);
            }}
        """)
        self.media_layout = QVBoxLayout(self.media_widget)
        self.media_layout.setContentsMargins(15, 15, 15, 15)
        self.media_layout.setSpacing(12)
        
        self.media_info_container = QHBoxLayout()
        self.media_text_layout = QVBoxLayout()
        self.track_label = QLabel(self.tr("no_music"))
        self.track_label.setAlignment(Qt.AlignCenter)
        self.track_label.setStyleSheet("color: white; font-size: 14px; font-weight: bold; background: transparent; border: none;")
        self.artist_label = QLabel("")
        self.artist_label.setAlignment(Qt.AlignCenter)
        self.artist_label.setStyleSheet("color: rgba(255, 255, 255, 0.7); font-size: 12px; background: transparent; border: none;")
        self.media_text_layout.addWidget(self.track_label)
        self.media_text_layout.addWidget(self.artist_label)
        self.media_info_container.addLayout(self.media_text_layout)
        
        self.media_layout.addLayout(self.media_info_container)

        self.media_controls = QHBoxLayout()
        self.media_controls.setSpacing(15)
        self.prev_btn = QPushButton("◀◀")
        self.play_btn = QPushButton("▶")
        self.next_btn = QPushButton("▶▶")
        
        btn_style = """
            QPushButton {
                background: rgba(255, 255, 255, 0.1);
                color: white;
                font-size: 18px;
                font-weight: bold;
                border-radius: 12px;
                border: none;
            }
            QPushButton:hover {
                background: rgba(255, 255, 255, 0.2);
            }
            QPushButton:pressed {
                background: rgba(255, 255, 255, 0.05);
            }
        """
        for btn in [self.prev_btn, self.play_btn, self.next_btn]:
            btn.setFixedSize(46, 46)
            btn.setStyleSheet(btn_style)
            btn.setCursor(Qt.PointingHandCursor)
        
        self.media_controls.addStretch()
        self.media_controls.addWidget(self.prev_btn)
        self.media_controls.addWidget(self.play_btn)
        self.media_controls.addWidget(self.next_btn)
        self.media_controls.addStretch()
        self.media_layout.addLayout(self.media_controls)
        self.expanded_layout.addWidget(self.media_widget)

        # Control Sliders
        self.sliders_layout = QVBoxLayout()
        self.sliders_layout.setSpacing(12)
        
        def create_slider_row(icon, slider_obj):
            row = QHBoxLayout()
            row.setSpacing(12)
            icon_label = QLabel(icon)
            icon_label.setStyleSheet("font-size: 16px;")
            slider_obj.setFixedHeight(24)
            slider_obj.setStyleSheet(f"""
                QSlider::groove:horizontal {{ height: 10px; background: rgba(255,255,255,0.1); border-radius: 5px; }}
                QSlider::handle:horizontal {{ width: 20px; height: 20px; background: white; border-radius: 10px; margin: -5px 0; }}
                QSlider::sub-page:horizontal {{ 
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, 
                        stop:0 #007aff, 
                        stop:0.5 #FF6B6B, 
                        stop:1 #32D74B); 
                    border-radius: 5px; 
                }}
            """)
            row.addWidget(icon_label)
            row.addWidget(slider_obj)
            return row

        self.vol_slider = QSlider(Qt.Horizontal)
        self.sliders_layout.addLayout(create_slider_row("🔊", self.vol_slider))
        
        self.bri_slider = QSlider(Qt.Horizontal)
        self.sliders_layout.addLayout(create_slider_row("☀️", self.bri_slider))
        
        self.expanded_layout.addLayout(self.sliders_layout)

        # Bottom Tools
        self.bottom_layout = QHBoxLayout()
        self.record_btn = QPushButton(self.tr("record_stop"))
        self.record_btn_style = """
            QPushButton {
                background: rgba(255, 255, 255, 0.1);
                color: white;
                border-radius: 14px;
                padding: 8px 18px;
                font-size: 14px;
                font-weight: bold;
                border: 1px solid rgba(255, 255, 255, 0.1);
            }
            QPushButton:hover {
                background: rgba(255, 255, 255, 0.2);
            }
            QPushButton:pressed {
                background: rgba(255, 255, 255, 0.05);
            }
        """
        self.record_btn.setStyleSheet(self.record_btn_style)
        self.record_btn.setCursor(Qt.PointingHandCursor)
        self.record_btn.clicked.connect(self.toggle_recording)
        self.bottom_layout.addWidget(self.record_btn)
        
        self.battery_label = QLabel("--%")
        self.battery_label.setStyleSheet("color: white; font-size: 14px; font-weight: bold; background: transparent;")
        self.bottom_layout.addStretch()
        self.bottom_layout.addWidget(self.battery_label)
        self.expanded_layout.addLayout(self.bottom_layout)

        self.main_layout.addWidget(self.expanded_widget)

        # Monitors
        self.monitor = SystemMonitor()
        self.monitor.updated.connect(self.update_system_ui)
        self.vol_slider.valueChanged.connect(self.monitor.set_volume)
        self.bri_slider.valueChanged.connect(self.monitor.set_brightness)

        self.media_monitor = MediaMonitor()
        self.media_monitor.metadata_changed.connect(self.update_media_info)
        self.media_monitor.status_changed.connect(self.update_media_status)
        
        self.play_btn.clicked.connect(self.media_monitor.play_pause)
        self.next_btn.clicked.connect(self.media_monitor.next)
        self.prev_btn.clicked.connect(self.media_monitor.previous)

        self.clip_monitor = ClipboardMonitor()
        self.clip_monitor.link_copied.connect(self.on_link_copied)

        self.hotkey_monitor = HotkeyMonitor("alt+o")
        self.hotkey_monitor.hotkey_pressed.connect(self.open_last_link)

        self.net_monitor = NetworkMonitor()
        self.net_monitor.wifi_changed.connect(self.on_wifi_changed)
        self.net_monitor.bluetooth_changed.connect(self.on_bluetooth_changed)

        self.recorder = ScreenRecorder()
        self.recorder.recording_status.connect(self.on_recording_status)

        # Initial size and position
        self.resize(self.collapsed_width, self.collapsed_height)
        self.center_top()

        # Global Mouse Polling
        self.mouse_timer = QTimer()
        self.mouse_timer.timeout.connect(self.check_mouse_pos)
        self.mouse_timer.start(100)

        # Start as passthrough
        self.hwnd = int(self.winId())
        set_mouse_passthrough(self.hwnd)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.is_dragging = True
            self.drag_pos = event.globalPos() - self.pos()
            event.accept()

    def mouseMoveEvent(self, event):
        if self.is_dragging and self.drag_pos:
            new_pos = event.globalPos() - self.drag_pos
            self.move(new_pos)
            event.accept()

    def mouseReleaseEvent(self, event):
        if self.is_dragging:
            self.is_dragging = False
            self.snap_to_edge()
            event.accept()

    def snap_to_edge(self):
        screen = QApplication.primaryScreen().geometry()
        x, y = self.x(), self.y()
        w, h = self.width(), self.height()
        
        # Calculate distances to edges
        dist_top = y
        dist_left = x
        dist_right = screen.width() - (x + w)
        
        # Snap logic
        min_dist = min(dist_top, dist_left, dist_right)
        
        if min_dist == dist_top:
            self.current_edge = "top"
            target_x = (screen.width() - w) // 2
            target_y = 8
        elif min_dist == dist_left:
            self.current_edge = "left"
            target_x = 8
            target_y = (screen.height() - h) // 2
        else:
            self.current_edge = "right"
            target_x = screen.width() - w - 8
            target_y = (screen.height() - h) // 2
            
        self.move(target_x, target_y)
        self.update_layout_orientation()

    def update_layout_orientation(self):
        is_vertical = self.current_edge in ["left", "right"]
        
        # Adjust layouts
        if is_vertical:
            self.main_layout.setDirection(QVBoxLayout.TopToBottom)
            self.collapsed_layout.setDirection(QVBoxLayout.TopToBottom)
            self.media_controls.setDirection(QVBoxLayout.TopToBottom)
            self.media_layout.setDirection(QVBoxLayout.TopToBottom)
            self.info_layout.setDirection(QVBoxLayout.TopToBottom)
            self.sliders_layout.setDirection(QVBoxLayout.TopToBottom)
            self.bottom_layout.setDirection(QVBoxLayout.TopToBottom)
            
            # Center alignment for vertical
            self.time_label.setAlignment(Qt.AlignCenter)
            self.date_label.setAlignment(Qt.AlignCenter)
            self.net_label.setAlignment(Qt.AlignCenter)
            self.clip_label.setAlignment(Qt.AlignCenter)
            self.track_label.setAlignment(Qt.AlignCenter)
            self.artist_label.setAlignment(Qt.AlignCenter)
            
            # Make sliders vertical if they are too wide
            self.vol_slider.setOrientation(Qt.Horizontal) 
            self.bri_slider.setOrientation(Qt.Horizontal)
        else:
            self.main_layout.setDirection(QVBoxLayout.TopToBottom)
            self.collapsed_layout.setDirection(QHBoxLayout.LeftToRight)
            self.media_controls.setDirection(QHBoxLayout.LeftToRight)
            self.media_layout.setDirection(QVBoxLayout.TopToBottom)
            self.info_layout.setDirection(QVBoxLayout.TopToBottom)
            self.sliders_layout.setDirection(QVBoxLayout.TopToBottom)
            self.bottom_layout.setDirection(QHBoxLayout.LeftToRight)
            
            # Ensure alignments
            self.time_label.setAlignment(Qt.AlignCenter)
            self.date_label.setAlignment(Qt.AlignCenter)
            self.net_label.setAlignment(Qt.AlignCenter)
            self.clip_label.setAlignment(Qt.AlignCenter)
            self.track_label.setAlignment(Qt.AlignCenter) # Centered in media card
            self.artist_label.setAlignment(Qt.AlignCenter)

        self.animate_resize_to_current_state()

    def animate_resize_to_current_state(self):
        w, h = self.get_target_dimensions()
        x, y = self.get_target_position(w, h)
        
        target_rect = QRect(x, y, w, h)
        self.anim = QPropertyAnimation(self, b"geometry")
        self.anim.setDuration(self.CONFIG["animation_duration"])
        self.anim.setEndValue(target_rect)
        self.anim.setEasingCurve(QEasingCurve.OutQuart)
        self.anim.start()

    def get_target_dimensions(self):
        is_vertical = self.current_edge in ["left", "right"]
        
        if self.is_expanded:
            return (self.v_expanded_width, self.v_expanded_height) if is_vertical else (self.expanded_width, self.expanded_height)
        else:
            # Notification active
            if self.notification_label_collapsed.isVisible():
                return (self.expanded_width - 20, self.collapsed_height)
            
            # Recording active in collapsed mode
            if self.is_recording and self.current_edge == "top":
                return (self.expanded_width - 100, self.collapsed_height)
                
            # Special case: music playing in collapsed mode
            if self.is_music_playing and self.current_edge == "top":
                return (self.expanded_width - 40, self.collapsed_height)
            
            return (self.v_collapsed_width, self.v_collapsed_height) if is_vertical else (self.collapsed_width, self.collapsed_height)

    def get_target_position(self, w, h):
        screen = QApplication.primaryScreen().geometry()
        if self.current_edge == "top":
            return (screen.width() - w) // 2, 8
        elif self.current_edge == "left":
            return 8, (screen.height() - h) // 2
        else: # right
            return screen.width() - w - 8, (screen.height() - h) // 2


    def center_top(self, w=None):
        if w is None:
            w = self.width()
        screen = QApplication.primaryScreen().geometry()
        x = (screen.width() - w) // 2
        y = 8
        return x, y

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.update_mask()

    def update_mask(self):
        # Physical clipping of the window to remove square corners
        path = QPainterPath()
        # Ensure radius is never more than half the dimension
        r = self.height() // 2 if not self.is_expanded else 32
        path.addRoundedRect(self.rect(), r, r)
        region = QRegion(path.toFillPolygon().toPolygon())
        self.setMask(region)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Draw background inside the clipped mask
        bg_color = QColor(10, 10, 10, self.CONFIG["glass_opacity"])
        painter.setBrush(bg_color)
        painter.setPen(Qt.NoPen)
        
        # Use high radius for expanded state (iOS style), capsule for collapsed
        radius = self.height() // 2 if not self.is_expanded else 32
        painter.drawRoundedRect(self.rect(), radius, radius)
        
        # Subtle border for glass effect
        border_color = QColor(255, 255, 255, 50)
        painter.setPen(QPen(border_color, 1.2))
        painter.setBrush(Qt.NoBrush)
        painter.drawRoundedRect(self.rect().adjusted(1, 1, -1, -1), radius, radius)

    def tr(self, key, *args):
        lang = self.CONFIG.get("language", "zh")
        text = self.I18N.get(lang, self.I18N["en"]).get(key, key)
        if args:
            return text.format(*args)
        return text

    def show_notification(self, text):
        # Update both labels
        self.notification_label_collapsed.setText(text)
        self.net_label.setText(text)
        
        # Show in collapsed if not expanded
        if not self.is_expanded:
            self.time_label.hide()
            self.music_viz_collapsed.hide()
            self.notification_label_collapsed.show()
            self.animate_resize_to_current_state()
            
        # Auto hide
        QTimer.singleShot(self.CONFIG["notification_duration"], self.hide_notification)

    def hide_notification(self):
        self.notification_label_collapsed.hide()
        if not self.is_expanded:
            if self.is_recording:
                self.time_label.hide()
                self.recording_indicator_collapsed.show()
            else:
                self.time_label.show()
                if self.is_music_playing:
                    self.music_viz_collapsed.show()
            self.animate_resize_to_current_state()

    def toggle_recording(self):
        if self.recorder.is_recording:
            self.recorder.stop_recording()
        else:
            self.recorder.start_recording()

    def update_recording_time(self):
        self.recording_seconds += 1
        self.recording_indicator_collapsed.set_time(self.recording_seconds)

    def on_recording_status(self, is_recording, filename):
        self.is_recording = is_recording
        if is_recording:
            self.recording_seconds = 0
            self.recording_timer.start(1000)
            self.record_btn.setText(self.tr("record_start"))
            # Keep consistent style, maybe subtle red text or indicator
            self.record_btn.setStyleSheet(self.record_btn_style.replace("color: white;", f"color: {self.CONFIG['main_color']};"))
            
            # Update collapsed view if not expanded
            if not self.is_expanded:
                self.time_label.hide()
                self.music_viz_collapsed.hide()
                self.recording_indicator_collapsed.show()
                self.animate_resize_to_current_state()
            
            self.show_notification(self.tr("record_start"))
        else:
            self.recording_timer.stop()
            self.record_btn.setText(self.tr("record_stop"))
            self.record_btn.setStyleSheet(self.record_btn_style)
            
            # Restore collapsed view if not expanded
            if not self.is_expanded:
                self.recording_indicator_collapsed.hide()
                self.time_label.show()
                if self.is_music_playing:
                    self.music_viz_collapsed.show()
                self.animate_resize_to_current_state()
                
            if filename:
                self.show_notification(f"✅ Saved: {filename}")

    def on_wifi_changed(self, status, name):
        key = "wifi_connected" if status else "wifi_disconnected"
        self.show_notification(self.tr(key, name))

    def on_bluetooth_changed(self, status, name):
        key = "bt_connected" if status else "bt_disconnected"
        self.show_notification(self.tr(key, name))

    def on_link_copied(self, link):
        self.last_link = link
        display_link = link if len(link) < 30 else link[:27] + "..."
        text = f"🔗 {display_link}"
        self.clip_label.setText(text)
        self.show_notification(text)

    def open_last_link(self):
        if self.last_link:
            webbrowser.open(self.last_link)
            self.show_notification(self.tr("link_opened"))

    def update_media_info(self, info):
        self.track_label.setText(info['title'])
        self.artist_label.setText(info['artist'])

    def update_media_status(self, is_playing):
        self.is_music_playing = is_playing
        self.play_btn.setText("⏸" if is_playing else "▶")
        
        # Toggle visualizer in collapsed mode
        if is_playing and not self.is_expanded:
            self.music_viz_collapsed.show()
            self.music_viz_collapsed.set_active(True)
        else:
            self.music_viz_collapsed.hide()
            self.music_viz_collapsed.set_active(False)
            
        # Resize if music state changed in collapsed mode
        if not self.is_expanded:
            self.animate_resize_to_current_state()

    def update_system_ui(self, info):
        self.time_label.setText(info['time'])
        self.battery_label.setText(f"🔋 {info['percent']}% {'⚡' if info['power_plugged'] else ''}")
        
        # Chinese Date Formatting
        now = datetime.datetime.now()
        weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        date_str = now.strftime(f"%m月%d日 {weekdays[now.weekday()]}")
        self.date_label.setText(date_str)
        
        if not self.vol_slider.isSliderDown():
            self.vol_slider.setValue(info['volume'])
        if not self.bri_slider.isSliderDown():
            self.bri_slider.setValue(info['brightness'])

    def check_mouse_pos(self):
        if self.is_dragging:
            return

        cursor_pos = QCursor.pos()
        screen_geom = QApplication.primaryScreen().geometry()
        
        # Check if mouse is near the island based on its current edge
        in_trigger_zone = False
        margin = 50 # Detection margin around the island
        
        if self.current_edge == "top":
            center_x = screen_geom.width() // 2
            in_trigger_zone = (abs(cursor_pos.x() - center_x) < self.width() // 2 + margin) and (cursor_pos.y() < self.y() + self.height() + margin)
        elif self.current_edge == "left":
            center_y = screen_geom.height() // 2
            in_trigger_zone = (cursor_pos.x() < self.x() + self.width() + margin) and (abs(cursor_pos.y() - center_y) < self.height() // 2 + margin)
        elif self.current_edge == "right":
            center_y = screen_geom.height() // 2
            in_trigger_zone = (cursor_pos.x() > self.x() - margin) and (abs(cursor_pos.y() - center_y) < self.height() // 2 + margin)
        
        if in_trigger_zone:
            if not self.is_expanded:
                self.expand()
            if hasattr(self, 'collapse_timer'):
                self.collapse_timer.stop()
        else:
            if self.is_expanded:
                if not hasattr(self, 'collapse_timer'):
                    self.collapse_timer = QTimer()
                    self.collapse_timer.setSingleShot(True)
                    self.collapse_timer.timeout.connect(self.collapse)
                if not self.collapse_timer.isActive():
                    self.collapse_timer.start(1000)

    def expand(self):
        if not self.is_expanded:
            self.is_expanded = True
            self.collapsed_widget.hide()
            self.music_viz_collapsed.set_active(False)
            self.recording_indicator_collapsed.hide()
            self.expanded_widget.show()
            unset_mouse_passthrough(self.hwnd)
            self.animate_resize_to_current_state()

    def collapse(self):
        if self.is_expanded:
            self.is_expanded = False
            self.expanded_widget.hide()
            self.collapsed_widget.show()
            
            # Restore appropriate collapsed view
            if self.is_recording:
                self.time_label.hide()
                self.music_viz_collapsed.hide()
                self.recording_indicator_collapsed.show()
            elif self.is_music_playing:
                self.time_label.show()
                self.music_viz_collapsed.show()
                self.music_viz_collapsed.set_active(True)
            else:
                self.time_label.show()
                self.music_viz_collapsed.hide()
                
            set_mouse_passthrough(self.hwnd)
            self.animate_resize_to_current_state()

    def animate_resize(self, w, h):
        x, y = self.center_top(w)
        target_rect = QRect(x, y, w, h)
        
        self.anim = QPropertyAnimation(self, b"geometry")
        self.anim.setDuration(400)
        self.anim.setEndValue(target_rect)
        self.anim.setEasingCurve(QEasingCurve.OutQuart)
        self.anim.start()

class IslandApp(QApplication):
    def __init__(self, args):
        super().__init__(args)
        self.island = DynamicIsland()
        self.island.show()

        # Tray Icon
        self.tray = QSystemTrayIcon(self)
        self.tray.setIcon(QIcon.fromTheme("system-run"))
        
        menu = QMenu()
        settings_action = QAction("Settings", self)
        settings_action.triggered.connect(self.show_settings)
        menu.addAction(settings_action)
        
        menu.addSeparator()
        
        exit_action = QAction("Exit", self)
        exit_action.triggered.connect(self.quit)
        menu.addAction(exit_action)
        
        self.tray.setContextMenu(menu)
        self.tray.show()

    def show_settings(self):
        print("Settings clicked")

if __name__ == "__main__":
    app = IslandApp(sys.argv)
    sys.exit(app.exec())
