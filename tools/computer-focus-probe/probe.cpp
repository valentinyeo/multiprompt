#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <windows.h>
#include <bcrypt.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

extern "C" int mp_computer_create(HWND);
extern "C" int mp_computer_ready();
extern "C" void mp_computer_present(int, int, int, int, int);
extern "C" void mp_computer_fallback(uint64_t, const char*, size_t);
extern "C" void mp_computer_focus();
extern "C" int mp_computer_has_input_focus();

namespace {
HWND mainWindow = nullptr;
HWND composer = nullptr;
bool ready = false;
bool controlling = false;
int takes = 0;
int lostFocusRevokes = 0;
int giveRevokes = 0;
std::vector<unsigned char> loaderBytes;
std::string loaderHash;
const char page[] = "<!doctype html><html><head><meta charset=\"utf-8\"></head><body style=\"margin:0;background:#222\"><button id=\"control\" style=\"position:absolute;left:40px;top:40px;width:240px;height:80px\">Take control</button><script src=\"probe.js\"></script></body></html>";
const char script[] = "const token = location.pathname.split('/')[1];\n"
    "const post = (owner, event) => window.chrome.webview.postMessage(`${token}|${owner}|${event}`);\n"
    "document.querySelector('#control').addEventListener('click', event => { if (event.isTrusted) post('1', 'take'); });\n"
    "window.addEventListener('blur', () => post('1', 'give'));\n"
    "post('0', 'ready');\n";

std::string name(HWND hwnd) {
    if (!hwnd) return "null";
    char text[128] = {};
    GetClassNameA(hwnd, text, sizeof(text));
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    char out[200];
    snprintf(out, sizeof(out), "%s%s", text, pid == GetCurrentProcessId() ? "" : "(other process)");
    return out;
}

void note(const char* what) {
    printf("%8lu %-28s controlling=%d focus=%s input_focus=%d\n", GetTickCount() % 100000000, what, controlling ? 1 : 0, name(GetFocus()).c_str(), mp_computer_has_input_focus());
    fflush(stdout);
}

LRESULT CALLBACK watch(int code, WPARAM wp, LPARAM lp) {
    if (code == HC_ACTION) {
        auto* message = reinterpret_cast<CWPSTRUCT*>(lp);
        if (message->message == WM_SETFOCUS || message->message == WM_KILLFOCUS) {
            std::string text = (message->message == WM_SETFOCUS ? "WM_SETFOCUS " : "WM_KILLFOCUS ") + name(message->hwnd);
            note(text.c_str());
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

LRESULT CALLBACK mainProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_SETFOCUS) {
        if (controlling) return DefWindowProcW(hwnd, msg, wp, lp);
        SetFocus(composer);
        return 0;
    }
    if (msg == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

void pump(DWORD milliseconds) {
    DWORD end = GetTickCount() + milliseconds;
    while (GetTickCount() < end) {
        MSG msg;
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); }
        MsgWaitForMultipleObjects(0, nullptr, FALSE, 10, QS_ALLINPUT);
    }
}

void click(int x, int y) {
    POINT point{x, y};
    ClientToScreen(mainWindow, &point);
    SetCursorPos(point.x, point.y);
    INPUT input[2] = {};
    input[0].type = INPUT_MOUSE; input[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    input[1].type = INPUT_MOUSE; input[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(1, &input[0], sizeof(INPUT));
    pump(80);
    SendInput(1, &input[1], sizeof(INPUT));
}

bool readLoader(const wchar_t* path) {
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    LARGE_INTEGER size{};
    GetFileSizeEx(file, &size);
    loaderBytes.resize(size_t(size.QuadPart));
    DWORD read = 0;
    bool ok = ReadFile(file, loaderBytes.data(), DWORD(loaderBytes.size()), &read, nullptr) && read == loaderBytes.size();
    CloseHandle(file);
    unsigned char hash[32];
    BCRYPT_ALG_HANDLE alg = nullptr;
    if (!ok || BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0) return false;
    ok = BCryptHash(alg, nullptr, 0, loaderBytes.data(), ULONG(loaderBytes.size()), hash, 32) >= 0;
    BCryptCloseAlgorithmProvider(alg, 0);
    const char* digits = "0123456789abcdef";
    for (unsigned char byte : hash) { loaderHash += digits[byte >> 4]; loaderHash += digits[byte & 15]; }
    return ok;
}
}

extern "C" const unsigned char* mp_computer_asset(const char* file, size_t length, size_t* size) {
    std::string wanted(file, length);
    if (wanted == "index.html") { *size = sizeof(page) - 1; return reinterpret_cast<const unsigned char*>(page); }
    if (wanted == "probe.js") { *size = sizeof(script) - 1; return reinterpret_cast<const unsigned char*>(script); }
    *size = 0;
    return nullptr;
}

extern "C" const unsigned char* mp_computer_loader(size_t* size, const char** expected) {
    *size = loaderBytes.size();
    *expected = loaderHash.c_str();
    return loaderBytes.data();
}

extern "C" void mp_computer_event(uint64_t generation, unsigned event) {
    char text[64];
    snprintf(text, sizeof(text), "event %u generation %llu", event, static_cast<unsigned long long>(generation));
    note(text);
    if (event == 1) ready = true;
    if (event == 5 && !controlling) { controlling = true; ++takes; note("take granted"); mp_computer_focus(); note("after MoveFocus"); }
    if (event == 9 && controlling) { controlling = false; ++lostFocusRevokes; note("revoked by LostFocus"); }
    if (event == 6 && controlling) { controlling = false; ++giveRevokes; note("revoked by page blur"); }
}

int wmain(int argc, wchar_t** argv) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    if (argc < 2 || !readLoader(argv[1])) { printf("loader unreadable\n"); return 2; }
    WNDCLASSW cls{};
    cls.lpfnWndProc = mainProc; cls.hInstance = GetModuleHandleW(nullptr); cls.lpszClassName = L"ComputerFocusProbe";
    cls.hCursor = LoadCursorW(nullptr, reinterpret_cast<LPCWSTR>(IDC_ARROW));
    RegisterClassW(&cls);
    mainWindow = CreateWindowExW(0, cls.lpszClassName, L"Computer focus probe", WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN, 40, 40, 1100, 820, nullptr, nullptr, cls.hInstance, nullptr);
    composer = CreateWindowExW(0, L"EDIT", L"", WS_CHILD | WS_VISIBLE | WS_BORDER, 0, 660, 1000, 60, mainWindow, nullptr, cls.hInstance, nullptr);
    SetWindowsHookExW(WH_CALLWNDPROC, watch, nullptr, GetCurrentThreadId());
    ShowWindow(mainWindow, SW_SHOWNORMAL);
    SetForegroundWindow(mainWindow);
    SetFocus(composer);
    if (mp_computer_create(mainWindow) < 0) { printf("viewer could not start\n"); return 2; }
    mp_computer_fallback(1, "probe", 5);
    mp_computer_present(0, 0, 1000, 600, 1);
    DWORD deadline = GetTickCount() + 60000;
    while (!ready && GetTickCount() < deadline) pump(50);
    if (!ready) { printf("page never became ready\n"); return 2; }
    pump(1500);
    SetForegroundWindow(mainWindow);
    pump(300);
    note("before click");
    click(160, 80);
    pump(2000);
    note("after click");
    click(600, 400);
    pump(1500);
    note("after second click in page");
    printf("RESULT takes=%d lostfocus_revokes=%d blur_revokes=%d controlling=%d input_focus=%d\n", takes, lostFocusRevokes, giveRevokes, controlling ? 1 : 0, mp_computer_has_input_focus());
    fflush(stdout);
    return takes == 1 && controlling && lostFocusRevokes == 0 && giveRevokes == 0 ? 0 : 1;
}
