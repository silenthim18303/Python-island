#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
手势识别问题诊断脚本
专门诊断手抓握识别和手拿开后误触发问题的具体原因
"""

import cv2
import numpy as np
import time
import sys
import os

# 添加当前目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def diagnose_gesture_issues():
    """诊断手势识别问题的具体原因"""
    print("=== 手势识别问题诊断 ===")
    print("诊断目标：")
    print("1. 分析手势分类算法的准确性")
    print("2. 检测手势检测参数的合理性")
    print("3. 验证手势状态转换的稳定性")
    print("")
    
    # 打开摄像头进行实时诊断
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("❌ 无法打开摄像头，跳过诊断")
        return
    
    print("✅ 摄像头已打开，开始手势诊断")
    print("请做出不同的手势，观察诊断信息")
    print("按 'q' 键退出诊断")
    print("")
    
    # 诊断统计
    diagnosis_stats = {
        "grab_frames": 0,
        "fist_frames": 0,
        "open_frames": 0,
        "unknown_frames": 0,
        "gesture_changes": 0,
        "hand_detected_frames": 0,
        "no_hand_frames": 0
    }
    
    prev_gesture = "unknown"
    frame_count = 0
    
    while True:
        success, image = cap.read()
        if not success:
            continue
        
        frame_count += 1
        
        # 翻转图像
        image = cv2.flip(image, 1)
        
        # 手势检测
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        
        # 肤色检测
        lower_skin = np.array([0, 20, 50], dtype=np.uint8)
        upper_skin = np.array([25, 220, 255], dtype=np.uint8)
        mask = cv2.inRange(hsv, lower_skin, upper_skin)
        
        # 形态学操作
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        
        # 查找轮廓
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        hand_detected = False
        gesture_type = "unknown"
        gesture_details = {}
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            if area > 500:
                # 手势形状分析
                hull = cv2.convexHull(contour)
                hull_area = cv2.contourArea(hull)
                
                if hull_area > 0:
                    compactness = area / hull_area
                    
                    # 计算轮廓的周长和圆度
                    perimeter = cv2.arcLength(contour, True)
                    circularity = 4 * np.pi * area / (perimeter * perimeter) if perimeter > 0 else 0
                    
                    # 计算轮廓的边界矩形和宽高比
                    x, y, w, h = cv2.boundingRect(contour)
                    aspect_ratio = float(w) / h if h > 0 else 0
                    rect_area = w * h
                    extent = float(area) / rect_area if rect_area > 0 else 0
                    
                    # 计算凸性缺陷（手指数量）
                    hull_indices = cv2.convexHull(contour, returnPoints=False)
                    finger_count = 0
                    
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
                                
                                # 凸性缺陷条件
                                if angle < 90 and d > 800 and d < 3000:
                                    finger_count += 1
                    
                    # 手势分类算法（与dynamic_island.py保持一致）
                    # 智能手势分类算法：基于多特征加权评分
                    
                    # 特征权重分配
                    compactness_weight = 0.4
                    finger_count_weight = 0.3
                    extent_weight = 0.2
                    circularity_weight = 0.1
                    
                    # 计算各手势类型的得分
                    grab_score = 0.0
                    fist_score = 0.0
                    open_score = 0.0
                    
                    # 抓握手势评分（中等紧凑度，中等手指数量）
                    if 0.4 <= compactness <= 0.75:
                        grab_score += compactness_weight * 0.8
                    if 2 <= finger_count <= 4:
                        grab_score += finger_count_weight * 1.0
                    elif 1 <= finger_count <= 5:
                        grab_score += finger_count_weight * 0.6
                    if 0.5 <= extent <= 0.85:
                        grab_score += extent_weight * 0.8
                    if circularity > 0.3:
                        grab_score += circularity_weight * 0.7
                    
                    # 握拳手势评分（高紧凑度，少手指）
                    if compactness > 0.75:
                        fist_score += compactness_weight * 1.0
                    if finger_count <= 2:
                        fist_score += finger_count_weight * 1.0
                    elif finger_count <= 3:
                        fist_score += finger_count_weight * 0.5
                    if extent > 0.7:
                        fist_score += extent_weight * 0.8
                    if circularity > 0.4:
                        fist_score += circularity_weight * 0.6
                    
                    # 张开手势评分（低紧凑度，多手指）
                    if compactness < 0.55:  # 提高紧凑度阈值，更容易识别张开手势
                        open_score += compactness_weight * 1.0
                    elif compactness < 0.65:  # 中等偏低紧凑度也考虑张开手势
                        open_score += compactness_weight * 0.5
                    if finger_count >= 2:  # 降低手指数量要求
                        open_score += finger_count_weight * 1.0
                    elif finger_count >= 1:
                        open_score += finger_count_weight * 0.5
                    if extent < 0.75:  # 提高范围阈值
                        open_score += extent_weight * 0.8
                    if circularity < 0.7:  # 提高圆度阈值
                        open_score += circularity_weight * 0.6
                    
                    # 选择得分最高的手势类型
                    scores = {"grab": grab_score, "fist": fist_score, "open": open_score}
                    max_gesture = max(scores, key=scores.get)
                    max_score = scores[max_gesture]
                    
                    # 置信度阈值检查
                    if max_score > 0.4:
                        gesture_type = max_gesture
                    else:
                        # 低置信度时使用紧凑度作为主要判断依据
                        if compactness > 0.7:
                            gesture_type = "fist"
                        elif compactness < 0.4:
                            gesture_type = "open"
                        else:
                            gesture_type = "unknown"
                    
                    hand_detected = True
                    gesture_details = {
                        "area": area,
                        "compactness": compactness,
                        "finger_count": finger_count,
                        "extent": extent,
                        "circularity": circularity,
                        "aspect_ratio": aspect_ratio
                    }
                    break  # 只处理最大的轮廓
        
        # 更新诊断统计
        if hand_detected:
            diagnosis_stats["hand_detected_frames"] += 1
            
            if gesture_type == "grab":
                diagnosis_stats["grab_frames"] += 1
            elif gesture_type == "fist":
                diagnosis_stats["fist_frames"] += 1
            elif gesture_type == "open":
                diagnosis_stats["open_frames"] += 1
            else:
                diagnosis_stats["unknown_frames"] += 1
            
            # 检测手势变化
            if gesture_type != prev_gesture:
                diagnosis_stats["gesture_changes"] += 1
                if prev_gesture != "unknown":
                    print(f"手势变化: {prev_gesture} -> {gesture_type}")
            
            prev_gesture = gesture_type
        else:
            diagnosis_stats["no_hand_frames"] += 1
            prev_gesture = "unknown"
        
        # 显示诊断信息
        cv2.putText(image, f"手势: {gesture_type}", (10, 30), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        if hand_detected and gesture_details:
            cv2.putText(image, f"面积: {gesture_details['area']:.0f}", (10, 60), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            cv2.putText(image, f"紧凑度: {gesture_details['compactness']:.2f}", (10, 80), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            cv2.putText(image, f"手指数: {gesture_details['finger_count']}", (10, 100), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            cv2.putText(image, f"范围: {gesture_details['extent']:.2f}", (10, 120), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            cv2.putText(image, f"圆度: {gesture_details['circularity']:.2f}", (10, 140), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            cv2.putText(image, f"宽高比: {gesture_details['aspect_ratio']:.2f}", (10, 160), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        cv2.imshow("手势识别问题诊断", image)
        
        # 每100帧输出一次诊断摘要
        if frame_count % 100 == 0:
            print(f"\n=== 诊断摘要 (帧 {frame_count}) ===")
            print(f"手部检测帧数: {diagnosis_stats['hand_detected_frames']}")
            print(f"无手部帧数: {diagnosis_stats['no_hand_frames']}")
            print(f"抓握帧数: {diagnosis_stats['grab_frames']}")
            print(f"握拳帧数: {diagnosis_stats['fist_frames']}")
            print(f"张开帧数: {diagnosis_stats['open_frames']}")
            print(f"未知帧数: {diagnosis_stats['unknown_frames']}")
            print(f"手势变化次数: {diagnosis_stats['gesture_changes']}")
            print("")
        
        # 按 'q' 键退出
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
        
        time.sleep(0.03)
    
    cap.release()
    cv2.destroyAllWindows()
    
    # 输出最终诊断结果
    print("\n=== 最终诊断结果 ===")
    total_frames = diagnosis_stats["hand_detected_frames"] + diagnosis_stats["no_hand_frames"]
    
    if total_frames > 0:
        hand_detection_rate = diagnosis_stats["hand_detected_frames"] / total_frames * 100
        print(f"手部检测率: {hand_detection_rate:.1f}%")
        
        if diagnosis_stats["hand_detected_frames"] > 0:
            grab_rate = diagnosis_stats["grab_frames"] / diagnosis_stats["hand_detected_frames"] * 100
            fist_rate = diagnosis_stats["fist_frames"] / diagnosis_stats["hand_detected_frames"] * 100
            open_rate = diagnosis_stats["open_frames"] / diagnosis_stats["hand_detected_frames"] * 100
            unknown_rate = diagnosis_stats["unknown_frames"] / diagnosis_stats["hand_detected_frames"] * 100
            
            print(f"抓握识别率: {grab_rate:.1f}%")
            print(f"握拳识别率: {fist_rate:.1f}%")
            print(f"张开识别率: {open_rate:.1f}%")
            print(f"未知手势率: {unknown_rate:.1f}%")
            
            gesture_change_frequency = diagnosis_stats["gesture_changes"] / diagnosis_stats["hand_detected_frames"] * 100
            print(f"手势变化频率: {gesture_change_frequency:.1f}%")
            
            # 诊断建议
            print("\n=== 诊断建议 ===")
            if grab_rate < 30:
                print("❌ 抓握识别率过低，需要优化手势分类算法")
            if gesture_change_frequency > 10:
                print("⚠️  手势变化过于频繁，需要提高手势稳定性检测")
            if unknown_rate > 20:
                print("⚠️  未知手势比例过高，需要优化手势特征提取")
            
            if grab_rate >= 50 and gesture_change_frequency < 5:
                print("✅ 手势识别算法表现良好")
            else:
                print("❌ 手势识别算法需要进一步优化")
    
    print("诊断完成")

if __name__ == "__main__":
    diagnose_gesture_issues()