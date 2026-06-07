#pragma once

#include <string>
#include <mutex>
#include <cstdio>

// 日志级别 ，这个DYLD是DynamicIsLand缩写
enum class LogLevel {
    DYLD_DEBUG,
    DYLD_INFO,
    DYLD_WARNING,
    DYLD_ERROR
};

// 日志管理器
class Logger {
public:
    static Logger& Instance();

    void SetLogFile(const std::string& path);
    void SetConsoleOutput(bool enable);
    void SetMinLevel(LogLevel level);

    void Log(LogLevel level, const char* file, int line, const char* fmt, ...);

    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

private:
    Logger();
    ~Logger();

    void WriteLine(const std::string& fullMessage) const;

    std::mutex mtx_;
    FILE* file_ = nullptr;
    bool console_output_ = false;
    LogLevel min_level_ = LogLevel::DYLD_DEBUG;
    std::string file_path_ = "log/dynamicisland.log";
    bool initialized_ = false;
};

#define LOG_DEBUG(...)   Logger::Instance().Log(LogLevel::DYLD_DEBUG,   __FILE__, __LINE__, __VA_ARGS__)
#define LOG_INFO(...)    Logger::Instance().Log(LogLevel::DYLD_INFO,    __FILE__, __LINE__, __VA_ARGS__)
#define LOG_WARNING(...) Logger::Instance().Log(LogLevel::DYLD_WARNING, __FILE__, __LINE__, __VA_ARGS__)
#define LOG_ERROR(...)   Logger::Instance().Log(LogLevel::DYLD_ERROR,   __FILE__, __LINE__, __VA_ARGS__)
