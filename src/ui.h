#pragma once

// 绘制灵动岛主界面
// 返回 true 表示进入了全屏覆盖模式
void DrawIslandUI(bool isDesktop, bool isFullscreen, bool isMouseOver, float animationY, float deltaTime);

// 绘制设置窗口
void DrawSettingsWindow();

// 检查鼠标是否悬停在灵动岛区域
bool IsMouseOverIsland();
