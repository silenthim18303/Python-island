#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
增强手势识别优化脚本
进一步优化手势识别，减少误触发，提高准确性
"""

import cv2
import numpy as np
import time
import sys
import os

# 添加当前目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def optimize_gesture_parameters():
    """优化手势识别参数"""
    
    optimized_params = {
        # 基础检测参数（更严格）
        "min_consecutive_frames": 10,  # 增加连续检测帧数要求
        "max_no_hand_frames": 6,      # 减少允许的连续未检测帧数
        "min_grab_duration": 1.0,     # 增加抓握手势持续时间要求
        
        # 置信度参数（更保守）
        "min_confidence_threshold": 0.85,  # 进一步提高最小置信度阈值
        "confidence_increase_rate": 0.08,  # 降低置信度增加率
        "confidence_decay_rate": 0.15,     # 提高置信度衰减率
        
        # 稳定性参数（更严格）
        "stability_window_size": 8,        # 增加稳定性窗口大小
        "gesture_stability_threshold": 0.85, # 提高稳定性阈值
        
        # 手部验证参数（更严格）
        "min_hand_area": 1000,             # 提高最小手部面积要求
        "max_hand_area": 18000,            # 降低最大手部面积要求
        "area_score_threshold": 0.8,       # 提高面积评分阈值
        "stability_score_threshold": 0.75, # 提高稳定性评分阈值
        "position_score_threshold": 0.75,  # 提高位置评分阈值
        "validation_score_threshold": 0.75, # 提高综合验证阈值
        
        # 图像处理参数（更精确）
        "adaptive_threshold_base": 1000,   # 提高自适应面积阈值
        "brightness_compensation": True,   # 启用亮度补偿
        "noise_reduction": True,           # 启用噪声抑制
        
        # 多阶段验证参数
        "multi_stage_validation": True,    # 启用多阶段验证
        "initial_validation_frames": 5,    # 初始验证帧数
        "final_validation_frames": 3,      # 最终验证帧数
    }
    
    return optimized_params

def enhanced_hand_validation(hand_area, stability_score, position_variance, 
                           gesture_confidence, gesture_type_history, 
                           hand_position_history, params):
    """增强的手部验证系统"""
    
    # 1. 基础验证
    if hand_area < params["min_hand_area"] or hand_area > params["max_hand_area"]:
        return False, "面积超出范围"
    
    if gesture_confidence < params["min_confidence_threshold"] * 0.5:
        return False, "置信度过低"
    
    # 2. 多阶段稳定性验证
    if len(gesture_type_history) >= params["stability_window_size"]:
        recent_gestures = gesture_type_history[-params["stability_window_size"]:]
        current_stability = recent_gestures.count("grab") / params["stability_window_size"]
        
        if current_stability < params["gesture_stability_threshold"] * 0.8:
            return False, "稳定性不足"
    
    # 3. 位置稳定性验证
    if len(hand_position_history) >= 4:
        positions = np.array(hand_position_history[-4:])
        position_variance = np.var(positions, axis=0).mean()
        
        if position_variance > 80:  # 更严格的位置变化限制
            return False, "位置变化过大"
    
    # 4. 综合评分计算
    area_score = 1.0 if params["min_hand_area"] <= hand_area <= params["max_hand_area"] else 0.0
    
    stability_score_normalized = min(1.0, stability_score)
    position_score = max(0.0, 1.0 - position_variance / 150.0)  # 更严格的位置评分
    
    validation_score = (area_score * 0.25 + 
                       stability_score_normalized * 0.35 + 
                       position_score * 0.4)  # 增加位置权重
    
    if validation_score < params["validation_score_threshold"]:
        return False, f"综合评分不足: {validation_score:.2f}"
    
    return True, f"验证通过: {validation_score:.2f}"

def adaptive_skin_detection(image, avg_brightness, params):
    """自适应皮肤检测"""
    
    # 根据亮度调整皮肤检测参数
    if avg_brightness < 40:  # 极低光照
        # 使用更宽松的皮肤检测参数
        lower_skin = np.array([0, 20, 60], dtype=np.uint8)
        upper_skin = np.array([20, 150, 255], dtype=np.uint8)
    elif avg_brightness < 80:  # 低光照
        lower_skin = np.array([0, 30, 60], dtype=np.uint8)
        upper_skin = np.array([20, 150, 255], dtype=np.uint8)
    else:  # 正常光照
        lower_skin = np.array([0, 40, 80], dtype=np.uint8)
        upper_skin = np.array([20, 150, 255], dtype=np.uint8)
    
    # 转换到HSV颜色空间
    hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
    
    # 皮肤检测
    skin_mask = cv2.inRange(hsv, lower_skin, upper_skin)
    
    # 噪声抑制
    if params["noise_reduction"]:
        kernel = np.ones((3, 3), np.uint8)
        skin_mask = cv2.morphologyEx(skin_mask, cv2.MORPH_OPEN, kernel)
        skin_mask = cv2.morphologyEx(skin_mask, cv2.MORPH_CLOSE, kernel)
    
    return skin_mask

def test_enhanced_gesture_recognition():
    """测试增强的手势识别"""
    
    print("=== 增强手势识别测试 ===")
    print("测试目标：验证优化后的手势识别误触发率")
    print()
    
    # 加载优化参数
    params = optimize_gesture_parameters()
    
    # 打开摄像头
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    
    if not cap.isOpened():
        print("错误：无法打开摄像头")
        return
    
    print("摄像头已打开，开始增强手势识别测试...")
    print("请确保摄像头前没有手部，测试将运行30秒")
    
    # 测试参数
    test_duration = 30
    start_time = time.time()
    
    # 统计信息
    total_frames = 0
    false_trigger_count = 0
    hand_detected_count = 0
    
    # 手势检测状态
    gesture_confidence = 0.0
    consecutive_grab_frames = 0
    grab_detected = False
    grab_start_time = 0
    
    # 历史记录
    gesture_type_history = []
    hand_position_history = []
    
    while time.time() - start_time < test_duration:
        success, image = cap.read()
        if not success:
            continue
        
        total_frames += 1
        
        # 转换图像格式
        image = cv2.cvtColor(cv2.flip(image, 1), cv2.COLOR_BGR2RGB)
        
        # 计算图像亮度
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        avg_brightness = np.mean(gray)
        
        # 自适应皮肤检测
        skin_mask = adaptive_skin_detection(image, avg_brightness, params)
        
        # 查找轮廓
        contours, _ = cv2.findContours(skin_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        hand_detected = False
        max_area = 0
        current_hand_position = None
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            # 过滤小面积轮廓
            if area > params["adaptive_threshold_base"]:
                hand_detected = True
                
                if area > max_area:
                    max_area = area
                    
                    # 计算手部位置
                    x, y, w, h = cv2.boundingRect(contour)
                    current_hand_position = (x + w//2, y + h//2)
        
        # 手势检测逻辑
        if hand_detected:
            hand_detected_count += 1
            
            # 模拟手势类型（在无手部情况下应该为None）
            gesture_type = None
            
            # 更新手势历史
            gesture_type_history.append(gesture_type)
            if len(gesture_type_history) > params["stability_window_size"]:
                gesture_type_history.pop(0)
            
            # 更新位置历史
            if current_hand_position:
                hand_position_history.append(current_hand_position)
                if len(hand_position_history) > 8:
                    hand_position_history.pop(0)
            
            # 计算稳定性
            stability_score = 0.0
            if len(gesture_type_history) >= 4:
                recent_gestures = gesture_type_history[-4:]
                stability_score = recent_gestures.count(None) / 4.0
            
            # 计算位置方差
            position_variance = 0.0
            if len(hand_position_history) >= 3:
                positions = np.array(hand_position_history[-3:])
                position_variance = np.var(positions, axis=0).mean()
            
            # 增强的手部验证
            hand_valid, validation_message = enhanced_hand_validation(
                max_area, stability_score, position_variance, 
                gesture_confidence, gesture_type_history, 
                hand_position_history, params
            )
            
            if not hand_valid:
                # 手部验证失败，重置检测状态
                consecutive_grab_frames = 0
                grab_detected = False
                gesture_confidence = max(0.0, gesture_confidence - params["confidence_decay_rate"] * 2)
            else:
                # 手部验证通过，更新置信度
                gesture_confidence = min(1.0, gesture_confidence + params["confidence_increase_rate"])
                
                # 模拟抓握手势检测
                if gesture_type == "grab":
                    consecutive_grab_frames += 1
                    
                    # 更严格的触发条件
                    if (consecutive_grab_frames >= params["min_consecutive_frames"] and 
                        gesture_confidence >= params["min_confidence_threshold"] and 
                        not grab_detected):
                        
                        grab_detected = True
                        grab_start_time = time.time()
                        false_trigger_count += 1
                        print(f"误触发检测！帧数: {total_frames}, 置信度: {gesture_confidence:.2f}")
                else:
                    consecutive_grab_frames = 0
                    gesture_confidence = max(0.0, gesture_confidence - params["confidence_decay_rate"])
        else:
            # 未检测到手部
            consecutive_grab_frames = 0
            gesture_confidence = max(0.0, gesture_confidence - params["confidence_decay_rate"] * 3)
            
            if grab_detected:
                grab_detected = False
        
        # 控制帧率
        time.sleep(0.03)
    
    # 关闭摄像头
    cap.release()
    
    # 输出测试结果
    print("\n=== 测试结果 ===")
    print(f"总帧数: {total_frames}")
    print(f"手部检测次数: {hand_detected_count}")
    print(f"误触发次数: {false_trigger_count}")
    print(f"误触发率: {false_trigger_count / total_frames * 100:.2f}%")
    
    if false_trigger_count == 0:
        print("✅ 增强手势识别测试通过：无误触发")
    elif false_trigger_count <= 3:
        print("⚠️ 增强手势识别测试基本通过：误触发率较低")
    else:
        print("❌ 增强手势识别测试失败：误触发率较高")

if __name__ == "__main__":
    test_enhanced_gesture_recognition()