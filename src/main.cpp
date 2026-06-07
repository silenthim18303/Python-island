#include <windows.h>
#include <d3d11.h>
#include <dwmapi.h>
#include <tchar.h>
#include <chrono>
#include <stdio.h>
#include <shlobj.h>

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

#include "logging.h"
#include "config.h"
#include "sysinfo.h"
#include "trayicon.h"
#include "scheduler.h"
#include "window.h"
#include "ui.h"

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shlwapi.lib")

// === 初始化程序 ===
bool InitializeApp(const bool silentStart) {
    // 清除旧日志
    FILE* f = fopen("log/dynamicisland.log", "w");
    if(f) fclose(f);

    LOG_INFO("=== DynamicIsland Starting ===");
    LOG_INFO("silentStart=%d", silentStart);

    // 初始化日志系统
    // 这句话取消注释就可以启用控制台log
    Logger::Instance().SetConsoleOutput(true);

    // 初始化 COM 库
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) {
        LOG_ERROR("Failed to initialize COM: 0x%X", hr);
        return false;
    }

    // 1. 加载配置
    LOG_INFO("Loading config...");
    if (!g_config.Load()) {
        LOG_INFO("Config not found, creating default");
        g_config.Save();
    }
    LOG_INFO("Config loaded: opacity=%.2f", g_config.GetAppearance().opacity);

    // 2. 初始化系统信息监控
    LOG_INFO("Initializing sysinfo...");
    if (!g_sysinfo.Initialize()) {
        LOG_ERROR("Failed to initialize sysinfo");
        MessageBox(nullptr, L"Failed to initialize system info monitor", L"Error", MB_OK);
        return false;
    }
    LOG_INFO("Sysinfo initialized");

    // 3. 启动监控线程
    LOG_INFO("Starting monitoring thread...");
    g_sysinfo.StartMonitoring();
    LOG_INFO("Monitoring started");

    // 4. 初始化任务计划程序
    LOG_INFO("Initializing scheduler...");
    g_scheduler.Initialize();
    if (g_config.GetBehavior().start_with_windows) {
        LOG_INFO("Startup enabled, checking registration...");
        if (!g_scheduler.IsRegistered()) {
            LOG_INFO("Not registered, registering...");
            TaskConfig taskConfig;
            taskConfig.delayStart = true;
            taskConfig.delaySeconds = 30;
            taskConfig.hidden = true;
            g_scheduler.Register(taskConfig);
        }
    }

    // 5. 创建窗口
    LOG_INFO("Creating main window...");
    g_hwnd = CreateMainWindow();
    LOG_INFO("Window handle: %p", g_hwnd);
    if (!g_hwnd) {
        MessageBox(nullptr, L"Failed to create window", L"Error", MB_OK);
        return false;
    }

    // 6. 初始化D3D
    LOG_INFO("Initializing D3D...");
    if (!CreateDeviceD3D(g_hwnd)) {
        LOG_ERROR("Failed to initialize D3D");
        CleanupDeviceD3D();
        ::DestroyWindow(g_hwnd);
        g_hwnd = nullptr;
        return false;
    }
    LOG_INFO("D3D initialized: device=%p", g_pd3dDevice);

    // 7. 初始化托盘图标
    LOG_INFO("Initializing tray icon...");
    if (!g_trayIcon.Initialize(g_hwnd, WM_TRAYICON)) {
        LOG_ERROR("Failed to initialize tray icon");
    } else {
        LOG_INFO("Tray icon initialized");
    }

    // 8. 设置托盘回调
    g_trayIcon.SetShowHideCallback([]() {
        g_islandVisible = !g_islandVisible;
    });

    g_trayIcon.SetExpandCallback([]() {
        g_islandExpanded = !g_islandExpanded;
        g_trayIcon.UpdateMenuState(
            g_windowVisible, g_islandExpanded,
            PerformanceMode::BALANCED,
            IslandPosition::TOP_CENTER,
            g_config.GetBehavior().start_with_windows
        );
    });

    g_trayIcon.SetPerformanceCallback([](PerformanceMode mode) {
        // 性能模式设置
    });

    g_trayIcon.SetPositionCallback([](IslandPosition pos) {
        g_config.GetIsland().position =
            (pos == IslandPosition::TOP_CENTER) ? "top-center" :
            (pos == IslandPosition::TOP_LEFT) ? "top-left" : "follow-taskbar";
        g_config.Save();
    });

    g_trayIcon.SetStartupCallback([](bool enabled) {
        g_config.GetBehavior().start_with_windows = enabled;
        g_config.Save();
        if (enabled) {
            TaskConfig taskConfig;
            taskConfig.delayStart = true;
            taskConfig.delaySeconds = 30;
            taskConfig.hidden = true;
            g_scheduler.Register(taskConfig);
        } else {
            g_scheduler.Unregister();
        }
    });

    g_trayIcon.SetExitCallback([]() {
        g_running = false;
        PostQuitMessage(0);
    });

    g_trayIcon.SetSettingsCallback([]() {
        g_showSettings = true;
    });

    // 9. 初始化ImGui
    LOG_INFO("Initializing ImGui...");
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    LOG_INFO("ImGui context created");

    ImGui::StyleColorsDark();
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 20.0f;
    style.FrameRounding = 8.0f;
    style.GrabRounding = 8.0f;
    style.PopupRounding = 8.0f;
    style.ScrollbarRounding = 8.0f;
    style.TabRounding = 8.0f;

    auto& appearance = g_config.GetAppearance();
    style.Alpha = appearance.opacity;

    ImGui_ImplWin32_Init(g_hwnd);
    ImGui_ImplDX11_Init(g_pd3dDevice, g_pd3dDeviceContext);

    // 10. 显示窗口
    if (!silentStart && !g_config.GetBehavior().start_minimized) {
        ::ShowWindow(g_hwnd, SW_SHOW);
        g_windowVisible = true;
    } else {
        if (g_config.GetBehavior().start_minimized) {
            ::ShowWindow(g_hwnd, SW_HIDE);
            g_windowVisible = false;
        } else {
            ::ShowWindow(g_hwnd, SW_SHOW);
            g_windowVisible = true;
        }
    }

    // 11. 注册全局热键 Ctrl+Shift+Z
    if (!RegisterHotKey(g_hwnd, 1, MOD_CONTROL | MOD_SHIFT, 'Z')) {
        LOG_ERROR("Failed to register hotkey");
    } else {
        LOG_INFO("Hotkey Ctrl+Shift+Z registered");
    }

    // 12. 更新托盘菜单状态
    g_trayIcon.UpdateMenuState(
        g_windowVisible, g_islandExpanded,
        PerformanceMode::BALANCED,
        IslandPosition::TOP_CENTER,
        g_config.GetBehavior().start_with_windows
    );

    return true;
}

// === 关闭程序 ===
void ShutdownApp() {
    g_config.Save();

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();

    g_trayIcon.Shutdown();
    g_sysinfo.Shutdown();
    g_scheduler.Shutdown();

    CleanupDeviceD3D();

    if (g_hwnd) {
        ::DestroyWindow(g_hwnd);
        g_hwnd = nullptr;
    }

    UnregisterHotKey(g_hwnd, 1);
    LOG_INFO("Hotkey unregistered");

    ::UnregisterClass(L"DynamicIsland", GetModuleHandle(nullptr));

    CoUninitialize();
    LOG_INFO("COM uninitialized");
}

// === 入口点 ===
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPWSTR lpCmdLine, int nCmdShow) {
    // 最早期的日志
    FILE* earlyLog = fopen("dynamicisland_early.log", "w");
    if (earlyLog) {
        fprintf(earlyLog, "WinMain started\n");
        fclose(earlyLog);
    }

    // 解析命令行参数
    bool silentStart = false;
    for (int i = 1; i < __argc; ++i) {
        char arg[256] = {};
        WideCharToMultiByte(CP_UTF8, 0, __wargv[i], -1, arg, 256, nullptr, nullptr);
        if (_stricmp(arg, "/background") == 0) {
            silentStart = true;
        }
    }

    earlyLog = fopen("dynamicisland_early.log", "a");
    if (earlyLog) {
        fprintf(earlyLog, "silentStart=%d\n", silentStart);
        fclose(earlyLog);
    }

    // 单实例保护
    HANDLE hMutex = CreateMutex(nullptr, FALSE, TEXT("Global\\DynamicIsland"));
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        earlyLog = fopen("dynamicisland_early.log", "a");
        if (earlyLog) {
            fprintf(earlyLog, "Another instance running, exiting\n");
            fclose(earlyLog);
        }
        HWND existingWnd = FindWindow(L"DynamicIsland", nullptr);
        if (existingWnd) {
            ShowWindow(existingWnd, SW_SHOW);
            SetForegroundWindow(existingWnd);
        }
        return 0;
    }

    earlyLog = fopen("dynamicisland_early.log", "a");
    if (earlyLog) {
        fprintf(earlyLog, "Mutex created, calling InitializeApp\n");
        fclose(earlyLog);
    }

    // 初始化应用程序
    if (!InitializeApp(silentStart)) {
        if (hMutex) CloseHandle(hMutex);
        return 1;
    }

    // === 主循环 ===
    LOG_INFO("Entering main loop");
    MSG msg;
    ZeroMemory(&msg, sizeof(msg));

    auto lastTime = std::chrono::steady_clock::now();
    int frameCount = 0;

    // 动画变量
    float animationY = 20.0f;
    float targetY = 20.0f;

    while (g_running) {
        // 处理Windows消息
        while (::PeekMessage(&msg, nullptr, 0U, 0U, PM_REMOVE)) {
            ::TranslateMessage(&msg);
            ::DispatchMessage(&msg);
            if (msg.message == WM_QUIT)
                g_running = false;
        }

        if (!g_running) break;

        // 计算 deltaTime
        auto currentTime = std::chrono::steady_clock::now();
        float deltaTime = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;

        // 动画更新
        const float animationSpeed = 8.0f;
        animationY += (targetY - animationY) * deltaTime * animationSpeed;

        // === 状态检测 ===
        // 桌面检测
        bool isDesktop = false;
        HWND foregroundWindow = GetForegroundWindow();
        HWND desktopWindow = GetDesktopWindow();
        HWND shellWindow = GetShellWindow();
        if (!foregroundWindow || foregroundWindow == desktopWindow || foregroundWindow == shellWindow) {
            isDesktop = true;
        } else {
            wchar_t className[256];
            GetClassNameW(foregroundWindow, className, sizeof(className) / sizeof(wchar_t));
            if (wcscmp(className, L"Progman") == 0 || wcscmp(className, L"WorkerW") == 0) {
                isDesktop = true;
            }
        }

        // 全屏检测
        bool isFullscreen = false;
        if (!isDesktop && foregroundWindow) {
            WINDOWPLACEMENT placement;
            if (GetWindowPlacement(foregroundWindow, &placement)) {
                if (placement.showCmd == SW_SHOWMAXIMIZED) {
                    isFullscreen = true;
                }
            }
            if (!isFullscreen) {
                RECT rect;
                if (GetWindowRect(foregroundWindow, &rect)) {
                    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
                    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
                    if (rect.right - rect.left >= screenWidth - 10 &&
                        rect.bottom - rect.top >= screenHeight - 10) {
                        isFullscreen = true;
                    }
                }
            }
        }
        if (isDesktop) {
            isFullscreen = false;
        }

        // 鼠标检测
        bool isMouseOver = IsMouseOverIsland();

        // 全屏时动画目标位置
        if (isFullscreen && !isMouseOver) {
            ImVec2 size = g_islandExpanded ? ImVec2(600.0f, 300.0f) : ImVec2(400.0f, 80.0f);
            targetY = -size.y + 10;
        } else {
            targetY = 20.0f;
        }

        // === ImGui 帧开始 ===
        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();

        // 绘制灵动岛界面
        if (g_islandVisible) {
            DrawIslandUI(isDesktop, isFullscreen, isMouseOver, animationY, deltaTime);
        }

        // 绘制设置窗口
        DrawSettingsWindow();

        // === 渲染 ===
        ImGui::Render();

        // 清除背景 (透明)
        const float clear_color[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        g_pd3dDeviceContext->OMSetRenderTargets(1, &g_mainRenderTargetView, nullptr);
        g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView, clear_color);

        // 绘制 ImGui
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());

        frameCount++;

        // 呈现
        g_pSwapChain->Present(1, 0);

        // 更新窗口几何
        UpdateWindowGeometry();
    }

    // === 清理 ===
    ShutdownApp();

    if (hMutex) CloseHandle(hMutex);

    return 0;
}
