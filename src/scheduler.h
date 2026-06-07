#pragma once

#include <windows.h>
#include <string>
#include <comdef.h>
#include <taskschd.h>

// ILogonTrigger 兼容层
#include "mingw_compat.h"

#pragma comment(lib, "taskschd.lib")
#pragma comment(lib, "comsupp.lib")

// 任务计划程序配置
struct TaskConfig {
    bool delayStart = true;       // 延迟30秒启动
    int delaySeconds = 30;        // 延迟时间
    bool acPowerOnly = false;     // 仅电源模式
    bool hidden = true;           // 隐藏窗口启动
    bool runAsAdmin = false;      // 以管理员权限运行
};

// 任务计划程序管理器
class TaskScheduler {
public:
    static TaskScheduler& Instance();
    
    // 初始化和清理COM
    bool Initialize();
    void Shutdown();
    
    // 检查是否已注册开机启动
    bool IsRegistered();
    
    // 注册开机启动任务
    // 首次运行或用户开启时调用，可能需要UAC提权
    bool Register(const TaskConfig& config = TaskConfig());
    
    // 取消注册开机启动
    bool Unregister();
    
    // 更新配置
    bool UpdateConfig(const TaskConfig& config);
    
    // 获取任务名称
    static const wchar_t* GetTaskName() { return L"DynamicIslandStartup"; }
    static const wchar_t* GetTaskFolder() { return L"\\"; }
    
private:
    TaskScheduler() = default;
    ~TaskScheduler() { Shutdown(); }
    TaskScheduler(const TaskScheduler&) = delete;
    TaskScheduler& operator=(const TaskScheduler&) = delete;
    
    // 获取程序路径
    std::wstring GetExecutablePath() const;
    
    // 生成任务XML定义
    std::wstring GenerateTaskXml(const TaskConfig& config) const;
    
    bool comInitialized = false;
    ITaskService* pService = nullptr;
};

// 全局访问宏
#define g_scheduler TaskScheduler::Instance()