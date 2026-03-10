#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改进的手势识别调试脚本
提供实时可视化调试界面，显示手势识别状态和参数
"""

import cv2
import numpy as np
import time
import sys
import os

# 添加当前目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_island import GestureRecognitionThread

def improved_gesture_debug():
    """改进的手势识别调试功能"""
    print("=== 改进的手势识别调试系统 ===")
    print("功能特性：")
    print("1. 实时显示手势识别状态")
    print("2. 可视化手势检测参数")
    print("3. 显示置信度和稳定性评分")
    print("4. 手部位置跟踪可视化")
    print("5. 抓握手势检测进度条")
    print()
    
    # 打开摄像头
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    
    if not cap.isOpened():
        print("错误：无法打开摄像头")
        return
    
    print("摄像头已打开，开始手势检测调试...")
    
    # 手势检测状态
    grab_detected = False
    grab_start_time = 0
    consecutive_grab_frames = 0
    min_consecutive_frames = 5
    min_grab_duration = 0.5
    
    # 手势识别参数
    gesture_confidence = 0.0
    min_confidence_threshold = 0.6
    confidence_increase_rate = 0.15
    confidence_decay_rate = 0.08
    
    # 手部跟踪状态
    hand_position_history = []
    max_tracking_history = 10
    
    # 手势历史
    gesture_type_history = []
    max_gesture_history = 15
    
    while True:
        success, image = cap.read()
        if not success:
            continue
        
        # 翻转图像
        image = cv2.flip(image, 1)
        
        # 转换到HSV和YCrCb颜色空间
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        ycrcb = cv2.cvtColor(image, cv2.COLOR_BGR2YCrCb)
        
        # 肤色检测
        lower_skin_hsv = np.array([0, 30, 60], dtype=np.uint8)
        upper_skin_hsv = np.array([25, 180, 255], dtype=np.uint8)
        lower_skin_ycrcb = np.array([0, 135, 85], dtype=np.uint8)
        upper_skin_ycrcb = np.array([255, 180, 135], dtype=np.uint8)
        
        mask_hsv = cv2.inRange(hsv, lower_skin_hsv, upper_skin_hsv)
        mask_ycrcb = cv2.inRange(ycrcb, lower_skin_ycrcb, upper_skin_ycrcb)
        mask = cv2.bitwise_or(mask_hsv, mask_ycrcb)
        
        # 形态学操作
        kernel_open = np.ones((3, 3), np.uint8)
        kernel_close = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)
        mask = cv2.medianBlur(mask, 5)
        mask = cv2.GaussianBlur(mask, (5, 5), 0)
        
        # 查找轮廓
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        hand_detected = False
        gesture_type = "unknown"
        max_area = 0
        hand_contour = None
        current_hand_position = None
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            if area > 500:
                x, y, w, h = cv2.boundingRect(contour)
                aspect_ratio = float(w)/h
                
                if 0.3 < aspect_ratio < 3.0:
                    hull = cv2.convexHull(contour)
                    hull_area = cv2.contourArea(hull)
                    
                    if hull_area > 0:
                        compactness = area / hull_area
                        
                        if 0.4 < compactness < 0.95:
                            hand_detected = True
                            
                            # 简化手势分类
                            if compactness > 0.75:
                                gesture_type = "fist"
                            elif compactness < 0.55:
                                gesture_type = "open"
                            else:
                                gesture_type = "grab"
                            
                            if area > max_area:
                                max_area = area
                                hand_contour = contour
                                current_hand_position = (x + w//2, y + h//2)
        
        # 手部位置跟踪
        if current_hand_position is not None:
            hand_position_history.append(current_hand_position)
            if len(hand_position_history) > max_tracking_history:
                hand_position_history.pop(0)
        
        # 手势历史追踪
        gesture_type_history.append(gesture_type)
        if len(gesture_type_history) > max_gesture_history:
            gesture_type_history.pop(0)
        
        # 计算手势稳定性
        stability_score = 0.0
        if len(gesture_type_history) >= 5:
            recent_gestures = gesture_type_history[-5:]
            stability_score = recent_gestures.count(gesture_type) / 5
        
        # 更新置信度
        if hand_detected:
            if gesture_type == "grab":
                gesture_confidence = min(1.0, gesture_confidence + confidence_increase_rate)
            else:
                gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate)
        else:
            gesture_confidence = max(0.0, gesture_confidence - confidence_decay_rate * 3)
        
        # 手势检测逻辑
        if hand_detected:
            if gesture_type == "grab":
                consecutive_grab_frames += 1
                
                # 基于置信度调整检测阈值
                confidence_adjusted_frames = max(3, int(min_consecutive_frames * (1.0 - gesture_confidence * 0.5)))
                
                if consecutive_grab_frames >= confidence_adjusted_frames and gesture_confidence >= min_confidence_threshold and not grab_detected:
                    grab_detected = True
                    grab_start_time = time.time()
                    print(f"开始检测抓握手势，置信度：{gesture_confidence:.2f}")
                
                elif grab_detected:
                    if gesture_type != "grab" or gesture_confidence < min_confidence_threshold * 0.7:
                        grab_detected = False
                        consecutive_grab_frames = 0
                        print(f"手势类型改变，重置检测状态")
                    elif time.time() - grab_start_time > min_grab_duration:
                        print("抓握手势已确认，执行截屏！")
                        grab_detected = False
                        consecutive_grab_frames = 0
                        time.sleep(1.5)
            else:
                consecutive_grab_frames = 0
        else:
            consecutive_grab_frames = 0
            grab_detected = False
        
        # 绘制调试信息
        # 1. 手势类型和状态
        cv2.putText(image, f"手势: {gesture_type}", (10, 30), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # 2. 置信度显示
        cv2.putText(image, f"置信度: {gesture_confidence:.2f}", (10, 60), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # 3. 稳定性评分
        cv2.putText(image, f"稳定性: {stability_score:.2f}", (10, 90), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        # 4. 抓握检测进度
        if grab_detected:
            elapsed_time = time.time() - grab_start_time
            progress = min(1.0, elapsed_time / min_grab_duration)
            
            # 绘制进度条
            bar_width = 200
            bar_height = 20
            bar_x = 10
            bar_y = 120
            
            cv2.rectangle(image, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), (100, 100, 100), -1)
            cv2.rectangle(image, (bar_x, bar_y), (bar_x + int(bar_width * progress), bar_y + bar_height), (0, 255, 0), -1)
            cv2.putText(image, f"截屏倒计时: {min_grab_duration - elapsed_time:.1f}s", 
                        (bar_x, bar_y + bar_height + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        
        # 5. 手部位置跟踪可视化
        for i, pos in enumerate(hand_position_history):
            radius = max(2, 10 - i)  # 历史位置逐渐变小
            color = (0, 255, 0) if i == 0 else (255, 0, 0)  # 当前位置绿色，历史位置蓝色
            cv2.circle(image, pos, radius, color, -1)
        
        # 6. 手部轮廓绘制
        if hand_contour is not None:
            cv2.drawContours(image, [hand_contour], -1, (0, 0, 255), 2)
            
            # 绘制手部中心点
            if current_hand_position is not None:
                cv2.circle(image, current_hand_position, 5, (0, 255, 0), -1)
        
        # 7. 检测参数显示
        param_y = 180
        cv2.putText(image, f"连续抓握帧数: {consecutive_grab_frames}/{min_consecutive_frames}", 
                    (10, param_y), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 1)
        cv2.putText(image, f"手部面积: {max_area}", 
                    (10, param_y + 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 1)
        
        # 显示图像
        cv2.imshow("改进的手势识别调试", image)
        
        # 按 'q' 键退出
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
        
        # 控制帧率
        time.sleep(0.03)
    
    cap.release()
    cv2.destroyAllWindows()
    print("调试结束")

def main():
    """主函数"""
    # 自动选择改进的手势识别调试模式
    print("自动选择改进的手势识别调试模式...")
    improved_gesture_debug()

if __name__ == "__main__":
    main()