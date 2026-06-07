/**
 * @author         : Romi Brooks
 * @file           : Logger.cpp
 * @brief          : 日志系统实现
 */

#include <chrono>
#include <ctime>
#include <cstdarg>
#include <iostream>
#include <sstream>
#include <iomanip>

#ifdef _WIN32
#include <windows.h>
#endif

#include "logging.h"

// 辅助函数
static const char* LevelToString(const LogLevel level) {
    switch (level) {
        case LogLevel::DYLD_DEBUG:   return "DEBUG";
        case LogLevel::DYLD_INFO:    return "INFO";
        case LogLevel::DYLD_WARNING: return "WARNING";
        case LogLevel::DYLD_ERROR:   return "ERROR";
    }
    return "UNKNOWN";
}

static std::string CurrentTimestamp() {
    const auto now = std::chrono::system_clock::now();
    auto timeT = std::chrono::system_clock::to_time_t(now);
    std::tm localTm;

    #ifdef _WIN32
        localtime_s(&localTm, &timeT);
    #else
        localtime_r(&timeT, &localTm);
    #endif

    std::ostringstream ss;
    ss << std::put_time(&localTm, "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

// Logger
Logger::Logger() {
    file_ = fopen(file_path_.c_str(), "w");
    if (file_) {
        initialized_ = true;
    }
}

Logger::~Logger() {
    if (file_) {
        fclose(file_);
        file_ = nullptr;
    }
}

Logger& Logger::Instance() {
    static Logger instance;
    return instance;
}

void Logger::SetLogFile(const std::string& path) {
    std::lock_guard<std::mutex> lock(mtx_);
    if (file_) {
        fclose(file_);
        file_ = nullptr;
    }
    file_path_ = path;
    file_ = fopen(file_path_.c_str(), "w");
    initialized_ = (file_ != nullptr);
}

void Logger::SetConsoleOutput(const bool enable) {
    std::lock_guard<std::mutex> lock(mtx_);
    console_output_ = enable;
    #ifdef _WIN32
        if (enable) {
            // GUI 程序默认没有控制台，需要分配一个
            if (AllocConsole()) {
                // 重定向 stdout 到新控制台
                FILE* fp;
                freopen_s(&fp, "CONOUT$", "w", stdout);
                freopen_s(&fp, "CONOUT$", "w", stderr);
                SetConsoleTitle(L"DynamicIsland Log");
            }
        }
    #endif
}

void Logger::SetMinLevel(LogLevel level) {
    std::lock_guard<std::mutex> lock(mtx_);
    min_level_ = level;
}

void Logger::WriteLine(const std::string& fullMessage) const {
    // 写入文件
    if (file_) {
        fprintf(file_, "%s\n", fullMessage.c_str());
        fflush(file_);
    }

    // 控制台输出
    if (console_output_) {
        std::cout << fullMessage << std::endl;
    }
}

void Logger::Log(const LogLevel level, const char* file, const int line, const char* fmt, ...) {
    std::lock_guard<std::mutex> lock(mtx_);

    // 级别过滤
    if (level < min_level_) return;

    // 格式化用户消息
    char message[4096];
    va_list args;
    va_start(args, fmt);
    vsnprintf(message, sizeof(message), fmt, args);
    va_end(args);

    // 构造完整日志行
    // [2025-09-20 14:30:00] [INFO] [src/main.cpp:31] message
    std::ostringstream full;
    full << "[" << CurrentTimestamp() << "]"
         << " [" << LevelToString(level) << "]"
         << " [" << file << ":" << line << "]"
         << " " << message;

    WriteLine(full.str());
}
