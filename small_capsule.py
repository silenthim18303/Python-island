from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtGui import QRegion, QPainterPath, QColor
from PySide6.QtCore import Qt, QUrl, QTimer
import sys
import os
from PySide6.QtCore import QPropertyAnimation, QEasingCurve, QPoint

class CapsuleWidget(QMainWindow):
    """
    胶囊状悬浮窗口组件
    功能特性：
    - 无边框透明背景
    - 支持鼠标拖动
    - 自动边缘吸附（左边缘半隐藏）
    - 自适应屏幕分辨率和系统缩放
    - 平滑动画过渡
    - 延迟加载 WebEngineView，减少启动时间
    """
    def __init__(self):
        super().__init__()
        # 先初始化所有实例属性（必须在 initUI 之前，因为 initUI 会访问它们）
        self.drag_position = None  # 拖动起始位置记录
        self.edge_sensitivity = 5  # 边缘吸附灵敏度（像素）
        self.auto_hidden = False   # 是否处于自动隐藏状态
        self.web_view = None       # 延迟创建的 WebEngineView
        self._web_engine_loaded = False  # WebEngine 是否已加载
        self._idle_timer = None    # 空闲计时器
        self._is_dimmed = False    # 当前是否处于减淡状态
        self._press_pos = None      # 鼠标按下位置，用于区分点击和拖动
        self._click_threshold = 3    # 点击阈值（像素），小于此值视为点击
        self._side_panel = None     # 侧边面板窗口引用
        self.initUI()

    def initUI(self):
        """初始化用户界面（轻量级，不含 WebEngine 的初始化）"""
        # 设置窗口无边框、透明背景、工具窗口标志
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # 获取屏幕逻辑分辨率（availableGeometry 已经是逻辑像素，包含系统缩放）
        screen = QApplication.primaryScreen()
        screen_geo = screen.availableGeometry()

        # 直接用逻辑像素计算，不再二次除以 devicePixelRatio
        # 按屏幕高度的1/8比例设置窗口高度，宽度为高度的1/4
        target_height = screen_geo.height() // 8
        target_width = target_height // 4

        # 设置窗口大小
        self.setFixedSize(target_width, target_height)

        # 居中显示窗口
        self.centerWindow()
        # 启动时自动吸附到左边缘（只露出一半）
        self.snapToLeftHalfOnStartup()

        # 使用定时器延迟创建 WebEngineView，等窗口首次事件循环完成后再创建
        # 这样可以让窗口先快速显示出来，避免启动时的卡顿
        QTimer.singleShot(0, self._initWebEngine)

        # 初始化空闲计时器（10秒无交互后减淡颜色）
        self._initIdleTimer()

    def _initIdleTimer(self):
        """初始化空闲检测计时器：10秒无活动则减淡颜色"""
        if self._idle_timer is None:
            self._idle_timer = QTimer(self)
            self._idle_timer.setSingleShot(True)
            self._idle_timer.setInterval(10000)  # 10秒
            self._idle_timer.timeout.connect(self._onIdleTimeout)
        # 启动倒计时
        self._idle_timer.start()

    def _resetIdleTimer(self):
        """重置空闲计时器：有用户活动时调用"""
        if self._is_dimmed:
            # 从减淡状态恢复
            self._setDimState(False)
            self._is_dimmed = False
        # 重新开始倒计时
        if self._idle_timer is not None:
            self._idle_timer.start()

    def _onIdleTimeout(self):
        """空闲超时：将胶囊减淡颜色"""
        if not self._is_dimmed:
            self._setDimState(True)
            self._is_dimmed = True

    def _setDimState(self, dimmed):
        """
        调用 HTML 中的 JS 函数，设置减淡状态
        :param dimmed: True=减淡, False=恢复
        """
        if not self._web_engine_loaded or self.web_view is None:
            return
        js_code = "window.setCapsuleDim && window.setCapsuleDim(%s);" % ("true" if dimmed else "false")
        self.web_view.page().runJavaScript(js_code)

    def _initWebEngine(self):
        """延迟初始化 WebEngineView（在事件循环空闲时执行）"""
        if self._web_engine_loaded:
            return

        # 延迟导入 QWebEngineView，因为 QtWebEngine 初始化开销较大
        from PySide6.QtWebEngineWidgets import QWebEngineView

        # 创建WebEngineView用于显示HTML内容
        self.web_view = QWebEngineView(self)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        # 让 WebView"忽略鼠标事件"，使窗口可以接收鼠标操作
        self.web_view.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.web_view.page().setBackgroundColor(Qt.transparent)
        self.setCentralWidget(self.web_view)
        self.web_view.resize(self.size())
        self.web_view.show()

        # 加载本地HTML文件
        html_path = os.path.join(os.path.dirname(__file__), 'widget.html')
        self.web_view.load(QUrl.fromLocalFile(html_path))

        self._web_engine_loaded = True


    
    def centerWindow(self):
        """将窗口居中显示"""
        qr = self.frameGeometry()  # 获取窗口矩形
        cp = QApplication.primaryScreen().availableGeometry().center()  # 获取屏幕中心点
        qr.moveCenter(cp)  # 将窗口矩形中心移动到屏幕中心
        self.move(qr.topLeft())  # 移动窗口到目标位置

    def mousePressEvent(self, event):
        """处理鼠标按下事件，记录拖动起始位置和点击检测基准点"""
        self._resetIdleTimer()  # 用户活动，重置空闲计时器
        if event.button() == Qt.LeftButton:
            # globalPosition() 返回浮点坐标（QPointF），转成 QPoint 更方便计算
            gp = event.globalPosition().toPoint()
            self.drag_position = gp - self.frameGeometry().topLeft()
            self._press_pos = gp  # 记录按下时的全局位置用于点击检测
            event.accept()

    def mouseMoveEvent(self, event):
        """处理鼠标移动事件，实现窗口拖动"""
        self._resetIdleTimer()  # 用户活动，重置空闲计时器
        # 拖动窗口
        if event.buttons() == Qt.LeftButton and self.drag_position is not None:
            # globalPosition() 返回浮点坐标（QPointF），转成 QPoint 更方便计算
            gp = event.globalPosition().toPoint()
            new_pos = gp - self.drag_position
            self.move(new_pos)
            event.accept()
            # 边缘检测
            self.checkEdgeSnap(new_pos)

    def mouseReleaseEvent(self, event):
        """处理鼠标释放事件：区分点击和拖动，点击时打开/关闭侧边面板"""
        self._resetIdleTimer()  # 用户活动，重置空闲计时器
        if event.button() == Qt.LeftButton:
            gp = event.globalPosition().toPoint()
            # 判断是否为点击（鼠标移动距离小于阈值）
            is_click = False
            if self._press_pos is not None:
                dx = gp.x() - self._press_pos.x()
                dy = gp.y() - self._press_pos.y()
                if abs(dx) <= self._click_threshold and abs(dy) <= self._click_threshold:
                    is_click = True
            self._press_pos = None

            if is_click:
                # 点击事件：切换侧边面板的显示/隐藏
                self.toggleSidePanel()
            else:
                # 拖动释放：执行自动吸附
                self.autoSnapToEdge()
            self.drag_position = None
            event.accept()

    def checkEdgeSnap(self, _pos):
        """检测是否靠近屏幕边缘，实现自动半隐藏"""
        # 靠屏幕左边缘的目标：半隐藏 => 窗口左上角 x = screen_left - width/2
        screen_left = QApplication.primaryScreen().availableGeometry().left()
        cur_x = self.x()  # 当前窗口左上角 x（全局坐标）
        cur_y = self.y()

        if cur_x <= screen_left + self.edge_sensitivity:
            target_x = int(screen_left - self.width() // 2)
            self.move(target_x, cur_y)
            self.auto_hidden = True
        else:
            self.auto_hidden = False

    def autoSnapToEdge(self):
        """自动吸附到左边缘（半隐藏状态）"""
        # 无条件吸附到左边缘（只露出一半）
        self.animateToLeftHalf()
        self.auto_hidden = True

    def snapToLeftHalfOnStartup(self):
        """启动时直接定位到左边缘半隐藏位置"""
        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_x = screen_geo.left() - self.width() // 2  # 左边缘半隐藏
        self.move(target_x, self.y())

    def animateToLeftHalf(self, y=None, duration=220):
        """
        平滑动画移动到左边缘半隐藏位置
        :param y: 目标Y坐标，默认使用当前Y坐标
        :param duration: 动画持续时间（毫秒）
        """
        screen_geo = QApplication.primaryScreen().availableGeometry()
        target_x = int(screen_geo.left() - self.width() // 2)
        if y is None:
            y = self.y()

        target_pos = QPoint(target_x, y)

        # 创建属性动画，实现平滑移动
        anim = QPropertyAnimation(self, b"pos", self)
        anim.setDuration(duration)
        anim.setEasingCurve(QEasingCurve.OutCubic)  # 使用OutCubic缓动曲线，先快后慢
        anim.setStartValue(self.pos())
        anim.setEndValue(target_pos)

        # 防止动画被垃圾回收导致不执行：保存引用
        self._snap_anim = anim
        anim.start()

    def toggleSidePanel(self):
        """点击胶囊时切换侧边面板的显示/隐藏"""
        if self._side_panel is not None and self._side_panel.isVisible():
            # 面板已显示则关闭
            self._side_panel.close()
            self._side_panel = None
        else:
            # 创建并显示新的侧边面板
            self._side_panel = SidePanelWidget()
            self._side_panel.show()


class SidePanelWidget(QMainWindow):
    """
    侧边面板窗口：点击胶囊时显示
    - 无边框、透明背景、始终置顶
    - 大小：屏幕高度的80% × 屏幕宽度的25%
    - 固定紧贴屏幕左边框
    - 显示 dist/index.html
    """
    def __init__(self):
        super().__init__()
        self._initWindow()
        self._initWebEngine()

    def _initWindow(self):
        """初始化窗口属性和尺寸位置"""
        # 无边框、透明背景、始终置顶（与胶囊窗口一致）
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # 获取屏幕逻辑分辨率（availableGeometry 已经是逻辑像素，包含系统缩放）
        screen = QApplication.primaryScreen()
        screen_geo = screen.availableGeometry()

        # 大窗口直接用逻辑像素计算，不再二次除以 devicePixelRatio
        # 窗口大小：屏幕高度的80% × 屏幕宽度的25%
        target_width = int(screen_geo.width() * 0.25)
        target_height = int(screen_geo.height() * 0.9)
        self.setFixedSize(target_width, target_height)

        # 距左边框留出 5% 屏幕宽度的空间，垂直居中（同样使用逻辑像素）
        left_margin = int(screen_geo.width() * 0.01)
        target_x = screen_geo.left() + left_margin
        target_y = screen_geo.top() + (screen_geo.height() - target_height) // 2
        self.move(target_x, target_y)

    def _initWebEngine(self):
        """初始化 WebEngineView 并加载 dist/index.html"""
        from PySide6.QtWebEngineWidgets import QWebEngineView

        self.web_view = QWebEngineView(self)
        self.web_view.setAttribute(Qt.WA_TranslucentBackground)
        # 不忽略鼠标事件（面板内容需要交互）
        self.web_view.page().setBackgroundColor(Qt.transparent)
        self.setCentralWidget(self.web_view)
        self.web_view.resize(self.size())

        # 加载 dist/index.html
        html_path = os.path.join(os.path.dirname(__file__),'pyisland_sideV', 'dist', 'index.html')
        self.web_view.load(QUrl.fromLocalFile(html_path))

if __name__ == '__main__':
    app = QApplication(sys.argv)
    
    # 设置应用程序样式
    app.setStyle('Fusion')
    
    # 创建并显示窗口
    widget = CapsuleWidget()
    widget.show()
    
    sys.exit(app.exec())