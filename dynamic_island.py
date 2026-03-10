import sys

import psutil
import threading
import os
import time
from datetime import datetime
from PyQt5.QtWidgets import QApplication, QWidget, QLabel, QHBoxLayout, QShortcut
from PyQt5.QtCore import Qt, QTimer, QPoint, QPointF, QPropertyAnimation, QEasingCurve, QThread, pyqtSignal, pyqtProperty, QRect
from PyQt5.QtGui import QPainter, QColor, QFont, QRadialGradient, QPixmap
from PyQt5.QtGui import QFont, QColor, QPalette, QPainter, QBrush, QPen, QRegion, QKeySequence

# 尝试导入屏幕录制所需的库
try:
    import mss
    from PIL import Image
    import cv2
    import numpy as np
    has_screen_recorder = True
except ImportError:
    has_screen_recorder = False
    print("未找到mss、pillow或opencv模块，屏幕录制功能不可用")

# 尝试导入音乐工具模块
try:
    import music_utils
    has_music_utils = True
except ImportError:
    has_music_utils = False
    print("未找到music_utils模块，将使用模拟音乐数据")

# 尝试导入音量控制模块
try:
    import volume_utils
    has_volume_utils = True
except ImportError:
    has_volume_utils = False
    print("未找到volume_utils模块，音量控制功能不可用")

# 尝试导入亮度控制模块
try:
    import brightness_utils
    has_brightness_utils = True
except ImportError:
    has_brightness_utils = False
    print("未找到brightness_utils模块，亮度控制功能不可用")

# 尝试导入手势识别和截屏模块
try:
    import mediapipe as mp
    import pyautogui
    has_gesture_screenshot = False  # 默认不开启手势截屏功能
except ImportError:
    has_gesture_screenshot = False
    print("未找到mediapipe或pyautogui模块，手势截屏功能不可用")



# 屏幕录制线程类，用于后台录制屏幕
class ScreenRecorderThread(QThread):
    recording_stopped = pyqtSignal()  # 录制停止信号
    
    def __init__(self):
        super().__init__()
        self.running = False
        self.filename = None
        self.video_folder = "recordings"  # 视频保存目录
        self.video_writer = None
        self.frame_count = 0
        self.start_time = None
        
        # 创建视频保存目录
        if not os.path.exists(self.video_folder):
            os.makedirs(self.video_folder)
    
    def run(self):
        self.running = True
        
        # 使用当前时间生成文件名
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.filename = os.path.join(self.video_folder, f"recording_{timestamp}.mp4")
        
        try:
            # 开始录制视频
            with mss.mss() as sct:
                # 获取主显示器的屏幕尺寸
                monitor = sct.monitors[1]  # 1表示主显示器
                
                # 获取屏幕尺寸
                screen_width = monitor["width"]
                screen_height = monitor["height"]
                
                # 画质优化：提高分辨率以提高画质
                # 提供多种画质选项，默认使用高质量（75%分辨率）
                quality_options = {
                    "high": 0.9,    # 高质量：90%分辨率
                    "medium": 0.75, # 中等质量：75%分辨率
                    "low": 0.5      # 低质量：50%分辨率（原设置）
                }
                
                # 使用中等质量以获得更好的画质和性能平衡
                scale_factor = quality_options["medium"]
                video_width = int(screen_width * scale_factor)
                video_height = int(screen_height * scale_factor)
                
                # 确保宽高为偶数（某些编码器要求）
                if video_width % 2 != 0:
                    video_width -= 1
                if video_height % 2 != 0:
                    video_height -= 1
                
                print(f"录制分辨率: {video_width}x{video_height} (原始: {screen_width}x{screen_height})")
                
                # 设置视频编码器和参数 - 使用MP4兼容的编码器
                # 优先使用H.264编码器，提供更好的画质和压缩比
                fourcc_options = [
                    cv2.VideoWriter_fourcc(*'X264'),  # H.264编码（最佳画质）
                    cv2.VideoWriter_fourcc(*'avc1'),  # H.264编码的另一种形式
                    cv2.VideoWriter_fourcc(*'mp4v'),  # MPEG-4编码
                    cv2.VideoWriter_fourcc(*'MJPG')   # 备用编码器
                ]
                
                fourcc = None
                for codec in fourcc_options:
                    try:
                        # 测试编码器是否可用
                        test_writer = cv2.VideoWriter('test.mp4', codec, 30, (video_width, video_height))
                        if test_writer.isOpened():
                            test_writer.release()
                            fourcc = codec
                            print(f"使用编码器: {codec}")
                            break
                    except:
                        continue
                
                if fourcc is None:
                    print("警告：未找到合适的MP4编码器，使用默认编码器")
                    fourcc = cv2.VideoWriter_fourcc(*'MJPG')
                
                fps = 60  # 帧率提升到60fps
                
                # 创建视频写入器，并尝试设置画质参数
                self.video_writer = cv2.VideoWriter(self.filename, fourcc, fps, (video_width, video_height))
                
                # 尝试设置编码器参数以提高画质
                try:
                    # 对于H.264编码器，设置CRF（恒定质量）参数
                    if fourcc in [cv2.VideoWriter_fourcc(*'X264'), cv2.VideoWriter_fourcc(*'avc1')]:
                        # CRF值越小，画质越好（18-23是推荐范围）
                        self.video_writer.set(cv2.VIDEOWRITER_PROP_QUALITY, 90)  # 设置画质为90%
                        print("H.264编码器画质参数已设置")
                    elif fourcc == cv2.VideoWriter_fourcc(*'mp4v'):
                        # MPEG-4编码器设置画质参数
                        self.video_writer.set(cv2.VIDEOWRITER_PROP_QUALITY, 90)
                        print("MPEG-4编码器画质参数已设置")
                except Exception as e:
                    print(f"编码器参数设置失败: {e}")
                
                if not self.video_writer.isOpened():
                    print("无法创建视频文件")
                    self.running = False
                    return
                
                print(f"开始录制视频: {self.filename}")
                
                # 性能监控
                import time
                self.start_time = time.time()
                self.frame_count = 0
                
                # 持续录制
                while self.running:
                    # 性能优化：记录帧开始时间
                    frame_start = time.time()
                    
                    # 截取屏幕 - 使用更高效的捕获方法
                    screenshot = sct.grab(monitor)
                    
                    # 性能优化：直接使用numpy数组，避免不必要的转换
                    # 直接从mss的BGRA格式转换为BGR，减少转换步骤
                    frame = np.frombuffer(screenshot.bgra, dtype=np.uint8)
                    frame = frame.reshape((screenshot.height, screenshot.width, 4))
                    frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
                    
                    # 调整分辨率到目标尺寸，使用高质量插值算法
                    frame = cv2.resize(frame, (video_width, video_height), interpolation=cv2.INTER_LANCZOS4)
                    
                    # 写入视频帧
                    self.video_writer.write(frame)
                    
                    # 帧计数和性能监控
                    self.frame_count += 1
                    
                    # 控制帧率，使用更精确的时间控制
                    frame_time = (time.time() - frame_start) * 1000  # 转换为毫秒
                    target_frame_time = 1000.0 / fps
                    sleep_time = max(0, int(target_frame_time - frame_time))
                    if sleep_time > 0:
                        self.msleep(sleep_time)
                    
        except Exception as e:
            print(f"屏幕录制失败: {e}")
        finally:
            # 确保视频写入器被正确释放
            if self.video_writer:
                self.video_writer.release()
                
                # 输出性能统计
                if self.start_time and self.frame_count > 0:
                    total_time = time.time() - self.start_time
                    actual_fps = self.frame_count / total_time
                    print(f"视频录制完成: {self.filename}")
                    print(f"录制统计: {self.frame_count} 帧, {total_time:.2f} 秒, 实际帧率: {actual_fps:.1f} fps")
                else:
                    print(f"视频录制完成: {self.filename}")
        
        self.recording_stopped.emit()
    
    def stop_recording(self):
        self.running = False
        # 等待录制线程完成
        if self.isRunning():
            self.wait(5000)  # 最多等待5秒

# 手势识别线程类，用于后台检测手抓握手势
class GestureRecognitionThread(QThread):
    gesture_detected = pyqtSignal(str)  # 信号：发送检测到的手势类型
    gesture_trajectory = pyqtSignal(list)  # 信号：发送手势轨迹数据
    
    def __init__(self):
        super().__init__()
        self.running = True
        self.gesture_enabled = False
        self.joint_movement_threshold = 5.0  # 关节移动阈值
        
        # 先进手势识别功能初始化
        self.gesture_trajectory_data = []  # 手势轨迹数据
        self.max_trajectory_length = 50  # 最大轨迹长度
        self.multi_hand_tracking = False  # 多手势追踪
        self.adaptive_learning_enabled = True  # 自适应学习
        
        # 手势学习数据
        self.gesture_patterns = {
            'grab': {'count': 0, 'confidence': 0.0, 'features': []},
            'fist': {'count': 0, 'confidence': 0.0, 'features': []},
            'open': {'count': 0, 'confidence': 0.0, 'features': []}
        }
        
        # 手势轨迹分析
        self.trajectory_analysis = {
            'speed': 0.0,
            'direction': 0.0,
            'smoothness': 0.0
        }
        
    def run(self):
        # 检查手势识别是否被用户启用
        if not self.gesture_enabled:
            return
            
        # 优化手势识别：使用更可靠的手部检测和跟踪算法
        # 打开摄像头
        cap = cv2.VideoCapture(0)
        
        # 检查摄像头是否成功打开
        if not cap.isOpened():
            print("❌ 无法打开摄像头，手势识别功能不可用")
            return
        
        print("✅ 摄像头已成功打开")
        
        # 设置摄像头参数
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)  # 设置帧率
        
        # 手势检测状态
        grab_detected = False
        grab_start_time = 0
        consecutive_hand_frames = 0  # 连续检测到手部的帧数
        consecutive_grab_frames = 0  # 连续检测到抓握手势的帧数
        no_hand_frames = 0  # 连续未检测到手部的帧数
        
        # 优化手势检测参数（平衡准确性和响应速度）
        min_consecutive_frames = 8  # 适当减少连续检测帧数要求，提高响应速度
        max_no_hand_frames = 8  # 增加允许的连续未检测帧数，提高稳定性
        min_grab_duration = 0.8  # 适当减少抓握手势持续时间要求，提高响应速度
        
        # 自适应参数调整
        frame_count = 0
        adaptive_threshold = 800  # 降低自适应面积阈值，提高灵敏度
        
        # 优化的手势检测逻辑（更智能的阈值）
        gesture_confidence = 0.0  # 手势置信度（0.0-1.0）
        min_confidence_threshold = 0.55  # 进一步降低最小置信度阈值，提高检测率
        confidence_increase_rate = 0.15  # 提高置信度增加率，加快检测
        confidence_decay_rate = 0.08  # 降低置信度衰减率，保持检测状态
        
        # 手掌关节识别参数（暂时禁用复杂关节检测）
        joint_detection_enabled = False  # 禁用关节检测以简化逻辑
        
        # 手部跟踪状态
        hand_tracking_enabled = True
        hand_position_history = []
        max_tracking_history = 10  # 增加跟踪历史长度，提高稳定性
        
        # 手势历史追踪（优化稳定性检测）
        gesture_type_history = []
        max_gesture_history = 20  # 增加历史长度，提高稳定性判断准确性
        stability_window_size = 6  # 适当增加稳定性窗口大小，平衡响应速度和稳定性
        gesture_stability_threshold = 0.5  # 进一步降低稳定性阈值，提高检测率
        
        # 先进手势识别功能初始化
        hand_positions = []  # 手部位置历史
        gesture_trajectory = []  # 手势轨迹
        multi_hand_data = []  # 多手势数据
        
        # 自适应学习参数
        learning_rate = 0.1  # 学习率
        confidence_threshold = 0.7  # 置信度阈值
        
        # 手势轨迹分析参数
        trajectory_smoothing = 0.8  # 轨迹平滑系数
        min_trajectory_length = 5  # 最小轨迹长度

        while self.running and self.gesture_enabled:
            success, image = cap.read()
            if not success:
                continue
                
            frame_count += 1
            
            # 转换图像格式
            image = cv2.cvtColor(cv2.flip(image, 1), cv2.COLOR_BGR2RGB)
            
            # 低光照优化：图像增强和亮度补偿
            # 计算图像平均亮度
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            avg_brightness = np.mean(gray)
            
            # 自适应亮度补偿（针对低光照条件）
            if avg_brightness < 60:  # 极低光照条件
                # 使用多阶段图像增强算法
                # 1. 伽马校正增强暗部细节
                gamma = 0.5  # 更强的伽马校正
                inv_gamma = 1.0 / gamma
                table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
                enhanced_image = cv2.LUT(image, table)
                
                # 2. 对比度和亮度增强
                alpha = 1.8  # 更强的对比度增强
                beta = 40    # 更强的亮度增强
                enhanced_image = cv2.convertScaleAbs(enhanced_image, alpha=alpha, beta=beta)
                
                # 3. 直方图均衡化增强对比度
                enhanced_image_yuv = cv2.cvtColor(enhanced_image, cv2.COLOR_RGB2YUV)
                enhanced_image_yuv[:,:,0] = cv2.equalizeHist(enhanced_image_yuv[:,:,0])
                enhanced_image = cv2.cvtColor(enhanced_image_yuv, cv2.COLOR_YUV2RGB)
                
                # 4. 双边滤波去除噪声同时保留边缘
                enhanced_image = cv2.bilateralFilter(enhanced_image, 9, 75, 75)
                
                processing_image = enhanced_image
                print(f"极低光照检测：平均亮度{avg_brightness:.1f}，已启用高级图像增强")
            elif avg_brightness < 80:  # 低光照条件
                # 使用伽马校正增强图像
                gamma = 0.6  # 伽马值小于1增强暗部
                inv_gamma = 1.0 / gamma
                table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
                enhanced_image = cv2.LUT(image, table)
                
                # 对比度增强
                alpha = 1.5  # 对比度增强系数
                beta = 30    # 亮度增强
                enhanced_image = cv2.convertScaleAbs(enhanced_image, alpha=alpha, beta=beta)
                
                # 使用高斯滤波去除噪声
                enhanced_image = cv2.GaussianBlur(enhanced_image, (5, 5), 0)
                
                # 使用增强后的图像进行肤色检测
                processing_image = enhanced_image
                print(f"低光照检测：平均亮度{avg_brightness:.1f}，已启用图像增强")
            else:
                # 正常光照下使用轻微噪声抑制
                processing_image = cv2.GaussianBlur(image, (3, 3), 0)
            
            # 改进的肤色检测：使用更可靠的肤色检测算法
            # 转换为HSV颜色空间进行肤色检测
            hsv = cv2.cvtColor(processing_image, cv2.COLOR_RGB2HSV)
            
            # 转换为YCrCb颜色空间（对光照变化更鲁棒）
            ycrcb = cv2.cvtColor(processing_image, cv2.COLOR_RGB2YCrCb)
            
            # 自适应肤色检测范围（根据光照条件调整）
            if avg_brightness < 60:  # 极低光照条件
                # 极低光照下的优化肤色范围
                lower_skin_hsv = np.array([0, 15, 25], dtype=np.uint8)   # 进一步降低阈值
                upper_skin_hsv = np.array([35, 220, 220], dtype=np.uint8) # 扩大色调和饱和度范围
                
                lower_skin_ycrcb = np.array([0, 110, 60], dtype=np.uint8)  # 调整YCrCb范围
                upper_skin_ycrcb = np.array([220, 170, 130], dtype=np.uint8)
            elif avg_brightness < 80:  # 低光照条件
                # 低光照下的优化肤色范围
                lower_skin_hsv = np.array([0, 20, 30], dtype=np.uint8)   # 降低饱和度和亮度阈值
                upper_skin_hsv = np.array([30, 200, 200], dtype=np.uint8) # 扩大色调范围
                
                lower_skin_ycrcb = np.array([0, 120, 70], dtype=np.uint8)  # 调整YCrCb范围
                upper_skin_ycrcb = np.array([200, 160, 120], dtype=np.uint8)
            else:
                # 正常光照下的肤色范围
                lower_skin_hsv = np.array([0, 30, 60], dtype=np.uint8)
                upper_skin_hsv = np.array([25, 180, 255], dtype=np.uint8)
                
                lower_skin_ycrcb = np.array([0, 135, 85], dtype=np.uint8)
                upper_skin_ycrcb = np.array([255, 180, 135], dtype=np.uint8)
            
            # 创建肤色掩码
            mask_hsv = cv2.inRange(hsv, lower_skin_hsv, upper_skin_hsv)
            mask_ycrcb = cv2.inRange(ycrcb, lower_skin_ycrcb, upper_skin_ycrcb)
            
            # 组合HSV和YCrCb掩码，提高检测准确性
            mask = cv2.bitwise_or(mask_hsv, mask_ycrcb)
            
            # 自适应形态学操作：根据光照条件调整参数
            if avg_brightness < 60:  # 极低光照条件
                # 更强的噪声抑制和空洞填充
                kernel_open = np.ones((2, 2), np.uint8)  # 更小的开运算核，保留更多细节
                kernel_close = np.ones((7, 7), np.uint8)  # 更大的闭运算核，更好填充空洞
                
                mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)  # 去除噪声
                mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)  # 填充空洞
                mask = cv2.medianBlur(mask, 7)  # 更强的中值滤波
                mask = cv2.GaussianBlur(mask, (7, 7), 0)  # 更强的高斯模糊
            elif avg_brightness < 80:  # 低光照条件
                # 中等强度的噪声抑制
                kernel_open = np.ones((3, 3), np.uint8)
                kernel_close = np.ones((5, 5), np.uint8)
                
                mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)  # 去除噪声
                mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)  # 填充空洞
                mask = cv2.medianBlur(mask, 5)  # 中值滤波去除噪声
                mask = cv2.GaussianBlur(mask, (5, 5), 0)  # 高斯模糊平滑边缘
            else:
                # 正常光照下的标准处理
                kernel_open = np.ones((3, 3), np.uint8)
                kernel_close = np.ones((5, 5), np.uint8)
                
                mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)  # 去除噪声
                mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)  # 填充空洞
                mask = cv2.medianBlur(mask, 3)  # 轻微的中值滤波
                mask = cv2.GaussianBlur(mask, (3, 3), 0)  # 轻微的高斯模糊
            
            # 查找轮廓
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # 改进的手部区域检测和跟踪
            hand_detected = False
            max_area = 0
            hand_contour = None
            gesture_type = "unknown"  # 手势类型：grab, open, fist, unknown
            joints = []  # 手掌关节信息
            grip_status = "no_grip"  # 抓握状态
            
            # 手部位置跟踪
            current_hand_position = None
            
            for contour in contours:
                area = cv2.contourArea(contour)
                
                # 更严格的面积过滤：手部面积通常在1000-50000像素之间
                if area > adaptive_threshold and area < 50000:  # 添加最大面积限制
                    # 计算轮廓的边界矩形
                    x, y, w, h = cv2.boundingRect(contour)
                    aspect_ratio = float(w)/h
                    
                    # 改进的手部宽高比检测
                    if 0.3 < aspect_ratio < 3.0:  # 更宽的范围以适应不同手势
                        # 计算轮廓的凸包
                        hull = cv2.convexHull(contour)
                        hull_area = cv2.contourArea(hull)
                        
                        # 计算轮廓的紧凑度（面积/凸包面积）
                        if hull_area > 0:
                            compactness = area / hull_area
                            
                            # 手部通常具有较高的紧凑度（0.5-0.9）
                            if 0.4 < compactness < 0.95:
                                hand_detected = True
                                
                                # 手势形状分析（传递光照信息）
                                gesture_type = self.analyze_gesture_shape(contour, hull, avg_brightness)
                                
                                # 手掌关节检测
                                if joint_detection_enabled:
                                    current_joints = self.detect_palm_joints(contour, hull)
                                    
                                    # 更新关节历史
                                    joint_positions_history.append(current_joints)
                                    if len(joint_positions_history) > joint_history_size:
                                        joint_positions_history.pop(0)
                                    
                                    # 分析关节移动和抓握状态
                                    if len(joint_positions_history) >= 2:
                                        movement_status = self.analyze_joint_movement(current_joints, joint_positions_history)
                                        grip_status = self.detect_grip_from_joints(current_joints)
                                        
                                        # 结合关节信息改进手势识别
                                        if grip_status == "strong_grip" and gesture_type == "grab":
                                            gesture_confidence = min(1.0, gesture_confidence + 0.2)  # 提高置信度
                                        
                                        joints = current_joints
                                
                                # 记录手部位置用于跟踪
                                if area > max_area:
                                    max_area = area
                                    hand_contour = contour
                                    current_hand_position = (x + w//2, y + h//2)  # 手部中心位置
            
            # 自适应调整阈值
            if frame_count % 30 == 0:  # 每30帧调整一次阈值
                if max_area > 0 and max_area < 50000:  # 只对合理大小的手部进行阈值调整
                    adaptive_threshold = max(500, min(2000, int(max_area * 0.4)))  # 动态调整
                else:
                    # 如果检测到异常大的面积，重置为默认阈值
                    adaptive_threshold = 1000
            
            # 手部位置跟踪逻辑
            if hand_tracking_enabled and current_hand_position is not None:
                hand_position_history.append(current_hand_position)
                if len(hand_position_history) > max_tracking_history:
                    hand_position_history.pop(0)
            
            # 手势历史追踪和模式识别
            if hand_detected:
                # 更新手势类型历史
                gesture_type_history.append(gesture_type)
                if len(gesture_type_history) > max_gesture_history:
                    gesture_type_history.pop(0)
                
                # 初始化稳定性分数为默认值
                stability_score = 0.0
                position_variance = 100.0  # 默认设置为较大的值，表示位置不稳定
                
                # 计算手势稳定性（最近N帧中相同手势的比例）
                if len(gesture_type_history) >= stability_window_size:
                    recent_gestures = gesture_type_history[-stability_window_size:]
                    stability_score = recent_gestures.count(gesture_type) / stability_window_size
            
            # 先进手势识别功能：轨迹追踪和多手势识别
            if hand_detected and current_hand_position is not None:
                # 手势轨迹追踪
                hand_positions.append(current_hand_position)
                if len(hand_positions) > self.max_trajectory_length:
                    hand_positions.pop(0)
                
                # 轨迹平滑处理
                if len(hand_positions) >= min_trajectory_length:
                    smoothed_position = self.smooth_trajectory(hand_positions, trajectory_smoothing)
                    gesture_trajectory.append(smoothed_position)
                    
                    # 轨迹分析
                    if len(gesture_trajectory) >= 3:
                        trajectory_analysis = self.analyze_trajectory(gesture_trajectory)
                        self.trajectory_analysis = trajectory_analysis
                        
                        # 发送轨迹数据
                        if len(gesture_trajectory) % 5 == 0:  # 每5帧发送一次轨迹数据
                            self.gesture_trajectory.emit(gesture_trajectory[-10:])  # 发送最近10个轨迹点
                
                # 多手势识别：检测多个手部轮廓
                if len(contours) > 1:
                    multi_hand_data = self.detect_multiple_hands(contours, adaptive_threshold)
                    if len(multi_hand_data) > 1:
                        print(f"检测到{len(multi_hand_data)}个手部，启用多手势模式")
                        self.multi_hand_tracking = True
                
                # 自适应学习：更新手势模式
                if self.adaptive_learning_enabled and gesture_type != "unknown":
                    self.update_gesture_patterns(gesture_type, {
                        'compactness': compactness,
                        'area': max_area,
                        'stability': stability_score
                    })
                    
                    # 基于稳定性更新置信度（优化灵敏度）
                    if stability_score > gesture_stability_threshold:
                        # 抓握手势时提高置信度增长
                        if gesture_type == "grab":
                            gesture_confidence = min(1.0, gesture_confidence + confidence_increase_rate * 1.5)
                        else:
                            gesture_confidence = min(1.0, gesture_confidence + confidence_increase_rate)
                    else:
                        # 降低非抓握手势的置信度衰减
                        if gesture_type != "grab":
                            gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 0.8)
                        else:
                            gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate)
                
                # 手部位置稳定性检测（优化位置变化计算）
            if len(hand_position_history) >= 3:
                # 计算手部位置的移动方差（使用更稳定的计算方法）
                positions = np.array(hand_position_history[-3:])
                
                # 计算相对位置变化而不是绝对方差
                if len(positions) >= 2:
                    # 计算连续帧之间的移动距离
                    distances = []
                    for i in range(1, len(positions)):
                        dist = np.sqrt(np.sum((positions[i] - positions[i-1])**2))
                        distances.append(dist)
                    
                    # 使用平均移动距离作为位置变化指标
                    if distances:
                        position_variance = np.mean(distances)
                    else:
                        position_variance = 0
                else:
                    position_variance = 0
                
                # 如果手部位置稳定，增加置信度（放宽位置变化限制）
                if position_variance < 100:  # 放宽位置变化限制
                    gesture_confidence = min(1.0, gesture_confidence + 0.05)
                else:
                    gesture_confidence = max(0.0, gesture_confidence - 0.02)  # 降低惩罚
                
                consecutive_hand_frames += 1
                no_hand_frames = 0
                
                # 改进的手势检测逻辑，防止误触发和漏检
                if gesture_type == "grab":
                    consecutive_grab_frames += 1
                    
                    # 增强的手部验证：检查手部面积和位置稳定性
                    hand_valid = self.validate_hand_detection(max_area, stability_score, position_variance)
                    
                    if not hand_valid:
                        # 手部验证失败，重置检测状态
                        consecutive_grab_frames = 0
                        grab_detected = False
                        print("手势检测：手部验证失败，重置检测状态")
                        continue
                    
                    # 高级触发条件：基于多因素综合评估的抓握检测
                    # 使用加权评分系统，平衡响应速度和准确性
                    trigger_score = 0.0
                    
                    # 1. 连续帧数评分（权重：0.3）
                    frame_score = min(1.0, consecutive_grab_frames / 6.0)  # 6帧为理想值
                    trigger_score += frame_score * 0.3
                    
                    # 2. 置信度评分（权重：0.3）
                    confidence_score = min(1.0, gesture_confidence / 0.6)  # 0.6为理想值
                    trigger_score += confidence_score * 0.3
                    
                    # 3. 稳定性评分（权重：0.2）
                    stability_score_normalized = min(1.0, stability_score / 0.6)  # 0.6为理想值
                    trigger_score += stability_score_normalized * 0.2
                    
                    # 4. 手部面积评分（权重：0.15）
                    area_score = 0.0
                    if 1000 <= max_area <= 20000:  # 理想手部面积范围
                        area_score = 1.0
                    elif 20000 < max_area <= 35000:  # 可接受范围
                        area_score = 0.5  # 降低权重
                    elif 35000 < max_area <= 50000:  # 边缘范围
                        area_score = 0.2  # 进一步降低权重
                    else:
                        area_score = 0.0  # 超出范围得分为0
                    trigger_score += area_score * 0.15
                    
                    # 5. 手部验证评分（权重：0.15）
                    validation_score = 1.0 if hand_valid else 0.0
                    trigger_score += validation_score * 0.15
                    
                    # 触发条件：综合评分达到阈值，且未处于检测状态
                    # 增加额外约束条件：必须满足手部验证和合理面积
                    if (trigger_score >= 0.90 and  # 进一步提高综合评分阈值，减少误触发
                        hand_valid and  # 必须通过手部验证
                        max_area >= 1000 and max_area <= 20000 and  # 必须在合理面积范围内
                        not grab_detected):
                        
                        grab_detected = True
                        grab_start_time = time.time()
                        print(f"手势检测：开始检测抓握手势，综合评分：{trigger_score:.2f}，手部面积：{max_area}，手势类型：{gesture_type}，置信度：{gesture_confidence:.2f}，稳定性：{stability_score:.2f}")
                    
                    # 如果已经检测到抓握手势，检查持续时间
                    elif grab_detected:
                        # 持续检测验证：使用更严格的验证条件
                        # 计算持续检测阶段的综合评分
                        sustain_trigger_score = 0.0
                        
                        # 持续检测阶段要求更严格
                        sustain_frame_score = min(1.0, consecutive_grab_frames / 4.0)  # 降低帧数要求
                        sustain_confidence_score = min(1.0, gesture_confidence / 0.4)  # 降低置信度要求
                        sustain_stability_score = min(1.0, stability_score / 0.4)  # 降低稳定性要求
                        
                        sustain_trigger_score = (sustain_frame_score * 0.3 + 
                                               sustain_confidence_score * 0.3 + 
                                               sustain_stability_score * 0.2 + 
                                               area_score * 0.1 + 
                                               validation_score * 0.1)
                        
                        # 持续检测验证条件
                        if (gesture_type != "grab" or 
                            sustain_trigger_score < 0.5 or  # 降低持续检测阈值
                            not hand_valid):
                            
                            grab_detected = False
                            consecutive_grab_frames = 0
                            print(f"手势检测：手势验证失败，重置检测状态（持续评分：{sustain_trigger_score:.2f}，手势类型：{gesture_type}）")
                        elif time.time() - grab_start_time > 0.7:  # 适当提高持续时间要求，提高准确性
                            self.gesture_detected.emit("grab")
                            print(f"手势检测：抓握手势已确认，执行截屏（持续评分：{sustain_trigger_score:.2f}，持续时间：{time.time() - grab_start_time:.2f}s）")
                            grab_detected = False
                            consecutive_hand_frames = 0
                            consecutive_grab_frames = 0
                            # 防止连续触发，适当等待
                            time.sleep(1.2)  # 优化等待时间，平衡响应性和防误触发
                else:
                    # 非抓握手势时，采用更智能的衰减策略，提高稳定性
                    # 容忍手势的轻微变化，避免频繁重置检测状态
                    if consecutive_grab_frames > 0:
                        # 根据手势类型决定衰减速度（优化衰减策略）
                        if gesture_type == "fist":  # 握拳手势与抓握较为相似，衰减较慢
                            consecutive_grab_frames = max(0, consecutive_grab_frames - 0.3)  # 进一步减慢衰减
                        elif gesture_type == "open":  # 张开手势与抓握差异较大，衰减较快
                            consecutive_grab_frames = max(0, consecutive_grab_frames - 1.5)  # 适度衰减
                        else:  # 未知手势，中等衰减速度
                            consecutive_grab_frames = max(0, consecutive_grab_frames - 0.8)  # 减慢衰减
                    
                    # 非抓握手势时适度降低置信度，避免过度惩罚
                    if gesture_type == "fist":
                        gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 0.8)  # 减慢衰减
                    elif gesture_type == "open":
                        gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 2.0)  # 适度衰减
                    else:
                        gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 1.5)  # 减慢衰减
                    
                    # 只有当连续多帧都不是抓握手势时才重置检测状态
                    if consecutive_grab_frames <= 0:
                        if grab_detected:
                            print(f"手势检测：手势类型变化，重置检测状态（当前手势：{gesture_type}）")
                        grab_detected = False
            else:
                no_hand_frames += 1
                consecutive_hand_frames = 0
                
                # 未检测到手部时立即重置抓握手势检测
                if grab_detected:
                    print("手势检测：手部消失，立即重置检测状态")
                grab_detected = False
                
                # 未检测到手部时快速降低置信度和连续帧计数
                gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 8)  # 进一步加快衰减
                consecutive_grab_frames = max(0, consecutive_grab_frames - 3)  # 快速衰减连续帧计数
                
                # 如果连续多帧未检测到手部，就彻底重置置信度和连续帧计数
                if no_hand_frames >= max_no_hand_frames:
                    gesture_confidence = 0.0  # 彻底重置置信度
                    consecutive_grab_frames = 0  # 彻底重置连续帧计数
            
            # 控制帧率
            time.sleep(0.03)  # 约30fps
    
    def detect_palm_joints(self, contour, hull):
        """检测手掌虚拟关节位置"""
        try:
            # 计算轮廓的质心
            M = cv2.moments(contour)
            if M["m00"] == 0:
                return []
            
            centroid_x = int(M["m10"] / M["m00"])
            centroid_y = int(M["m01"] / M["m00"])
            centroid = (centroid_x, centroid_y)
            
            # 计算轮廓的凸性缺陷
            hull_indices = cv2.convexHull(contour, returnPoints=False)
            joints = []
            
            if len(hull_indices) > 3:
                defects = cv2.convexityDefects(contour, hull_indices)
                
                if defects is not None:
                    for i in range(defects.shape[0]):
                        s, e, f, d = defects[i, 0]
                        start = tuple(contour[s][0])
                        end = tuple(contour[e][0])
                        far = tuple(contour[f][0])
                        
                        # 计算三角形边长
                        a = np.sqrt((end[0] - start[0])**2 + (end[1] - start[1])**2)
                        b = np.sqrt((far[0] - start[0])**2 + (far[1] - start[1])**2)
                        c = np.sqrt((end[0] - far[0])**2 + (end[1] - far[1])**2)
                        
                        # 计算角度
                        angle = np.arccos((b**2 + c**2 - a**2) / (2*b*c)) * 180 / np.pi if b*c > 0 else 180
                        
                        # 有效的关节点条件：角度小于90度，深度足够大
                        if angle < 90 and d > 800 and d < 3000:
                            # 计算关节点到质心的距离
                            distance_to_centroid = np.sqrt((far[0] - centroid_x)**2 + (far[1] - centroid_y)**2)
                            
                            # 添加关节信息
                            joint_info = {
                                'position': far,
                                'depth': d,
                                'angle': angle,
                                'distance_to_centroid': distance_to_centroid,
                                'type': 'finger_joint' if distance_to_centroid > 30 else 'palm_joint'
                            }
                            joints.append(joint_info)
            
            # 添加手掌中心点
            palm_joint = {
                'position': centroid,
                'depth': 0,
                'angle': 0,
                'distance_to_centroid': 0,
                'type': 'palm_center'
            }
            joints.append(palm_joint)
            
            return joints
            
        except Exception as e:
            print(f"关节检测错误: {e}")
            return []
    
    def analyze_joint_movement(self, current_joints, joint_history):
        """分析关节移动模式，识别抓握动作"""
        if len(joint_history) < 2:
            return "unknown"
        
        try:
            # 计算关节移动距离
            movement_scores = []
            
            for i, joint in enumerate(current_joints):
                if i >= len(joint_history[-1]):
                    continue
                
                prev_joint = joint_history[-1][i]
                current_pos = joint['position']
                prev_pos = prev_joint['position']
                
                # 计算移动距离
                movement = np.sqrt((current_pos[0] - prev_pos[0])**2 + (current_pos[1] - prev_pos[1])**2)
                movement_scores.append(movement)
            
            if not movement_scores:
                return "unknown"
            
            avg_movement = np.mean(movement_scores)
            
            # 分析移动模式
            if avg_movement < self.joint_movement_threshold:
                return "stable"  # 稳定状态
            elif avg_movement < self.joint_movement_threshold * 2:
                return "slight_movement"  # 轻微移动
            else:
                return "significant_movement"  # 显著移动
                
        except Exception as e:
            print(f"关节移动分析错误: {e}")
            return "unknown"
    
    def detect_grip_from_joints(self, joints):
        """基于关节位置检测抓握动作"""
        try:
            if len(joints) < 3:  # 至少需要手掌中心和两个关节点
                return "no_grip"
            
            # 分离不同类型的关节
            palm_center = None
            finger_joints = []
            palm_joints = []
            
            for joint in joints:
                if joint['type'] == 'palm_center':
                    palm_center = joint
                elif joint['type'] == 'finger_joint':
                    finger_joints.append(joint)
                else:
                    palm_joints.append(joint)
            
            if palm_center is None:
                return "no_grip"
            
            # 计算手指关节到手掌中心的平均距离
            distances = []
            for joint in finger_joints:
                distance = joint['distance_to_centroid']
                distances.append(distance)
            
            if not distances:
                return "no_grip"
            
            avg_distance = np.mean(distances)
            max_distance = np.max(distances)
            min_distance = np.min(distances)
            
            # 抓握判断逻辑
            grip_score = 0.0
            
            # 距离变化特征（抓握时手指会靠近手掌）
            if max_distance - min_distance > 20:  # 手指距离差异较大
                grip_score += 0.3
            
            # 关节数量特征
            if len(finger_joints) >= 3:  # 至少检测到3个手指关节
                grip_score += 0.4
            
            # 距离范围特征
            if 30 < avg_distance < 100:  # 合理的手指距离范围
                grip_score += 0.3
            
            # 判断抓握状态
            if grip_score > 0.7:
                return "strong_grip"
            elif grip_score > 0.4:
                return "weak_grip"
            else:
                return "no_grip"
                
        except Exception as e:
            print(f"抓握检测错误: {e}")
            return "no_grip"
    
    def analyze_gesture_shape(self, contour, hull, avg_brightness=100):
        """高级手势形状分析，结合多特征识别抓握、张开、握拳等手势"""
        try:
            # 计算轮廓面积和凸包面积
            area = cv2.contourArea(contour)
            hull_area = cv2.contourArea(hull)
            
            if hull_area == 0:
                return "unknown"
            
            # 计算紧凑度（面积/凸包面积）
            compactness = area / hull_area
            
            # 计算轮廓的周长和圆度
            perimeter = cv2.arcLength(contour, True)
            circularity = 4 * np.pi * area / (perimeter * perimeter) if perimeter > 0 else 0
            
            # 计算轮廓的边界矩形和宽高比
            x, y, w, h = cv2.boundingRect(contour)
            aspect_ratio = float(w) / h if h > 0 else 0
            rect_area = w * h
            extent = float(area) / rect_area if rect_area > 0 else 0
            
            # 计算轮廓的凸性缺陷
            hull_indices = cv2.convexHull(contour, returnPoints=False)
            finger_count = 0
            avg_defect_depth = 0
            
            if len(hull_indices) > 3:
                defects = cv2.convexityDefects(contour, hull_indices)
                
                if defects is not None:
                    valid_defects = []
                    for i in range(defects.shape[0]):
                        s, e, f, d = defects[i, 0]
                        start = tuple(contour[s][0])
                        end = tuple(contour[e][0])
                        far = tuple(contour[f][0])
                        
                        # 计算三角形边长
                        a = np.sqrt((end[0] - start[0])**2 + (end[1] - start[1])**2)
                        b = np.sqrt((far[0] - start[0])**2 + (far[1] - start[1])**2)
                        c = np.sqrt((end[0] - far[0])**2 + (end[1] - far[1])**2)
                        
                        # 计算角度
                        angle = np.arccos((b**2 + c**2 - a**2) / (2*b*c)) * 180 / np.pi if b*c > 0 else 180
                        
                        # 改进的凸性缺陷条件：角度、深度和距离综合判断
                        if angle < 90 and d > 800 and d < 3000:  # 优化深度阈值范围
                            valid_defects.append((angle, d))
                            finger_count += 1
                    
                    # 计算平均缺陷深度
                    if valid_defects:
                        avg_defect_depth = np.mean([d for _, d in valid_defects])
            
            # 高级手势分类算法：基于多特征加权评分和机器学习启发式方法
            
            # 优化特征权重分配 - 更注重紧凑度和手指数量，提高抓握识别精度
            compactness_weight = 0.50
            finger_count_weight = 0.30
            extent_weight = 0.12
            circularity_weight = 0.08
            
            # 计算各手势类型的得分
            grab_score = 0.0
            fist_score = 0.0
            open_score = 0.0
            
            # 高级抓握手势评分：使用非线性评分函数提高准确性
            # 紧凑度评分：抓握手势通常在0.5-0.7之间
            if 0.48 <= compactness <= 0.68:  # 更精确的紧凑度范围
                grab_score += compactness_weight * 1.0
            elif 0.42 <= compactness <= 0.72:  # 扩展范围但降低权重
                grab_score += compactness_weight * 0.7
            elif 0.38 <= compactness <= 0.76:  # 更宽范围作为参考
                grab_score += compactness_weight * 0.4
                
            # 手指数量评分：抓握手势通常有2-3个可见手指
            if 2 <= finger_count <= 3:  # 理想范围
                grab_score += finger_count_weight * 1.0
            elif 1 <= finger_count <= 4:  # 可接受范围
                grab_score += finger_count_weight * 0.8
            elif finger_count == 0 or finger_count == 5:  # 边缘情况
                grab_score += finger_count_weight * 0.3
                
            # 范围评分：抓握手势通常有中等范围值
            if 0.58 <= extent <= 0.78:  # 更精确的范围
                grab_score += extent_weight * 1.0
            elif 0.52 <= extent <= 0.82:  # 扩展范围
                grab_score += extent_weight * 0.7
            elif 0.48 <= extent <= 0.86:  # 更宽范围
                grab_score += extent_weight * 0.4
                
            # 圆度评分：抓握手势通常有中等圆度
            if 0.28 <= circularity <= 0.58:  # 更精确的圆度范围
                grab_score += circularity_weight * 1.0
            elif 0.22 <= circularity <= 0.62:  # 扩展范围
                grab_score += circularity_weight * 0.6
            
            # 握拳手势评分（高紧凑度，少手指）
            if compactness > 0.72:  # 提高紧凑度阈值，减少与抓握的混淆
                fist_score += compactness_weight * 1.0
            elif compactness > 0.68:  # 边缘情况
                fist_score += compactness_weight * 0.7
            if finger_count <= 1:  # 握拳通常只有0-1个可见手指
                fist_score += finger_count_weight * 1.0
            elif finger_count <= 2:  # 可接受范围
                fist_score += finger_count_weight * 0.6
            if extent > 0.75:  # 提高范围阈值
                fist_score += extent_weight * 0.9
            elif extent > 0.7:  # 边缘情况
                fist_score += extent_weight * 0.5
            if circularity > 0.45:  # 提高圆度阈值
                fist_score += circularity_weight * 0.8
            elif circularity > 0.4:  # 边缘情况
                fist_score += circularity_weight * 0.4
            
            # 张开手势评分（低紧凑度，多手指）
            if compactness < 0.45:  # 降低紧凑度阈值，更容易识别张开手势
                open_score += compactness_weight * 1.0
            elif compactness < 0.52:  # 中等偏低紧凑度
                open_score += compactness_weight * 0.7
            elif compactness < 0.58:  # 边缘情况
                open_score += compactness_weight * 0.3
            if finger_count >= 3:  # 张开手势通常有3-5个手指
                open_score += finger_count_weight * 1.0
            elif finger_count >= 2:  # 可接受范围
                open_score += finger_count_weight * 0.7
            if extent < 0.65:  # 降低范围阈值
                open_score += extent_weight * 0.9
            elif extent < 0.72:  # 边缘情况
                open_score += extent_weight * 0.5
            if circularity < 0.6:  # 降低圆度阈值
                open_score += circularity_weight * 0.8
            elif circularity < 0.65:  # 边缘情况
                open_score += circularity_weight * 0.4
            
            # 高级手势选择算法：考虑特征之间的相关性
            scores = {"grab": grab_score, "fist": fist_score, "open": open_score}
            max_gesture = max(scores, key=scores.get)
            max_score = scores[max_gesture]
            
            # 动态置信度阈值：根据特征一致性调整
            score_variance = np.var(list(scores.values()))
            dynamic_threshold = 0.35 + (0.15 * (1 - score_variance))  # 特征越一致，阈值越低
            
            # 置信度阈值检查
            if max_score > dynamic_threshold:
                # 额外检查：如果抓握得分接近握拳，优先选择抓握
                if max_gesture == "fist" and grab_score > max_score * 0.8:
                    return "grab"
                return max_gesture
            else:
                # 低置信度时使用紧凑度和手指数量作为主要判断依据
                if compactness > 0.68 and finger_count <= 2:
                    return "fist"
                elif compactness < 0.48 and finger_count >= 2:
                    return "open"
                elif 0.5 <= compactness <= 0.7 and 1 <= finger_count <= 3:
                    return "grab"
                else:
                    return "unknown"
                
        except Exception as e:
            print(f"手势形状分析错误: {e}")
            return "unknown"
    
    def validate_hand_detection(self, hand_area, stability_score, position_variance):
        """高级手部检测验证：基于多因素综合评估，提高抓握检测准确度"""
        try:
            # 1. 基础验证：快速排除明显不合理的检测
            if hand_area < 800 or hand_area > 45000:  # 进一步缩小面积范围，提高准确性
                print(f"手部验证失败：面积{hand_area}超出合理范围")
                return False
            
            if stability_score < 0.35:  # 进一步提高稳定性阈值，减少误触发
                print(f"手部验证失败：稳定性{stability_score:.2f}过低")
                return False
            
            if position_variance > 180:  # 进一步缩小位置变化限制，提高稳定性
                print(f"手部验证失败：位置变化{position_variance:.1f}过大")
                return False
            
            # 2. 高级综合评分系统：使用非线性评分函数
            validation_score = 0.0
            
            # 面积评分：使用高斯函数进行非线性评分
            ideal_area = 12000  # 理想手部面积
            area_std = 8000     # 标准差
            area_gaussian = np.exp(-((hand_area - ideal_area) ** 2) / (2 * area_std ** 2))
            area_score = area_gaussian * 0.8 + 0.2  # 确保最低分数为0.2
            
            # 稳定性评分：使用S型函数进行非线性评分
            stability_threshold = 0.5
            stability_steepness = 10.0
            stability_sigmoid = 1.0 / (1.0 + np.exp(-stability_steepness * (stability_score - stability_threshold)))
            stability_score_normalized = stability_sigmoid * 0.9 + 0.1  # 确保最低分数为0.1
            
            # 位置稳定性评分：使用指数衰减函数
            position_ideal = 50  # 理想位置变化
            position_decay = 0.02  # 衰减系数
            position_score = np.exp(-position_decay * max(0, position_variance - position_ideal))
            
            # 3. 特征一致性检查：确保各特征之间的一致性
            consistency_penalty = 0.0
            
            # 检查面积与稳定性的相关性：大面积手部应该更稳定
            if hand_area > 20000 and stability_score < 0.4:
                consistency_penalty += 0.1
            
            # 检查位置变化与稳定性的相关性：位置变化大时稳定性应较低
            if position_variance > 100 and stability_score > 0.7:
                consistency_penalty += 0.1
            
            # 4. 综合评分：使用动态权重分配
            # 根据手部面积动态调整权重
            if hand_area < 5000:  # 小面积手部，更注重稳定性
                area_weight = 0.25
                stability_weight = 0.45
                position_weight = 0.30
            elif hand_area > 25000:  # 大面积手部，更注重位置稳定性
                area_weight = 0.30
                stability_weight = 0.35
                position_weight = 0.35
            else:  # 中等面积手部，平衡权重
                area_weight = 0.35
                stability_weight = 0.40
                position_weight = 0.25
            
            # 计算综合评分
            validation_score = (area_score * area_weight + 
                              stability_score_normalized * stability_weight + 
                              position_score * position_weight - 
                              consistency_penalty)
            
            # 5. 动态阈值：根据手部特征调整验证阈值
            dynamic_threshold = 0.65  # 基础阈值
            
            # 大面积手部需要更高的验证分数
            if hand_area > 20000:
                dynamic_threshold += 0.05
            
            # 低稳定性需要更高的验证分数
            if stability_score < 0.5:
                dynamic_threshold += 0.05
            
            # 高位置变化需要更高的验证分数
            if position_variance > 80:
                dynamic_threshold += 0.05
            
            # 最终验证决策
            if validation_score >= dynamic_threshold:
                print(f"手部验证通过：综合评分{validation_score:.2f} (面积:{area_score:.2f}, 稳定性:{stability_score_normalized:.2f}, 位置:{position_score:.2f}, 动态阈值:{dynamic_threshold:.2f})")
                return True
            else:
                print(f"手部验证失败：综合评分{validation_score:.2f} (面积:{area_score:.2f}, 稳定性:{stability_score_normalized:.2f}, 位置:{position_score:.2f}, 动态阈值:{dynamic_threshold:.2f})")
                return False
                
        except Exception as e:
            print(f"手部验证错误: {e}")
            return False
    
    def start_gesture_recognition(self):
        self.gesture_enabled = True
        if not self.isRunning():
            self.start()
    
    def stop_gesture_recognition(self):
        self.gesture_enabled = False
    
    # ========== 先进手势识别功能 ==========
    
    def smooth_trajectory(self, positions, smoothing_factor=0.8):
        """轨迹平滑处理：使用指数加权移动平均"""
        if len(positions) < 2:
            return positions[-1] if positions else (0, 0)
        
        smoothed_x, smoothed_y = positions[-1]
        
        # 指数加权移动平均
        for i in range(len(positions) - 2, -1, -1):
            x, y = positions[i]
            smoothed_x = smoothing_factor * smoothed_x + (1 - smoothing_factor) * x
            smoothed_y = smoothing_factor * smoothed_y + (1 - smoothing_factor) * y
        
        return (int(smoothed_x), int(smoothed_y))
    
    def analyze_trajectory(self, trajectory):
        """分析手势轨迹：速度、方向和平滑度"""
        if len(trajectory) < 3:
            return {'speed': 0.0, 'direction': 0.0, 'smoothness': 0.0}
        
        try:
            # 计算速度（像素/帧）
            speeds = []
            for i in range(1, len(trajectory)):
                x1, y1 = trajectory[i-1]
                x2, y2 = trajectory[i]
                distance = np.sqrt((x2 - x1)**2 + (y2 - y1)**2)
                speeds.append(distance)
            
            avg_speed = np.mean(speeds) if speeds else 0.0
            
            # 计算方向（角度）
            if len(trajectory) >= 2:
                x1, y1 = trajectory[0]
                x2, y2 = trajectory[-1]
                dx = x2 - x1
                dy = y2 - y1
                direction = np.arctan2(dy, dx) * 180 / np.pi  # 转换为角度
            else:
                direction = 0.0
            
            # 计算平滑度（速度变化的标准差）
            smoothness = 1.0 / (1.0 + np.std(speeds)) if speeds else 0.0
            
            return {
                'speed': avg_speed,
                'direction': direction,
                'smoothness': smoothness
            }
            
        except Exception as e:
            print(f"轨迹分析错误: {e}")
            return {'speed': 0.0, 'direction': 0.0, 'smoothness': 0.0}
    
    def detect_multiple_hands(self, contours, area_threshold):
        """检测多个手部轮廓"""
        hands = []
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            if area > area_threshold and area < 50000:
                # 计算轮廓特征
                x, y, w, h = cv2.boundingRect(contour)
                aspect_ratio = float(w) / h if h > 0 else 0
                
                # 手部特征验证
                if 0.3 < aspect_ratio < 3.0:
                    hull = cv2.convexHull(contour)
                    hull_area = cv2.contourArea(hull)
                    
                    if hull_area > 0:
                        compactness = area / hull_area
                        
                        if 0.4 < compactness < 0.95:
                            hand_info = {
                                'position': (x + w//2, y + h//2),
                                'area': area,
                                'aspect_ratio': aspect_ratio,
                                'compactness': compactness
                            }
                            hands.append(hand_info)
        
        # 按面积排序
        hands.sort(key=lambda x: x['area'], reverse=True)
        return hands
    
    def update_gesture_patterns(self, gesture_type, features):
        """自适应学习：更新手势模式"""
        if gesture_type not in self.gesture_patterns:
            return
        
        pattern = self.gesture_patterns[gesture_type]
        pattern['count'] += 1
        
        # 更新特征平均值
        if not pattern['features']:
            pattern['features'] = features.copy()
        else:
            # 指数移动平均更新
            for key in features:
                if key in pattern['features']:
                    pattern['features'][key] = 0.9 * pattern['features'][key] + 0.1 * features[key]
                else:
                    pattern['features'][key] = features[key]
        
        # 更新置信度
        pattern['confidence'] = min(1.0, pattern['count'] / 100.0)
        
        # 每10次学习打印一次进度
        if pattern['count'] % 10 == 0:
            print(f"手势学习进度 - {gesture_type}: 次数={pattern['count']}, 置信度={pattern['confidence']:.2f}")
    
    def get_gesture_prediction(self, features):
        """基于学习模式进行手势预测"""
        if not any(pattern['count'] > 0 for pattern in self.gesture_patterns.values()):
            return None
        
        scores = {}
        
        for gesture_type, pattern in self.gesture_patterns.items():
            if pattern['count'] == 0:
                continue
            
            # 计算特征相似度
            similarity = 0.0
            feature_count = 0
            
            for key in features:
                if key in pattern['features']:
                    # 计算归一化相似度
                    diff = abs(features[key] - pattern['features'][key])
                    max_val = max(features[key], pattern['features'][key])
                    if max_val > 0:
                        similarity += 1.0 - (diff / max_val)
                        feature_count += 1
            
            if feature_count > 0:
                avg_similarity = similarity / feature_count
                # 结合学习置信度
                scores[gesture_type] = avg_similarity * pattern['confidence']
        
        if scores:
            best_gesture = max(scores, key=scores.get)
            if scores[best_gesture] > 0.6:  # 相似度阈值
                return best_gesture
        
        return None

# 音乐播放器线程类，用于后台获取音乐信息
class MusicPlayerThread(QThread):
    music_updated = pyqtSignal(str, str)  # 信号：发送歌曲名和艺术家
    
    def __init__(self):
        super().__init__()
        self.running = True
        self.current_song = None
        self.current_artist = None
        
    def run(self):
        while self.running:
            if has_music_utils:
                try:
                    # 尝试从所有支持的播放器获取音乐信息
                    song = None
                    artist = None
                    
                    # 1. 尝试获取当前活动窗口的音乐信息
                    song, artist = music_utils.get_current_playing_music()
                    
                    # 2. 如果当前没有获取到，尝试检查所有运行的播放器
                    if not song:
                        running_players = music_utils.get_all_running_players()
                        for player_name in running_players:
                            player_song, player_artist = music_utils.get_music_from_specific_player(player_name)
                            if player_song:
                                song = player_song
                                artist = player_artist
                                break
                    
                    if song and artist:
                        # 确保信息不为空
                        song = song or "未知歌曲"
                        artist = artist or "未知艺术家"
                        
                        # 如果信息发生变化，发送信号
                        if (song != self.current_song or artist != self.current_artist):
                            self.current_song = song
                            self.current_artist = artist
                            self.music_updated.emit(song, artist)
                    else:
                        # 没有音乐播放时的处理
                        song = "无音乐播放"
                        artist = ""
                        if (song != self.current_song or artist != self.current_artist):
                            self.current_song = song
                            self.current_artist = artist
                            self.music_updated.emit(song, artist)
                except Exception:
                    # 如果出错，使用模拟数据
                    song = "示例音乐"
                    artist = "示例艺术家"
                    if song != self.current_song or artist != self.current_artist:
                        self.current_song = song
                        self.current_artist = artist
                        self.music_updated.emit(song, artist)
            else:
                # 使用模拟数据
                song = "示例音乐"
                artist = "示例艺术家"
                if song != self.current_song or artist != self.current_artist:
                    self.current_song = song
                    self.current_artist = artist
                    self.music_updated.emit(song, artist)
            
            # 每500毫秒检查一次
            self.msleep(500)
    
    def stop(self):
        self.running = False

# 自定义圆形录制按钮类
class CustomRecordButton(QLabel):
    def __init__(self, parent=None, flags=Qt.WindowFlags()):
        super().__init__(parent, flags)
        self.setFixedSize(24, 24)
        self._button_scale = 1.0  # 初始缩放比例
        
        # 设置窗口属性，消除白色杂色
        self.setWindowFlags(Qt.FramelessWindowHint)  # 无边框
        self.setAttribute(Qt.WA_TranslucentBackground)  # 透明背景
        
        # 加载录制按钮图片
        self.record_pixmap = QPixmap("images/copy.png")
        
        # 检查图片是否加载成功
        if self.record_pixmap.isNull():
            print("错误：无法加载 images/copy.png 图片")
            # 创建一个简单的红色圆形作为备用
            self.record_pixmap = QPixmap(24, 24)
            self.record_pixmap.fill(Qt.transparent)
            painter = QPainter(self.record_pixmap)
            painter.setRenderHint(QPainter.Antialiasing)
            painter.setBrush(QBrush(QColor(255, 0, 0)))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(0, 0, 24, 24)
            painter.end()
        else:
            print("成功加载录制按钮图片")
        
        self.hide()
    
    @pyqtProperty(float)
    def button_scale(self):
        # 获取缩放比例
        return self._button_scale
    
    @button_scale.setter
    def button_scale(self, value):
        # 设置缩放比例
        self._button_scale = value
        self.update()  # 触发重绘
    
    def paintEvent(self, event):
        painter = QPainter(self)
        
        # 设置高质量渲染属性，确保图片边缘平滑
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setRenderHint(QPainter.SmoothPixmapTransform, True)
        
        # 获取按钮的中心和尺寸
        rect = self.rect()
        size = min(rect.width(), rect.height()) * self._button_scale
        
        # 计算中心和半径
        center = rect.center()
        scaled_radius = size / 2
        
        # 计算图片绘制区域
        image_rect = rect.adjusted(
            int((rect.width() - size) / 2),
            int((rect.height() - size) / 2),
            -int((rect.width() - size) / 2),
            -int((rect.height() - size) / 2)
        )
        
        # 先绘制黑色圆形背景
        painter.setBrush(QBrush(QColor(0, 0, 0)))  # 纯黑色背景
        painter.setPen(Qt.NoPen)  # 无边框
        painter.drawEllipse(center, scaled_radius, scaled_radius)
        
        # 然后在背景上绘制图片
        painter.drawPixmap(image_rect, self.record_pixmap.scaled(
            image_rect.size(),
            Qt.KeepAspectRatio,
            Qt.SmoothTransformation
        ))

class DynamicIsland(QWidget):
    def __init__(self):
        super().__init__()
        self.draggable = False
        self.drag_position = QPoint()
        self.click_pos = QPoint()  # 记录点击位置，用于区分点击和拖拽
        self.expanded = False  # 展开状态标志
        self.desktop_only = False  # 仅桌面显示模式标志，默认为False（在所有页面显示）
        self.is_recording = False  # 录制状态标志
        
        # 初始化音乐信息
        self.current_song = "示例音乐"
        self.current_artist = "示例艺术家"
        
        # 先初始化UI，确保所有UI组件都已创建
        self.initUI()
        
        # 初始化音乐播放器线程
        self.music_thread = MusicPlayerThread()
        self.music_thread.music_updated.connect(self.update_music_info)
        self.music_thread.start()
        
        # 初始化屏幕录制线程
        if has_screen_recorder:
            self.record_thread = ScreenRecorderThread()
            self.record_thread.recording_stopped.connect(self.on_recording_stopped)
        
        # 初始化手势识别线程
        if has_gesture_screenshot:
            print("✅ 手势识别模块已加载，正在初始化手势识别线程...")
            self.gesture_thread = GestureRecognitionThread()
            self.gesture_thread.gesture_detected.connect(self.on_gesture_detected)
            self.gesture_thread.gesture_trajectory.connect(self.on_gesture_trajectory)
            # 默认不开启手势识别（由用户通过右键菜单控制）
            print("✅ 手势识别线程已初始化（默认关闭）")
        else:
            print("❌ 手势识别模块不可用(更新测试中，暂不开放)")
        

        
        # 初始化窗口检查定时器
        self.window_check_timer = QTimer(self)
        self.window_check_timer.timeout.connect(self.check_current_window)
        self.window_check_timer.start(500)  # 每500毫秒检查一次
        
        # 设置窗口激活定时器，确保录制按钮始终在最上层
        self.activation_timer = QTimer(self)
        self.activation_timer.setInterval(1000)  # 每秒检查一次
        self.activation_timer.timeout.connect(self.check_activation_status)
        self.activation_timer.start()
        
        # 初始化快捷键
        self.initShortcuts()
        
    def initUI(self):
        # 设置窗口大小
        self.original_width = 220
        self.original_height = 40
        
        # 设置窗口标题
        self.setWindowTitle('Dynamic Island')
        
        # 计算屏幕居中位置（顶部居中）
        screen = QApplication.primaryScreen()
        screen_geometry = screen.availableGeometry()
        x = (screen_geometry.width() - self.original_width) // 2
        y = 10  # 距离顶部10像素
        self.setGeometry(x, y, self.original_width, self.original_height)
        
        # 设置窗口样式
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.Window)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_TransparentForMouseEvents, False)
        self.setFocusPolicy(Qt.StrongFocus)  # 设置焦点策略以接收键盘事件
        self.activateWindow()  # 激活窗口以确保接收键盘事件
        
        # 设置背景色和透明度
        palette = self.palette()
        palette.setColor(QPalette.Window, QColor(0, 0, 0, 230))  # 降低透明度（更高的alpha值）
        self.setPalette(palette)
        
        # 初始化动画存储变量
        self.active_animations = []
        
        # 创建布局
        layout = QHBoxLayout(self)
        layout.setContentsMargins(15, 8, 15, 8)
        layout.setSpacing(15)
        
        # 创建状态图标标签
        self.volume_label = QLabel(self)
        self.volume_label.setText("🔊")
        self.volume_label.setFont(QFont('Arial', 14))
        self.volume_label.setStyleSheet("color: white;")
        self.volume_label.setToolTip("点击调节音量")
        
        # 音量控制相关
        self.volume_percent_label = QLabel(self)
        self.volume_percent_label.setText("50%")
        self.volume_percent_label.setFont(QFont('Arial', 10))
        self.volume_percent_label.setStyleSheet("color: white;")
        self.volume_percent_label.hide()  # 默认隐藏音量百分比

        # 创建亮度图标标签
        self.brightness_label = QLabel(self)
        self.brightness_label.setText("💡")
        self.brightness_label.setFont(QFont('Arial', 14))
        self.brightness_label.setStyleSheet("color: white;")
        self.brightness_label.setToolTip("点击调节亮度")
        self.brightness_label.hide()  # 默认隐藏亮度图标
        
        # 亮度控制相关
        self.brightness_percent_label = QLabel(self)
        self.brightness_percent_label.setText("50%")
        self.brightness_percent_label.setFont(QFont('Arial', 10))
        self.brightness_percent_label.setStyleSheet("color: white;")
        self.brightness_percent_label.hide()  # 默认隐藏亮度百分比

        self.battery_label = QLabel(self)
        self.battery_label.setText("🔋")
        self.battery_label.setFont(QFont('Arial', 14))
        self.battery_label.setStyleSheet("color: white;")
        self.battery_label.hide()  # 默认隐藏电池图标
        
        # 创建日历图标标签
        self.calendar_label = QLabel(self)
        self.calendar_label.setText("📅")
        self.calendar_label.setFont(QFont('Arial', 14))
        self.calendar_label.setStyleSheet("color: white;")
        self.calendar_label.setToolTip("点击查看日期")
        self.calendar_label.hide()  # 默认隐藏日历图标
        
        # 日历详情标签
        self.calendar_detail_label = QLabel(self)
        self.calendar_detail_label.setFont(QFont('Arial', 10))
        self.calendar_detail_label.setStyleSheet("color: white;")
        self.calendar_detail_label.hide()  # 默认隐藏日历详情
        
        # 创建时间标签
        self.time_label = QLabel(self)
        self.time_label.setFont(QFont('Arial', 12, QFont.Bold))
        self.time_label.setAlignment(Qt.AlignCenter)
        self.time_label.setStyleSheet("color: white;")
        
        # 创建通知图标
        self.notification_label = QLabel(self)
        self.notification_label.setText("🔔")
        self.notification_label.setFont(QFont('Arial', 14))
        self.notification_label.setStyleSheet("color: white;")
        
        # 创建手势状态指示器
        self.gesture_status_label = QLabel(self)
        self.gesture_status_label.setText("👋")
        self.gesture_status_label.setFont(QFont('Arial', 12))
        self.gesture_status_label.setStyleSheet("color: white;")
        self.gesture_status_label.setToolTip("手势识别状态")
        self.gesture_status_label.hide()  # 默认隐藏
        
        # 展开时的额外信息
        self.extra_info_label = QLabel(self)
        self.extra_info_label.setText(f"正在播放: {self.current_song} - {self.current_artist}")
        self.extra_info_label.setFont(QFont('Arial', 10))
        self.extra_info_label.setStyleSheet("color: white;")
        self.extra_info_label.hide()
        
        # 创建自定义圆形录制按钮（初始隐藏，作为独立窗口）
        self.record_button = CustomRecordButton(None, Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        
        # 添加到布局
        layout.addWidget(self.volume_label)
        layout.addWidget(self.volume_percent_label)
        layout.addWidget(self.brightness_label)
        layout.addWidget(self.brightness_percent_label)
        layout.addWidget(self.battery_label)
        layout.addWidget(self.calendar_label)
        layout.addWidget(self.calendar_detail_label)
        layout.addWidget(self.time_label)
        layout.addWidget(self.notification_label)
        layout.addWidget(self.gesture_status_label)
        layout.addWidget(self.extra_info_label)
        
        # 更新时间、音量、亮度和电池信息
        self.update_time()
        self.update_volume_info()
        self.update_brightness_info()
        self.update_battery_info()
        
        # 设置定时器，每秒更新时间
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_time)
        self.timer.start(1000)
        
        # 设置音量更新定时器
        self.volume_timer = QTimer(self)
        self.volume_timer.timeout.connect(self.update_volume_info)
        self.volume_timer.start(1000)
        
        # 设置亮度更新定时器
        self.brightness_timer = QTimer(self)        
        self.brightness_timer.timeout.connect(self.update_brightness_info)
        self.brightness_timer.start(1000)
        
        # 设置电池电量更新定时器
        self.battery_timer = QTimer(self)
        self.battery_timer.timeout.connect(self.update_battery_info)
        self.battery_timer.start(5000)  # 每5秒更新一次电池信息
        
        # 创建全局快捷键
        self.shortcut_volume_up = QShortcut(QKeySequence("Ctrl+Up"), self)
        self.shortcut_volume_up.activated.connect(self.volume_up)
        
        self.shortcut_volume_down = QShortcut(QKeySequence("Ctrl+Down"), self)
        self.shortcut_volume_down.activated.connect(self.volume_down)
        
        self.shortcut_volume_mute = QShortcut(QKeySequence("Ctrl+M"), self)
        self.shortcut_volume_mute.activated.connect(self.toggle_mute)
        
        # 创建亮度调节快捷键
        self.shortcut_brightness_up = QShortcut(QKeySequence("Ctrl+Right"), self)
        self.shortcut_brightness_up.activated.connect(self.brightness_up)
        
        self.shortcut_brightness_down = QShortcut(QKeySequence("Ctrl+Left"), self)
        self.shortcut_brightness_down.activated.connect(self.brightness_down)
        
    def initShortcuts(self):
        # 创建Ctrl+Shift快捷键用于开始/停止录制
        self.record_shortcut = QShortcut(QKeySequence("Ctrl+Shift"), self)
        self.record_shortcut.activated.connect(self.toggle_recording)
        
        print("录制快捷键已设置: Ctrl+Shift")
    
    def toggle_recording(self):
        # 切换录制状态
        if not has_screen_recorder:
            print("屏幕录制功能不可用")
            return
            
        if self.is_recording:
            # 如果正在录制，则停止录制
            print("快捷键: 停止录制")
            self.stop_recording()
        else:
            # 如果未在录制，则开始录制
            print("快捷键: 开始录制")
            self.start_recording()
    
    def paintEvent(self, event):
        # 绘制圆角窗口
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # 绘制背景
        rect = self.rect()
        painter.setBrush(QBrush(QColor(0, 0, 0, 230)))  # 降低透明度（更高的alpha值）
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(rect, 20, 20)
    

    
    def mouseMoveEvent(self, event):
        # 鼠标移动事件，用于拖动窗口
        if event.buttons() & Qt.LeftButton:
            # 计算鼠标移动距离
            distance = (event.pos() - self.click_pos).manhattanLength()
            
            # 如果移动距离超过阈值，标记为拖拽状态
            if distance > 5:  # 5像素阈值
                self.draggable = True
                
                # 使用统一的方法停止所有动画，避免拖动时与动画冲突
                self.stop_all_animations()
                
                # 移动窗口
                self.move(event.globalPos() - self.drag_position)
            
            event.accept()
    
    def mouseReleaseEvent(self, event):
        # 鼠标释放事件
        if event.button() == Qt.LeftButton:
            # 计算鼠标移动距离
            distance = (event.pos() - self.click_pos).manhattanLength()
            
            # 如果移动距离小于阈值，认为是点击操作，执行展开/收起
            if distance < 5 and self.rect().contains(self.click_pos):
                self.toggle_expand()
            
            # 重置拖动状态
            self.draggable = False
    
    def stop_all_animations(self):
        # 停止并移除所有活动动画
        for attr_name in ['hover_animation', 'expand_animation', 'collapse_animation', 'bell_animation', 'bell_animation_group', 'record_fade_in_animation', 'record_fade_out_animation', 'record_pulse_animation', 'record_position_animation']:
            if hasattr(self, attr_name):
                animation = getattr(self, attr_name)
                # 检查动画是否正在运行
                from PyQt5.QtCore import QParallelAnimationGroup, QPropertyAnimation, QSequentialAnimationGroup
                if isinstance(animation, QPropertyAnimation) and animation.state() == QPropertyAnimation.Running:
                    animation.stop()
                elif isinstance(animation, (QParallelAnimationGroup, QSequentialAnimationGroup)) and animation.state() == QParallelAnimationGroup.Running:
                    animation.stop()
                delattr(self, attr_name)
    
    def toggle_expand(self):
        # 切换展开/收起状态
        self.expanded = not self.expanded
        
        # 首先停止所有可能的动画
        self.stop_all_animations()
        
        if self.expanded:
            # 展开时的动画
            new_width = self.original_width + 100
            new_height = self.original_height + 30
            
            # 获取当前窗口位置
            current_geometry = self.geometry()
            
            # 保持窗口中心位置不变，计算新的x坐标
            current_center = current_geometry.x() + current_geometry.width() // 2
            new_x = current_center - new_width // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 显示额外信息
            self.extra_info_label.show()
            
            # 增加背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 250))  # 展开时更不透明
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_expand_finished():
                self.setGeometry(new_x, new_y, new_width, new_height)
            
            # 创建新的窗口矩形
            from PyQt5.QtCore import QRect
            new_rect = QRect(new_x, new_y, new_width, new_height)
            
            # 使用新的几何动画方法
            self.expand_animation = self.create_geometry_animation(
                current_geometry,
                new_rect,
                duration=350,
                finished_callback=on_expand_finished,
                easing_curve=QEasingCurve.OutQuart
            )
            
            # 启动动画
            self.expand_animation.start()
            
        else:
            # 获取当前窗口位置
            current_geometry = self.geometry()
            
            # 保持窗口中心位置不变，计算新的x坐标
            current_center = current_geometry.x() + current_geometry.width() // 2
            new_x = current_center - self.original_width // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 隐藏额外信息
            self.extra_info_label.hide()
            
            # 恢复背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 230))  # 降低透明度（更高的alpha值）
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_collapse_finished():
                self.setGeometry(new_x, new_y, self.original_width, self.original_height)
            
            # 创建新的窗口矩形
            from PyQt5.QtCore import QRect
            new_rect = QRect(new_x, new_y, self.original_width, self.original_height)
            
            # 使用新的几何动画方法
            self.collapse_animation = self.create_geometry_animation(
                current_geometry,
                new_rect,
                duration=350,
                finished_callback=on_collapse_finished,
                easing_curve=QEasingCurve.InOutQuart
            )
            
            # 启动动画
            self.collapse_animation.start()
    
    def enterEvent(self, event):
        # 鼠标进入事件，放大窗口
        if not self.expanded:  # 只有在未展开状态下才执行悬停动画
            # 停止所有动画
            self.stop_all_animations()
            
            new_width = self.original_width + 40
            new_height = self.original_height + 10
            
            # 获取当前窗口位置
            current_geometry = self.geometry()
            
            # 保持窗口中心位置不变，计算新的x坐标
            current_center = current_geometry.x() + current_geometry.width() // 2
            new_x = current_center - new_width // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 增加背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 230))
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_hover_enter_finished():
                self.setGeometry(new_x, new_y, new_width, new_height)
            
            # 创建新的窗口矩形
            from PyQt5.QtCore import QRect
            new_rect = QRect(new_x, new_y, new_width, new_height)
            
            # 使用新的几何动画方法
            self.hover_animation = self.create_geometry_animation(
                current_geometry,
                new_rect,
                duration=250,
                finished_callback=on_hover_enter_finished,
                easing_curve=QEasingCurve.OutQuad
            )
            
            # 启动动画
            self.hover_animation.start()
        
    def leaveEvent(self, event):
        # 鼠标离开事件，恢复原始大小
        if not self.expanded:  # 只有在未展开状态下才执行悬停动画
            # 停止所有动画
            self.stop_all_animations()
            
            # 获取当前窗口位置
            current_geometry = self.geometry()
            
            # 保持窗口中心位置不变，计算新的x坐标
            current_center = current_geometry.x() + current_geometry.width() // 2
            new_x = current_center - self.original_width // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 恢复背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 200))
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_hover_leave_finished():
                self.setGeometry(new_x, new_y, self.original_width, self.original_height)
            
            # 创建新的窗口矩形
            from PyQt5.QtCore import QRect
            new_rect = QRect(new_x, new_y, self.original_width, self.original_height)
            
            # 使用新的几何动画方法
            self.hover_animation = self.create_geometry_animation(
                current_geometry,
                new_rect,
                duration=250,
                finished_callback=on_hover_leave_finished,
                easing_curve=QEasingCurve.InOutQuad
            )
            
            # 启动动画
            self.hover_animation.start()
    
    def contextMenuEvent(self, event):
        # 右键菜单事件
        from PyQt5.QtWidgets import QMenu
        menu = QMenu(self)
        exit_action = menu.addAction("退出")
        action = menu.exec_(self.mapToGlobal(event.pos()))
        if action == exit_action:
            QApplication.quit()
        
    def create_animation(self, property_name, start_value, end_value, duration=300, finished_callback=None, easing_curve=QEasingCurve.OutQuad):
        # 不直接支持geometry属性的动画
        if property_name == b"geometry":
            # 使用几何动画方法替代
            from PyQt5.QtCore import QRect
            if isinstance(start_value, QRect) and isinstance(end_value, tuple):
                end_rect = QRect(*end_value)
                return self.create_geometry_animation(start_value, end_rect, duration, finished_callback, easing_curve)
            return None
            
        # 创建并配置动画
        animation = QPropertyAnimation(self, property_name)
        animation.setDuration(duration)
        animation.setEasingCurve(easing_curve)
        
        # 设置起始值和结束值
        animation.setStartValue(start_value)
        animation.setEndValue(end_value)
        
        if finished_callback:
            animation.finished.connect(finished_callback)
        return animation
        
    def create_geometry_animation(self, start_rect, end_rect, duration=300, finished_callback=None, easing_curve=QEasingCurve.OutQuad):
        # 创建位置和大小的动画组
        from PyQt5.QtCore import QParallelAnimationGroup
        
        # 创建位置动画
        pos_animation = QPropertyAnimation(self, b"pos")
        pos_animation.setDuration(duration)
        pos_animation.setEasingCurve(easing_curve)
        pos_animation.setStartValue(start_rect.topLeft())
        pos_animation.setEndValue(end_rect.topLeft())
        
        # 创建大小动画
        size_animation = QPropertyAnimation(self, b"size")
        size_animation.setDuration(duration)
        size_animation.setEasingCurve(easing_curve)
        size_animation.setStartValue(start_rect.size())
        size_animation.setEndValue(end_rect.size())
        
        # 创建动画组
        animation_group = QParallelAnimationGroup(self)
        animation_group.addAnimation(pos_animation)
        animation_group.addAnimation(size_animation)
        
        if finished_callback:
            animation_group.finished.connect(finished_callback)
        
        return animation_group
    
    def ring_bell_animation(self):
        # 使用QPropertyAnimation实现更流畅的铃铛摇摆动画
        # 首先停止所有可能的铃铛动画
        if hasattr(self, 'bell_animation_group'):
            self.bell_animation_group.stop()
            delattr(self, 'bell_animation_group')
        
        # 创建自定义属性来控制旋转角度
        self._bell_rotation_angle = 0
        
        from PyQt5.QtCore import QPropertyAnimation, QSequentialAnimationGroup, QEasingCurve
        
        # 创建动画组，实现多次摇摆效果
        self.bell_animation_group = QSequentialAnimationGroup(self)
        
        # 定义摇摆参数
        max_angle = 15
        animations = [
            (max_angle, 0.2, QEasingCurve.OutQuad),    # 向右摆
            (-max_angle, 0.2, QEasingCurve.InOutQuad), # 向左摆
            (max_angle, 0.2, QEasingCurve.InOutQuad),  # 向右摆
            (-max_angle, 0.2, QEasingCurve.InOutQuad), # 向左摆
            (max_angle * 0.7, 0.15, QEasingCurve.InOutQuad),  # 向右摆（幅度减小）
            (-max_angle * 0.7, 0.15, QEasingCurve.InOutQuad), # 向左摆（幅度减小）
            (max_angle * 0.4, 0.12, QEasingCurve.InOutQuad),  # 向右摆（幅度减小）
            (0, 0.1, QEasingCurve.OutQuad)             # 回到初始位置
        ]
        
        # 创建所有旋转动画
        for angle, duration, curve in animations:
            # 转换为毫秒
            ms_duration = int(duration * 1000)
            
            # 创建旋转动画
            rotation_anim = QPropertyAnimation(self, b"bell_rotation_angle")
            rotation_anim.setDuration(ms_duration)
            rotation_anim.setStartValue(self.bell_rotation_angle)
            rotation_anim.setEndValue(angle)
            rotation_anim.setEasingCurve(curve)
            
            # 连接动画更新信号
            rotation_anim.valueChanged.connect(self.update_bell_rotation)
            
            # 添加到动画组
            self.bell_animation_group.addAnimation(rotation_anim)
        
        # 启动动画组
        self.bell_animation_group.start()
    
    def get_bell_rotation_angle(self):
        return self._bell_rotation_angle
    
    def set_bell_rotation_angle(self, angle):
        # 直接设置内部变量，避免递归调用
        self._bell_rotation_angle = angle
        self.update_bell_rotation()
    
    # 定义自定义属性
    bell_rotation_angle = property(get_bell_rotation_angle, set_bell_rotation_angle)
    
    def update_bell_rotation(self, value=None):
        # 应用旋转效果
        font = QFont('Arial', 14)
        self.notification_label.setFont(font)
        
        # 使用HTML和CSS变换来实现旋转效果
        angle = self._bell_rotation_angle if value is None else value
        rotation_style = f"style='transform: rotate({angle}deg); display: inline-block; transform-origin: 50% 50%;'"
        self.notification_label.setText(f"<span {rotation_style}>🔔</span>")
    
    def update_music_info(self, song, artist):
        # 更新音乐信息
        self.current_song = song
        self.current_artist = artist
        # 安全检查：确保extra_info_label已初始化
        if hasattr(self, 'extra_info_label'):
            self.extra_info_label.setText(f"正在播放: {song} - {artist}")
        else:
            print("警告：extra_info_label尚未初始化，音乐信息已保存但未显示")
    
    def update_volume_info(self):
        # 更新音量显示信息
        if has_volume_utils and volume_utils.volume_initialized:
            try:
                volume_percent = volume_utils.get_volume_percentage()
                mute = volume_utils.get_mute()
                
                # 更新音量图标
                if mute:
                    self.volume_label.setText("🔇")
                elif volume_percent == 0:
                    self.volume_label.setText("🔈")
                elif volume_percent < 50:
                    self.volume_label.setText("🔉")
                else:
                    self.volume_label.setText("🔊")
                
                # 更新音量百分比
                self.volume_percent_label.setText(f"{volume_percent}%")
            except Exception:
                # 如果出现错误，使用默认值
                self.volume_label.setText("🔊")
                self.volume_percent_label.setText("50%")
        else:
            # 如果音量功能不可用，使用默认值
            self.volume_label.setText("🔊")
            self.volume_percent_label.setText("50%")
    
    def update_battery_info(self):
        # 更新电池信息显示
        try:
            battery = psutil.sensors_battery()
            if battery:
                percent = int(battery.percent)
                plugged = battery.power_plugged
                
                # 根据充电状态和电量选择合适的图标
                if plugged:
                    # 充电状态
                    if percent == 100:
                        self.battery_label.setText("🔋100%")
                    else:
                        self.battery_label.setText(f"🔌{percent}%")
                else:
                    # 放电状态
                    if percent > 80:
                        self.battery_label.setText(f"🔋{percent}%")
                    elif percent > 20:
                        self.battery_label.setText(f"🔋{percent}%")
                    else:
                        self.battery_label.setText(f"🪫{percent}%")
            else:
                # 如果无法获取电池信息
                self.battery_label.setText("🔋")
        except Exception:
            # 如果出现错误，使用默认值
            self.battery_label.setText("🔋")
    
    def volume_up(self):
        # 增加音量
        if has_volume_utils and volume_utils.volume_initialized:
            volume_utils.increase_volume(step=0.05)
            self.update_volume_info()
    
    def volume_down(self):
        # 减少音量
        if has_volume_utils and volume_utils.volume_initialized:
            volume_utils.decrease_volume(step=0.05)
            self.update_volume_info()
    
    def toggle_mute(self):
        # 切换静音状态
        if has_volume_utils and volume_utils.volume_initialized:
            volume_utils.toggle_mute()
            self.update_volume_info()
    
    def update_brightness_info(self):
        # 更新亮度显示信息
        if has_brightness_utils and brightness_utils.brightness_initialized:
            try:
                brightness_percent = brightness_utils.get_brightness()
                
                # 更新亮度百分比
                self.brightness_percent_label.setText(f"{brightness_percent}%")
                
                # 根据亮度调整图标
                if brightness_percent == 0:
                    self.brightness_label.setText("💡")
                elif brightness_percent < 30:
                    self.brightness_label.setText("💡")
                elif brightness_percent < 70:
                    self.brightness_label.setText("💡")
                else:
                    self.brightness_label.setText("💡")
            except Exception:
                # 如果出现错误，使用默认值
                self.brightness_label.setText("💡")
                self.brightness_percent_label.setText("50%")
        else:
            # 如果亮度功能不可用，使用默认值
            self.brightness_label.setText("💡")
            self.brightness_percent_label.setText("50%")
    
    def brightness_up(self):
        # 增加亮度（仅在展开状态下可用）
        if self.expanded and has_brightness_utils and brightness_utils.brightness_initialized:
            brightness_utils.increase_brightness(step=10)
            self.update_brightness_info()
    
    def brightness_down(self):
        # 减少亮度（仅在展开状态下可用）
        if self.expanded and has_brightness_utils and brightness_utils.brightness_initialized:
            brightness_utils.decrease_brightness(step=10)
            self.update_brightness_info()
    
    def mousePressEvent(self, event):
        # 鼠标按下事件，用于拖动窗口和点击切换展开/收起
        if event.button() == Qt.LeftButton:
            # 激活窗口以确保接收键盘事件
            self.setFocus()
            self.activateWindow()
            
            # 检查是否点击了音量图标（添加安全检查）
            if hasattr(self, 'volume_label') and self.volume_label.geometry().contains(event.pos()):
                # 点击音量图标切换静音
                self.toggle_mute()
            # 检查是否点击了亮度图标（添加安全检查）
            elif hasattr(self, 'brightness_label') and self.brightness_label.geometry().contains(event.pos()):
                # 点击亮度图标，仅在展开状态下循环增加亮度
                if self.expanded and has_brightness_utils and brightness_utils.brightness_initialized:
                    current_brightness = brightness_utils.get_brightness()
                    new_brightness = (current_brightness + 20) % 120
                    if new_brightness > 100:
                        new_brightness = 0
                    brightness_utils.set_brightness(new_brightness)
                    self.update_brightness_info()
            # 检查是否点击了日历图标（添加安全检查）
            elif hasattr(self, 'calendar_label') and self.calendar_label.geometry().contains(event.pos()):
                # 点击日历图标切换日历详情显示
                if self.calendar_detail_label.isVisible():
                    self.calendar_detail_label.hide()
                else:
                    self.calendar_detail_label.show()
            # 检查是否点击了铃铛图标（添加安全检查）
            elif hasattr(self, 'notification_label') and self.notification_label.geometry().contains(event.pos()):
                # 点击铃铛图标触发摇摆动画
                self.ring_bell_animation()
            else:
                # 记录点击位置和拖拽起始位置
                self.click_pos = event.pos()
                self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
                
                # 设置拖动状态为False，后续根据移动距离判断
                self.draggable = False
            event.accept()
    
    def mouseReleaseEvent(self, event):
        # 鼠标释放事件
        if event.button() == Qt.LeftButton:
            # 计算鼠标移动距离
            distance = (event.pos() - self.click_pos).manhattanLength() if hasattr(self, 'click_pos') else 0
            
            # 如果移动距离小于阈值，认为是点击操作，执行展开/收起
            if distance < 5 and self.rect().contains(self.click_pos):
                # 检查是否点击了音量图标或日历图标（添加安全检查）
                volume_clicked = hasattr(self, 'volume_label') and self.volume_label.geometry().contains(event.pos())
                calendar_clicked = hasattr(self, 'calendar_label') and self.calendar_label.geometry().contains(event.pos())
                if not volume_clicked and not calendar_clicked:
                    self.toggle_expand()
            else:
                # 如果移动距离大于阈值，认为是拖动操作，释放后自动回到顶部居中位置
                self.return_to_original_position()
            
            # 重置拖动状态
            self.draggable = False

    def return_to_original_position(self):
        # 自动回到顶部居中位置
        screen = QApplication.primaryScreen()
        screen_geometry = screen.availableGeometry()
        
        # 计算顶部居中位置
        x = (screen_geometry.width() - self.width()) // 2
        y = 10  # 距离顶部10像素
        
        # 使用带动画的方式回到原始位置
        current_geometry = self.geometry()
        new_rect = QRect(x, y, self.width(), self.height())
        
        # 创建几何动画
        self.position_animation = self.create_geometry_animation(
            current_geometry,
            new_rect,
            duration=300,  # 300毫秒动画
            finished_callback=None,
            easing_curve=QEasingCurve.OutCubic
        )
        
        # 启动动画
        self.position_animation.start()

    def keyPressEvent(self, event):
        # 键盘事件处理，实现音量控制快捷键
        modifiers = event.modifiers()
        key = event.key()
        
        # 检查是否按下了Ctrl键
        if modifiers & Qt.ControlModifier:
            if key == Qt.Key_Up or key == Qt.Key_Equal:  # Ctrl+Up 或 Ctrl+=
                self.volume_up()
            elif key == Qt.Key_Down or key == Qt.Key_Minus:  # Ctrl+Down 或 Ctrl+-  
                self.volume_down()
            elif key == Qt.Key_M:  # Ctrl+M
                self.toggle_mute()
        
        event.accept()
    
    def toggle_expand(self):
        # 切换展开/收起状态
        self.expanded = not self.expanded
        
        # 首先停止所有可能的动画
        self.stop_all_animations()
        
        if self.expanded:
            # 展开时的动画
            new_width = self.original_width + 100
            new_height = self.original_height + 30
            
            # 使用availableGeometry获取可用屏幕区域（排除任务栏）
            screen = QApplication.primaryScreen()
            screen_geometry = screen.availableGeometry()
            new_x = (screen_geometry.width() - new_width) // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 获取当前窗口位置作为动画起始点
            current_geometry = self.geometry()
            
            # 显示额外信息（添加安全检查）
            if hasattr(self, 'extra_info_label'):
                self.extra_info_label.show()
            if hasattr(self, 'volume_percent_label'):
                self.volume_percent_label.show()  # 展开时显示音量百分比
            if hasattr(self, 'brightness_label'):
                self.brightness_label.show()  # 展开时显示亮度图标
            if hasattr(self, 'brightness_percent_label'):
                self.brightness_percent_label.show()  # 展开时显示亮度百分比
            if hasattr(self, 'battery_label'):
                self.battery_label.show()  # 展开时显示电池图标
            if hasattr(self, 'calendar_label'):
                self.calendar_label.show()  # 展开时显示日历图标
            # 不自动显示日历详情，只有点击后才显示
            if hasattr(self, 'calendar_detail_label'):
                self.calendar_detail_label.hide()
            # 展开时显示手势状态指示器
            if hasattr(self, 'gesture_status_label'):
                self.gesture_status_label.show()
                # 更新手势状态显示
                self.update_gesture_status()
            # 展开时隐藏录制按钮，添加淡出动画
            self.fade_out_record_button()
            
            # 增加背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 240))
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_expand_finished():
                self.setGeometry(new_x, new_y, new_width, new_height)
            
            # 使用统一的动画创建方法
            self.expand_animation = self.create_animation(
                b"geometry",
                current_geometry,
                (new_x, new_y, new_width, new_height),
                duration=350,
                finished_callback=on_expand_finished,
                easing_curve=QEasingCurve.OutQuart
            )
            
            # 启动动画
            self.expand_animation.start()
            
        else:
            # 使用availableGeometry获取可用屏幕区域（排除任务栏）
            screen = QApplication.primaryScreen()
            screen_geometry = screen.availableGeometry()
            new_x = (screen_geometry.width() - self.original_width) // 2
            new_y = 10  # 固定在顶部10像素处
            
            # 获取当前窗口位置作为动画起始点
            current_geometry = self.geometry()
            
            # 隐藏额外信息（添加安全检查）
            if hasattr(self, 'extra_info_label'):
                self.extra_info_label.hide()
            if hasattr(self, 'volume_percent_label'):
                self.volume_percent_label.hide()  # 收起时隐藏音量百分比
            if hasattr(self, 'brightness_label'):
                self.brightness_label.hide()  # 收起时隐藏亮度图标
            if hasattr(self, 'brightness_percent_label'):
                self.brightness_percent_label.hide()  # 收起时隐藏亮度百分比
            if hasattr(self, 'calendar_detail_label'):
                self.calendar_detail_label.hide()  # 收起时隐藏日历详情
            if hasattr(self, 'battery_label'):
                self.battery_label.hide()  # 收起时隐藏电池图标
            if hasattr(self, 'calendar_label'):
                self.calendar_label.hide()  # 收起时隐藏日历图标
            # 收起时隐藏手势状态指示器
            if hasattr(self, 'gesture_status_label'):
                self.gesture_status_label.hide()
            
            # 收起时如果正在录制，显示录制按钮并设置独立位置
            if self.is_recording:
                # 使用统一的淡入动画方法
                self.fade_in_record_button()
                self.start_record_pulse_animation()
            else:
                # 添加安全检查
                if hasattr(self, 'record_button'):
                    self.record_button.hide()
            
            # 恢复背景透明度
            palette = self.palette()
            palette.setColor(QPalette.Window, QColor(0, 0, 0, 200))
            self.setPalette(palette)
            
            # 确保动画结束后窗口位置正确
            def on_collapse_finished():
                self.setGeometry(new_x, new_y, self.original_width, self.original_height)
            
            # 使用统一的动画创建方法
            self.collapse_animation = self.create_animation(
                b"geometry",
                current_geometry,
                (new_x, new_y, self.original_width, self.original_height),
                duration=400,
                finished_callback=on_collapse_finished
            )
            
            # 启动动画
            self.collapse_animation.start()
    
    def start_recording(self):
        # 开始录制屏幕
        print("[DEBUG] start_recording called")
        print(f"[DEBUG] has_screen_recorder: {has_screen_recorder}")
        print(f"[DEBUG] self.is_recording: {self.is_recording}")
        if has_screen_recorder and not self.is_recording:
            self.is_recording = True
            print(f"[DEBUG] self.record_button: {self.record_button}")
            print(f"[DEBUG] self.expanded: {self.expanded}")
            self.record_thread = ScreenRecorderThread()
            self.record_thread.recording_stopped.connect(self.on_recording_stopped)
            self.record_thread.start()
            
            # 无论窗口是展开还是收起状态，都显示录制按钮
            print("[DEBUG] Calling fade_in_record_button")
            self.fade_in_record_button()
    
    def stop_recording(self):
        # 停止录制屏幕
        if has_screen_recorder and self.is_recording:
            self.is_recording = False
            self.record_thread.stop_recording()
            # 直接隐藏录制按钮，不使用动画
            self.record_button.hide()
    
    def resizeEvent(self, event):
        # 窗口大小变化时，更新录制按钮位置
        if self.is_recording:
            # 使用带动画的位置更新方法
            self.update_record_button_position(animated=True)
        super().resizeEvent(event)
    
    def moveEvent(self, event):
        # 窗口移动时，更新录制按钮位置
        if self.is_recording:
            # 使用带动画的位置更新方法
            self.update_record_button_position(animated=True)
        super().moveEvent(event)
    
    def showEvent(self, event):
        # 窗口显示时，确保录制按钮正确定位
        if self.is_recording:
            # 使用非动画方式立即定位，然后可以选择是否添加进入动画
            self.update_record_button_position(animated=False)
            # 如果录制按钮不可见，显示它
            if not self.record_button.isVisible():
                self.record_button.show()
        super().showEvent(event)
    
    def hideEvent(self, event):
        # 窗口隐藏时，同步隐藏录制按钮
        if self.is_recording:
            # 隐藏录制按钮但不停止录制
            self.record_button.hide()
        super().hideEvent(event)
    
    def changeEvent(self, event):
        # 处理窗口状态变化事件
        if event.type() == event.WindowStateChange:
            if self.is_recording:
                # 窗口状态变化（最小化/最大化等）时，更新录制按钮位置
                if self.isVisible():
                    # 如果窗口可见，确保录制按钮正确定位
                    self.update_record_button_position(animated=True)
                else:
                    # 如果窗口不可见，隐藏录制按钮
                    self.record_button.hide()
        elif event.type() == event.ActivationChange:
            if self.is_recording:
                # 窗口激活状态变化时，可选择调整录制按钮的视觉效果
                if self.isActiveWindow():
                    # 窗口激活时，确保录制按钮在最上层
                    self.record_button.raise_()
        super().changeEvent(event)
    
    def on_recording_stopped(self):
        # 录制停止回调
        self.is_recording = False
        self.fade_out_record_button()
    
    def fade_in_record_button(self):
        # 简化录制按钮淡入动画
        # 首先停止可能正在运行的淡出动画
        if hasattr(self, 'record_fade_out_animation'):
            self.record_fade_out_animation.stop()
            delattr(self, 'record_fade_out_animation')
        
        # 计算并设置录制按钮位置
        geometry = self.geometry()
        button_width = self.record_button.width()
        button_height = self.record_button.height()
        
        # 将按钮放在主窗口右侧
        x = geometry.x() + geometry.width() + 5
        y = geometry.y() + (geometry.height() - button_height) // 2
        
        # 设置按钮位置
        self.record_button.move(x, y)
        
        # 确保按钮显示在最上层
        self.record_button.raise_()
        
        # 简化动画：直接显示按钮，不使用复杂动画
        self.record_button.show()
        self.record_button.setWindowOpacity(1.0)
        self.record_button.button_scale = 1.0
        
        # 启动简化脉冲动画
        self.start_record_pulse_animation()
    
    def fade_out_record_button(self):
        # 简化录制按钮淡出动画
        # 首先停止可能正在运行的淡入动画
        if hasattr(self, 'record_fade_in_animation'):
            self.record_fade_in_animation.stop()
            delattr(self, 'record_fade_in_animation')
        
        # 检查按钮是否可见，避免重复调用（添加安全检查）
        if not hasattr(self, 'record_button') or not self.record_button.isVisible():
            return
        
        # 简化动画：直接隐藏按钮，不使用复杂动画（添加安全检查）
        if hasattr(self, 'record_button'):
            self.record_button.hide()
            
            # 重置按钮状态
            self.record_button.setWindowOpacity(1.0)
            self.record_button.button_scale = 1.0
    
    def update_record_button_position(self, animated=True):
        # 简化录制按钮位置更新
        if self.is_recording:
            # 计算新位置
            window_pos = self.mapToGlobal(QPoint(0, 0))
            window_width = self.width()
            window_height = self.height()
            
            # 计算按钮的新位置
            button_width = self.record_button.width()
            button_height = self.record_button.height()
            
            new_x = window_pos.x() + window_width + 5
            new_y = window_pos.y() + (window_height - button_height) // 2
            
            # 屏幕边界检查
            desktop = QApplication.desktop()
            screen_geometry = desktop.screenGeometry(self)
            
            # 检查右侧边界
            if new_x + button_width > screen_geometry.right():
                new_x = screen_geometry.right() - button_width - 5
            
            # 检查顶部边界
            if new_y < screen_geometry.top():
                new_y = screen_geometry.top() + 5
            
            # 检查底部边界
            if new_y + button_height > screen_geometry.bottom():
                new_y = screen_geometry.bottom() - button_height - 5
            
            # 确保按钮可见
            if not self.record_button.isVisible():
                self.record_button.show()
            
            # 简化：直接移动按钮，不使用动画
            self.record_button.move(new_x, new_y)
    
    def start_record_pulse_animation(self):
        # 简化录制状态脉冲动画
        # 首先停止可能正在运行的脉冲动画
        if hasattr(self, 'record_pulse_animation'):
            self.record_pulse_animation.stop()
            delattr(self, 'record_pulse_animation')
        
        # 确保按钮处于正确的初始状态
        self.record_button.button_scale = 1.0
        
        # 简化脉冲动画：使用简单的缩放效果
        from PyQt5.QtCore import QPropertyAnimation
        self.record_pulse_animation = QPropertyAnimation(self.record_button, b"button_scale")
        self.record_pulse_animation.setDuration(1000)
        self.record_pulse_animation.setStartValue(1.0)
        self.record_pulse_animation.setEndValue(1.05)
        
        # 简化动画：只播放一次，不循环
        self.record_pulse_animation.start()
    
    def contextMenuEvent(self, event):
        # 右键菜单事件
        print(f"[DEBUG] contextMenuEvent: has_screen_recorder = {has_screen_recorder}")
        # 暂停窗口检查定时器，防止在右键菜单操作时隐藏窗口
        self.window_check_timer.stop()  # 修复拼写错误
        
        from PyQt5.QtWidgets import QMenu
        menu = QMenu(self)
        
        # 音量控制菜单项
        if has_volume_utils and volume_utils.volume_initialized:
            volume_menu = menu.addMenu("音量控制")
            volume_up_action = volume_menu.addAction("增加音量")
            volume_down_action = volume_menu.addAction("减少音量")
            mute_action = volume_menu.addAction("切换静音")
            menu.addSeparator()
            
            # 连接信号
            volume_up_action.triggered.connect(self.volume_up)
            volume_down_action.triggered.connect(self.volume_down)
            mute_action.triggered.connect(self.toggle_mute)
        
        # 屏幕录制菜单项
        if has_screen_recorder:
            print("[DEBUG] Adding screen recording menu")
            record_menu = menu.addMenu("屏幕录制")
            if not self.is_recording:
                print("[DEBUG] Added start recording action")
                start_record_action = record_menu.addAction("开始录制")
                start_record_action.triggered.connect(self.start_recording)
            else:
                print("[DEBUG] Added stop recording action")
                stop_record_action = record_menu.addAction("停止录制")
                stop_record_action.triggered.connect(self.stop_recording)
            menu.addSeparator()
        
        # 手势截屏功能已移除（保留其他菜单项不变）
        # 如需恢复，可在此处重新添加手势识别/截屏动作


        # 退出菜单项
        exit_action = menu.addAction("退出")
        
        # 执行菜单项
        action = menu.exec_(self.mapToGlobal(event.pos()))
        
        # 恢复窗口检查定时器
        self.window_check_timer.start(500)  # 修复拼写错误
        
        if action == exit_action:
            QApplication.quit()
    
    def update_time(self):
        from datetime import datetime
        current_datetime = datetime.now()
        current_time = current_datetime.strftime('%H:%M')
        current_date = current_datetime.strftime('%m-%d')
        
        # 更新时间标签
        self.time_label.setText(f"{current_date} {current_time}")
        
        # 更新日历详情
        week_day = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][current_datetime.weekday()]
        full_date = current_datetime.strftime('%Y年%m月%d日')
        self.calendar_detail_label.setText(f"{full_date} {week_day}")
    
    def keyPressEvent(self, event):
        # 键盘事件处理，用于音量控制快捷键
        modifiers = event.modifiers()
        key = event.key()
        
        # 音量增加：Ctrl + Up或Ctrl + 上箭头
        if modifiers & Qt.ControlModifier:
            if key == Qt.Key_Up or key == Qt.Key_Equal:
                self.volume_up()
            # 音量减少：Ctrl + Down或Ctrl + 减号
            elif key == Qt.Key_Down or key == Qt.Key_Minus:
                self.volume_down()
            # 静音切换：Ctrl + M
            elif key == Qt.Key_M:
                self.toggle_mute()
        
        event.accept()
    
    def set_desktop_only(self):
        # 设置仅桌面显示模式
        self.desktop_only = True
        self.check_current_window()  # 立即检查当前窗口状态
    
    def set_default_display(self):
        # 设置默认显示模式
        self.desktop_only = False
        self.show()  # 立即显示窗口
    
    def check_current_window(self):
        # 检查当前活动窗口，实现仅桌面显示功能
        if not self.desktop_only:
            return  # 如果不是仅桌面显示模式，直接返回
        
        try:
            # 尝试使用pygetwindow获取当前活动窗口
            try:
                import pygetwindow as gw
                current_window = gw.getActiveWindow()
                
                # 检查当前窗口是否为桌面
                if current_window is None or "Program Manager" in str(current_window):
                    self.show()
                else:
                    self.hide()
            except ImportError:
                # 如果没有安装pygetwindow，使用替代方法
                import win32gui
                hwnd = win32gui.GetForegroundWindow()
                window_title = win32gui.GetWindowText(hwnd)
                
                # 检查当前窗口是否为桌面
                if window_title == "" or window_title == "Program Manager":
                    self.show()
                else:
                    self.hide()
        except Exception as e:
            print(f"检查当前窗口失败: {e}")
            # 如果出现错误，默认显示窗口
            self.show()
    
    def check_activation_status(self):
        # 定期检查窗口激活状态，确保录制按钮始终在最上层
        if self.is_recording:
            # 确保录制按钮在主窗口可见时也可见
            if self.isVisible() and not self.record_button.isVisible():
                self.record_button.show()
            
            # 确保录制按钮始终在最上层
            self.record_button.raise_()
            
            # 检查主窗口是否激活，如果是，确保录制按钮也保持在激活状态
            if self.isActiveWindow():
                self.record_button.activateWindow()
                self.record_button.setFocus()
    
    def closeEvent(self, event):
        # 窗口关闭时停止所有线程
        self.music_thread.stop()
        self.music_thread.wait()
        
        # 停止手势识别线程
        if has_gesture_screenshot and hasattr(self, 'gesture_thread'):
            self.gesture_thread.stop_gesture_recognition()
            self.gesture_thread.wait()
        
        event.accept()
    
    def on_gesture_detected(self, gesture_type):
        """手势截屏已禁用，保持占位防止信号报错"""
        print(f"手势截屏已关闭，忽略手势: {gesture_type}")
    
    def on_gesture_trajectory(self, trajectory_data):

        """处理手势轨迹信号"""
        # 这里可以处理手势轨迹数据，比如显示轨迹或进行其他分析
        # 目前暂时只记录日志，可以根据需要扩展功能
        if len(trajectory_data) > 0:
            print(f"手势轨迹更新: {len(trajectory_data)}个轨迹点")
    
    def take_screenshot(self):
        """手动截屏已禁用，避免误触"""
        print("手动截屏功能已关闭，未执行操作")
    
    def start_gesture_recognition(self):
        """手势识别已禁用，不执行"""
        print("手势识别已关闭，不会启动")
        if hasattr(self, 'gesture_status_label') and self.gesture_status_label.isVisible():
            self.gesture_status_label.setText("👋⚫")
            self.gesture_status_label.setToolTip("手势识别功能已关闭")
    
    def stop_gesture_recognition(self):
        """手势识别已禁用，不执行"""
        print("手势识别已关闭，无需停止")
        if hasattr(self, 'gesture_status_label') and self.gesture_status_label.isVisible():
            self.gesture_status_label.setText("👋⚫")
            self.gesture_status_label.setToolTip("手势识别功能已关闭")
    

    
    def update_gesture_status(self):
        """更新手势识别状态显示"""
        self.gesture_status_label.setText("👋⚫")
        self.gesture_status_label.setToolTip("手势识别功能已关闭")

    
    def show_screenshot_notification(self, filename):
        """显示截屏成功的通知"""
        # 保存原始图标和样式
        original_text = self.notification_label.text()
        original_style = self.notification_label.styleSheet()
        
        # 设置截屏成功图标和特殊样式
        self.notification_label.setText("📸")
        self.notification_label.setStyleSheet("color: #00ff00; font-weight: bold; font-size: 16px;")
        
        # 添加闪烁动画效果
        from PyQt5.QtCore import QTimer, QPropertyAnimation, QEasingCurve
        
        # 创建闪烁动画
        self.flash_animation = QPropertyAnimation(self.notification_label, b"styleSheet")
        self.flash_animation.setDuration(500)
        self.flash_animation.setLoopCount(3)  # 闪烁3次
        
        # 设置动画关键帧
        self.flash_animation.setStartValue("color: #00ff00; font-weight: bold; font-size: 16px;")
        self.flash_animation.setKeyValueAt(0.5, "color: #ffff00; font-weight: bold; font-size: 18px;")
        self.flash_animation.setEndValue("color: #00ff00; font-weight: bold; font-size: 16px;")
        
        self.flash_animation.setEasingCurve(QEasingCurve.InOutQuad)
        self.flash_animation.start()
        
        # 使用定时器恢复原始图标和样式
        QTimer.singleShot(2000, lambda: self.restore_notification_icon(original_text, original_style))
        
        print(f"截屏成功: {filename}")
    
    def restore_notification_icon(self, original_text, original_style):
        """恢复通知图标到原始状态"""
        # 停止闪烁动画
        if hasattr(self, 'flash_animation') and self.flash_animation.state() == QPropertyAnimation.Running:
            self.flash_animation.stop()
        
        # 恢复原始图标和样式
        self.notification_label.setText(original_text)
        self.notification_label.setStyleSheet(original_style)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    island = DynamicIsland()
    island.show()
    sys.exit(app.exec_())

