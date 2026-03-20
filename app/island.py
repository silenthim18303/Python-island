"""现代化灵动岛主窗口模块

实现灵动岛的主窗口，整合各个功能模块，提供完整的用户界面。
"""

from PySide6.QtCore import QEvent, QRect, Qt
from PySide6.QtGui import QCursor
from PySide6.QtWidgets import QApplication, QWidget

from app.animations.effects import AnimationManager, RoundedMaskHelper
from app.core.animation_controller import AnimationController
from app.core.config import (
    CLIPBOARD_CHECK_INTERVAL,
    COLLAPSED_HEIGHT,
    COLLAPSED_WIDTH,
    CONNECTION_AUTO_CLOSE_DELAY,
    DEBOUNCE_DELAY,
    EXPANDED_HEIGHT,
    EXPANDED_WIDTH,
    MAX_EXPAND_HEIGHT_RATIO,
    STATUS_UPDATE_INTERVAL,
    STYLES_PATH,
    TIME_UPDATE_INTERVAL,
    URL_AUTO_CLOSE_DELAY,
)
from app.core.event_handler import EventHandler
from app.core.service_coordinator import ServiceCoordinator
from app.core.state_manager import IslandState, IslandStateManager
from app.core.time_display_manager import TimeDisplayManager
from app.core.timer_manager import TimerManager
from app.core.ui_builder import IslandUIBuilder
from app.services.tray import TrayService


class ModernIsland(QWidget):
    """带展开式控制面板的现代化灵动岛小部件。

    整合各个功能模块，提供时间显示、亮度控制、系统状态显示、
    剪贴板URL检测等功能。
    """

    def __init__(self):
        super().__init__()
        self._init_managers()
        self._init_window()
        self._init_ui()
        self._init_timers()
        self._load_styles()
        self._register_state_callbacks()

    def _init_managers(self):
        self.state_manager = IslandStateManager()
        self.timer_manager = TimerManager(self)
        self.service_coordinator = ServiceCoordinator()
        self.animation_manager = None
        self.animation_controller = None
        self.event_handler = None
        self.time_display_manager = None
        self.tray_service = TrayService()

    def _init_window(self):
        self.setWindowFlags(
            Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)

        self.screen_w = QApplication.primaryScreen().size().width()
        self.screen_h = QApplication.primaryScreen().size().height()
        self.max_expand_h = self.screen_h // MAX_EXPAND_HEIGHT_RATIO

        self.col_rect = QRect(
            (self.screen_w - COLLAPSED_WIDTH) // 2, 20,
            COLLAPSED_WIDTH, COLLAPSED_HEIGHT
        )
        self.setGeometry(self.col_rect)

        self.setMouseTracking(True)
        QApplication.instance().focusChanged.connect(self._on_focus_changed)

    def _init_ui(self):
        ui_builder = IslandUIBuilder(self)
        (
            self.container,
            self.time_label,
            self.date_label,
            self.controls,
            self.status_bar,
            self.bright_slider,
            self.bright_val
        ) = ui_builder.build()

        self.animation_manager = AnimationManager(self)
        self._icon_cache = ui_builder.get_icon_cache()
        self.current_brightness = 50

        self.animation_controller = AnimationController(
            self.animation_manager,
            self.container,
            self.controls,
            self._update_rounded_mask,
            self._update_time_display
        )

        self.time_display_manager = TimeDisplayManager(
            self.time_label,
            self.date_label,
            IslandUIBuilder.position_label_center
        )

        self.event_handler = EventHandler(
            self.toggle_island,
            self.state_manager.is_expanded
        )

        self.bright_slider.valueChanged.connect(self._on_brightness_slider_changed)
        self._update_rounded_mask()

    def _init_timers(self):
        self.timer_manager.create_timer(
            "time_update", TIME_UPDATE_INTERVAL, self._update_time_display
        )
        self.timer_manager.create_timer(
            "status_update", STATUS_UPDATE_INTERVAL, self._start_status_update
        )
        self.timer_manager.create_debounce_timer(
            "brightness_debounce", DEBOUNCE_DELAY, self._apply_brightness
        )
        self.timer_manager.create_timer(
            "clipboard_check", CLIPBOARD_CHECK_INTERVAL, self._check_clipboard
        )

        self._start_status_update()
        self._load_initial_brightness()

    def _load_styles(self):
        try:
            with open(STYLES_PATH, "r", encoding="utf-8") as f:
                self.setStyleSheet(f.read())
        except Exception:
            pass

    def _register_state_callbacks(self):
        self.state_manager.register_callback(
            IslandState.COLLAPSED, self._on_state_collapsed
        )
        self.state_manager.register_callback(
            IslandState.HOVERING, self._on_state_hovering
        )
        self.state_manager.register_callback(
            IslandState.EXPANDED, self._on_state_expanded
        )

    def _on_state_collapsed(self, data):
        self.time_display_manager.show_time_only()
        self.controls.hide()

    def _on_state_hovering(self, data):
        self.time_display_manager.update_for_hover()

    def _on_state_expanded(self, data):
        self.time_display_manager.show_date_only()

    def _load_initial_brightness(self):
        self.service_coordinator.load_initial_brightness(
            self._on_brightness_loaded
        )

    def _on_brightness_loaded(self, brightness):
        if brightness is not None:
            brightness = max(0, min(100, brightness))
            self.bright_slider.setValue(brightness)
            self.bright_val.setText(f"{brightness}%")
            self.current_brightness = brightness

    def _on_brightness_slider_changed(self, value):
        self.bright_val.setText(f"{value}%")
        self.current_brightness = value
        self.timer_manager.trigger_debounce("brightness_debounce")

    def _apply_brightness(self):
        self.service_coordinator.apply_brightness(self.current_brightness)

    def _start_status_update(self):
        self.service_coordinator.update_system_status(
            self._on_status_updated,
            self._on_status_error
        )

    def _on_status_error(self, error):
        print(f"状态更新失败: {error}")

    def _on_status_updated(self, result):
        ssid, signal, bt_name, bt_status, charge, status, dns_connected = \
            self.service_coordinator.process_status_update(result)

        self.status_bar.update_wifi(ssid, signal)
        self.status_bar.update_bluetooth(bt_name, bt_status)
        self.status_bar.update_battery(charge, status)

        wifi_msg, bt_msg, battery_msg = self.service_coordinator.check_status_changes(
            ssid, dns_connected, result[1], status
        )

        if wifi_msg:
            self._show_connection_animation(wifi_msg, "internet")
        elif bt_msg:
            self._show_connection_animation(bt_msg, "bluetooth")
        elif battery_msg:
            self._show_connection_animation(battery_msg, "battery")

    def _update_time_display(self):
        self.time_display_manager.update(
            self.state_manager.is_expanded(),
            self.state_manager.is_hovering()
        )

    def _check_clipboard(self):
        has_new, urls = self.service_coordinator.check_clipboard()
        if has_new:
            self._show_url_notification(urls)

    def _show_url_notification(self, urls: list):
        if len(urls) == 1:
            self.controls.setCurrentIndex(1)
            url_single_page = self.controls.widget(1)
            url_single_page.build_single_url_page(
                urls[0],
                self._open_url_and_close,
                self._close_url_page
            )
            target_height = EXPANDED_HEIGHT
        else:
            self.controls.setCurrentIndex(2)
            url_multi_page = self.controls.widget(2)
            target_height = url_multi_page.build_multi_url_page(
                urls,
                self._open_selected_and_close,
                self._close_url_page
            )
            target_height = min(target_height, self.max_expand_h)

        self._expand_to_url_page(target_height)
        self.timer_manager.create_auto_close_timer(
            "url_auto_close", URL_AUTO_CLOSE_DELAY, self._close_url_page
        )

    def _expand_to_url_page(self, target_height: int):
        if self.state_manager.is_expanded():
            current_h = self.geometry().height()
            if current_h != target_height:
                self.animation_controller.animate_height_change(
                    current_h, target_height,
                    self.geometry().width(),
                    self._set_controls_height
                )
            return

        self.state_manager.set_state(IslandState.URL_DISPLAY)
        self._update_time_display()

        self.animation_controller.animate_url_expand(
            target_height,
            on_finished=lambda: self._set_controls_height(target_height)
        )

    def _set_controls_height(self, container_h: int):
        controls_h = AnimationController.calculate_controls_height(container_h)
        self.controls.setFixedHeight(controls_h)

    def _close_url_page(self):
        self.controls.setCurrentIndex(0)
        self.controls.setFixedHeight(
            AnimationController.calculate_controls_height(EXPANDED_HEIGHT)
        )
        if self.state_manager.is_expanded():
            self._collapse_from_url_page()

    def _collapse_from_url_page(self):
        current_pos = self.pos()

        self.state_manager.set_state(IslandState.COLLAPSED)
        self.time_display_manager.hide_all()

        def on_finished():
            self.time_display_manager.show_time_only()
            self._update_time_display()

        self.animation_controller.animate_collapse(
            self.geometry(),
            current_pos.x(),
            self.rect().width(),
            on_finished
        )

        self.controls.setCurrentIndex(0)

    def _open_url_and_close(self, url: str):
        self.service_coordinator.open_url(url)
        self._close_url_page()

    def _open_selected_and_close(self):
        url_multi_page = self.controls.widget(2)
        selected_urls = url_multi_page.get_selected_urls()
        if selected_urls:
            self.service_coordinator.open_urls(selected_urls)
        self._close_url_page()

    def _show_connection_animation(self, message: str, icon: str = "📶"):
        self.timer_manager.stop_timer("time_update")

        if not self.state_manager.is_expanded():
            self._do_hover_and_show_connection(message, icon)
        else:
            self._update_connection_display(message, icon)

        self.timer_manager.create_auto_close_timer(
            "connection_auto_close",
            CONNECTION_AUTO_CLOSE_DELAY,
            self._close_connection_page
        )

    def _do_hover_and_show_connection(self, message: str, icon: str):
        self.state_manager.set_state(IslandState.HOVERING)

        self.time_label.hide()
        self.date_label.hide()

        def on_finished():
            from app.core.config import HOVER_WIDTH, HOVER_HEIGHT
            self.time_display_manager.show_connection_message(message, icon, HOVER_WIDTH, HOVER_HEIGHT)
            self.time_label.hide()
            self.date_label.show()

        self.animation_controller.animate_hover(
            self.geometry(), True, self.screen_w, on_finished
        )

    def _update_connection_display(self, message: str, icon: str):
        self.time_label.hide()
        self.date_label.show()
        from app.core.config import EXPANDED_WIDTH, EXPANDED_HEIGHT
        self.time_display_manager.show_connection_message(message, icon, EXPANDED_WIDTH, EXPANDED_HEIGHT)

    def _close_connection_page(self):
        if self.state_manager.is_hovering():
            self.state_manager.set_state(IslandState.COLLAPSED)
            
            self.time_label.hide()
            self.date_label.hide()
            was_timer_running = self.timer_manager.is_timer_active("time_update")
            
            def on_finished():
                self.time_display_manager.show_time_only()
                self._update_time_display()
                self.time_label.show()
                self.date_label.hide()
                if was_timer_running:
                    self.timer_manager.start_timer("time_update")
            
            self.animation_controller.animate_hover(
                self.geometry(), False, self.screen_w, on_finished
            )
        else:
            self.timer_manager.start_timer("time_update")
            self._update_time_display()

    def _update_rounded_mask(self):
        RoundedMaskHelper.update_mask(self)

    def mousePressEvent(self, event):
        self.event_handler.handle_mouse_press(
            event, self.frameGeometry().topLeft
        )

    def mouseMoveEvent(self, event):
        self.event_handler.handle_mouse_move(event, self.move)

    def mouseReleaseEvent(self, event):
        self.event_handler.handle_mouse_release(event, self.rect)

    def enterEvent(self, event):
        super().enterEvent(event)
        self.event_handler.handle_enter_event(
            self.state_manager.is_collapsed(),
            self._start_hover_animation
        )

    def leaveEvent(self, event):
        super().leaveEvent(event)
        self.event_handler.handle_leave_event(
            self.state_manager.is_collapsed() or self.state_manager.is_hovering(),
            self._start_hover_animation
        )

    def _start_hover_animation(self, is_enter: bool):
        if is_enter:
            if not self.state_manager.is_collapsed():
                return
            self.state_manager.set_state(IslandState.HOVERING)
        else:
            if not self.state_manager.is_hovering():
                return
            self.state_manager.set_state(IslandState.COLLAPSED)

        self.time_label.hide()
        was_timer_running = self.timer_manager.is_timer_active("time_update")
        if was_timer_running:
            self.timer_manager.stop_timer("time_update")

        def on_finished():
            if is_enter:
                self.time_display_manager.update_for_hover()
            else:
                self._update_time_display()
            self.time_label.show()
            if was_timer_running:
                self.timer_manager.start_timer("time_update")

        self.animation_controller.animate_hover(
            self.geometry(), is_enter, self.screen_w, on_finished
        )

    def _on_focus_changed(self, old_widget, new_widget):
        self.event_handler.handle_focus_change(
            old_widget, new_widget, lambda: self
        )

    def toggle_island(self):
        current_pos = self.pos()

        if not self.state_manager.is_expanded():
            self._do_expand(current_pos)
        else:
            self._do_collapse(current_pos)

    def _do_expand(self, current_pos):
        self.state_manager.set_state(IslandState.EXPANDED)
        self.time_display_manager.hide_all()

        def on_finished():
            self.time_display_manager.show_date_only()
            self._update_time_display()

        self.animation_controller.animate_expand(
            self.geometry(),
            current_pos.x(),
            self.rect().width(),
            on_finished
        )

    def _do_collapse(self, current_pos):
        self.state_manager.set_state(IslandState.COLLAPSED)
        self.time_display_manager.hide_all()

        def on_finished():
            self.time_display_manager.show_time_only()
            self._update_time_display()

        self.animation_controller.animate_collapse(
            self.geometry(),
            current_pos.x(),
            self.rect().width(),
            on_finished
        )

        self.controls.setCurrentIndex(0)

    def eventFilter(self, obj, event):
        if event.type() == QEvent.Close and obj == getattr(self, '_url_dialog', None):
            self._url_dialog = None
            return True
        return super().eventFilter(obj, event)