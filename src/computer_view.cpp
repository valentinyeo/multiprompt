#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <windows.h>
#include <shlobj.h>
#include <sddl.h>
#include <bcrypt.h>
#include <objbase.h>
#include <WebView2.h>
#include <atomic>
#include <array>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <algorithm>
#include <cstring>
#include <cstdlib>

extern "C" const unsigned char* mp_computer_asset(const char*, size_t, size_t*);
extern "C" const unsigned char* mp_computer_loader(size_t*, const char**);
extern "C" void mp_computer_event(uint64_t, unsigned);

namespace {
std::wstring wide(const std::string& s) {
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), int(s.size()), nullptr, 0);
    if (!n && !s.empty()) return {};
    std::wstring out(n, 0);
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), int(s.size()), out.data(), n);
    return out;
}
std::wstring quote(const std::wstring& s) {
    std::wstring out = L"\"";
    size_t slashes = 0;
    for (wchar_t c : s) {
        if (c == L'\\') { ++slashes; continue; }
        out.append(slashes * (c == L'\"' ? 2 : 1), L'\\');
        slashes = 0;
        if (c == L'\"') out += L'\\';
        out += c;
    }
    out.append(slashes * 2, L'\\');
    return out + L'\"';
}
bool digest(const void* bytes, size_t length, unsigned char out[32]) {
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0) return false;
    NTSTATUS status = BCryptHash(alg, nullptr, 0, const_cast<PUCHAR>(static_cast<const unsigned char*>(bytes)), ULONG(length), out, 32);
    BCryptCloseAlgorithmProvider(alg, 0);
    return status >= 0;
}
std::string hex(const unsigned char* bytes, size_t length) {
    const char* digits = "0123456789abcdef";
    std::string out;
    for (size_t i = 0; i < length; ++i) { out += digits[bytes[i] >> 4]; out += digits[bytes[i] & 15]; }
    return out;
}
std::string nonce() {
    unsigned char bytes[24];
    if (BCryptGenRandom(nullptr, bytes, sizeof(bytes), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) return {};
    return hex(bytes, sizeof(bytes));
}
void wipe(std::string& value) {
    if (!value.empty()) SecureZeroMemory(value.data(), value.size());
    value.clear();
}
template<class I, class... A> class Handler final : public I {
    std::atomic<ULONG> refs{1};
    std::function<HRESULT(A...)> fn;
    IID interface_id;
public:
    Handler(REFIID id, std::function<HRESULT(A...)> f) : fn(std::move(f)), interface_id(id) {}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (id == IID_IUnknown || id == interface_id) { *out = static_cast<I*>(this); AddRef(); return S_OK; }
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { ULONG n = --refs; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE Invoke(A... args) override { return fn(args...); }
};
template<class I, class... A, class F> I* callback(REFIID id, F fn) { return new Handler<I, A...>(id, std::move(fn)); }
template<class I> void release(I*& value) { if (value) value->Release(); value = nullptr; }

class Options final : public ICoreWebView2EnvironmentOptions, public ICoreWebView2EnvironmentOptions6 {
    std::atomic<ULONG> refs{1};
    std::wstring arguments = L"--disable-remote-debugging --disable-breakpad --disable-crash-reporter --disable-gpu-shader-disk-cache --disable-features=msEdgeDevToolsWdpRemoteDebugging,msWebOOUI,msPdfOOUI";
    static HRESULT copy(const std::wstring& value, LPWSTR* out) {
        if (!out) return E_POINTER;
        *out = static_cast<LPWSTR>(CoTaskMemAlloc((value.size() + 1) * sizeof(wchar_t)));
        if (!*out) return E_OUTOFMEMORY;
        memcpy(*out, value.c_str(), (value.size() + 1) * sizeof(wchar_t));
        return S_OK;
    }
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (id == IID_IUnknown || id == IID_ICoreWebView2EnvironmentOptions) *out = static_cast<ICoreWebView2EnvironmentOptions*>(this);
        else if (id == IID_ICoreWebView2EnvironmentOptions6) *out = static_cast<ICoreWebView2EnvironmentOptions6*>(this);
        else return E_NOINTERFACE;
        AddRef(); return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { ULONG n = --refs; if (!n) delete this; return n; }
    HRESULT STDMETHODCALLTYPE get_AdditionalBrowserArguments(LPWSTR* v) override { return copy(arguments, v); }
    HRESULT STDMETHODCALLTYPE put_AdditionalBrowserArguments(LPCWSTR) override { return E_ACCESSDENIED; }
    HRESULT STDMETHODCALLTYPE get_Language(LPWSTR* v) override { return copy(L"en-US", v); }
    HRESULT STDMETHODCALLTYPE put_Language(LPCWSTR) override { return E_ACCESSDENIED; }
    HRESULT STDMETHODCALLTYPE get_TargetCompatibleBrowserVersion(LPWSTR* v) override { return copy(L"120.0.0.0", v); }
    HRESULT STDMETHODCALLTYPE put_TargetCompatibleBrowserVersion(LPCWSTR) override { return E_ACCESSDENIED; }
    HRESULT STDMETHODCALLTYPE get_AllowSingleSignOnUsingOSPrimaryAccount(BOOL* v) override { *v = FALSE; return S_OK; }
    HRESULT STDMETHODCALLTYPE put_AllowSingleSignOnUsingOSPrimaryAccount(BOOL) override { return E_ACCESSDENIED; }
    HRESULT STDMETHODCALLTYPE get_AreBrowserExtensionsEnabled(BOOL* v) override { *v = FALSE; return S_OK; }
    HRESULT STDMETHODCALLTYPE put_AreBrowserExtensionsEnabled(BOOL) override { return E_ACCESSDENIED; }
};

bool privateDirectory(std::wstring& path) {
    wchar_t base[MAX_PATH];
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, SHGFP_TYPE_CURRENT, base))) return false;
    std::string random = nonce();
    if (random.empty()) return false;
    path = std::wstring(base) + L"\\MultipromptComputer-" + wide(random);
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    std::vector<unsigned char> data(size);
    bool ok = size && GetTokenInformation(token, TokenUser, data.data(), size, &size);
    CloseHandle(token);
    if (!ok) return false;
    LPWSTR sid = nullptr;
    if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid, &sid)) return false;
    std::wstring sddl = L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;" + std::wstring(sid) + L")";
    LocalFree(sid);
    PSECURITY_DESCRIPTOR descriptor = nullptr;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) return false;
    SECURITY_ATTRIBUTES attributes{sizeof(attributes), descriptor, FALSE};
    ok = CreateDirectoryW(path.c_str(), &attributes) != FALSE;
    LocalFree(descriptor);
    return ok;
}

HMODULE sdk_loader_process_lifetime = nullptr;
HANDLE sdk_loader_file_process_lifetime = INVALID_HANDLE_VALUE;
bool computer_sta_process_lifetime = false;
std::wstring computer_directory_process_lifetime;

struct View : std::enable_shared_from_this<View> {
    HWND host = nullptr;
    HWND parent = nullptr;
    HMODULE loader = nullptr;
    HANDLE loaderFile = INVALID_HANDLE_VALUE;
    ICoreWebView2Environment* environment = nullptr;
    ICoreWebView2Controller* controller = nullptr;
    ICoreWebView2* web = nullptr;
    std::string token;
    std::wstring origin;
    std::wstring page;
    std::wstring directory;
    std::wstring fallback;
    uint64_t generation = 0;
    bool ready = false;
    bool visible = false;
    bool focused = false;
    bool failed = false;
    bool navigating = false;
    bool com = false;
    bool placing = false;
    RECT placement{};
    ~View() {
        ready = false;
        if (controller) controller->Close();
        release(web); release(controller); release(environment);
        if (host) DestroyWindow(host);
        if (loaderFile != INVALID_HANDLE_VALUE) CloseHandle(loaderFile);
    }
    void lost() {
        failed = true;
        if (controller) controller->put_IsVisible(FALSE);
        InvalidateRect(host, nullptr, TRUE);
        mp_computer_event(generation, 2);
    }
    void send(const char* bytes, size_t length) {
        if (!ready || !web || length < 2 || bytes[0] != '{' || length > 8192) return;
        std::string json;
        json.reserve(length + token.size() + 16);
        json = "{\"token\":\"";
        json += token;
        json += "\",";
        json.append(bytes + 1,length - 1);
        std::wstring text = wide(json);
        web->PostWebMessageAsJson(text.c_str());
        if (!text.empty()) SecureZeroMemory(text.data(), text.size() * sizeof(wchar_t));
        wipe(json);
    }
    HRESULT resource(ICoreWebView2WebResourceRequestedEventArgs* args) {
        ICoreWebView2WebResourceRequest* request = nullptr;
        if (FAILED(args->get_Request(&request))) return E_FAIL;
        LPWSTR uri = nullptr;
        LPWSTR method = nullptr;
        request->get_Uri(&uri); request->get_Method(&method);
        std::wstring url = uri ? uri : L"";
        bool get = method && wcscmp(method, L"GET") == 0;
        CoTaskMemFree(uri); CoTaskMemFree(method); request->Release();
        const unsigned char* bytes = nullptr;
        size_t length = 0;
        std::string name;
        if (get && url.compare(0, origin.size(), origin) == 0) {
            std::wstring suffix = url.substr(origin.size());
            if (suffix.find_first_of(L"%?#\\") == std::wstring::npos && suffix.find(L"..") == std::wstring::npos) {
                name.assign(suffix.begin(), suffix.end());
                bytes = mp_computer_asset(name.data(), name.size(), &length);
            }
        }
        std::wstring type = L"application/octet-stream";
        if (name == "index.html") type = L"text/html; charset=utf-8";
        else if (name.size() > 3 && name.substr(name.size()-3) == ".js") type = L"text/javascript; charset=utf-8";
        else if (name == "computer.css") type = L"text/css; charset=utf-8";
        IStream* stream = nullptr;
        if (bytes) {
            if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) return E_OUTOFMEMORY;
            ULONG written = 0;
            if (FAILED(stream->Write(bytes, ULONG(length), &written)) || written != length) { stream->Release(); return E_FAIL; }
            LARGE_INTEGER zero{};
            stream->Seek(zero, STREAM_SEEK_SET, nullptr);
        }
        std::wstring headers = L"Content-Type: " + type + L"\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src ws://127.0.0.1:*; object-src 'none'; base-uri 'none'; frame-src 'none'; form-action 'none'; frame-ancestors 'none'\r\n";
        ICoreWebView2WebResourceResponse* response = nullptr;
        HRESULT result = environment->CreateWebResourceResponse(stream, bytes ? 200 : 403, bytes ? L"OK" : L"Forbidden", headers.c_str(), &response);
        if (stream) stream->Release();
        if (SUCCEEDED(result)) { result = args->put_Response(response); response->Release(); }
        return result;
    }
    bool configure() {
        ICoreWebView2Settings* settings = nullptr;
        if (FAILED(web->get_Settings(&settings))) return false;
        bool ok = SUCCEEDED(settings->put_IsScriptEnabled(TRUE)) && SUCCEEDED(settings->put_IsWebMessageEnabled(TRUE)) &&
            SUCCEEDED(settings->put_AreDefaultScriptDialogsEnabled(FALSE)) && SUCCEEDED(settings->put_AreDefaultContextMenusEnabled(FALSE)) &&
            SUCCEEDED(settings->put_AreDevToolsEnabled(FALSE)) && SUCCEEDED(settings->put_AreHostObjectsAllowed(FALSE)) &&
            SUCCEEDED(settings->put_IsStatusBarEnabled(FALSE)) && SUCCEEDED(settings->put_IsZoomControlEnabled(FALSE));
        ICoreWebView2Settings4* settings4 = nullptr;
        if (SUCCEEDED(settings->QueryInterface(IID_ICoreWebView2Settings4, reinterpret_cast<void**>(&settings4)))) {
            ok = ok && SUCCEEDED(settings4->put_AreBrowserAcceleratorKeysEnabled(FALSE)) &&
                SUCCEEDED(settings4->put_IsPasswordAutosaveEnabled(FALSE)) && SUCCEEDED(settings4->put_IsGeneralAutofillEnabled(FALSE));
            settings4->Release();
        } else ok = false;
        settings->Release();
        ICoreWebView2Controller4* c4 = nullptr;
        if (SUCCEEDED(controller->QueryInterface(IID_ICoreWebView2Controller4, reinterpret_cast<void**>(&c4)))) {
            ok = ok && SUCCEEDED(c4->put_AllowExternalDrop(FALSE)); c4->Release();
        } else ok = false;
        if (!ok) return false;
        std::weak_ptr<View> weak = shared_from_this();
        EventRegistrationToken event{};
        auto gotFocus = callback<ICoreWebView2FocusChangedEventHandler, ICoreWebView2Controller*, IUnknown*>(IID_ICoreWebView2FocusChangedEventHandler, [weak](auto*, auto*) {
            if (auto self = weak.lock()) self->focused = true;
            return S_OK;
        });
        ok = SUCCEEDED(controller->add_GotFocus(gotFocus, &event)); gotFocus->Release();
        auto lostFocus = callback<ICoreWebView2FocusChangedEventHandler, ICoreWebView2Controller*, IUnknown*>(IID_ICoreWebView2FocusChangedEventHandler, [weak](auto*, auto*) {
            if (auto self = weak.lock()) { self->focused = false; mp_computer_event(self->generation, 9); }
            return S_OK;
        });
        ok = ok && SUCCEEDED(controller->add_LostFocus(lostFocus, &event)); lostFocus->Release();
        auto navigation = callback<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs*>(IID_ICoreWebView2NavigationStartingEventHandler, [weak](auto*, auto* a) {
            auto self = weak.lock();
            LPWSTR uri = nullptr; a->get_Uri(&uri);
            bool allow = self && !self->navigating && uri && self->page == uri;
            if (allow) self->navigating = true;
            a->put_Cancel(!allow); CoTaskMemFree(uri); return S_OK;
        });
        ok = ok && SUCCEEDED(web->add_NavigationStarting(navigation, &event)); navigation->Release();
        auto frame = callback<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs*>(IID_ICoreWebView2NavigationStartingEventHandler, [](auto*, auto* a) { a->put_Cancel(TRUE); return S_OK; });
        ok = ok && SUCCEEDED(web->add_FrameNavigationStarting(frame, &event)); frame->Release();
        auto popup = callback<ICoreWebView2NewWindowRequestedEventHandler, ICoreWebView2*, ICoreWebView2NewWindowRequestedEventArgs*>(IID_ICoreWebView2NewWindowRequestedEventHandler, [](auto*, auto* a) { a->put_Handled(TRUE); return S_OK; });
        ok = ok && SUCCEEDED(web->add_NewWindowRequested(popup, &event)); popup->Release();
        auto permission = callback<ICoreWebView2PermissionRequestedEventHandler, ICoreWebView2*, ICoreWebView2PermissionRequestedEventArgs*>(IID_ICoreWebView2PermissionRequestedEventHandler, [](auto*, auto* a) { a->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY); return S_OK; });
        ok = ok && SUCCEEDED(web->add_PermissionRequested(permission, &event)); permission->Release();
        auto process = callback<ICoreWebView2ProcessFailedEventHandler, ICoreWebView2*, ICoreWebView2ProcessFailedEventArgs*>(IID_ICoreWebView2ProcessFailedEventHandler, [weak](auto*, auto*) { if (auto s = weak.lock()) s->lost(); return S_OK; });
        ok = ok && SUCCEEDED(web->add_ProcessFailed(process, &event)); process->Release();
        auto message = callback<ICoreWebView2WebMessageReceivedEventHandler, ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs*>(IID_ICoreWebView2WebMessageReceivedEventHandler, [weak](auto*, auto* a) {
            auto self = weak.lock(); if (!self) return S_OK;
            LPWSTR source = nullptr; LPWSTR value = nullptr;
            a->get_Source(&source);
            if (!source || self->page != source || FAILED(a->TryGetWebMessageAsString(&value))) { CoTaskMemFree(source); return S_OK; }
            std::wstring text = value ? value : L"";
            CoTaskMemFree(source); CoTaskMemFree(value);
            std::wstring prefix = wide(self->token) + L"|";
            if (text.size() > 128 || text.compare(0, prefix.size(), prefix) != 0) return S_OK;
            size_t bar = text.find(L'|', prefix.size());
            if (bar == std::wstring::npos || bar == prefix.size()) return S_OK;
            uint64_t owner = 0;
            for (size_t i = prefix.size(); i < bar; ++i) {
                if (text[i] < L'0' || text[i] > L'9' || owner > UINT64_MAX / 10 - 10) return S_OK;
                owner = owner * 10 + (text[i] - L'0');
            }
            std::wstring kind = text.substr(bar + 1);
            if (kind == L"ready" && owner == 0 && !self->ready) { self->ready = true; mp_computer_event(0, 1); return S_OK; }
            if (owner != self->generation || !self->ready) return S_OK;
            unsigned id = kind == L"lost" ? 2 : kind == L"painted" ? 3 : kind == L"stopped" ? 4 : kind == L"take" ? 5 : kind == L"give" ? 6 : kind == L"wide" ? 7 : kind == L"retry" ? 8 : 0;
            if (id) mp_computer_event(owner, id);
            return S_OK;
        });
        ok = ok && SUCCEEDED(web->add_WebMessageReceived(message, &event)); message->Release();
        auto resourceHandler = callback<ICoreWebView2WebResourceRequestedEventHandler, ICoreWebView2*, ICoreWebView2WebResourceRequestedEventArgs*>(IID_ICoreWebView2WebResourceRequestedEventHandler, [weak](auto*, auto* a) { if (auto s = weak.lock()) return s->resource(a); return E_ABORT; });
        ok = ok && SUCCEEDED(web->AddWebResourceRequestedFilter(L"https://*/*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL)) &&
            SUCCEEDED(web->AddWebResourceRequestedFilter(L"http://*/*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL)) &&
            SUCCEEDED(web->add_WebResourceRequested(resourceHandler, &event)); resourceHandler->Release();
        ICoreWebView2_4* w4 = nullptr;
        if (SUCCEEDED(web->QueryInterface(IID_ICoreWebView2_4, reinterpret_cast<void**>(&w4)))) {
            auto download = callback<ICoreWebView2DownloadStartingEventHandler, ICoreWebView2*, ICoreWebView2DownloadStartingEventArgs*>(IID_ICoreWebView2DownloadStartingEventHandler, [](auto*, auto* a) { a->put_Cancel(TRUE); a->put_Handled(TRUE); return S_OK; });
            ok = ok && SUCCEEDED(w4->add_DownloadStarting(download, &event)); download->Release(); w4->Release();
        } else ok = false;
        return ok;
    }
};
std::shared_ptr<View> view;
LRESULT CALLBACK hostProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_PAINT) {
        PAINTSTRUCT ps{}; HDC dc = BeginPaint(hwnd, &ps);
        RECT rect; GetClientRect(hwnd, &rect);
        HBRUSH brush = CreateSolidBrush(RGB(25,25,25)); FillRect(dc, &rect, brush); DeleteObject(brush);
        if (view && view->host == hwnd && (!view->ready || view->failed)) {
            SetTextColor(dc, RGB(220,220,220)); SetBkMode(dc, TRANSPARENT);
            DrawTextW(dc, view->fallback.c_str(), -1, &rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
        }
        EndPaint(hwnd, &ps); return 0;
    }
    if (msg == WM_LBUTTONUP && view && view->host == hwnd && (view->failed || !view->ready)) mp_computer_event(view->generation, 8);
    if (msg == WM_SETFOCUS && view && view->host == hwnd) SetFocus(view->parent);
    return DefWindowProcW(hwnd, msg, wp, lp);
}

bool load(View& v) {
    if (computer_directory_process_lifetime.empty()) {
        std::wstring directory;
        if (!privateDirectory(directory)) return false;
        computer_directory_process_lifetime = std::move(directory);
    }
    v.directory = computer_directory_process_lifetime;
    if (sdk_loader_process_lifetime) { v.loader = sdk_loader_process_lifetime; return true; }
    size_t size = 0; const char* expected = nullptr;
    auto bytes = mp_computer_loader(&size, &expected);
    unsigned char hash[32];
    if (!bytes || !expected || !digest(bytes, size, hash) || hex(hash,32) != expected) return false;
    std::wstring path = v.directory + L"\\" + wide(expected) + L".dll";
    HANDLE file = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    bool ok = WriteFile(file, bytes, DWORD(size), &written, nullptr) && written == size && FlushFileBuffers(file);
    CloseHandle(file);
    if (!ok) return false;
    v.loaderFile = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (v.loaderFile == INVALID_HANDLE_VALUE) return false;
    BY_HANDLE_FILE_INFORMATION info{};
    std::vector<unsigned char> check(size);
    DWORD read = 0;
    if (!GetFileInformationByHandle(v.loaderFile, &info) || info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT ||
        !ReadFile(v.loaderFile, check.data(), DWORD(size), &read, nullptr) || read != size || !digest(check.data(), size, hash) || hex(hash,32) != expected) return false;
    v.loader = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!v.loader) return false;
    sdk_loader_process_lifetime = v.loader;
    sdk_loader_file_process_lifetime = v.loaderFile;
    v.loaderFile = INVALID_HANDLE_VALUE;
    return true;
}
}

extern "C" int mp_computer_create(HWND parent) {
    if (view) return view->failed ? -1 : 1;
    auto self = std::make_shared<View>(); view = self; self->parent = parent;
    if (!computer_sta_process_lifetime) computer_sta_process_lifetime = SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED));
    self->com = computer_sta_process_lifetime;
    WNDCLASSW cls{}; cls.hInstance = GetModuleHandleW(nullptr); cls.lpfnWndProc = hostProc; cls.lpszClassName = L"MultipromptPrivateComputer"; cls.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    RegisterClassW(&cls);
    self->host = CreateWindowExW(WS_EX_NOACTIVATE, cls.lpszClassName, L"", WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS, 0,0,1,1,parent,nullptr,cls.hInstance,nullptr);
    self->token = nonce();
    self->origin = L"http://127.0.0.1/" + wide(self->token) + L"/";
    self->page = self->origin + L"index.html";
    if (!self->com || !self->host || self->token.empty() || !load(*self)) { self->lost(); return -1; }
    using Create = HRESULT(STDAPICALLTYPE*)(PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions*, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler*);
    auto create = reinterpret_cast<Create>(GetProcAddress(self->loader, "CreateCoreWebView2EnvironmentWithOptions"));
    if (!create) { self->lost(); return -1; }
    const wchar_t* vars[] = {L"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS", L"WEBVIEW2_PIPE_FOR_SCRIPT_DEBUGGER", L"WEBVIEW2_WAIT_FOR_SCRIPT_DEBUGGER", L"WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", L"WEBVIEW2_USER_DATA_FOLDER"};
    for (auto name : vars) SetEnvironmentVariableW(name, nullptr);
    std::weak_ptr<View> weak = self;
    auto handler = callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, HRESULT, ICoreWebView2Environment*>(IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, [weak](HRESULT result, ICoreWebView2Environment* env) {
        auto s = weak.lock(); if (!s) return S_OK;
        if (FAILED(result) || !env) { s->lost(); return S_OK; }
        s->environment = env; env->AddRef();
        ICoreWebView2Environment10* e10 = nullptr;
        if (FAILED(env->QueryInterface(IID_ICoreWebView2Environment10, reinterpret_cast<void**>(&e10)))) { s->lost(); return S_OK; }
        ICoreWebView2ControllerOptions* options = nullptr;
        bool ok = SUCCEEDED(e10->CreateCoreWebView2ControllerOptions(&options));
        if (ok) ok = SUCCEEDED(options->put_IsInPrivateModeEnabled(TRUE)) && SUCCEEDED(options->put_ProfileName(L"Computer"));
        auto done = callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, HRESULT, ICoreWebView2Controller*>(IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, [weak](HRESULT status, ICoreWebView2Controller* controller) {
            auto current = weak.lock();
            if (!current) { if (controller) controller->Close(); return S_OK; }
            if (FAILED(status) || !controller) { current->lost(); return S_OK; }
            current->controller = controller; controller->AddRef();
            if (FAILED(controller->get_CoreWebView2(&current->web)) || !current->configure()) { current->lost(); return S_OK; }
            RECT rect; GetClientRect(current->host, &rect); controller->put_Bounds(rect); controller->put_IsVisible(current->visible);
            if (FAILED(current->web->Navigate(current->page.c_str()))) current->lost();
            return S_OK;
        });
        if (ok) ok = SUCCEEDED(e10->CreateCoreWebView2ControllerWithOptions(s->host, options, done));
        done->Release(); release(options); e10->Release();
        if (!ok) s->lost();
        return S_OK;
    });
    auto options = new Options();
    HRESULT result = create(nullptr, (self->directory + L"\\Profile").c_str(), options, handler);
    options->Release(); handler->Release();
    if (FAILED(result)) { self->lost(); return -1; }
    return 1;
}
extern "C" int mp_computer_ready() { return view && view->ready && !view->failed; }
extern "C" void mp_computer_present(int x, int y, int width, int height, int visible) {
    if (!view || view->placing) return;
    view->placing = true;
    bool wasVisible = view->visible;
    view->visible = visible != 0;
    RECT next{x,y,x+width,y+height};
    bool changed = !EqualRect(&next,&view->placement) || !wasVisible;
    view->placement = next;
    if (visible) {
        if (changed || !IsWindowVisible(view->host) || GetWindow(view->host,GW_HWNDPREV))
            SetWindowPos(view->host, HWND_TOP, x,y,width,height,SWP_NOACTIVATE | SWP_SHOWWINDOW);
        if (changed) {
            unsigned dpi = GetDpiForWindow(view->host);
            int corner = MulDiv(24,dpi ? dpi : 96,96);
            HRGN region = CreateRoundRectRgn(0,0,width+1,height+1,corner,corner);
            if (!SetWindowRgn(view->host, region, TRUE)) DeleteObject(region);
            if (view->controller) { RECT bounds{0,0,width,height}; view->controller->put_Bounds(bounds); view->controller->put_IsVisible(!view->failed); }
        }
    } else if (wasVisible) ShowWindow(view->host, SW_HIDE);
    view->placing = false;
}
extern "C" void mp_computer_command(uint64_t generation, const char* json, size_t length) {
    if (!view) return;
    view->generation = generation;
    view->send(json,length);
}
extern "C" void mp_computer_fallback(uint64_t generation, const char* text, size_t length) {
    if (!view) return;
    std::wstring next = wide(std::string(text,length));
    if (view->generation == generation && view->fallback == next) return;
    view->generation = generation; view->fallback = std::move(next);
    InvalidateRect(view->host,nullptr,TRUE);
}
extern "C" void mp_computer_focus() {
    if (view && view->controller && view->visible && !view->failed) view->controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
}
extern "C" int mp_computer_has_input_focus() {
    if (!view || !view->controller || !view->visible || view->failed || GetForegroundWindow() != view->parent) return 0;
    GUITHREADINFO focus{}; focus.cbSize = sizeof(focus);
    if (GetGUIThreadInfo(0, &focus) && focus.hwndFocus) return focus.hwndFocus == view->host || IsChild(view->host, focus.hwndFocus);
    return view->focused;
}
extern "C" int mp_computer_cursor_inside() {
    if (!view || !view->visible) return 0;
    RECT rect{}; POINT point{};
    return GetWindowRect(view->host,&rect) && GetCursorPos(&point) && PtInRect(&rect,point);
}
extern "C" void mp_computer_destroy() { view.reset(); }

namespace {
struct SshResult {
    int state = 0;
    unsigned short localPort = 0;
    unsigned char profile[32]{};
    char json[4096]{};
};
struct SshJob {
    HANDLE cancel = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    HANDLE group = CreateJobObjectW(nullptr, nullptr);
    std::mutex mutex;
    SshResult result;
    ~SshJob() {
        SecureZeroMemory(&result, sizeof(result));
        if (group) CloseHandle(group);
        if (cancel) CloseHandle(cancel);
    }
};
struct SshOwner { std::shared_ptr<SshJob> job; };
struct Child {
    HANDLE process = nullptr;
    HANDLE input = nullptr;
    HANDLE output = nullptr;
    ~Child() {
        if (input) CloseHandle(input);
        if (output) CloseHandle(output);
        if (process) { TerminateProcess(process, 1); CloseHandle(process); }
    }
};
bool spawn(SshJob& job, std::wstring command, Child& child) {
    SECURITY_ATTRIBUTES sa{sizeof(sa), nullptr, TRUE};
    HANDLE inRead = nullptr, outWrite = nullptr;
    if (!CreatePipe(&inRead, &child.input, &sa, 0)) return false;
    if (!CreatePipe(&child.output, &outWrite, &sa, 0)) { CloseHandle(inRead); return false; }
    SetHandleInformation(child.input, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(child.output, HANDLE_FLAG_INHERIT, 0);
    HANDLE errors = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0, nullptr);
    if (errors == INVALID_HANDLE_VALUE) { CloseHandle(inRead); CloseHandle(outWrite); return false; }
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(nullptr, 1, 0, &size);
    std::vector<unsigned char> attributes(size);
    auto list = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributes.data());
    const bool initialized = InitializeProcThreadAttributeList(list, 1, 0, &size) != FALSE;
    bool ok = initialized;
    HANDLE handles[] = {inRead, outWrite, errors};
    if (ok) ok = UpdateProcThreadAttribute(list, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, handles, sizeof(handles), nullptr, nullptr) != FALSE;
    STARTUPINFOEXW startup{};
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = inRead;
    startup.StartupInfo.hStdOutput = outWrite;
    startup.StartupInfo.hStdError = errors;
    startup.lpAttributeList = list;
    PROCESS_INFORMATION process{};
    if (ok) ok = CreateProcessW(nullptr, command.data(), nullptr, nullptr, TRUE,
        CREATE_NO_WINDOW | CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT, nullptr, nullptr, &startup.StartupInfo, &process) != FALSE;
    if (initialized) DeleteProcThreadAttributeList(list);
    CloseHandle(inRead); CloseHandle(outWrite); CloseHandle(errors);
    if (!ok) return false;
    child.process = process.hProcess;
    ok = AssignProcessToJobObject(job.group, process.hProcess) && WaitForSingleObject(job.cancel,0) != WAIT_OBJECT_0;
    if (ok) ok = ResumeThread(process.hThread) != DWORD(-1);
    CloseHandle(process.hThread);
    return ok;
}
bool readOutput(SshJob& job, Child& child, std::string& output, size_t limit, bool line) {
    output.reserve(limit + 4096);
    ULONGLONG deadline = GetTickCount64() + 15000;
    while (GetTickCount64() < deadline && WaitForSingleObject(job.cancel,0) != WAIT_OBJECT_0) {
        DWORD available = 0;
        if (!PeekNamedPipe(child.output, nullptr, 0, nullptr, &available, nullptr)) {
            DWORD code = 1;
            return !line && GetLastError() == ERROR_BROKEN_PIPE && WaitForSingleObject(child.process,100) == WAIT_OBJECT_0 && GetExitCodeProcess(child.process,&code) && code == 0;
        }
        if (available) {
            char buffer[4096]; DWORD read = 0;
            if (!ReadFile(child.output, buffer, std::min<DWORD>(available,sizeof(buffer)), &read,nullptr)) return false;
            output.append(buffer, read); SecureZeroMemory(buffer,sizeof(buffer));
            if (output.size() > limit) return false;
            if (line && output.find('\n') != std::string::npos) return output.find('\n') == output.size()-1;
        } else if (WaitForSingleObject(child.process,0) == WAIT_OBJECT_0) {
            DWORD code = 1; GetExitCodeProcess(child.process,&code);
            return code == 0 && !line;
        } else WaitForSingleObject(job.cancel,20);
    }
    return false;
}
unsigned short localPort() {
    WSADATA data{};
    if (WSAStartup(MAKEWORD(2,2), &data)) return 0;
    SOCKET sock = socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
    sockaddr_in address{}; address.sin_family = AF_INET; address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    BOOL exclusive = TRUE;
    unsigned short port = 0;
    if (sock != INVALID_SOCKET && setsockopt(sock,SOL_SOCKET,SO_EXCLUSIVEADDRUSE,reinterpret_cast<const char*>(&exclusive),sizeof(exclusive)) == 0 &&
        bind(sock,reinterpret_cast<sockaddr*>(&address),sizeof(address)) == 0) {
        int length = sizeof(address);
        if (!getsockname(sock,reinterpret_cast<sockaddr*>(&address),&length)) port = ntohs(address.sin_port);
    }
    if (sock != INVALID_SOCKET) closesocket(sock);
    WSACleanup(); return port;
}
bool pinnedConfig(const std::string& config, std::wstring& arguments, std::string& user) {
    const std::vector<std::string> allowed = {
        "hostname", "user", "port", "identityfile", "certificatefile", "identityagent", "identitiesonly",
        "preferredauthentications", "pubkeyauthentication", "passwordauthentication", "kbdinteractiveauthentication",
        "hostkeyalias", "hostkeyalgorithms", "pubkeyacceptedalgorithms", "userknownhostsfile", "globalknownhostsfile",
        "checkhostip", "verifyhostkeydns", "revokedhostkeys", "fingerprinthash", "ciphers", "macs", "kexalgorithms",
        "bindaddress", "bindinterface", "addressfamily", "compression", "securitykeyprovider", "pkcs11provider",
        "casignaturealgorithms", "requiredrsasize"
    };
    bool host = false, port = false;
    user.clear();
    arguments = L" -F none";
    size_t offset = 0;
    while (offset < config.size()) {
        size_t end = config.find('\n', offset);
        if (end == std::string::npos) end = config.size();
        std::string line = config.substr(offset,end-offset);
        offset = end + 1;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        size_t space = line.find(' ');
        if (space == std::string::npos) continue;
        std::string key = line.substr(0,space), value = line.substr(space+1);
        if (value.find_first_of("\r\n\0",0,3) != std::string::npos) return false;
        if ((key == "proxycommand" || key == "proxyjump" || key == "knownhostscommand") && value != "none") return false;
        if (std::find(allowed.begin(),allowed.end(),key) == allowed.end()) continue;
        if (key == "user") {
            if (value.empty() || value.size() > 128) return false;
            for (unsigned char c : value) if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false;
            user = value;
        }
        if (key == "hostname") host = !value.empty();
        if (key == "port") {
            port = !value.empty() && value.size() <= 5 && value.find_first_not_of("0123456789") == std::string::npos && std::strtoul(value.c_str(),nullptr,10) > 0 && std::strtoul(value.c_str(),nullptr,10) <= 65535;
            if (!port) return false;
        }
        bool paths = key == "userknownhostsfile" || key == "globalknownhostsfile";
        std::string option = key + "=";
        if (paths) {
            size_t begin = 0;
            while (begin < value.size()) {
                size_t stop = value.find(' ',begin); if (stop == std::string::npos) stop = value.size();
                std::string path = value.substr(begin,stop-begin);
                if (path.empty() || (path != "none" && path[0] != '/' && path[0] != '~' && !(path.size() > 2 && path[1] == ':'))) return false;
                if (begin) option += ' ';
                option += '"';
                for (char c : path) { if (c == '\\' || c == '"') option += '\\'; option += c; }
                option += '"';
                begin = stop + 1;
            }
        } else {
            option += '"';
            for (char c : value) { if (c == '\\' || c == '"') option += '\\'; option += c; }
            option += '"';
        }
        arguments += L" -o " + quote(wide(option));
        if (arguments.size() > 24000) return false;
    }
    return host && port && !user.empty();
}
void sshWorker(std::shared_ptr<SshJob> job, std::wstring prefix, std::wstring alias, std::string script,
               unsigned short remotePort, std::array<unsigned char,32> expected) {
    auto fail = [&] { std::lock_guard<std::mutex> lock(job->mutex); job->result.state = -1; SecureZeroMemory(job->result.json,sizeof(job->result.json)); };
    const std::wstring safe = L" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o AddKeysToAgent=no -o ControlMaster=no -o ControlPath=none -o ForwardAgent=no -o ForwardX11=no -o PermitLocalCommand=no -o Tunnel=no -o ConnectTimeout=8 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o LogLevel=QUIET ";
    std::string config;
    unsigned char hash[32];
    {
        Child resolve;
        if (!spawn(*job, prefix + L" -G " + alias, resolve)) { fail(); return; }
        CloseHandle(resolve.input); resolve.input = nullptr;
        if (!readOutput(*job, resolve, config,65536,false) || !digest(config.data(),config.size(),hash)) { wipe(config); fail(); return; }
    }
    std::wstring pinned;
    std::string user;
    if (!pinnedConfig(config,pinned,user)) { wipe(config); fail(); return; }
    wipe(config);
    if (remotePort && memcmp(expected.data(),hash,32)) { fail(); return; }
    unsigned short port = remotePort ? localPort() : 0;
    if (remotePort && !port) { fail(); return; }
    std::wstring forward = remotePort ? L" -o ExitOnForwardFailure=yes -L 127.0.0.1:" + std::to_wstring(port) + L":127.0.0.1:" + std::to_wstring(remotePort) : L" -o ClearAllForwardings=yes";
    std::string body = "__name__='computer'\n" + script + "\ntry:\n r=discover(" + (remotePort ? "True" : "False") + ",'" + user + "')\n print(json.dumps(r,separators=(',',':')),flush=True)\nexcept Exception:\n sys.exit(1)\n";
    body += "r.clear()\n";
    if (remotePort) body += "sys.stdin.buffer.read(1)\n";
    std::string bootstrap = "python3 -u -c \"import sys;exec(compile(sys.stdin.buffer.read(" + std::to_string(body.size()) + "),'<computer>','exec'))\"";
    Child child;
    if (!spawn(*job,prefix + safe + pinned + forward + L" -T " + alias + L" " + quote(wide(bootstrap)),child)) { wipe(body); fail(); return; }
    DWORD written = 0;
    if (!WriteFile(child.input,body.data(),DWORD(body.size()),&written,nullptr) || written != body.size()) { wipe(body); fail(); return; }
    wipe(body);
    if (!remotePort) { CloseHandle(child.input); child.input = nullptr; }
    std::string output;
    if (!readOutput(*job,child,output,4095,remotePort != 0)) { wipe(output); fail(); return; }
    if (output.empty() || output.front() != '{' || output.back() != '\n') { wipe(output); fail(); return; }
    {
        std::lock_guard<std::mutex> lock(job->mutex);
        memcpy(job->result.profile,hash,32);
        memcpy(job->result.json,output.data(),output.size());
        job->result.localPort = port;
        job->result.state = 1;
    }
    wipe(output);
    if (!remotePort) return;
    HANDLE waits[] = {job->cancel,child.process};
    WaitForMultipleObjects(2,waits,FALSE,INFINITE);
    fail();
}
}
extern "C" void* mp_computer_ssh_start(const uint16_t* prefix, size_t prefixLen, const char* alias, size_t aliasLen,
                                      const char* script, size_t scriptLen, unsigned short remotePort, const unsigned char* expected) {
    auto job = std::make_shared<SshJob>();
    if (!job->cancel || !job->group) return nullptr;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job->group,JobObjectExtendedLimitInformation,&limits,sizeof(limits))) return nullptr;
    std::array<unsigned char,32> hash{}; if (expected) memcpy(hash.data(),expected,32);
    auto owner = new SshOwner{job};
    std::thread(sshWorker,job,std::wstring(reinterpret_cast<const wchar_t*>(prefix),prefixLen),wide(std::string(alias,aliasLen)),std::string(script,scriptLen),remotePort,hash).detach();
    return owner;
}
extern "C" int mp_computer_ssh_poll(void* raw, SshResult* result) {
    if (!raw) return -1;
    auto job = static_cast<SshOwner*>(raw)->job;
    std::lock_guard<std::mutex> lock(job->mutex);
    *result = job->result;
    SecureZeroMemory(job->result.json,sizeof(job->result.json));
    return result->state;
}
extern "C" void mp_computer_ssh_close(void* raw) {
    if (!raw) return;
    auto owner = static_cast<SshOwner*>(raw);
    SetEvent(owner->job->cancel);
    TerminateJobObject(owner->job->group,1);
    delete owner;
}

extern "C" int mp_computer_profile_policy_test() {
    const std::string config = "host remote-1\nhostname example.invalid\nuser example\nport 2222\nidentityfile C:/Users/Example Person/.ssh/id_example\nuserknownhostsfile ~/.ssh/known_hosts ~/.ssh/known_hosts2\nhostkeyalias example-key\nlocalforward 0.0.0.0:12345 example.invalid:80\nremoteforward 12346 localhost:80\nlocalcommand unwanted\n";
    std::wstring arguments;
    std::string user;
    if (!pinnedConfig(config,arguments,user) || user != "example") return 1;
    if (arguments.find(L"localforward") != std::wstring::npos || arguments.find(L"remoteforward") != std::wstring::npos || arguments.find(L"unwanted") != std::wstring::npos) return 2;
    if (arguments.find(L"known_hosts") == std::wstring::npos || arguments.find(L"example-key") == std::wstring::npos || arguments.find(L"Example Person") == std::wstring::npos) return 3;
    if (pinnedConfig(config + "proxycommand arbitrary\n",arguments,user)) return 4;
    if (pinnedConfig(config + "proxyjump example-hop\n",arguments,user)) return 5;
    if (pinnedConfig(config + "knownhostscommand arbitrary\n",arguments,user)) return 6;
    if (pinnedConfig("hostname example.invalid\nuser bad'user\nport 22\n",arguments,user)) return 7;
    if (pinnedConfig("hostname example.invalid\nuser example\nport 65536\n",arguments,user)) return 8;
    if (pinnedConfig("hostname example.invalid\nport 22\n",arguments,user)) return 9;
    if (pinnedConfig(config + "userknownhostsfile C:/Users/Example Person/known_hosts\n",arguments,user)) return 10;
    return 0;
}
