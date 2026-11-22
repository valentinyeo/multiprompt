
#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include "WebView2.h"


static HWND                    g_hwnd   = nullptr;
static ICoreWebView2Controller *g_ctrl  = nullptr;
static ICoreWebView2           *g_wv    = nullptr;
static wchar_t                 g_url[2048] = L"https://example.com";

static void fit() {
    if (!g_ctrl) return;
    RECT r; GetClientRect(g_hwnd, &r);
    g_ctrl->put_Bounds(r);
}


struct CtrlHandler : ICoreWebView2CreateCoreWebView2ControllerCompletedHandler {
    ULONG refs = 1;
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **p) override
        { *p = this; AddRef(); return S_OK; }
    ULONG   STDMETHODCALLTYPE AddRef()   override { return ++refs; }
    ULONG   STDMETHODCALLTYPE Release()  override {
        if (!--refs) { delete this; return 0; } return refs;
    }
    HRESULT STDMETHODCALLTYPE Invoke(HRESULT hr, ICoreWebView2Controller *ctrl) override {
        if (FAILED(hr) || !ctrl) {
            wchar_t buf[128];
            wsprintfW(buf, L"CreateController failed: 0x%08X", (unsigned)hr);
            MessageBoxW(g_hwnd, buf, L"WebView2 Spike Error", MB_ICONERROR);
            PostQuitMessage(1);
            return hr;
        }
        g_ctrl = ctrl; ctrl->AddRef();
        ctrl->get_CoreWebView2(&g_wv);
        fit();
        ctrl->put_IsVisible(TRUE);
        g_wv->Navigate(g_url);
        return S_OK;
    }
};

struct EnvHandler : ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler {
    ULONG refs = 1;
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **p) override
        { *p = this; AddRef(); return S_OK; }
    ULONG   STDMETHODCALLTYPE AddRef()   override { return ++refs; }
    ULONG   STDMETHODCALLTYPE Release()  override {
        if (!--refs) { delete this; return 0; } return refs;
    }
    HRESULT STDMETHODCALLTYPE Invoke(HRESULT hr, ICoreWebView2Environment *env) override {
        if (FAILED(hr) || !env) {
            wchar_t buf[128];
            wsprintfW(buf, L"CreateEnvironment failed: 0x%08X", (unsigned)hr);
            MessageBoxW(g_hwnd, buf, L"WebView2 Spike Error", MB_ICONERROR);
            PostQuitMessage(1);
            return hr;
        }
        env->CreateCoreWebView2Controller(g_hwnd, new CtrlHandler());
        return S_OK;
    }
};


LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_SIZE:
        fit();
        return 0;
    case WM_DESTROY:
        if (g_wv)   { g_wv->Release();   g_wv   = nullptr; }
        if (g_ctrl) { g_ctrl->Release(); g_ctrl = nullptr; }
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}


int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int nCmdShow) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    GetEnvironmentVariableW(L"WEBVIEW2_SPIKE_URL", g_url,
                            static_cast<DWORD>(sizeof(g_url) / sizeof(g_url[0])));

    WNDCLASSW wc   = {};
    wc.lpfnWndProc = WndProc;
    wc.hInstance   = hInst;
    wc.lpszClassName = L"WV2Spike";
    wc.hCursor     = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassW(&wc);

    g_hwnd = CreateWindowW(
        L"WV2Spike",
        L"WebView2 Spike — ZigShell Feasibility",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 1100, 750,
        nullptr, nullptr, hInst, nullptr);

    ShowWindow(g_hwnd, nCmdShow);
    UpdateWindow(g_hwnd);

    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
                                                          new EnvHandler());
    if (FAILED(hr)) {
        wchar_t buf[128];
        wsprintfW(buf, L"WebView2 not available (0x%08X).\n"
                        L"Ensure Edge / WebView2 Runtime is installed.", (unsigned)hr);
        MessageBoxW(g_hwnd, buf, L"WebView2 Spike Error", MB_ICONERROR);
        return 1;
    }

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    CoUninitialize();
    return (int)msg.wParam;
}
