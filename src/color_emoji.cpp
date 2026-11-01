#include <windows.h>
#include <d2d1.h>
#include <dwrite.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>
#include <cmath>

using PlainDraw = int (*)(HDC, const wchar_t *, int, RECT *, unsigned);

static unsigned scalar(const wchar_t *text, unsigned length, unsigned &at) {
    unsigned cp = text[at++];
    if (cp >= 0xd800 && cp <= 0xdbff && at < length && text[at] >= 0xdc00 && text[at] <= 0xdfff)
        cp = 0x10000 + ((cp - 0xd800) << 10) + (text[at++] - 0xdc00);
    return cp;
}

static bool emoji(unsigned cp) {
    return (cp >= 0x1f000 && cp <= 0x1faff) || (cp >= 0x2600 && cp <= 0x27bf) ||
        cp == 0xa9 || cp == 0xae || cp == 0x203c || cp == 0x2049 || cp == 0x2122 || cp == 0x2139 ||
        (cp >= 0x2194 && cp <= 0x2199) || cp == 0x21a9 || cp == 0x21aa ||
        cp == 0x231a || cp == 0x231b || cp == 0x2328 || cp == 0x23cf ||
        (cp >= 0x23e9 && cp <= 0x23f3) || (cp >= 0x23f8 && cp <= 0x23fa) ||
        cp == 0x24c2 || cp == 0x25aa || cp == 0x25ab || cp == 0x25b6 || cp == 0x25c0 || (cp >= 0x25fb && cp <= 0x25fe) ||
        cp == 0x2934 || cp == 0x2935 || (cp >= 0x2b05 && cp <= 0x2b07) || cp == 0x2b1b || cp == 0x2b1c ||
        cp == 0x2b50 || cp == 0x2b55 || cp == 0x3030 || cp == 0x303d || cp == 0x3297 || cp == 0x3299;
}

static unsigned clusterEnd(const wchar_t *text, unsigned length, unsigned begin) {
    unsigned at = begin;
    const unsigned first = scalar(text, length, at);
    if (!emoji(first)) {
        if (!(first == '#' || first == '*' || (first >= '0' && first <= '9'))) return begin;
        if (at < length && text[at] == 0xfe0f) ++at;
        return at < length && text[at] == 0x20e3 ? at + 1 : begin;
    }
    bool regional = first >= 0x1f1e6 && first <= 0x1f1ff;
    while (at < length) {
        unsigned next = at;
        const unsigned cp = scalar(text, length, next);
        if (cp == 0xfe0f || cp == 0xfe0e || (cp >= 0x1f3fb && cp <= 0x1f3ff) || (cp >= 0xe0020 && cp <= 0xe007f)) at = next;
        else if (regional && cp >= 0x1f1e6 && cp <= 0x1f1ff) { at = next; regional = false; }
        else if (cp == 0x200d && next < length) { scalar(text, length, next); at = next; }
        else break;
    }
    return at;
}

struct Painter {
    struct Entry {
        wchar_t *text = nullptr;
        unsigned length = 0;
        int width = 0, height = 0;
        float em = 0;
        COLORREF ink = 0;
        HDC dc = nullptr;
        HBITMAP bitmap = nullptr;
        HGDIOBJ previous = nullptr;
        void clear() {
            if (dc && previous) SelectObject(dc, previous);
            if (bitmap) DeleteObject(bitmap);
            if (dc) DeleteDC(dc);
            if (text) HeapFree(GetProcessHeap(), 0, text);
            text = nullptr; bitmap = nullptr; dc = nullptr; previous = nullptr;
        }
    } entries[128];
    unsigned next = 0;
    ID2D1Factory *factory = nullptr;
    IDWriteFactory *write = nullptr;
    ID2D1DCRenderTarget *target = nullptr;
    IDWriteTextFormat *format = nullptr;
    ID2D1SolidColorBrush *brush = nullptr;
    float size = 0;

    ~Painter() {
        for (auto &entry : entries) entry.clear();
        reset();
        if (write) write->Release();
        if (factory) factory->Release();
    }
    void reset() {
        if (brush) brush->Release();
        if (target) target->Release();
        if (format) format->Release();
        brush = nullptr; target = nullptr; format = nullptr; size = 0;
    }
    bool ready(float em) {
        if (!factory && FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory))) return false;
        if (!write && FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(&write)))) return false;
        if (!target) {
            const auto properties = D2D1::RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_SOFTWARE,
                D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED), 96, 96);
            if (FAILED(factory->CreateDCRenderTarget(&properties, &target))) return false;
            target->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
            if (FAILED(target->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::White), &brush))) { reset(); return false; }
        }
        if (!format || size != em) {
            if (format) format->Release();
            format = nullptr;
            if (FAILED(write->CreateTextFormat(L"Segoe UI Emoji", nullptr, DWRITE_FONT_WEIGHT_NORMAL,
                DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, em, L"en-us", &format))) return false;
            format->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
            format->SetTextAlignment(DWRITE_TEXT_ALIGNMENT_CENTER);
            format->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
            size = em;
        }
        return true;
    }
    bool draw(HDC dc, const wchar_t *text, unsigned length, RECT bounds, float em) {
        RECT clip, visible;
        if (GetClipBox(dc, &clip) == ERROR) return false;
        if (!IntersectRect(&visible, &bounds, &clip)) return true;
        const int width = bounds.right - bounds.left, height = bounds.bottom - bounds.top;
        const COLORREF ink = GetTextColor(dc);
        Entry *cached = nullptr;
        for (auto &entry : entries) {
            if (entry.text && entry.length == length && entry.width == width && entry.height == height &&
                entry.em == em && entry.ink == ink && !memcmp(entry.text, text, length * sizeof(wchar_t))) {
                cached = &entry;
                break;
            }
        }
        if (!cached) {
            if (!ready(em)) return false;
            Entry &entry = entries[next++ % 128];
            entry.clear();
            entry.text = static_cast<wchar_t *>(HeapAlloc(GetProcessHeap(), 0, length * sizeof(wchar_t)));
            entry.dc = CreateCompatibleDC(dc);
            BITMAPINFO info = {};
            info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            info.bmiHeader.biWidth = width;
            info.bmiHeader.biHeight = -height;
            info.bmiHeader.biPlanes = 1;
            info.bmiHeader.biBitCount = 32;
            info.bmiHeader.biCompression = BI_RGB;
            void *pixels = nullptr;
            entry.bitmap = CreateDIBSection(dc, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
            if (!entry.text || !entry.dc || !entry.bitmap || !pixels) { entry.clear(); return false; }
            CopyMemory(entry.text, text, length * sizeof(wchar_t));
            entry.length = length; entry.width = width; entry.height = height; entry.em = em; entry.ink = ink;
            entry.previous = SelectObject(entry.dc, entry.bitmap);
            if (!entry.previous || entry.previous == HGDI_ERROR) { entry.previous = nullptr; entry.clear(); return false; }
            ZeroMemory(pixels, width * height * 4);
            RECT cell = {0, 0, width, height};
            if (FAILED(target->BindDC(entry.dc, &cell))) { entry.clear(); return false; }
            wchar_t symbol[3];
            if (length == 1 && (text[0] == 0x2713 || text[0] == 0x2717)) {
                symbol[0] = text[0] == 0x2713 ? 0x2705 : 0x274c;
                symbol[1] = 0xfe0f; text = symbol; length = 2;
            } else if (length <= 2) {
                unsigned at = 0;
                if (emoji(scalar(text, length, at)) && at == length) {
                    CopyMemory(symbol, text, length * sizeof(wchar_t));
                    symbol[length++] = 0xfe0f; text = symbol;
                }
            }
            IDWriteTextLayout *layout = nullptr;
            if (FAILED(write->CreateTextLayout(text, length, format, float(width), float(height), &layout))) { entry.clear(); return false; }
            DWRITE_TEXT_METRICS metrics;
            if (SUCCEEDED(layout->GetMetrics(&metrics)) && metrics.widthIncludingTrailingWhitespace > width)
                layout->SetFontSize(em * width / metrics.widthIncludingTrailingWhitespace, {0, length});
            brush->SetColor(D2D1::ColorF(GetRValue(ink) / 255.0f, GetGValue(ink) / 255.0f, GetBValue(ink) / 255.0f));
            target->BeginDraw();
            target->Clear(D2D1::ColorF(0, 0, 0, 0));
            target->DrawTextLayout(D2D1::Point2F(0, 0), layout, brush,
                static_cast<D2D1_DRAW_TEXT_OPTIONS>(D2D1_DRAW_TEXT_OPTIONS_CLIP | D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT));
            const HRESULT result = target->EndDraw();
            layout->Release();
            if (FAILED(result)) { entry.clear(); reset(); return false; }
            cached = &entry;
        }
        const BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
        return AlphaBlend(dc, bounds.left, bounds.top, width, height, cached->dc, 0, 0, width, height, blend) != 0;
    }
};

using PositionedPlain = int (*)(void *, HDC, const unsigned char *);

extern "C" int mp_draw_color_positioned(HDC dc, const wchar_t *text, unsigned length, const float *advances,
    int x, int y, const RECT *clip, unsigned long color, PositionedPlain plain, void *context) {
    if (!text || !advances || !clip || !plain || !context || !dc) return -1;
    bool found = false;
    for (unsigned at = 0; at < length;) {
        unsigned end = clusterEnd(text, length, at);
        if (end != at) { found = true; break; }
        scalar(text, length, at);
    }
    if (!found) return 0;
    if (GetMapMode(dc) != MM_TEXT || length > INT_MAX || clip->left == INT_MIN || clip->top == INT_MIN) return -1;
    const long long width64 = static_cast<long long>(clip->right) - clip->left;
    const long long height64 = static_cast<long long>(clip->bottom) - clip->top;
    if (width64 <= 0 || height64 <= 0 || width64 > INT_MAX || height64 > INT_MAX ||
        static_cast<long long>(x) - clip->left < INT_MIN || static_cast<long long>(x) - clip->left > INT_MAX ||
        static_cast<long long>(y) - clip->top < INT_MIN || static_cast<long long>(y) - clip->top > INT_MAX) return -1;
    const int width = static_cast<int>(width64), height = static_cast<int>(height64);
    TEXTMETRICW metrics;
    if (!GetTextMetricsW(dc, &metrics) || metrics.tmHeight <= 0 || metrics.tmInternalLeading < 0 || metrics.tmHeight <= metrics.tmInternalLeading ||
        static_cast<long long>(y) + metrics.tmHeight > INT_MAX ||
        static_cast<long long>(y) - clip->top + metrics.tmAscent > INT_MAX ||
        static_cast<long long>(y) - clip->top + metrics.tmAscent < INT_MIN) return -1;
    struct Resources {
        unsigned char *mask = nullptr;
        double *positions = nullptr;
        HDC dc = nullptr;
        HBITMAP bitmap = nullptr;
        HGDIOBJ old_bitmap = nullptr;
        HGDIOBJ old_font = nullptr;
        ~Resources() {
            if (dc && old_font && old_font != HGDI_ERROR) SelectObject(dc, old_font);
            if (dc && old_bitmap && old_bitmap != HGDI_ERROR) SelectObject(dc, old_bitmap);
            if (bitmap) DeleteObject(bitmap);
            if (dc) DeleteDC(dc);
            if (mask) HeapFree(GetProcessHeap(), 0, mask);
            if (positions) HeapFree(GetProcessHeap(), 0, positions);
        }
    } r;
    if (static_cast<size_t>(length) + 1 > SIZE_MAX / sizeof(double)) return -1;
    r.mask = static_cast<unsigned char *>(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, length));
    r.positions = static_cast<double *>(HeapAlloc(GetProcessHeap(), 0, (static_cast<size_t>(length) + 1) * sizeof(double)));
    if (!r.mask || !r.positions) return -1;
    r.positions[0] = 0;
    for (unsigned i = 0; i < length; ++i) {
        if (!std::isfinite(advances[i]) || std::floor(advances[i]) != advances[i]) return -1;
        r.positions[i + 1] = r.positions[i] + advances[i];
        if (!std::isfinite(r.positions[i + 1]) || std::abs(r.positions[i + 1]) > 16777216 ||
            r.positions[i + 1] + x < INT_MIN || r.positions[i + 1] + x > INT_MAX) return -1;
    }
    for (unsigned at = 0; at < length;) {
        const unsigned end = clusterEnd(text, length, at);
        if (end == at) { scalar(text, length, at); continue; }
        if (at > 0 && !r.mask[at - 1]) {
            const wchar_t previous = text[at - 1];
            if (previous == 0x200d || previous == 0xfe0e || previous == 0xfe0f || (previous >= 0xd800 && previous <= 0xdbff)) return -1;
            if (previous < 0xdc00 || previous > 0xdfff) {
                WORD type = 0;
                if (!GetStringTypeW(CT_CTYPE3, text + at - 1, 1, &type) ||
                    (type & (C3_NONSPACING | C3_DIACRITIC | C3_VOWELMARK))) return -1;
            }
        }
        if (end < length) {
            const wchar_t next = text[end];
            if (next == 0x200d || next == 0xfe0e || next == 0xfe0f || (next >= 0xdc00 && next <= 0xdfff)) return -1;
            if (next < 0xd800 || next > 0xdbff) {
                WORD type = 0;
                if (!GetStringTypeW(CT_CTYPE3, text + end, 1, &type) ||
                    (type & (C3_NONSPACING | C3_DIACRITIC | C3_VOWELMARK))) return -1;
            }
        }
        memset(r.mask + at, 1, end - at);
        const double left = r.positions[at] + x, right = r.positions[end] + x;
        if (left == right || std::floor(left) != left || std::floor(right) != right ||
            std::abs(right - left) > INT_MAX || std::abs(right - left) * metrics.tmHeight > INT_MAX / 4) return -1;
        at = end;
    }
    r.dc = CreateCompatibleDC(dc);
    if (!r.dc) return -1;
    r.bitmap = CreateCompatibleBitmap(dc, width, height);
    if (!r.bitmap) return -1;
    r.old_bitmap = SelectObject(r.dc, r.bitmap);
    if (!r.old_bitmap || r.old_bitmap == HGDI_ERROR) return -1;
    HGDIOBJ font = GetCurrentObject(dc, OBJ_FONT);
    if (!font) return -1;
    r.old_font = SelectObject(r.dc, font);
    if (!r.old_font || r.old_font == HGDI_ERROR) return -1;
    if (!BitBlt(r.dc, 0, 0, width, height, dc, clip->left, clip->top, SRCCOPY)) return -1;
    if (!SetViewportOrgEx(r.dc, -clip->left, -clip->top, nullptr) ||
        IntersectClipRect(r.dc, clip->left, clip->top, clip->right, clip->bottom) == ERROR ||
        SetTextColor(r.dc, color) == CLR_INVALID) return -1;
    if (!plain(context, r.dc, r.mask)) return -1;
    static thread_local Painter painter;
    for (unsigned at = 0; at < length;) {
        const unsigned end = clusterEnd(text, length, at);
        if (end == at) { scalar(text, length, at); continue; }
        const int a = static_cast<int>(r.positions[at] + x), b = static_cast<int>(r.positions[end] + x);
        RECT cell = {a < b ? a : b, y, a < b ? b : a, y + metrics.tmHeight};
        if (!painter.draw(r.dc, text + at, end - at, cell, float(metrics.tmHeight - metrics.tmInternalLeading))) return -1;
        at = end;
    }
    if (!BitBlt(dc, clip->left, clip->top, width, height, r.dc, clip->left, clip->top, SRCCOPY)) return -1;
    return 1;
}

extern "C" int mp_draw_color_text(HDC dc, const wchar_t *input, unsigned length, RECT *rect, unsigned flags, PlainDraw plain) {
    const unsigned supported = DT_SINGLELINE | DT_NOPREFIX | DT_VCENTER | DT_CENTER | DT_RIGHT | DT_END_ELLIPSIS;
    if ((flags & ~supported) || !(flags & DT_SINGLELINE) || !(flags & DT_NOPREFIX) || GetMapMode(dc) != MM_TEXT) return 0;
    bool found = false;
    for (unsigned at = 0; at < length;) {
        if (clusterEnd(input, length, at) != at) { found = true; break; }
        scalar(input, length, at);
    }
    if (!found) return 0;
    TEXTMETRICW metrics;
    if (!GetTextMetricsW(dc, &metrics)) return 0;
    const int width = rect->right - rect->left;
    const int height = rect->bottom - rect->top;
    if (width <= 0 || height <= 0) return metrics.tmHeight;
    auto text = input;
    wchar_t *shortened = nullptr;
    SIZE extent;
    if (!GetTextExtentPoint32W(dc, text, length, &extent)) return 0;
    if ((flags & DT_END_ELLIPSIS) && extent.cx > width) {
        shortened = static_cast<wchar_t *>(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (length + 5) * sizeof(wchar_t)));
        if (!shortened) return 0;
        CopyMemory(shortened, text, length * sizeof(wchar_t));
        SIZE dots;
        GetTextExtentPoint32W(dc, L"...", 3, &dots);
        unsigned kept = 0;
        for (unsigned at = 0; at < length;) {
            unsigned end = clusterEnd(input, length, at);
            if (end == at) { end = at; scalar(input, length, end); }
            SIZE prefix;
            if (!GetTextExtentPoint32W(dc, input, end, &prefix) || prefix.cx + dots.cx > width) break;
            kept = end; at = end;
        }
        CopyMemory(shortened + kept, L"...", 4 * sizeof(wchar_t));
        text = shortened;
        length = kept + 3;
        GetTextExtentPoint32W(dc, text, length, &extent);
    }
    auto positions = static_cast<int *>(HeapAlloc(GetProcessHeap(), 0, length * sizeof(int)));
    int fit = 0;
    if (!positions || !GetTextExtentExPointW(dc, text, length, INT_MAX, &fit, positions, &extent)) {
        if (positions) HeapFree(GetProcessHeap(), 0, positions);
        if (shortened) HeapFree(GetProcessHeap(), 0, shortened);
        return 0;
    }
    const int x = rect->left + ((flags & DT_RIGHT) ? width - extent.cx : (flags & DT_CENTER) ? (width - extent.cx) / 2 : 0);
    const int y = rect->top + ((flags & DT_VCENTER) ? (height - metrics.tmHeight) / 2 : 0);
    static thread_local Painter painter;
    unsigned begin = 0;
    int left = x;
    while (begin < length) {
        unsigned end = clusterEnd(text, length, begin);
        const bool colored = end != begin;
        if (!colored) {
            end = begin;
            do { scalar(text, length, end); } while (end < length && clusterEnd(text, length, end) == end);
        }
        const int right = x + positions[end - 1];
        RECT cell = {left, y, right, y + metrics.tmHeight};
        const int saved = SaveDC(dc);
        IntersectClipRect(dc, rect->left, rect->top, rect->right, rect->bottom);
        if (!colored || !painter.draw(dc, text + begin, end - begin, cell, float(metrics.tmHeight - metrics.tmInternalLeading)))
            plain(dc, text + begin, end - begin, &cell, DT_SINGLELINE | DT_NOPREFIX);
        RestoreDC(dc, saved);
        left = right;
        begin = end;
    }
    HeapFree(GetProcessHeap(), 0, positions);
    if (shortened) HeapFree(GetProcessHeap(), 0, shortened);
    return metrics.tmHeight;
}
