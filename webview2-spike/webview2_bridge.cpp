#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include "WebView2.h"

#define WV2_EXPORT extern "C" __declspec(dllexport)

static constexpr UINT WM_APP_WEBVIEW2_FOCUS = WM_APP + 116;
static constexpr UINT WM_APP_WEBVIEW2_TAB_ACTION = WM_APP + 1;
static constexpr int MAX_WEBVIEW_TABS = 32;

struct WebViewTab {
    ICoreWebView2Controller *controller = nullptr;
    ICoreWebView2 *webview = nullptr;
    EventRegistrationToken got_focus_token = {};
    EventRegistrationToken lost_focus_token = {};
    EventRegistrationToken new_window_token = {};
    EventRegistrationToken accelerator_token = {};
    bool got_focus_registered = false;
    bool lost_focus_registered = false;
    bool new_window_registered = false;
    bool accelerator_registered = false;
};

static HINSTANCE g_instance = nullptr;
static HWND g_host = nullptr;
static ICoreWebView2Environment *g_environment = nullptr;
static ICoreWebView2Controller *g_controller = nullptr;
static ICoreWebView2 *g_webview = nullptr;
static WebViewTab g_tabs[MAX_WEBVIEW_TABS] = {};
static int g_tab_count = 0;
static int g_active_tab = -1;
static bool g_wanted = false;
static bool g_com_initialized = false;
static unsigned g_generation = 0;
static wchar_t g_initial_url[2048] = L"https://example.com";

static HRESULT create_tab_async(const wchar_t *url, bool focus_when_ready);
static int cycle_active_tab(bool reverse);
static int close_active_tab();

static BOOL host_has_focus() {
    if (!g_host) return FALSE;
    const HWND direct = GetFocus();
    if (direct == g_host || (direct && IsChild(g_host, direct))) return TRUE;

    GUITHREADINFO info = {};
    info.cbSize = sizeof(info);
    if (GetGUIThreadInfo(0, &info)) {
        const HWND focused = info.hwndFocus;
        if (focused == g_host || (focused && IsChild(g_host, focused))) return TRUE;
    }
    return FALSE;
}

static void post_focus_state(WPARAM state) {
    if (!g_host) return;
    const HWND parent = GetParent(g_host);
    if (parent) PostMessageW(parent, WM_APP_WEBVIEW2_FOCUS, state, 0);
}

static void fit_controllers() {
    if (!g_host) return;
    RECT bounds = {};
    GetClientRect(g_host, &bounds);
    for (int i = 0; i < g_tab_count; ++i) {
        if (g_tabs[i].controller) g_tabs[i].controller->put_Bounds(bounds);
    }
}

static void activate_tab(int index, bool focus) {
    if (index < 0 || index >= g_tab_count) return;
    if (g_active_tab >= 0 && g_active_tab < g_tab_count && g_active_tab != index) {
        if (g_tabs[g_active_tab].controller) g_tabs[g_active_tab].controller->put_IsVisible(FALSE);
    }
    g_active_tab = index;
    g_controller = g_tabs[index].controller;
    g_webview = g_tabs[index].webview;
    fit_controllers();
    if (g_controller) g_controller->put_IsVisible(TRUE);
    if (g_host) ShowWindow(g_host, SW_SHOW);
    if (focus && g_controller && g_host) {
        SetFocus(g_host);
        g_controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
        post_focus_state(2);
    }
}

static LRESULT CALLBACK HostProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
    case WM_SIZE:
        fit_controllers();
        return 0;
    case WM_SETFOCUS:
        if (g_controller) g_controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
        return 0;
    case WM_APP_WEBVIEW2_TAB_ACTION:
        if (wparam == 4) cycle_active_tab(false);
        else if (wparam == 5) cycle_active_tab(true);
        else if (wparam == 6) close_active_tab();
        else if (wparam == 7) create_tab_async(L"about:blank", true);
        return 0;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
}

static bool register_host_class() {
    static bool registered = false;
    if (registered) return true;

    WNDCLASSW wc = {};
    wc.lpfnWndProc = HostProc;
    wc.hInstance = g_instance;
    wc.lpszClassName = L"MultipromptWebView2Host";
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    if (!RegisterClassW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
    registered = true;
    return true;
}

struct FocusChangedHandler final : ICoreWebView2FocusChangedEventHandler {
    ULONG refs = 1;
    bool focused;

    explicit FocusChangedHandler(bool value) : focused(value) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **result) override {
        if (!result) return E_POINTER;
        if (IsEqualIID(iid, IID_IUnknown) ||
            IsEqualIID(iid, IID_ICoreWebView2FocusChangedEventHandler)) {
            *result = static_cast<ICoreWebView2FocusChangedEventHandler *>(this);
            AddRef();
            return S_OK;
        }
        *result = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE Invoke(ICoreWebView2Controller *, IUnknown *) override {
        post_focus_state(focused ? 1 : 0);
        return S_OK;
    }
};

struct NewWindowHandler final : ICoreWebView2NewWindowRequestedEventHandler {
    ULONG refs = 1;

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **result) override {
        if (!result) return E_POINTER;
        if (IsEqualIID(iid, IID_IUnknown) ||
            IsEqualIID(iid, IID_ICoreWebView2NewWindowRequestedEventHandler)) {
            *result = static_cast<ICoreWebView2NewWindowRequestedEventHandler *>(this);
            AddRef();
            return S_OK;
        }
        *result = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE Invoke(ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *args) override {
        if (!args) return E_POINTER;
        LPWSTR uri = nullptr;
        const HRESULT uri_result = args->get_Uri(&uri);
        if (SUCCEEDED(uri_result) && uri && *uri) {
            (void)create_tab_async(uri, true);
            args->put_Handled(TRUE);
        }
        if (uri) CoTaskMemFree(uri);
        return S_OK;
    }
};

struct AcceleratorHandler final : ICoreWebView2AcceleratorKeyPressedEventHandler {
    ULONG refs = 1;

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **result) override {
        if (!result) return E_POINTER;
        if (IsEqualIID(iid, IID_IUnknown) ||
            IsEqualIID(iid, IID_ICoreWebView2AcceleratorKeyPressedEventHandler)) {
            *result = static_cast<ICoreWebView2AcceleratorKeyPressedEventHandler *>(this);
            AddRef();
            return S_OK;
        }
        *result = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE Invoke(
        ICoreWebView2Controller *, ICoreWebView2AcceleratorKeyPressedEventArgs *args) override {
        if (!args) return E_POINTER;
        COREWEBVIEW2_KEY_EVENT_KIND kind = COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN;
        UINT key = 0;
        if (FAILED(args->get_KeyEventKind(&kind)) || FAILED(args->get_VirtualKey(&key))) return S_OK;
        if ((GetKeyState(VK_CONTROL) & 0x8000) == 0) return S_OK;

        UINT action = 0;
        if (key == VK_TAB) action = (GetKeyState(VK_SHIFT) & 0x8000) ? 5 : 4;
        else if (key == 'W' && (GetKeyState(VK_SHIFT) & 0x8000) == 0) action = 6;
        else if (key == 'T' && (GetKeyState(VK_SHIFT) & 0x8000) == 0) action = 7;
        if (!action) return S_OK;

        args->put_Handled(TRUE);
        const bool key_down = kind == COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN ||
                              kind == COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN;
        if (key_down) {
            COREWEBVIEW2_PHYSICAL_KEY_STATUS status = {};
            if (FAILED(args->get_PhysicalKeyStatus(&status)) || !status.WasKeyDown)
                PostMessageW(g_host, WM_APP_WEBVIEW2_TAB_ACTION, action, 0);
        }
        return S_OK;
    }
};

struct ControllerHandler final : ICoreWebView2CreateCoreWebView2ControllerCompletedHandler {
    ULONG refs = 1;
    unsigned generation;
    bool focus_when_ready;
    wchar_t url[2048] = {};

    ControllerHandler(unsigned value, const wchar_t *target, bool focus)
        : generation(value), focus_when_ready(focus) {
        lstrcpynW(url, (target && *target) ? target : L"about:blank",
                  static_cast<int>(sizeof(url) / sizeof(url[0])));
    }

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **result) override {
        if (!result) return E_POINTER;
        if (IsEqualIID(iid, IID_IUnknown) ||
            IsEqualIID(iid, IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler)) {
            *result = static_cast<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *>(this);
            AddRef();
            return S_OK;
        }
        *result = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE Invoke(HRESULT error, ICoreWebView2Controller *controller) override {
        if (FAILED(error) || !controller) return error;
        if (!g_wanted || generation != g_generation || !g_host || g_tab_count >= MAX_WEBVIEW_TABS) {
            controller->Close();
            return S_OK;
        }

        WebViewTab tab = {};
        tab.controller = controller;
        tab.controller->AddRef();
        error = tab.controller->get_CoreWebView2(&tab.webview);
        if (FAILED(error) || !tab.webview) {
            tab.controller->Release();
            return error;
        }

        auto *got_focus = new FocusChangedHandler(true);
        tab.got_focus_registered = SUCCEEDED(tab.controller->add_GotFocus(got_focus, &tab.got_focus_token));
        got_focus->Release();
        auto *lost_focus = new FocusChangedHandler(false);
        tab.lost_focus_registered = SUCCEEDED(tab.controller->add_LostFocus(lost_focus, &tab.lost_focus_token));
        lost_focus->Release();
        auto *new_window = new NewWindowHandler();
        tab.new_window_registered = SUCCEEDED(tab.webview->add_NewWindowRequested(new_window, &tab.new_window_token));
        new_window->Release();
        auto *accelerator = new AcceleratorHandler();
        tab.accelerator_registered = SUCCEEDED(tab.controller->add_AcceleratorKeyPressed(
            accelerator, &tab.accelerator_token));
        accelerator->Release();

        tab.controller->put_IsVisible(FALSE);
        const int index = g_tab_count;
        g_tabs[g_tab_count++] = tab;
        tab.webview->Navigate(url);
        activate_tab(index, focus_when_ready || host_has_focus());
        return S_OK;
    }
};

static HRESULT create_tab_async(const wchar_t *url, bool focus_when_ready) {
    if (!g_wanted || !g_environment || !g_host) return E_UNEXPECTED;
    if (g_tab_count >= MAX_WEBVIEW_TABS) return HRESULT_FROM_WIN32(ERROR_TOO_MANY_OPEN_FILES);
    return g_environment->CreateCoreWebView2Controller(
        g_host, new ControllerHandler(g_generation, url, focus_when_ready));
}

struct EnvironmentHandler final : ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler {
    ULONG refs = 1;
    unsigned generation;

    explicit EnvironmentHandler(unsigned value) : generation(value) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **result) override {
        if (!result) return E_POINTER;
        if (IsEqualIID(iid, IID_IUnknown) ||
            IsEqualIID(iid, IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler)) {
            *result = static_cast<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *>(this);
            AddRef();
            return S_OK;
        }
        *result = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --refs;
        if (!remaining) delete this;
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE Invoke(HRESULT error, ICoreWebView2Environment *environment) override {
        if (FAILED(error) || !environment) return error;
        if (!g_wanted || generation != g_generation || !g_host) return S_OK;

        g_environment = environment;
        g_environment->AddRef();
        return create_tab_async(g_initial_url, true);
    }
};

static void release_tab(WebViewTab *tab) {
    if (!tab) return;
    if (tab->controller && tab->got_focus_registered)
        tab->controller->remove_GotFocus(tab->got_focus_token);
    if (tab->controller && tab->lost_focus_registered)
        tab->controller->remove_LostFocus(tab->lost_focus_token);
    if (tab->webview && tab->new_window_registered)
        tab->webview->remove_NewWindowRequested(tab->new_window_token);
    if (tab->controller && tab->accelerator_registered)
        tab->controller->remove_AcceleratorKeyPressed(tab->accelerator_token);
    if (tab->controller) tab->controller->Close();
    if (tab->webview) tab->webview->Release();
    if (tab->controller) tab->controller->Release();
    *tab = {};
}

static int close_active_tab() {
    if (g_active_tab < 0 || g_active_tab >= g_tab_count) return g_tab_count;
    const int closing = g_active_tab;
    const bool had_focus = host_has_focus() != FALSE;
    release_tab(&g_tabs[closing]);
    for (int i = closing; i + 1 < g_tab_count; ++i) g_tabs[i] = g_tabs[i + 1];
    g_tabs[g_tab_count - 1] = {};
    --g_tab_count;
    g_active_tab = -1;
    g_controller = nullptr;
    g_webview = nullptr;
    if (g_tab_count > 0) {
        const int next = closing < g_tab_count ? closing : g_tab_count - 1;
        activate_tab(next, had_focus);
    }
    return g_tab_count;
}

static int cycle_active_tab(bool reverse) {
    if (g_tab_count <= 0) return 0;
    int next = g_active_tab;
    if (reverse) next = (next <= 0) ? g_tab_count - 1 : next - 1;
    else next = (next + 1 >= g_tab_count) ? 0 : next + 1;
    activate_tab(next, true);
    return g_tab_count;
}

WV2_EXPORT HRESULT wv2_create(HWND parent, const wchar_t *url) {
    if (!parent) return E_INVALIDARG;
    if (g_wanted) return S_FALSE;
    if (!register_host_class()) return HRESULT_FROM_WIN32(GetLastError());

    const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(com)) g_com_initialized = true;
    else if (com != RPC_E_CHANGED_MODE) return com;

    lstrcpynW(g_initial_url, (url && *url) ? url : L"about:blank",
              static_cast<int>(sizeof(g_initial_url) / sizeof(g_initial_url[0])));
    g_wanted = true;
    ++g_generation;
    g_host = CreateWindowExW(
        0, L"MultipromptWebView2Host", L"", WS_CHILD | WS_CLIPCHILDREN | WS_VISIBLE,
        0, 0, 1, 1, parent, nullptr, g_instance, nullptr);
    if (!g_host) {
        g_wanted = false;
        return HRESULT_FROM_WIN32(GetLastError());
    }

    const HRESULT result = CreateCoreWebView2EnvironmentWithOptions(
        nullptr, nullptr, nullptr, new EnvironmentHandler(g_generation));
    if (FAILED(result)) {
        DestroyWindow(g_host);
        g_host = nullptr;
        g_wanted = false;
    }
    return result;
}

WV2_EXPORT void wv2_set_bounds(int x, int y, int width, int height) {
    if (!g_host) return;
    MoveWindow(g_host, x, y, width > 1 ? width : 1, height > 1 ? height : 1, TRUE);
    fit_controllers();
}

WV2_EXPORT void wv2_focus() {
    if (g_host) {
        SetFocus(g_host);
        if (g_controller) g_controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
    }
}

WV2_EXPORT BOOL wv2_has_focus() {
    return host_has_focus();
}

WV2_EXPORT HWND wv2_get_host() {
    return g_host;
}

WV2_EXPORT void wv2_set_visible(BOOL visible) {
    if (g_controller) g_controller->put_IsVisible(visible);
    if (g_host) ShowWindow(g_host, visible ? SW_SHOW : SW_HIDE);
}

WV2_EXPORT void wv2_navigate(const wchar_t *url) {
    if (g_webview && url && *url) g_webview->Navigate(url);
}

WV2_EXPORT BOOL wv2_open_tab(const wchar_t *url, BOOL focus_when_ready) {
    return SUCCEEDED(create_tab_async(
        (url && *url) ? url : L"about:blank", focus_when_ready != FALSE));
}

WV2_EXPORT int wv2_next_tab(BOOL reverse) {
    return cycle_active_tab(reverse != FALSE);
}

WV2_EXPORT int wv2_close_tab() {
    return close_active_tab();
}

WV2_EXPORT int wv2_tab_count() {
    return g_tab_count;
}

WV2_EXPORT void wv2_back() {
    BOOL can_go_back = FALSE;
    if (g_webview && SUCCEEDED(g_webview->get_CanGoBack(&can_go_back)) && can_go_back)
        g_webview->GoBack();
}

WV2_EXPORT void wv2_forward() {
    BOOL can_go_forward = FALSE;
    if (g_webview && SUCCEEDED(g_webview->get_CanGoForward(&can_go_forward)) && can_go_forward)
        g_webview->GoForward();
}

WV2_EXPORT void wv2_reload() {
    if (g_webview) g_webview->Reload();
}

WV2_EXPORT void wv2_close() {
    g_wanted = false;
    ++g_generation;
    if (g_host) ShowWindow(g_host, SW_HIDE);
    for (int i = g_tab_count - 1; i >= 0; --i) release_tab(&g_tabs[i]);
    g_tab_count = 0;
    g_active_tab = -1;
    g_controller = nullptr;
    g_webview = nullptr;
    if (g_environment) {
        g_environment->Release();
        g_environment = nullptr;
    }
    if (g_host) {
        DestroyWindow(g_host);
        g_host = nullptr;
    }
    if (g_com_initialized) {
        CoUninitialize();
        g_com_initialized = false;
    }
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_instance = instance;
    return TRUE;
}
