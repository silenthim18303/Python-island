#include "window.h"
#include "logging.h"

#include <dwmapi.h>
#include <d3d11.h>
#include <ole2.h>
#include <oleidl.h>
#include <shlobj.h>

// DWM attribute not defined in older SDKs
#ifndef DWMWA_USE_HOSTBACKDROPBRUSH
#define DWMWA_USE_HOSTBACKDROPBRUSH 38
#endif

#ifndef DWMWA_MICA_EFFECT
#define DWMWA_MICA_EFFECT 1029
#endif

#include "config.h"
#include <imgui.h>
#include "sysinfo.h"
#if USE_FILE_TRANSFER
#include "transferstation.h"
#endif

#include "trayicon.h"

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shlwapi.lib")

// === 全局变量定义 ===
ID3D11Device* g_pd3dDevice = nullptr;
ID3D11DeviceContext* g_pd3dDeviceContext = nullptr;
IDXGISwapChain* g_pSwapChain = nullptr;
ID3D11RenderTargetView* g_mainRenderTargetView = nullptr;

HWND g_hwnd = nullptr;
bool g_running = true;
bool g_windowVisible = true;
bool g_islandVisible = true;
bool g_islandExpanded = false;

bool g_showSettings = false;

const UINT WM_TRAYICON = WM_APP + 1;

// 拖放相关 (文件中转站)
#if USE_FILE_TRANSFER
static size_t g_dragFileIndex = -1;
static size_t g_selectedFileIndex = -1;
static bool g_showPreview = false;
#endif

// === CDropSource 实现 ===
class CDropSource : public IDropSource {
private:
    ULONG m_refCount;

public:
    CDropSource() : m_refCount(1) {}
    ~CDropSource() {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) {
        if (riid == IID_IUnknown || riid == IID_IDropSource) {
            *ppvObject = static_cast<IDropSource*>(this);
            AddRef();
            return S_OK;
        }
        *ppvObject = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() {
        return InterlockedIncrement(&m_refCount);
    }

    ULONG STDMETHODCALLTYPE Release() {
        ULONG ref = InterlockedDecrement(&m_refCount);
        if (ref == 0) {
            delete this;
        }
        return ref;
    }

    HRESULT STDMETHODCALLTYPE QueryContinueDrag(BOOL fEscapePressed, DWORD grfKeyState) {
        if (fEscapePressed) return DRAGDROP_S_CANCEL;
        if (!(grfKeyState & MK_LBUTTON)) return DRAGDROP_S_DROP;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GiveFeedback(DWORD dwEffect) {
        return DRAGDROP_S_USEDEFAULTCURSORS;
    }
};

// === 创建文件拖放数据对象 ===
HRESULT CreateFileDropDataObject(const std::vector<std::wstring>& filePaths, IDataObject** ppDataObject) {
    HRESULT hr;
    size_t fileCount = filePaths.size();
    if (fileCount == 0) return E_INVALIDARG;

    std::vector<LPITEMIDLIST> pidls;
    pidls.reserve(fileCount);

    for (const auto& filePath : filePaths) {
        LPITEMIDLIST pidl = ILCreateFromPathW(filePath.c_str());
        if (pidl) {
            pidls.push_back(pidl);
        } else {
            for (auto p : pidls) ILFree(p);
            return E_FAIL;
        }
    }

    hr = SHCreateDataObject(
        nullptr, (UINT)pidls.size(),
        const_cast<const ITEMIDLIST**>(pidls.data()),
        nullptr, IID_IDataObject, (void**)ppDataObject
    );

    for (auto p : pidls) ILFree(p);
    return hr;
}

// === 更新窗口几何 ===
void UpdateWindowGeometry() {
    if (!g_hwnd) return;

    int w = GetSystemMetrics(SM_CXSCREEN);
    int h = GetSystemMetrics(SM_CYSCREEN);

    SetWindowPos(g_hwnd, HWND_TOPMOST, 0, 0, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);

    BOOL useBackdrop = TRUE;
    DwmSetWindowAttribute(g_hwnd, DWMWA_USE_HOSTBACKDROPBRUSH, &useBackdrop, sizeof(useBackdrop));

    MARGINS margins = { -1 };
    DwmExtendFrameIntoClientArea(g_hwnd, &margins);
}

// === D3D 设备管理 ===
bool CreateDeviceD3D(HWND hWnd) {
    DXGI_SWAP_CHAIN_DESC sd = {};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 0;
    sd.BufferDesc.Height = 0;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hWnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;

    D3D_FEATURE_LEVEL featureLevel;
    const D3D_FEATURE_LEVEL featureLevelArray[2] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_0
    };

    HRESULT res = D3D11CreateDeviceAndSwapChain(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
        featureLevelArray, 2, D3D11_SDK_VERSION,
        &sd, &g_pSwapChain, &g_pd3dDevice, &featureLevel, &g_pd3dDeviceContext
    );

    if (res != S_OK) return false;

    CreateRenderTarget();
    return true;
}

void CreateRenderTarget() {
    ID3D11Texture2D* pBackBuffer;
    g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));

    D3D11_RENDER_TARGET_VIEW_DESC rtvDesc;
    rtvDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
    rtvDesc.Texture2D.MipSlice = 0;

    g_pd3dDevice->CreateRenderTargetView(pBackBuffer, &rtvDesc, &g_mainRenderTargetView);
    pBackBuffer->Release();
}

void CleanupRenderTarget() {
    if (g_mainRenderTargetView) {
        g_mainRenderTargetView->Release();
        g_mainRenderTargetView = nullptr;
    }
}

void CleanupDeviceD3D() {
    CleanupRenderTarget();
    if (g_pSwapChain) { g_pSwapChain->Release(); g_pSwapChain = nullptr; }
    if (g_pd3dDeviceContext) { g_pd3dDeviceContext->Release(); g_pd3dDeviceContext = nullptr; }
    if (g_pd3dDevice) { g_pd3dDevice->Release(); g_pd3dDevice = nullptr; }
}

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
// === 窗口过程 ===

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

    if (msg == WM_KEYDOWN && wParam == VK_ESCAPE && g_showSettings) {
        g_showSettings = false;
        return 0;
    }

    switch (msg) {
    case WM_SIZE:
        if (g_pd3dDevice != nullptr && wParam != SIZE_MINIMIZED) {
            CleanupRenderTarget();
            g_pSwapChain->ResizeBuffers(0, (UINT)LOWORD(lParam), (UINT)HIWORD(lParam),
                                        DXGI_FORMAT_UNKNOWN, 0);
            CreateRenderTarget();
        }
        UpdateWindowGeometry();
        return 0;

    case WM_NCHITTEST:
        {
            POINT pt;
            pt.x = LOWORD(lParam);
            pt.y = HIWORD(lParam);
            ::ScreenToClient(hWnd, &pt);

            RECT rcClient;
            ::GetClientRect(hWnd, &rcClient);

            int dragAreaWidth = 100;
            int dragAreaHeight = 20;
            int dragAreaX = (rcClient.right - rcClient.left - dragAreaWidth) / 2;
            int dragAreaY = 10;

            RECT dragRect;
            dragRect.left = dragAreaX;
            dragRect.top = dragAreaY;
            dragRect.right = dragAreaX + dragAreaWidth;
            dragRect.bottom = dragAreaY + dragAreaHeight;

            if (PtInRect(&dragRect, pt)) {
                return HTCAPTION;
            } else {
                return HTTRANSPARENT;
            }
        }

    case WM_TRAYICON:
        g_trayIcon.HandleMessage(wParam, lParam);
        return 0;

    case WM_COMMAND:
        g_trayIcon.HandleMessage(LOWORD(wParam), MAKELPARAM(WM_COMMAND, 0));
        return 0;

    case WM_DISPLAYCHANGE:
        g_sysinfo.UpdateDisplayInfo();
        return 0;

    case WM_DROPFILES:
    {
#if USE_FILE_TRANSFER
        HDROP hDrop = (HDROP)wParam;
        UINT fileCount = DragQueryFile(hDrop, 0xFFFFFFFF, nullptr, 0);
        for (UINT i = 0; i < fileCount; i++) {
            wchar_t filePath[MAX_PATH];
            if (DragQueryFile(hDrop, i, filePath, MAX_PATH)) {
                g_transferstation.AddFile(filePath);
                LOG_INFO("File dropped: %ls", filePath);
            }
        }
        DragFinish(hDrop);
#endif
        return 0;
    }

    case WM_HOTKEY:
        if (wParam == 1) {
            ::PostQuitMessage(0);
            g_running = false;
            return 0;
        }
        break;

    case WM_KEYDOWN:
        if (wParam == 'Z' && (GetKeyState(VK_CONTROL) & 0x8000) && (GetKeyState(VK_SHIFT) & 0x8000)) {
            ::PostQuitMessage(0);
            g_running = false;
            return 0;
        }
        break;

    case WM_LBUTTONDOWN:
        return 0;

    case WM_DESTROY:
        ::PostQuitMessage(0);
        g_running = false;
        return 0;
    }

    return ::DefWindowProc(hWnd, msg, wParam, lParam);
}

// === 创建主窗口 ===
HWND CreateMainWindow() {
    WNDCLASSEX wc = { sizeof(WNDCLASSEX), CS_CLASSDC, WndProc, 0L, 0L,
                      GetModuleHandle(nullptr), nullptr, nullptr, nullptr, nullptr,
                      L"DynamicIsland", nullptr };
    if (!::RegisterClassEx(&wc)) {
        return nullptr;
    }

    HWND hwnd = ::CreateWindowEx(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        wc.lpszClassName,
        L"DynamicIsland",
        WS_POPUP,
        0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN),
        nullptr, nullptr, wc.hInstance, nullptr
    );

    if (!hwnd) return nullptr;

#if USE_FILE_TRANSFER
    ::DragAcceptFiles(hwnd, TRUE);
#endif

    return hwnd;
}
