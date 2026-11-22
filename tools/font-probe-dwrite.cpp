#include <windows.h>
#include <dwrite.h>

extern "C" int probe_dwrite(HDC dc, const wchar_t *text, unsigned length, float x, float baseline, float em, int cleartype, float *advance) {
    IDWriteFactory *factory = nullptr;
    IDWriteGdiInterop *interop = nullptr;
    IDWriteFontFace *face = nullptr;
    IDWriteBitmapRenderTarget *target = nullptr;
    IDWriteRenderingParams *params = nullptr;
    HRESULT hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_ISOLATED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(&factory));
    if (SUCCEEDED(hr)) hr = factory->GetGdiInterop(&interop);
    if (SUCCEEDED(hr)) hr = interop->CreateFontFaceFromHdc(dc, &face);
    if (SUCCEEDED(hr)) hr = interop->CreateBitmapRenderTarget(dc, 1000, 100, &target);
    if (SUCCEEDED(hr)) hr = factory->CreateCustomRenderingParams(2.2f, 1.0f, cleartype ? 1.0f : 0.0f, DWRITE_PIXEL_GEOMETRY_RGB, DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC, &params);
    UINT32 codepoints[128];
    UINT16 indices[128];
    DWRITE_GLYPH_METRICS metrics[128];
    FLOAT advances[128];
    if (length > 128) hr = E_INVALIDARG;
    for (unsigned i = 0; i < length && i < 128; ++i) codepoints[i] = text[i];
    if (SUCCEEDED(hr)) hr = face->GetGlyphIndices(codepoints, length, indices);
    if (SUCCEEDED(hr)) hr = face->GetDesignGlyphMetrics(indices, length, metrics, FALSE);
    if (SUCCEEDED(hr)) {
        DWRITE_FONT_METRICS fm;
        face->GetMetrics(&fm);
        *advance = 0;
        for (unsigned i = 0; i < length; ++i) {
            advances[i] = metrics[i].advanceWidth * em / fm.designUnitsPerEm;
            *advance += advances[i];
        }
        target->SetPixelsPerDip(1.0f);
        if (!BitBlt(target->GetMemoryDC(), 0, 0, 1000, 100, dc, 0, 0, SRCCOPY)) hr = E_FAIL;
        DWRITE_GLYPH_RUN run = {face, em, length, indices, advances, nullptr, FALSE, 0};
        RECT bounds;
        if (SUCCEEDED(hr)) hr = target->DrawGlyphRun(x, baseline, DWRITE_MEASURING_MODE_NATURAL, &run, params, GetTextColor(dc), &bounds);
        if (SUCCEEDED(hr) && !BitBlt(dc, 0, 0, 1000, 100, target->GetMemoryDC(), 0, 0, SRCCOPY)) hr = E_FAIL;
    }
    if (params) params->Release();
    if (target) target->Release();
    if (face) face->Release();
    if (interop) interop->Release();
    if (factory) factory->Release();
    return static_cast<int>(hr);
}

static BOOL CALLBACK chat_window_dpi(HWND window, LPARAM data) {
    wchar_t name[64];
    if (GetClassNameW(window, name, 64) && lstrcmpW(name, L"ZigShell") == 0) {
        *reinterpret_cast<UINT *>(data) = GetDpiForWindow(window);
        return FALSE;
    }
    return TRUE;
}

extern "C" unsigned probe_chat_dpi() {
    UINT dpi = 0;
    HDESK desktop = OpenDesktopW(L"Default", 0, FALSE, DESKTOP_ENUMERATE | DESKTOP_READOBJECTS);
    if (desktop) {
        EnumDesktopWindows(desktop, chat_window_dpi, reinterpret_cast<LPARAM>(&dpi));
        CloseDesktop(desktop);
    }
    return dpi;
}
