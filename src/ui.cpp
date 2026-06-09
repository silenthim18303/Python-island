#include "ui.h"
#include "window.h"
#include "logging.h"
#include "config.h"
#include "sysinfo.h"
#include "trayicon.h"

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

#include <dwmapi.h>
#include <d3d11.h>
#include <stdio.h>

#if USE_FILE_TRANSFER
#include "transferstation.h"

// 文件预览相关
static size_t g_selectedFileIndex = -1;
static bool g_showPreview = false;
#endif

// 创建文件拖放数据对象 (在 window.cpp 中实现，这里 extern 声明)
HRESULT CreateFileDropDataObject(const std::vector<std::wstring>& filePaths, IDataObject** ppDataObject);

// 文件大小格式化辅助函数
static std::string FormatFileSize(uint64_t size) {
    if (size < 1024) {
        return std::to_string(size) + " B";
    } else if (size < 1024 * 1024) {
        return std::to_string((int)(size / 1024)) + " KB";
    } else if (size < 1024 * 1024 * 1024) {
        char buf[32];
        sprintf(buf, "%.1f MB", (float)size / (1024 * 1024));
        return buf;
    } else {
        char buf[32];
        sprintf(buf, "%.2f GB", (float)size / (1024 * 1024 * 1024));
        return buf;
    }
}

// === 检查鼠标是否悬停在灵动岛区域 ===
bool IsMouseOverIsland() {
    if (!g_islandVisible) return false;

    ImVec2 size = g_islandExpanded ? ImVec2(600.0f, 300.0f) : ImVec2(400.0f, 80.0f);
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    ImVec2 pos;
    pos.x = (screenWidth - size.x) * 0.5f;
    pos.y = 20.0f; // 默认位置

    POINT mousePos;
    GetCursorPos(&mousePos);

    RECT islandRect;
    islandRect.left = (int)pos.x;
    islandRect.top = 0;
    islandRect.right = (int)(pos.x + size.x);
    islandRect.bottom = (int)(size.y + 30);

    return PtInRect(&islandRect, mousePos);
}

// === 绘制灵动岛主界面 ===
void DrawIslandUI(bool isDesktop, bool isFullscreen, bool isMouseOver, float animationY, float deltaTime) {
    if (!g_islandVisible) return;

    // 灵动岛配置
    ImVec2 size = g_islandExpanded ? ImVec2(600.0f, 300.0f) : ImVec2(400.0f, 80.0f);
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    ImVec2 pos;
    pos.x = (screenWidth - size.x) * 0.5f;

    bool isFullscreenEffective = isFullscreen;

    // 全屏时鼠标悬停则展开
    if (isMouseOver && isFullscreenEffective) {
        isFullscreenEffective = false;
    }

    // 使用动画位置
    pos.y = animationY;

    ImGui::SetNextWindowPos(pos, ImGuiCond_Always);
    ImGui::SetNextWindowSize(size);

    // 设置窗口区域
    POINT topLeft = { (LONG)pos.x, (LONG)pos.y };
    ScreenToClient(g_hwnd, &topLeft);
    HRGN imguiRgn = CreateRectRgn(topLeft.x, topLeft.y,
                                  topLeft.x + (LONG)size.x, topLeft.y + (LONG)size.y);
    SetWindowRgn(g_hwnd, imguiRgn, TRUE);

    ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 1.0f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, size.y * 0.5f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, IM_COL32(0, 0, 0, 0));

    bool open = true;
    if (ImGui::Begin("DynamicIsland", &open,
        ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoNav |
        ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize |
        ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoBackground)) {

        auto& appearance = g_config.GetAppearance();

        // 绘制背景
        ImDrawList* dl = ImGui::GetWindowDrawList();
        ImVec2 p0 = ImGui::GetWindowPos();
        ImU32 bgColor;
        if (appearance.style == "white") {
            bgColor = IM_COL32(240, 240, 240, 200);
        } else {
            bgColor = IM_COL32(30, 30, 40, 200);
        }
        dl->AddRectFilled(p0, ImVec2(p0.x + size.x, p0.y + size.y), bgColor, size.y * 0.5f);

        // 状态指示点
        float cpuUsage = g_sysinfo.GetCpuUsage();
        ImU32 dotColor;
        if (cpuUsage < 50.0f) dotColor = IM_COL32(0, 255, 0, 255);
        else if (cpuUsage < 80.0f) dotColor = IM_COL32(255, 255, 0, 255);
        else dotColor = IM_COL32(255, 0, 0, 255);

        float cy = p0.y + size.y * 0.5f;
        dl->AddCircleFilled(ImVec2(p0.x + 20, cy), 6.0f, dotColor);

        // 时间显示
        char timeBuf[16];
        SYSTEMTIME st;
        GetLocalTime(&st);
        sprintf(timeBuf, "%02d:%02d:%02d", st.wHour, st.wMinute, st.wSecond);

        ImGui::SetCursorPos(ImVec2(40, 15));
        if (appearance.style == "white") {
            ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(0, 200, 100, 255));
        } else {
            ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(0, 255, 100, 255));
        }
        float oldFontSize = ImGui::GetFont()->Scale;
        ImGui::GetFont()->Scale = 1.2f;
        ImGui::TextUnformatted(timeBuf);
        ImGui::GetFont()->Scale = oldFontSize;
        ImGui::PopStyleColor();

        // 文本颜色
        if (appearance.style == "white") {
            ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(30, 30, 40, 255));
        } else {
            ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(240, 240, 240, 255));
        }

        if (!g_islandExpanded) {
            // === 收起状态 ===
            ImGui::SetCursorPos(ImVec2(40, 45));
            float cpu = g_sysinfo.GetCpuUsage();
            auto memInfo = g_sysinfo.GetMemoryInfo();
            float memUsedGB = memInfo.used_bytes / (1024.0f * 1024.0f * 1024.0f);
            float memTotalGB = memInfo.total_bytes / (1024.0f * 1024.0f * 1024.0f);
            ImGui::Text("CPU: %.1f%% | Mem: %.1f/%.1f GB", cpu, memUsedGB, memTotalGB);

            ImGui::SetCursorPos(ImVec2(280, 30));
            float battery = g_sysinfo.GetBatteryPercent();
            ImGui::Text("Batt: %.0f%%", battery);

            auto batteryInfo = g_sysinfo.GetBatteryInfo();
            if (batteryInfo.is_plugged) {
                ImGui::SetCursorPos(ImVec2(280, 45));
                ImGui::Text("Charging");
            }

#if USE_FILE_TRANSFER
            size_t fileCount = g_transferstation.GetFileCount();
            if (fileCount > 0) {
                uint64_t totalSize = g_transferstation.GetTotalSize();
                ImGui::SetCursorPos(ImVec2(280, 60));
                ImGui::Text("%zu files \xb7 %s", fileCount, FormatFileSize(totalSize).c_str());
            }
#endif
        } else {
            // === 展开状态 ===
            ImGui::SetCursorPos(ImVec2(40, 45));
            float cpu = g_sysinfo.GetCpuUsage();
            auto memInfo = g_sysinfo.GetMemoryInfo();
            float memUsedGB = memInfo.used_bytes / (1024.0f * 1024.0f * 1024.0f);
            float memTotalGB = memInfo.total_bytes / (1024.0f * 1024.0f * 1024.0f);
            ImGui::Text("CPU: %.1f%% | Mem: %.1f/%.1f GB", cpu, memUsedGB, memTotalGB);

            auto gpuInfo = g_sysinfo.GetGPUInfo();
            if (gpuInfo.available) {
                ImGui::SetCursorPos(ImVec2(40, 65));
                ImGui::Text("GPU: %.1f%% | %s", gpuInfo.usage_percent, gpuInfo.name.c_str());
            }

            auto networkInfo = g_sysinfo.GetNetworkInfo();
            if (networkInfo.is_connected) {
                ImGui::SetCursorPos(ImVec2(40, 85));
                ImGui::Text("\xE2\x86\x93%.1f Mbps | \xE2\x86\x91%.1f Mbps",
                            networkInfo.download_speed_mbps, networkInfo.upload_speed_mbps);
            }

            ImGui::SetCursorPos(ImVec2(300, 45));
            float battery = g_sysinfo.GetBatteryPercent();
            ImGui::Text("Battery: %.0f%%", battery);

            auto batteryInfo = g_sysinfo.GetBatteryInfo();
            if (batteryInfo.is_plugged) {
                ImGui::SetCursorPos(ImVec2(300, 65));
                ImGui::Text("Charging");
            } else if (batteryInfo.remaining_minutes > 0) {
                ImGui::SetCursorPos(ImVec2(300, 65));
                ImGui::Text("Remaining: %d min", batteryInfo.remaining_minutes);
            }

            auto displayInfo = g_sysinfo.GetDisplayInfo();
            ImGui::SetCursorPos(ImVec2(300, 85));
            ImGui::Text("Display: %dx%d @ %dHz",
                        displayInfo.resolution_x, displayInfo.resolution_y, displayInfo.refresh_rate_hz);

#if USE_FILE_TRANSFER
            // 文件中转站 UI
            ImGui::SetCursorPos(ImVec2(40, 110));
            ImGui::Text("File Transfer Station:");

            auto files = g_transferstation.GetFiles();
            if (files.empty()) {
                ImGui::SetCursorPos(ImVec2(60, 130));
                ImGui::Text("Drop files here to add to transfer station");
            } else {
                // ... 文件列表 UI (与原代码相同，因篇幅略)
                size_t fileCount = g_transferstation.GetFileCount();
                uint64_t totalSize = g_transferstation.GetTotalSize();
                ImGui::SetCursorPos(ImVec2(60, 130));
                ImGui::Text("Total: %zu files \xb7 %s", fileCount, FormatFileSize(totalSize).c_str());

                // 排序选项
                ImGui::SetCursorPos(ImVec2(60, 150));
                ImGui::Text("Sort by:");
                ImGui::SameLine();

                static int sortMode = 0;
                if (ImGui::RadioButton("Time", sortMode == 0)) sortMode = 0;
                ImGui::SameLine();
                if (ImGui::RadioButton("Name", sortMode == 1)) sortMode = 1;
                ImGui::SameLine();
                if (ImGui::RadioButton("Size", sortMode == 2)) sortMode = 2;

                // 排序文件
                std::vector<FileInfo> sortedFiles = files;
                switch (sortMode) {
                case 0:
                    std::sort(sortedFiles.begin(), sortedFiles.end(),
                              [](const FileInfo& a, const FileInfo& b) { return a.added_time > b.added_time; });
                    break;
                case 1:
                    std::sort(sortedFiles.begin(), sortedFiles.end(),
                              [](const FileInfo& a, const FileInfo& b) { return a.name < b.name; });
                    break;
                case 2:
                    std::sort(sortedFiles.begin(), sortedFiles.end(),
                              [](const FileInfo& a, const FileInfo& b) { return a.size > b.size; });
                    break;
                }

                for (size_t i = 0; i < sortedFiles.size(); i++) {
                    const auto& file = sortedFiles[i];
                    std::string fileSizeStr = FormatFileSize(file.size);

                    // 格式化时间
                    std::time_t time = std::chrono::system_clock::to_time_t(file.added_time);
                    std::tm localTime;
                    localtime_s(&localTime, &time);
                    char timeStr[20];
                    sprintf(timeStr, "%04d-%02d-%02d %02d:%02d",
                            localTime.tm_year + 1900, localTime.tm_mon + 1,
                            localTime.tm_mday, localTime.tm_hour, localTime.tm_min);

                    // 文件扩展名
                    std::wstring ext = L"";
                    size_t dotPos = file.name.find_last_of(L'.');
                    if (dotPos != std::wstring::npos) {
                        ext = file.name.substr(dotPos + 1);
                    }

                    std::string fileItemId = "fileItem##" + std::to_string(i);
                    ImGui::PushID(fileItemId.c_str());

                    float lineHeight = 35.0f;
                    float yPos = 180 + i * lineHeight;

                    // 图标
                    ImGui::SetCursorPos(ImVec2(70, yPos));
                    std::string iconText = "\xF0\x9F\x93\x84";
                    if (ext == L"jpg" || ext == L"jpeg" || ext == L"png" ||
                        ext == L"gif" || ext == L"bmp") iconText = "\xF0\x9F\x96\xBC\xEF\xB8\x8F";
                    else if (ext == L"mp3" || ext == L"wav" || ext == L"flac") iconText = "\xF0\x9F\x8E\xB5";
                    else if (ext == L"mp4" || ext == L"avi" || ext == L"mov") iconText = "\xF0\x9F\x8E\xAC";
                    else if (ext == L"zip" || ext == L"rar" || ext == L"7z") iconText = "\xF0\x9F\x93\xA6";
                    else if (ext == L"exe" || ext == L"msi") iconText = "\xF0\x9F\x92\xBE";
                    ImGui::Text("%s", iconText.c_str());

                    // 文件名
                    ImGui::SetCursorPos(ImVec2(100, yPos));
                    ImGui::Text("%s", file.name.c_str());

                    // 大小
                    ImGui::SetCursorPos(ImVec2(300, yPos));
                    ImGui::Text("%s", fileSizeStr.c_str());

                    // 时间
                    ImGui::SetCursorPos(ImVec2(380, yPos));
                    ImGui::Text("%s", timeStr);

                    // 操作按钮
                    float buttonStartX = 480.0f;
                    float buttonWidth = 50.0f;
                    float buttonSpacing = 5.0f;

                    // 查找原始索引
                    auto findOriginalIndex = [&]() -> size_t {
                        for (size_t j = 0; j < files.size(); j++) {
                            if (files[j].path == file.path) return j;
                        }
                        return (size_t)-1;
                    };

                    // 打开
                    ImGui::SetCursorPos(ImVec2(buttonStartX, yPos - 2));
                    if (ImGui::Button(("Open##" + std::to_string(i)).c_str(), ImVec2(buttonWidth, 20))) {
                        size_t idx = findOriginalIndex();
                        if (idx < files.size()) g_transferstation.OpenFile(idx);
                    }

                    // 复制
                    ImGui::SetCursorPos(ImVec2(buttonStartX + buttonWidth + buttonSpacing, yPos - 2));
                    if (ImGui::Button(("Copy##" + std::to_string(i)).c_str(), ImVec2(buttonWidth, 20))) {
                        size_t idx = findOriginalIndex();
                        if (idx < files.size()) {
                            BROWSEINFO bi = { 0 };
                            bi.lpszTitle = L"Select destination folder";
                            LPITEMIDLIST pidl = SHBrowseForFolder(&bi);
                            if (pidl) {
                                wchar_t path[MAX_PATH];
                                if (SHGetPathFromIDList(pidl, path)) {
                                    g_transferstation.TransferCopyFile(idx, path);
                                }
                                CoTaskMemFree(pidl);
                            }
                        }
                    }

                    // 移动
                    ImGui::SetCursorPos(ImVec2(buttonStartX + (buttonWidth + buttonSpacing) * 2, yPos - 2));
                    if (ImGui::Button(("Move##" + std::to_string(i)).c_str(), ImVec2(buttonWidth, 20))) {
                        size_t idx = findOriginalIndex();
                        if (idx < files.size()) {
                            BROWSEINFO bi = { 0 };
                            bi.lpszTitle = L"Select destination folder";
                            LPITEMIDLIST pidl = SHBrowseForFolder(&bi);
                            if (pidl) {
                                wchar_t path[MAX_PATH];
                                if (SHGetPathFromIDList(pidl, path)) {
                                    g_transferstation.TransferMoveFile(idx, path);
                                }
                                CoTaskMemFree(pidl);
                            }
                        }
                    }

                    // 预览
                    ImGui::SetCursorPos(ImVec2(buttonStartX + (buttonWidth + buttonSpacing) * 3, yPos - 2));
                    if (ImGui::Button(("Preview##" + std::to_string(i)).c_str(), ImVec2(buttonWidth, 20))) {
                        size_t idx = findOriginalIndex();
                        if (idx < files.size()) {
                            g_selectedFileIndex = idx;
                            g_showPreview = true;
                        }
                    }

                    // 删除
                    ImGui::SetCursorPos(ImVec2(buttonStartX + (buttonWidth + buttonSpacing) * 4, yPos - 2));
                    if (ImGui::Button(("Delete##" + std::to_string(i)).c_str(), ImVec2(buttonWidth, 20))) {
                        size_t idx = findOriginalIndex();
                        if (idx < files.size()) g_transferstation.TransferDeleteFile(idx);
                    }

                    ImGui::PopID();
                }
            }
#endif // USE_FILE_TRANSFER
        }

        ImGui::PopStyleColor(); // 文本颜色
    }

    ImGui::End();
    ImGui::PopStyleColor(); // WindowBg
    ImGui::PopStyleVar(3);

    // === 文件预览窗口 (仅文件中转站启用时) ===
#if USE_FILE_TRANSFER
    if (g_showPreview && g_selectedFileIndex != (size_t)-1) {
        auto files = g_transferstation.GetFiles();
        if (g_selectedFileIndex < files.size()) {
            const auto& file = files[g_selectedFileIndex];
            auto previewInfo = g_transferstation.GetFilePreviewInfo(g_selectedFileIndex);

            ImVec2 previewSize(800.0f, 600.0f);
            int screenWidth = GetSystemMetrics(SM_CXSCREEN);
            int screenHeight = GetSystemMetrics(SM_CYSCREEN);
            ImVec2 previewPos((screenWidth - previewSize.x) * 0.5f, (screenHeight - previewSize.y) * 0.5f);

            ImGui::SetNextWindowPos(previewPos, ImGuiCond_Always);
            ImGui::SetNextWindowSize(previewSize, ImGuiCond_Always);
            ImGui::PushStyleColor(ImGuiCol_WindowBg, IM_COL32(30, 30, 40, 240));

            bool previewOpen = true;
            if (ImGui::Begin("File Preview", &previewOpen,
                ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove)) {
                ImGui::Text("File: %s", file.name.c_str());
                ImGui::Separator();
                ImGui::Text("File Type: %s", previewInfo.file_type.c_str());
                ImGui::Text("Extension: %s", previewInfo.file_extension.c_str());
                ImGui::Text("Size: %s", FormatFileSize(file.size).c_str());
                ImGui::Text("Creation Time: %s", previewInfo.creation_time.c_str());
                ImGui::Text("Last Modified: %s", previewInfo.last_modified_time.c_str());
                ImGui::Text("Last Accessed: %s", previewInfo.last_access_time.c_str());
                ImGui::Text("Path: %s", file.path.c_str());
                ImGui::Separator();

                if (previewInfo.is_text) {
                    ImGui::BeginChild("TextContent", ImVec2(0, 300), true, ImGuiWindowFlags_HorizontalScrollbar);
                    ImGui::TextUnformatted(previewInfo.text_content.c_str());
                    ImGui::EndChild();
                } else if (previewInfo.is_image) {
                    ImGui::BeginChild("ImageContent", ImVec2(0, 300), true);
                    ImGui::Text("[Image Preview - Not yet implemented]");
                    ImGui::EndChild();
                } else {
                    ImGui::Text("No preview available for this file type");
                }

                if (!previewOpen) {
                    g_showPreview = false;
                    g_selectedFileIndex = -1;
                }
            }
            ImGui::End();
            ImGui::PopStyleColor();
        }
    }
#endif
}

// === 绘制设置窗口 ===
void DrawSettingsWindow() {
    if (!g_showSettings) return;

    ImVec2 settingsSize(600.0f, 400.0f);
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    ImVec2 settingsPos((screenWidth - settingsSize.x) * 0.5f, (screenHeight - settingsSize.y) * 0.5f);

    ImGui::SetNextWindowPos(settingsPos, ImGuiCond_Always);
    ImGui::SetNextWindowSize(settingsSize, ImGuiCond_Always);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, IM_COL32(40, 40, 50, 255));

    bool settingsOpen = true;
    if (ImGui::Begin("\xe8\xae\xbe\xe7\xbd\xae", &settingsOpen,
        ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove)) {
        ImGui::Text("DynamicIsland \xe8\xae\xbe\xe7\xbd\xae");
        ImGui::Separator();

        static int selectedCategory = 0;
        ImGui::BeginChild("Categories", ImVec2(150, 0), true);
        if (ImGui::Selectable("\xe9\x80\x9a\xe7\x94\xa8", selectedCategory == 0)) selectedCategory = 0;
        if (ImGui::Selectable("\xe5\xa4\x96\xe8\xa7\x82", selectedCategory == 1)) selectedCategory = 1;
        if (ImGui::Selectable("\xe9\x80\x9a\xe7\x9f\xa5", selectedCategory == 2)) selectedCategory = 2;
        if (ImGui::Selectable("\xe6\x96\x87\xe4\xbb\xb6\xe4\xb8\xad\xe8\xbd\xac\xe7\xab\x99", selectedCategory == 3)) selectedCategory = 3;
        if (ImGui::Selectable("\xe9\xab\x98\xe7\xba\xa7", selectedCategory == 4)) selectedCategory = 4;
        if (ImGui::Selectable("\xe5\x85\xb3\xe4\xba\x8e", selectedCategory == 5)) selectedCategory = 5;
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("Content", ImVec2(0, 0), true);
        switch (selectedCategory) {
        case 0:
            ImGui::Text("\xe9\x80\x9a\xe7\x94\xa8\xe8\xae\xbe\xe7\xbd\xae");
            ImGui::Separator();
            if (ImGui::CollapsingHeader("\xe5\xbc\x80\xe6\x9c\xba\xe5\x90\xaf\xe5\x8a\xa8")) {
                ImGui::Text("\xe8\xae\xbe\xe7\xbd\xae\xe7\xa8\x8b\xe5\xba\x8f\xe6\x98\xaf\xe5\x90\xa6\xe5\x9c\xa8\xe7\xb3\xbb\xe7\xbb\x9f\xe5\x90\xaf\xe5\x8a\xa8\xe6\x97\xb6\xe8\x87\xaa\xe5\x8a\xa8\xe8\xbf\x90\xe8\xa1\x8c");
            }
            if (ImGui::CollapsingHeader("\xe5\x88\xb7\xe6\x96\xb0\xe9\xa2\x91\xe7\x8e\x87")) {
                ImGui::Text("\xe8\xb0\x83\xe6\x95\xb4\xe7\xb3\xbb\xe7\xbb\x9f\xe4\xbf\xa1\xe6\x81\xaf\xe7\x9a\x84\xe5\x88\xb7\xe6\x96\xb0\xe9\x80\x9f\xe5\xba\xa6");
            }
            break;
        case 1:
            ImGui::Text("\xe5\xa4\x96\xe8\xa7\x82\xe8\xae\xbe\xe7\xbd\xae");
            ImGui::Separator();
            if (ImGui::CollapsingHeader("\xe4\xb8\xbb\xe9\xa2\x98")) {
                ImGui::Text("\xe9\x80\x89\xe6\x8b\xa9\xe7\x81\xb5\xe5\x8a\xa8\xe5\xb2\x9b\xe7\x9a\x84\xe5\xa4\x96\xe8\xa7\x82\xe4\xb8\xbb\xe9\xa2\x98");
            }
            if (ImGui::CollapsingHeader("\xe5\x8a\xa8\xe7\x94\xbb")) {
                ImGui::Text("\xe9\x85\x8d\xe7\xbd\xae\xe5\xb1\x95\xe5\xbc\x80/\xe6\x94\xb6\xe8\xb5\xb7\xe5\x8a\xa8\xe7\x94\xbb\xe6\x95\x88\xe6\x9e\x9c");
            }
            break;
        case 2:
            ImGui::Text("\xe9\x80\x9a\xe7\x9f\xa5\xe8\xae\xbe\xe7\xbd\xae");
            ImGui::Separator();
            if (ImGui::CollapsingHeader("\xe7\xb3\xbb\xe7\xbb\x9f\xe9\x80\x9a\xe7\x9f\xa5")) {
                ImGui::Text("\xe9\x85\x8d\xe7\xbd\xae\xe9\x80\x9a\xe7\x9f\xa5\xe6\x8f\x90\xe9\x86\x92\xe5\x8a\x9f\xe8\x83\xbd");
            }
            break;
        case 3:
            ImGui::Text("\xe6\x96\x87\xe4\xbb\xb6\xe4\xb8\xad\xe8\xbd\xac\xe7\xab\x99\xe8\xae\xbe\xe7\xbd\xae");
            ImGui::Separator();
            if (ImGui::CollapsingHeader("\xe5\xad\x98\xe5\x82\xa8\xe8\xae\xbe\xe7\xbd\xae")) {
                ImGui::Text("\xe9\x85\x8d\xe7\xbd\xae\xe6\x96\x87\xe4\xbb\xb6\xe4\xb8\xad\xe8\xbd\xac\xe7\xab\x99\xe7\x9a\x84\xe5\xad\x98\xe5\x82\xa8\xe4\xbd\x8d\xe7\xbd\xae\xe5\x92\x8c\xe9\x99\x90\xe5\x88\xb6");
            }
            break;
        case 4:
            ImGui::Text("\xe9\xab\x98\xe7\xba\xa7\xe8\xae\xbe\xe7\xbd\xae");
            ImGui::Separator();
            if (ImGui::CollapsingHeader("\xe8\xb0\x83\xe8\xaf\x95\xe9\x80\x89\xe9\xa1\xb9")) {
                ImGui::Text("\xe8\xb0\x83\xe8\xaf\x95\xe5\x92\x8c\xe8\xaf\x8a\xe6\x96\xad\xe9\x80\x89\xe9\xa1\xb9");
            }
            break;
        case 5:
            ImGui::Text("\xe5\x85\xb3\xe4\xba\x8e");
            ImGui::Separator();
            ImGui::Text("DynamicIsland v1.0");
            ImGui::Text("\xe4\xb8\x80\xe4\xb8\xaa\xe6\xa8\xa1\xe4\xbf\xbf\xe8\x8b\xb9\xe6\x9e\x9c\xe7\x81\xb5\xe5\x8a\xa8\xe5\xb2\x9b\xe7\x9a\x84 Windows \xe7\xb3\xbb\xe7\xbb\x9f\xe7\x9b\x91\xe6\x8e\xa7\xe5\xb7\xa5\xe5\x85\xb7");
            ImGui::Spacing();
            ImGui::Text("\xe5\x8a\x9f\xe8\x83\xbd:");
            ImGui::BulletText("\xe5\xae\x9e\xe6\x97\xb6\xe7\xb3\xbb\xe7\xbb\x9f\xe7\x9b\x91\xe6\x8e\xa7 (CPU, \xe5\x86\x85\xe5\xad\x98, GPU, \xe7\xbd\x91\xe7\xbb\x9c)");
            ImGui::BulletText("\xe6\x96\x87\xe4\xbb\xb6\xe4\xb8\xad\xe8\xbd\xac\xe7\xab\x99\xe5\x8a\x9f\xe8\x83\xbd");
            ImGui::BulletText("\xe5\x8f\xaf\xe5\xae\x9a\xe5\x88\xb6\xe7\x9a\x84\xe6\x80\xa7\xe8\x83\xbd\xe5\x92\x8c\xe5\xa4\x96\xe8\xa7\x82\xe8\xae\xbe\xe7\xbd\xae");
            break;
        }
        ImGui::EndChild();

        if (!settingsOpen) {
            g_showSettings = false;
        }
    }
    ImGui::End();
    ImGui::PopStyleColor();
}
