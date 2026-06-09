#pragma once

#include <windows.h>
#include <d3d11.h>

// 全局 D3D 设备
extern ID3D11Device* g_pd3dDevice;
extern ID3D11DeviceContext* g_pd3dDeviceContext;
extern IDXGISwapChain* g_pSwapChain;
extern ID3D11RenderTargetView* g_mainRenderTargetView;

// 窗口相关
extern HWND g_hwnd;
extern bool g_running;
extern bool g_windowVisible;
extern bool g_islandVisible;
extern bool g_islandExpanded;

// 设置窗口
extern bool g_showSettings;

// 托盘消息 ID
extern const UINT WM_TRAYICON;

// --- 函数声明 ---

// 更新窗口位置和大小
void UpdateWindowGeometry();

// D3D 设备管理
bool CreateDeviceD3D(HWND hWnd);
void CreateRenderTarget();
void CleanupRenderTarget();
void CleanupDeviceD3D();

// 窗口过程
LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

// 创建主窗口
HWND CreateMainWindow();
