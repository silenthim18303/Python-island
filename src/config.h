#pragma once

#include <string>
#include <mutex>

// 配置结构体定义 - ref : config.json
struct IslandConfig {
    std::string position = "top-center";
    int offset_x = 0;
    int offset_y = 20;
    int idle_width = 120;
    int idle_height = 40;
    int expanded_width = 380;
    int expanded_height = 450;
    float animation_speed = 12.0f;
    float auto_hide_delay = 5.0f;
    bool show_seconds = false;
};

struct AppearanceConfig {
    std::string theme = "dark";
    std::string accent_color = "#0078D4";
    float opacity = 0.95f;
    float corner_radius = 20.0f;
    bool shadow_enabled = true;
    bool blur_enabled = true;
    int font_size = 16;
    std::string font_family = "Noto Sans CJK SC";
    std::string style = "frosted"; // frosted: 毛玻璃, liquid: 液态玻璃
};

struct SystemConfig {
    int update_interval_ms = 1000;
    bool cpu_enabled = true;
    bool gpu_enabled = true;
    bool memory_enabled = true;
    bool battery_enabled = true;
    bool network_enabled = false;
};

struct BehaviorConfig {
    bool start_with_windows = true;
    bool start_minimized = false;
    bool silent_mode = false;
    bool game_mode_detection = true;
    bool notification_enabled = true;
    int max_notifications = 5;
};

// 全局配置管理器
class Config {
    public:
        static Config& Instance();

        // 加载/保存配置
        bool Load();
        bool Save();

        // 获取配置引用
        IslandConfig& GetIsland() { return island; }
        AppearanceConfig& GetAppearance() { return appearance; }
        SystemConfig& GetSystem() { return system; }
        BehaviorConfig& GetBehavior() { return behavior; }

        // 线程安全访问
        std::mutex& GetMutex() { return mtx; }

        // 获取配置文件路径
        std::string GetConfigPath() const;

        // 重置为默认值
        void ResetToDefaults();

    private:
        Config() = default;
        ~Config() = default;
        Config(const Config&) = delete;
        Config& operator=(const Config&) = delete;

        IslandConfig island;
        AppearanceConfig appearance;
        SystemConfig system;
        BehaviorConfig behavior;
        std::mutex mtx;
};

// 全局访问宏
#define g_config Config::Instance()