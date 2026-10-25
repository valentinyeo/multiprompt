const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const duplex = @import("voice_duplex.zig");
const voice_filter = @import("voice_filter.zig");
const crash_recorder = @import("crash_recorder.zig");
const DWORD = @import("win32.zig").DWORD;
const LPCWSTR = @import("win32.zig").LPCWSTR;
const WM_APP_DICTATION_READY = @import("win32.zig").WM_APP_DICTATION_READY;
const WM_APP_VOICE_TTS_FALLBACK = @import("win32.zig").WM_APP_VOICE_TTS_FALLBACK;
const WM_APP_VOICE_UTTERANCE_READY = @import("win32.zig").WM_APP_VOICE_UTTERANCE_READY;
const WM_APP_VOICE_MIC_STATUS = @import("win32.zig").WM_APP_VOICE_MIC_STATUS;
const WM_APP_VOICE_TTS_AUDIO_STARTED = @import("win32.zig").WM_APP_VOICE_TTS_AUDIO_STARTED;
const TIMER_CAP_MSG = @import("win32.zig").TIMER_CAP_MSG;
const TIMER_CHAT_REFRESH = @import("win32.zig").TIMER_CHAT_REFRESH;
const TIMER_VOICE_POLL = @import("win32.zig").TIMER_VOICE_POLL;
const TIMER_VOICE_TURN_END = @import("win32.zig").TIMER_VOICE_TURN_END;
const TIMER_VOICE_TTS_POS = @import("win32.zig").TIMER_VOICE_TTS_POS;
const RECT = @import("win32.zig").RECT;
const HKEY_CURRENT_USER = @import("win32.zig").HKEY_CURRENT_USER;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetWindowTextW = @import("win32.zig").GetWindowTextW;
const GetWindowTextLengthW = @import("win32.zig").GetWindowTextLengthW;
const SetWindowTextW = @import("win32.zig").SetWindowTextW;
const Sleep = @import("win32.zig").Sleep;
const CloseHandle = @import("win32.zig").CloseHandle;
const RegGetValueW = @import("win32.zig").RegGetValueW;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const AttachConsole = @import("win32.zig").AttachConsole;
const FreeConsole = @import("win32.zig").FreeConsole;
const GetConsoleScreenBufferInfo = @import("win32.zig").GetConsoleScreenBufferInfo;
const MultiByteToWideChar = @import("win32.zig").MultiByteToWideChar;
const WideCharToMultiByte = @import("win32.zig").WideCharToMultiByte;
const CreateEventW = @import("win32.zig").CreateEventW;
const CP_UTF8 = @import("win32.zig").CP_UTF8;
const INTERNET_DEFAULT_HTTPS_PORT = @import("win32.zig").INTERNET_DEFAULT_HTTPS_PORT;
const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = @import("win32.zig").WINHTTP_ACCESS_TYPE_DEFAULT_PROXY;
const WINHTTP_FLAG_SECURE = @import("win32.zig").WINHTTP_FLAG_SECURE;
const WINHTTP_ADDREQ_FLAG_ADD = @import("win32.zig").WINHTTP_ADDREQ_FLAG_ADD;
const WINHTTP_QUERY_STATUS_CODE = @import("win32.zig").WINHTTP_QUERY_STATUS_CODE;
const WINHTTP_QUERY_FLAG_NUMBER = @import("win32.zig").WINHTTP_QUERY_FLAG_NUMBER;
const WinHttpOpen = @import("win32.zig").WinHttpOpen;
const WinHttpConnect = @import("win32.zig").WinHttpConnect;
const WinHttpOpenRequest = @import("win32.zig").WinHttpOpenRequest;
const WinHttpAddRequestHeaders = @import("win32.zig").WinHttpAddRequestHeaders;
const WinHttpSendRequest = @import("win32.zig").WinHttpSendRequest;
const WinHttpReceiveResponse = @import("win32.zig").WinHttpReceiveResponse;
const WinHttpQueryHeaders = @import("win32.zig").WinHttpQueryHeaders;
const WinHttpQueryDataAvailable = @import("win32.zig").WinHttpQueryDataAvailable;
const WinHttpReadData = @import("win32.zig").WinHttpReadData;
const WinHttpSetTimeouts = @import("win32.zig").WinHttpSetTimeouts;
const WinHttpCloseHandle = @import("win32.zig").WinHttpCloseHandle;
const HWAVEIN = @import("win32.zig").HWAVEIN;
const WAVE_MAPPER = @import("win32.zig").WAVE_MAPPER;
const WAVE_FORMAT_PCM = @import("win32.zig").WAVE_FORMAT_PCM;
const CALLBACK_EVENT = @import("win32.zig").CALLBACK_EVENT;
const WHDR_DONE = @import("win32.zig").WHDR_DONE;
const WAVEFORMATEX = @import("win32.zig").WAVEFORMATEX;
const WAVEHDR = @import("win32.zig").WAVEHDR;
const waveInOpen = @import("win32.zig").waveInOpen;
const waveInPrepareHeader = @import("win32.zig").waveInPrepareHeader;
const waveInUnprepareHeader = @import("win32.zig").waveInUnprepareHeader;
const waveInAddBuffer = @import("win32.zig").waveInAddBuffer;
const waveInStart = @import("win32.zig").waveInStart;
const waveInStop = @import("win32.zig").waveInStop;
const waveInReset = @import("win32.zig").waveInReset;
const waveInClose = @import("win32.zig").waveInClose;
const HWAVEOUT = @import("win32.zig").HWAVEOUT;
const waveOutOpen = @import("win32.zig").waveOutOpen;
const waveOutPrepareHeader = @import("win32.zig").waveOutPrepareHeader;
const waveOutUnprepareHeader = @import("win32.zig").waveOutUnprepareHeader;
const waveOutWrite = @import("win32.zig").waveOutWrite;
const waveOutReset = @import("win32.zig").waveOutReset;
const waveOutClose = @import("win32.zig").waveOutClose;
const WaitForSingleObject = @import("win32.zig").WaitForSingleObject;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const COORD = @import("win32.zig").COORD;
const CONSOLE_SCREEN_BUFFER_INFO = @import("win32.zig").CONSOLE_SCREEN_BUFFER_INFO;
const SendMessageW = @import("win32.zig").SendMessageW;
const L = @import("startup.zig").L;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetFocus = @import("focus.zig").SetFocus;
const isCtrlDown = @import("focus.zig").isCtrlDown;
const win32OpenAppend = @import("file_io.zig").win32OpenAppend;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const debugLog = @import("diagnostics.zig").debugLog;
const writeAuditU64 = @import("diagnostics.zig").writeAuditU64;
const S_OK = @import("win32.zig").S_OK;
const CLSCTX_INPROC_SERVER = @import("win32.zig").CLSCTX_INPROC_SERVER;
const COINIT_APARTMENTTHREADED = @import("win32.zig").COINIT_APARTMENTTHREADED;
const IUnknown = @import("win32.zig").IUnknown;
const CoInitializeEx = @import("win32.zig").CoInitializeEx;
const CoUninitialize = @import("win32.zig").CoUninitialize;
const CLSID_MMDeviceEnumerator = @import("win32.zig").CLSID_MMDeviceEnumerator;
const IID_IMMDeviceEnumerator = @import("win32.zig").IID_IMMDeviceEnumerator;
const IID_IAudioSessionManager = @import("win32.zig").IID_IAudioSessionManager;
const IID_IAudioSessionControl2 = @import("win32.zig").IID_IAudioSessionControl2;
const IMMDeviceEnumerator = @import("win32.zig").IMMDeviceEnumerator;
const IMMDevice = @import("win32.zig").IMMDevice;
const IAudioSessionManager = @import("win32.zig").IAudioSessionManager;
const IAudioSessionControl2 = @import("win32.zig").IAudioSessionControl2;
const CoCreateInstance = @import("win32.zig").CoCreateInstance;
const CLSID_SpVoice = @import("win32.zig").CLSID_SpVoice;
const IID_ISpVoice = @import("win32.zig").IID_ISpVoice;
const SPF_ASYNC = @import("win32.zig").SPF_ASYNC;
const SPF_PURGEBEFORESPEAK = @import("win32.zig").SPF_PURGEBEFORESPEAK;
const SPF_IS_NOT_XML = @import("win32.zig").SPF_IS_NOT_XML;
const SPRS_DONE = @import("win32.zig").SPRS_DONE;
const SPVOICESTATUS = @import("win32.zig").SPVOICESTATUS;
const DEEPGRAM_TTS_MODEL = @import("app_state.zig").DEEPGRAM_TTS_MODEL;
const DEEPGRAM_TTS_SAMPLE_RATE = @import("app_state.zig").DEEPGRAM_TTS_SAMPLE_RATE;
const VoiceSpeed = @import("app_state.zig").VoiceSpeed;
const DEEPGRAM_TTS_CHAR_LIMIT = @import("app_state.zig").DEEPGRAM_TTS_CHAR_LIMIT;
const DEEPGRAM_TTS_MAX_CHUNKS = @import("app_state.zig").DEEPGRAM_TTS_MAX_CHUNKS;
const DEEPGRAM_TTS_MAX_PCM_BYTES = @import("app_state.zig").DEEPGRAM_TTS_MAX_PCM_BYTES;
const VOICE_TTS_SLICE_BYTES = @import("app_state.zig").VOICE_TTS_SLICE_BYTES;
const VOICE_TTS_READ_BYTES = @import("app_state.zig").VOICE_TTS_READ_BYTES;
const VoiceTtsBuffer = @import("app_state.zig").VoiceTtsBuffer;
const TtsChunkRange = @import("app_state.zig").TtsChunkRange;
const comRelease = @import("workspaces.zig").comRelease;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const keybd_event = @import("win32.zig").keybd_event;
const focusActiveBrowserPane = @import("focus.zig").focusActiveBrowserPane;
const activeBrowserHwndLive = @import("browser_pane.zig").activeBrowserHwndLive;
const activeBrowserSurfaceHasForegroundFocus = @import("browser_pane.zig").activeBrowserSurfaceHasForegroundFocus;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const chatBlockDisplayRange = @import("chat_capture.zig").chatBlockDisplayRange;
const voiceRefreshTranscriptCache = @import("chat_session.zig").voiceRefreshTranscriptCache;
const chatLatestAgentReply = @import("chat_session.zig").chatLatestAgentReply;
const chatMaxScroll = @import("chat_render.zig").chatMaxScroll;
const chatMinScroll = @import("chat_render.zig").chatMinScroll;
const voiceSendTranscriptToShell = @import("chat_send.zig").voiceSendTranscriptToShell;
const voicePasteTranscriptToShellNoEnter = @import("chat_send.zig").voicePasteTranscriptToShellNoEnter;
const sendChatPrompt = @import("chat_send.zig").sendChatPrompt;
const invalidateChatHeader = @import("chat_composer.zig").invalidateChatHeader;
const voiceScreenFallbackShouldSpeak = @import("app_state.zig").voiceScreenFallbackShouldSpeak;
const VoiceMic = @import("app_state.zig").VoiceMic;
const VoiceResult = @import("app_state.zig").VoiceResult;
const VoiceJob = @import("app_state.zig").VoiceJob;
const VoiceFrame = @import("app_state.zig").VoiceFrame;
const ReadConsoleOutputCharacterW = @import("win32.zig").ReadConsoleOutputCharacterW;
const setUnicodeClipboardTextWithRetry = @import("clipboard.zig").setUnicodeClipboardTextWithRetry;
const preserveClipboardTextAfterPaste = @import("clipboard.zig").preserveClipboardTextAfterPaste;
const rememberLastPasteText = @import("clipboard.zig").rememberLastPasteText;
const DICTATION_SAMPLE_RATE = @import("app_state.zig").DICTATION_SAMPLE_RATE;
const DICTATION_CHUNK_BYTES = @import("app_state.zig").DICTATION_CHUNK_BYTES;
const DICTATION_BUFFER_COUNT = @import("app_state.zig").DICTATION_BUFFER_COUNT;
const DICTATION_MAX_BYTES = @import("app_state.zig").DICTATION_MAX_BYTES;
const pcmFrameRms = @import("app_state.zig").pcmFrameRms;
const vadStep = @import("app_state.zig").vadStep;
const DictationHttpResult = @import("app_state.zig").DictationHttpResult;
const DEEPGRAM_HOST = @import("app_state.zig").DEEPGRAM_HOST;
const DEEPGRAM_MIP_OPT_OUT = @import("app_state.zig").DEEPGRAM_MIP_OPT_OUT;
const DictationShellPasteResult = @import("app_state.zig").DictationShellPasteResult;
const pasteTextToShellDirect = @import("clipboard.zig").pasteTextToShellDirect;
const openAttachedConsoleOutput = @import("clipboard.zig").openAttachedConsoleOutput;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;

pub fn voiceSapiStart() bool {
    if (app_state.g_voice_sapi != null) return true;
    const co = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    if (co != S_OK and co != 1) return false;
    app_state.g_voice_com_initialized = true;
    var ptr: ?*anyopaque = null;
    if (CoCreateInstance(&CLSID_SpVoice, null, CLSCTX_INPROC_SERVER, &IID_ISpVoice, &ptr) != S_OK or ptr == null) {
        CoUninitialize();
        app_state.g_voice_com_initialized = false;
        return false;
    }
    app_state.g_voice_sapi = @ptrCast(@alignCast(ptr.?));
    return true;
}

fn voiceSapiStop() void {
    if (app_state.g_voice_sapi) |v| {
        _ = v.lpVtbl.Release(v);
        app_state.g_voice_sapi = null;
    }
    if (app_state.g_voice_com_initialized) {
        CoUninitialize();
        app_state.g_voice_com_initialized = false;
    }
}

pub fn voiceSpeak(text: []const u16) void {
    const v = app_state.g_voice_sapi orelse return;
    var buf: [8192]u16 = undefined;
    const n = @min(text.len, buf.len - 1);
    @memcpy(buf[0..n], text[0..n]);
    buf[n] = 0;
    _ = v.lpVtbl.Speak(v, @ptrCast(&buf), SPF_ASYNC | SPF_PURGEBEFORESPEAK | SPF_IS_NOT_XML, null);
}

pub fn voiceStopSpeaking() void {
    if (app_state.g_voice_sapi) |v| _ = v.lpVtbl.Speak(v, null, SPF_PURGEBEFORESPEAK, null);
    voiceTtsStopPlayback();
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_TTS_POS);
}

pub fn voiceIsSpeaking() bool {
    var sapi_speaking = false;
    if (app_state.g_voice_sapi) |v| {
        var status: SPVOICESTATUS = std.mem.zeroes(SPVOICESTATUS);
        if (v.lpVtbl.GetStatus(v, &status, null) == S_OK) sapi_speaking = status.dwRunningState != SPRS_DONE;
    }
    return sapi_speaking or voiceTtsIsPlaying();
}

pub fn voiceSpeedLabel(s: VoiceSpeed) []const u8 {
    return switch (s) {
        .s100 => "1x",
        .s125 => "1.25x",
        .s140 => "1.4x",
        .s150 => "1.5x",
    };
}

pub fn voiceSpeedSessionValue(s: VoiceSpeed) []const u8 {
    return switch (s) {
        .s100 => "1.0",
        .s125 => "1.25",
        .s140 => "1.4",
        .s150 => "1.5",
    };
}

fn voiceSpeedPath(s: VoiceSpeed) LPCWSTR {
    return switch (s) {
        .s100 => L("/v1/speak?model=" ++ DEEPGRAM_TTS_MODEL ++ "&encoding=linear16&sample_rate=24000&container=none&speed=1.0&mip_opt_out=true"),
        .s125 => L("/v1/speak?model=" ++ DEEPGRAM_TTS_MODEL ++ "&encoding=linear16&sample_rate=24000&container=none&speed=1.25&mip_opt_out=true"),
        .s140 => L("/v1/speak?model=" ++ DEEPGRAM_TTS_MODEL ++ "&encoding=linear16&sample_rate=24000&container=none&speed=1.4&mip_opt_out=true"),
        .s150 => L("/v1/speak?model=" ++ DEEPGRAM_TTS_MODEL ++ "&encoding=linear16&sample_rate=24000&container=none&speed=1.5&mip_opt_out=true"),
    };
}

fn voiceTtsEvenFlushLen(carry_len: usize, new_bytes: usize) usize {
    const total = carry_len + new_bytes;
    return total - (total % 2);
}

test "voiceTtsEvenFlushLen flushes an even count and carries at most one byte" {
    try std.testing.expectEqual(@as(usize, 0), voiceTtsEvenFlushLen(0, 0));
    try std.testing.expectEqual(@as(usize, 24000), voiceTtsEvenFlushLen(0, 24000));
    try std.testing.expectEqual(@as(usize, 2), voiceTtsEvenFlushLen(0, 3));
    try std.testing.expectEqual(@as(usize, 2), voiceTtsEvenFlushLen(1, 2));
    try std.testing.expectEqual(@as(usize, 24000), voiceTtsEvenFlushLen(1, 23999));
    try std.testing.expectEqual(@as(usize, 0), voiceTtsEvenFlushLen(1, 0));
}

fn speechUrlLen(line: []const u8, pos: usize) usize {
    if (pos > 0 and std.ascii.isAlphanumeric(line[pos - 1])) return 0;
    const rest = line[pos..];
    if (!std.ascii.startsWithIgnoreCase(rest, "https://") and
        !std.ascii.startsWithIgnoreCase(rest, "http://") and
        !std.ascii.startsWithIgnoreCase(rest, "www.")) return 0;
    var n: usize = 0;
    while (n < rest.len and rest[n] != ' ' and rest[n] != '\t' and rest[n] != ')' and rest[n] != '>' and rest[n] != '"') n += 1;
    while (n > 0 and (rest[n - 1] == '.' or rest[n - 1] == ',' or rest[n - 1] == ';' or rest[n - 1] == ':')) n -= 1;
    return n;
}

fn stripMarkdownForSpeech(text: []const u8, out: []u8) usize {
    var out_len: usize = 0;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i <= text.len) : (i += 1) {
        const at_end = i == text.len;
        if (!at_end and text[i] != '\n') continue;
        const line = text[line_start..i];
        var p: usize = 0;
        while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
        var content_start: usize = 0;
        var h = p;
        while (h < line.len and line[h] == '#') h += 1;
        if (h > p and h < line.len and line[h] == ' ') {
            content_start = h + 1;
        } else if (p < line.len and (line[p] == '-' or line[p] == '*') and p + 1 < line.len and line[p + 1] == ' ') {
            content_start = p + 2;
        } else {
            content_start = 0;
        }
        var k: usize = content_start;
        while (k < line.len) {
            const url_len = speechUrlLen(line, k);
            if (url_len > 0) {
                const wrapped = out_len > 0 and (out[out_len - 1] == '(' or out[out_len - 1] == '<');
                if (wrapped) out_len -= 1;
                k += url_len;
                if (wrapped and k < line.len and (line[k] == ')' or line[k] == '>')) k += 1;
                continue;
            }
            const c = line[k];
            k += 1;
            if (c == '*' or c == '`') continue;
            if (out_len < out.len) {
                out[out_len] = c;
                out_len += 1;
            }
        }
        if (!at_end and out_len < out.len) {
            out[out_len] = '\n';
            out_len += 1;
        }
        line_start = i + 1;
    }
    return out_len;
}

fn splitTtsChunks(text: []const u8, max_len: usize, out: []TtsChunkRange) usize {
    if (max_len == 0) return 0;
    var count: usize = 0;
    var pos: usize = 0;
    while (pos < text.len and count < out.len) {
        const remaining = text.len - pos;
        if (remaining <= max_len) {
            out[count] = .{ .start = pos, .end = text.len };
            count += 1;
            break;
        }
        const hard_cut = pos + max_len;
        var end: usize = hard_cut;
        var i = hard_cut;
        while (i > pos) : (i -= 1) {
            const c = text[i - 1];
            if (c == '\n') {
                end = i;
                break;
            }
            if ((c == '.' or c == '!' or c == '?') and (text[i] == ' ' or text[i] == '\n')) {
                end = i;
                break;
            }
        }
        while (end > pos and (text[end] & 0xC0) == 0x80) end -= 1;
        if (end <= pos) end = hard_cut;
        while (end > pos and (text[end] & 0xC0) == 0x80) end -= 1;
        if (end <= pos) end = pos + 1;
        out[count] = .{ .start = pos, .end = end };
        count += 1;
        pos = end;
        while (pos < text.len and (text[pos] == ' ' or text[pos] == '\n')) pos += 1;
    }
    return count;
}

fn wideToUtf8(text: []const u16, out: []u8) usize {
    if (text.len == 0) return 0;
    const n = WideCharToMultiByte(CP_UTF8, 0, text.ptr, @intCast(text.len), out.ptr, @intCast(out.len), null, null);
    return if (n > 0) @intCast(n) else 0;
}

fn ttsAppendLit(buf: []u8, pos: *usize, s: []const u8) void {
    for (s) |c| {
        if (pos.* >= buf.len) return;
        buf[pos.*] = c;
        pos.* += 1;
    }
}

fn ttsAppendJsonEscaped(buf: []u8, pos: *usize, s: []const u8) void {
    for (s) |c| {
        switch (c) {
            '"' => ttsAppendLit(buf, pos, "\\\""),
            '\\' => ttsAppendLit(buf, pos, "\\\\"),
            '\n' => ttsAppendLit(buf, pos, "\\n"),
            '\r' => ttsAppendLit(buf, pos, "\\r"),
            '\t' => ttsAppendLit(buf, pos, "\\t"),
            else => {
                if (c < 0x20) continue;
                if (pos.* < buf.len) {
                    buf[pos.*] = c;
                    pos.* += 1;
                }
            },
        }
    }
}

fn voiceTtsFlushStaged(hw: HWAVEOUT, generation: u64, chunk_count: usize, bytes: []const u8, queued: *usize) bool {
    const piece = std.heap.page_allocator.dupe(u8, bytes) catch return false;
    if (!voiceTtsQueuePcm(hw, piece, generation)) return false;
    if (queued.* == 0) dictationAudit("voice-tts-deepgram", chunk_count);
    queued.* += bytes.len;
    return true;
}

fn deepgramSpeakChunk(
    text: []const u8,
    hw: HWAVEOUT,
    generation: u64,
    chunk_count: usize,
    staging: *[VOICE_TTS_SLICE_BYTES]u8,
    staging_len: *usize,
    queued: *usize,
    req_start_tick: u64,
    stale_out: *bool,
) DWORD {
    var key_buf: [256]u8 = undefined;
    const key = readDeepgramApiKey(&key_buf) orelse return 0;

    var body_buf: [DEEPGRAM_TTS_CHAR_LIMIT * 6 + 32]u8 = undefined;
    var body_len: usize = 0;
    ttsAppendLit(&body_buf, &body_len, "{\"text\":\"");
    ttsAppendJsonEscaped(&body_buf, &body_len, text);
    ttsAppendLit(&body_buf, &body_len, "\"}");

    const session = WinHttpOpen(L("multiprompt Voice"), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (session == null) return 0;
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 8000, 8000, 20000, 20000);

    const http_connect = WinHttpConnect(session, DEEPGRAM_HOST, INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (http_connect == null) return 0;
    defer _ = WinHttpCloseHandle(http_connect);

    const request = WinHttpOpenRequest(
        http_connect,
        L("POST"),
        voiceSpeedPath(app_state.g_voice_speed),
        null,
        null,
        null,
        WINHTTP_FLAG_SECURE,
    );
    if (request == null) return 0;
    defer _ = WinHttpCloseHandle(request);

    var header_ascii: [420]u8 = undefined;
    const headers = std.fmt.bufPrint(&header_ascii, "Authorization: Token {s}\r\nContent-Type: application/json\r\n", .{key}) catch return 0;
    var header_wide: [420]u16 = undefined;
    const header_z = asciiToWideZ(headers, &header_wide) orelse return 0;
    if (WinHttpAddRequestHeaders(request, header_z, 0xFFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD) == 0) return 0;

    if (body_len > std.math.maxInt(DWORD)) return 0;
    const body_dword: DWORD = @intCast(body_len);
    if (WinHttpSendRequest(request, null, 0, @ptrCast(&body_buf), body_dword, body_dword, 0) == 0) return 0;
    if (WinHttpReceiveResponse(request, null) == 0) return 0;

    var status: DWORD = 0;
    var status_size: DWORD = @sizeOf(DWORD);
    _ = WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, null, &status, &status_size, null);
    if (status < 200 or status >= 300) return status;

    const bytes_before = queued.*;
    var total_read: usize = 0;
    var ok = true;
    var logged_first_bytes = false;
    var read_buf: [VOICE_TTS_READ_BYTES]u8 = undefined;
    while (total_read < DEEPGRAM_TTS_MAX_PCM_BYTES) {
        if (app_state.g_voice_tts_generation.load(.acquire) != generation) {
            stale_out.* = true;
            break;
        }
        var avail: DWORD = 0;
        if (WinHttpQueryDataAvailable(request, &avail) == 0) {
            ok = false;
            break;
        }
        if (avail == 0) break;

        const room_left = DEEPGRAM_TTS_MAX_PCM_BYTES - total_read;
        const take: usize = @min(@min(@as(usize, avail), VOICE_TTS_READ_BYTES), room_left);
        var got: DWORD = 0;
        if (WinHttpReadData(request, &read_buf, @intCast(take), &got) == 0) {
            ok = false;
            break;
        }
        if (got == 0) break;
        total_read += @as(usize, got);
        if (!logged_first_bytes and req_start_tick != 0) {
            logged_first_bytes = true;
            dictationAudit("voice-tts-http-ms", @intCast(GetTickCount64() -| req_start_tick));
        }

        var src_off: usize = 0;
        while (src_off < got) {
            if (app_state.g_voice_tts_generation.load(.acquire) != generation) {
                stale_out.* = true;
                break;
            }
            const room = VOICE_TTS_SLICE_BYTES - staging_len.*;
            const take2 = @min(room, @as(usize, got) - src_off);
            @memcpy(staging[staging_len.* .. staging_len.* + take2], read_buf[src_off .. src_off + take2]);
            staging_len.* += take2;
            src_off += take2;
            if (staging_len.* == VOICE_TTS_SLICE_BYTES) {
                if (!voiceTtsFlushStaged(hw, generation, chunk_count, staging[0..VOICE_TTS_SLICE_BYTES], queued)) {
                    if (app_state.g_voice_tts_generation.load(.acquire) != generation) stale_out.* = true else ok = false;
                    break;
                }
                staging_len.* = 0;
            }
        }
        if (stale_out.* or !ok) break;
    }
    if (!stale_out.* and ok and staging_len.* > 0) {
        const flush_len = voiceTtsEvenFlushLen(0, staging_len.*);
        if (flush_len > 0) {
            if (!voiceTtsFlushStaged(hw, generation, chunk_count, staging[0..flush_len], queued)) {
                if (app_state.g_voice_tts_generation.load(.acquire) != generation) stale_out.* = true else ok = false;
            }
        }
        if (!stale_out.* and ok) {
            const leftover = staging_len.* - flush_len;
            if (leftover > 0) staging[0] = staging[flush_len];
            staging_len.* = leftover;
        }
    }
    if (stale_out.*) return status;
    if (!ok or queued.* == bytes_before) return 0;
    return status;
}

fn voiceTtsDeviceOpen() bool {
    if (app_state.g_voice_tts_wave_out != null) return true;
    const fmt = WAVEFORMATEX{
        .wFormatTag = WAVE_FORMAT_PCM,
        .nChannels = 1,
        .nSamplesPerSec = DEEPGRAM_TTS_SAMPLE_RATE,
        .nAvgBytesPerSec = DEEPGRAM_TTS_SAMPLE_RATE * 2,
        .nBlockAlign = 2,
        .wBitsPerSample = 16,
        .cbSize = 0,
    };
    var hw: HWAVEOUT = null;
    const mmr = waveOutOpen(&hw, WAVE_MAPPER, &fmt, 0, 0, 0);
    dictationAudit("voice-tts-open", mmr);
    if (mmr != 0 or hw == null) return false;
    app_state.g_voice_tts_wave_out = hw;
    return true;
}

fn voiceTtsFreeBuffer(hw: HWAVEOUT, buf: *VoiceTtsBuffer) void {
    _ = waveOutUnprepareHeader(hw, &buf.header, @sizeOf(WAVEHDR));
    std.heap.page_allocator.free(buf.pcm);
    std.heap.page_allocator.destroy(buf);
}

fn voiceTtsReapDone(hw: HWAVEOUT) void {
    while (!app_state.g_voice_tts_mutex.tryLock()) Sleep(0);
    defer app_state.g_voice_tts_mutex.unlock();
    var i: usize = 0;
    while (i < app_state.g_voice_tts_outstanding.items.len) {
        const buf = app_state.g_voice_tts_outstanding.items[i];
        if ((buf.header.dwFlags & WHDR_DONE) != 0) {
            voiceTtsFreeBuffer(hw, buf);
            _ = app_state.g_voice_tts_outstanding.swapRemove(i);
            _ = app_state.g_voice_tts_outstanding_count.fetchSub(1, .acq_rel);
        } else {
            i += 1;
        }
    }
}

fn voiceTtsIsPlaying() bool {
    if (app_state.g_voice_tts_fetching.load(.acquire)) return true;
    const hw = app_state.g_voice_tts_wave_out orelse return false;
    voiceTtsReapDone(hw);
    return app_state.g_voice_tts_outstanding_count.load(.acquire) > 0;
}

pub fn voiceTtsStopPlayback() void {
    while (!app_state.g_voice_tts_mutex.tryLock()) Sleep(0);
    defer app_state.g_voice_tts_mutex.unlock();
    _ = app_state.g_voice_tts_generation.fetchAdd(1, .acq_rel);
    app_state.g_voice_tts_fetching.store(false, .release);
    app_state.g_voice_tts_audible.store(false, .release);
    app_state.g_voice_tts_quiet_since.store(GetTickCount64(), .release);
    const hw = app_state.g_voice_tts_wave_out orelse return;
    _ = waveOutReset(hw);
    for (app_state.g_voice_tts_outstanding.items) |buf| voiceTtsFreeBuffer(hw, buf);
    app_state.g_voice_tts_outstanding.clearRetainingCapacity();
    app_state.g_voice_tts_outstanding_count.store(0, .release);
}

pub fn voiceTtsDeviceStop() void {
    voiceTtsStopPlayback();
    if (app_state.g_voice_tts_wave_out) |hw| {
        _ = waveOutClose(hw);
        app_state.g_voice_tts_wave_out = null;
    }
}

fn voiceTtsQueuePcm(hw: HWAVEOUT, pcm: []u8, generation: u64) bool {
    voiceTtsReapDone(hw);
    while (!app_state.g_voice_tts_mutex.tryLock()) Sleep(0);
    defer app_state.g_voice_tts_mutex.unlock();
    if (app_state.g_voice_tts_generation.load(.acquire) != generation or app_state.g_voice_tts_wave_out != hw) {
        std.heap.page_allocator.free(pcm);
        return false;
    }
    const buf = std.heap.page_allocator.create(VoiceTtsBuffer) catch {
        std.heap.page_allocator.free(pcm);
        return false;
    };
    buf.* = .{ .header = std.mem.zeroes(WAVEHDR), .pcm = pcm };
    buf.header.lpData = pcm.ptr;
    buf.header.dwBufferLength = @intCast(pcm.len);
    app_state.g_voice_tts_outstanding.ensureUnusedCapacity(std.heap.page_allocator, 1) catch {
        std.heap.page_allocator.free(pcm);
        std.heap.page_allocator.destroy(buf);
        return false;
    };
    const prepare_mmr = waveOutPrepareHeader(hw, &buf.header, @sizeOf(WAVEHDR));
    if (prepare_mmr != 0) {
        dictationAudit("voice-tts-prepare", prepare_mmr);
        std.heap.page_allocator.free(pcm);
        std.heap.page_allocator.destroy(buf);
        return false;
    }
    const write_mmr = waveOutWrite(hw, &buf.header, @sizeOf(WAVEHDR));
    if (write_mmr != 0) {
        dictationAudit("voice-tts-write", write_mmr);
        _ = waveOutUnprepareHeader(hw, &buf.header, @sizeOf(WAVEHDR));
        std.heap.page_allocator.free(pcm);
        std.heap.page_allocator.destroy(buf);
        return false;
    }
    app_state.g_voice_tts_outstanding.appendAssumeCapacity(buf);
    _ = app_state.g_voice_tts_outstanding_count.fetchAdd(1, .acq_rel);
    app_state.g_voice_tts_audible.store(true, .release);

    if (app_state.g_voice_tts_generation.load(.acquire) == generation and app_state.g_voice_tts_audio_started.cmpxchgStrong(false, true, .acq_rel, .acquire) == null) {
        app_state.g_voice_tts_since.store(GetTickCount64(), .release);
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_TTS_AUDIO_STARTED, 0, 0);
    }
    return true;
}

fn voiceTtsFallbackToSapi(fallback_text: []const u16, shell_id: u32, generation: u64) void {
    if (app_state.g_voice_tts_generation.load(.acquire) != generation) return;
    const n = @min(fallback_text.len, app_state.g_voice_tts_fallback_text.len - 1);
    @memcpy(app_state.g_voice_tts_fallback_text[0..n], fallback_text[0..n]);
    app_state.g_voice_tts_fallback_len = n;
    app_state.g_voice_tts_fallback_shell_id = shell_id;
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_TTS_FALLBACK, 0, 0);
}

fn voiceTtsWorkerThread(hw: HWAVEOUT, text_owned: []u8, fallback_owned: []u16, shell_id: u32, generation: u64) void {
    defer std.heap.page_allocator.free(text_owned);
    defer std.heap.page_allocator.free(fallback_owned);
    defer {
        while (!app_state.g_voice_tts_mutex.tryLock()) Sleep(0);
        if (app_state.g_voice_tts_generation.load(.acquire) == generation) app_state.g_voice_tts_fetching.store(false, .release);
        app_state.g_voice_tts_mutex.unlock();
    }

    var chunks: [DEEPGRAM_TTS_MAX_CHUNKS]TtsChunkRange = undefined;
    const chunk_count = splitTtsChunks(text_owned, DEEPGRAM_TTS_CHAR_LIMIT, &chunks);
    if (chunk_count == 0) return;

    var staging: [VOICE_TTS_SLICE_BYTES]u8 = undefined;
    var staging_len: usize = 0;
    var queued: usize = 0;

    var i: usize = 0;
    while (i < chunk_count) : (i += 1) {
        if (app_state.g_voice_tts_generation.load(.acquire) != generation) {
            dictationAudit("voice-tts-discarded-stale", queued);
            return;
        }
        var stale = false;
        const req_start = GetTickCount64();
        const status = deepgramSpeakChunk(text_owned[chunks[i].start..chunks[i].end], hw, generation, chunk_count, &staging, &staging_len, &queued, req_start, &stale);
        if (stale) {
            dictationAudit("voice-tts-discarded-stale", queued);
            return;
        }
        if (status < 200 or status >= 300) {
            dictationAudit("voice-tts-deepgram-failed", status);
            if (i == 0 and queued == 0) voiceTtsFallbackToSapi(fallback_owned, shell_id, generation);
            return;
        }
    }
    dictationAudit("voice-tts-queued-bytes", queued);
}

fn voiceSpeakReply(text: []const u16, shell_id: u32) bool {
    dictationAudit("voice-stop", 3);
    voiceStopSpeaking();
    app_state.g_voice_tts_audio_started.store(false, .release);

    var utf8_buf: [24576]u8 = undefined;
    const utf8_len = wideToUtf8(text, &utf8_buf);
    var stripped_buf: [24576]u8 = undefined;
    const stripped_len = if (utf8_len > 0) stripMarkdownForSpeech(utf8_buf[0..utf8_len], &stripped_buf) else 0;
    while (!app_state.g_voice_spoken_mutex.tryLock()) Sleep(0);
    app_state.g_voice_spoken_len = @min(stripped_len, app_state.g_voice_spoken.len);
    @memcpy(app_state.g_voice_spoken[0..app_state.g_voice_spoken_len], stripped_buf[0..app_state.g_voice_spoken_len]);
    app_state.g_voice_spoken_mutex.unlock();
    const clean_wide: []const u16 = if (stripped_len > 0) blk: {
        const n = std.unicode.utf8ToUtf16Le(&app_state.g_voice_clean_wide, stripped_buf[0..stripped_len]) catch break :blk text;
        break :blk app_state.g_voice_clean_wide[0..n];
    } else text;

    var key_buf: [256]u8 = undefined;
    if (readDeepgramApiKey(&key_buf) != null and voiceTtsDeviceOpen()) {
        const hw = app_state.g_voice_tts_wave_out.?;
        if (stripped_len > 0) {
            const text_owned = std.heap.page_allocator.dupe(u8, stripped_buf[0..stripped_len]) catch null;
            if (text_owned) |owned_text| {
                const fallback_owned = std.heap.page_allocator.dupe(u16, clean_wide) catch null;
                if (fallback_owned) |owned_fallback| {
                    const generation = app_state.g_voice_tts_generation.load(.acquire);
                    app_state.g_voice_tts_fetching.store(true, .release);
                    const t = std.Thread.spawn(.{}, voiceTtsWorkerThread, .{ hw, owned_text, owned_fallback, shell_id, generation }) catch null;
                    if (t) |thread| {
                        thread.detach();
                        return true;
                    }
                    app_state.g_voice_tts_fetching.store(false, .release);
                    std.heap.page_allocator.free(owned_fallback);
                }
                std.heap.page_allocator.free(owned_text);
            }
        }
    }

    dictationAudit("voice-tts-windows-voice", clean_wide.len);
    if (!voiceSapiStart()) return false;
    app_state.g_voice_tts_audio_started.store(true, .release);
    app_state.g_voice_tts_since.store(GetTickCount64(), .release);
    voiceSpeak(clean_wide);
    app_state.g_voice_tts_audible.store(true, .release);
    return true;
}

test "speech skips web addresses but keeps the words around them" {
    var out: [256]u8 = undefined;
    const n1 = stripMarkdownForSpeech("Open https://app.example.com/demo to see it.", &out);
    try std.testing.expectEqualStrings("Open  to see it.", out[0..n1]);

    const n2 = stripMarkdownForSpeech("Look at http://example.com.", &out);
    try std.testing.expectEqualStrings("Look at .", out[0..n2]);

    const n3 = stripMarkdownForSpeech("the page (https://x.dev/a?b=1) is live", &out);
    try std.testing.expectEqualStrings("the page  is live", out[0..n3]);

    const n4 = stripMarkdownForSpeech("see <www.example.com> and **bold**", &out);
    try std.testing.expectEqualStrings("see  and bold", out[0..n4]);

    const n5 = stripMarkdownForSpeech("- https://a.b\nnext line", &out);
    try std.testing.expectEqualStrings("\nnext line", out[0..n5]);

    const n6 = stripMarkdownForSpeech("the xhttps://y word and wwwhat", &out);
    try std.testing.expectEqualStrings("the xhttps://y word and wwwhat", out[0..n6]);
}

test "markdown strip removes only marker characters, words stay intact" {
    var out: [256]u8 = undefined;
    const n1 = stripMarkdownForSpeech("**hello** world", &out);
    try std.testing.expectEqualStrings("hello world", out[0..n1]);

    const n2 = stripMarkdownForSpeech("This is *emphasis* and `code`.", &out);
    try std.testing.expectEqualStrings("This is emphasis and code.", out[0..n2]);

    const n3 = stripMarkdownForSpeech("# Heading one", &out);
    try std.testing.expectEqualStrings("Heading one", out[0..n3]);

    const n4 = stripMarkdownForSpeech("## Heading two", &out);
    try std.testing.expectEqualStrings("Heading two", out[0..n4]);

    const n5 = stripMarkdownForSpeech("- bullet one\n* bullet two", &out);
    try std.testing.expectEqualStrings("bullet one\nbullet two", out[0..n5]);

    const n6 = stripMarkdownForSpeech("3 * 4 is twelve", &out);
    try std.testing.expectEqualStrings("3  4 is twelve", out[0..n6]);

    const n7 = stripMarkdownForSpeech("plain text, nothing to strip", &out);
    try std.testing.expectEqualStrings("plain text, nothing to strip", out[0..n7]);
}

test "tts chunk splitter respects the character limit" {
    var chunks: [DEEPGRAM_TTS_MAX_CHUNKS]TtsChunkRange = undefined;

    {
        const text = "Hello there.";
        const count = splitTtsChunks(text, 2000, &chunks);
        try std.testing.expectEqual(@as(usize, 1), count);
        try std.testing.expectEqualStrings(text, text[chunks[0].start..chunks[0].end]);
    }

    {
        const text = "First sentence here. Second sentence here. Third one.";
        const count = splitTtsChunks(text, 21, &chunks);
        try std.testing.expect(count >= 2);
        for (chunks[0..count]) |c| try std.testing.expect(c.end - c.start <= 21);
        try std.testing.expectEqualStrings("First sentence here.", text[chunks[0].start..chunks[0].end]);
    }

    {
        const text = "a" ** 50;
        const count = splitTtsChunks(text, 7, &chunks);
        try std.testing.expect(count > 1);
        var rebuilt_len: usize = 0;
        for (chunks[0..count]) |c| {
            try std.testing.expect(c.end - c.start <= 7);
            rebuilt_len += c.end - c.start;
        }
        try std.testing.expectEqual(text.len, rebuilt_len);
    }

    {
        const text = "aaaaa" ++ "\u{00e9}" ++ "aaaaa";
        const count = splitTtsChunks(text, 6, &chunks);
        for (chunks[0..count]) |c| {
            const chunk = text[c.start..c.end];
            _ = std.unicode.Utf8View.init(chunk) catch unreachable;
        }
    }
}

pub fn voiceStatusLabel() [*:0]const u16 {
    return switch (app_state.g_voice_state) {
        .speaking => if (app_state.g_voice_tts_audio_started.load(.acquire)) L("Voice: speaking") else L("Voice: preparing"),
        .listening => if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) L("Voice: hearing you") else L("Voice: listening"),
        .sending => L("Voice: sending"),
        .idle => if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) L("Voice: listening") else L("Voice: waiting for agent"),
        .waiting => if (app_state.g_voice_always_listen) L("Voice: agent working") else L("Voice: waiting for agent"),
    };
}

pub fn insertTextIntoChatComposer(text: []const u16) void {
    if (app_state.g_chat_composer_hwnd == null or text.len == 0) return;
    var current: [16384]u16 = undefined;
    const current_len_i = GetWindowTextW(app_state.g_chat_composer_hwnd, &current, @intCast(current.len));
    const current_len: usize = if (current_len_i > 0) @intCast(current_len_i) else 0;
    var output: [16384]u16 = undefined;
    var pos: usize = 0;
    if (current_len > 0) {
        const n = @min(current_len, output.len - 1);
        @memcpy(output[0..n], current[0..n]);
        pos = n;
        if (pos < output.len - 1) {
            output[pos] = ' ';
            pos += 1;
        }
    }
    const n2 = @min(text.len, output.len - 1 - pos);
    @memcpy(output[pos .. pos + n2], text[0..n2]);
    pos += n2;
    output[pos] = 0;
    _ = SetWindowTextW(app_state.g_chat_composer_hwnd, @ptrCast(&output));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B1, pos, @intCast(pos));
    _ = SetFocus(app_state.g_chat_composer_hwnd);
}

fn chatComposerCaretToEnd() void {
    if (app_state.g_chat_composer_hwnd == null) return;
    const end: usize = @intCast(@max(0, GetWindowTextLengthW(app_state.g_chat_composer_hwnd)));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B1, end, @intCast(end));
    _ = SendMessageW(app_state.g_chat_composer_hwnd, 0x00B7, 0, 0);
}

pub fn voiceStartListening() void {
    if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) {
        app_state.g_voice_state = .idle;
        invalidateChatHeader();
        return;
    }
    if (!app_state.g_voice_mode_active) {
        app_state.g_voice_state = .idle;
        invalidateChatHeader();
        return;
    }
    if (app_state.g_dictation_recording.load(.acquire) or app_state.g_dictation_running.load(.acquire)) return;
    var key_buf: [256]u8 = undefined;
    if (readDeepgramApiKey(&key_buf) == null) {
        app_state.g_voice_state = .idle;
        showHeaderNoticeAscii("Set DEEPGRAM_API_KEY to use dictation", 5000, true);
        invalidateChatHeader();
        return;
    }
    app_state.g_voice_vad_state = .{};
    app_state.g_voice_listening_active.store(true, .release);
    app_state.g_voice_state = .listening;
    toggleDictation();
    if (!app_state.g_dictation_recording.load(.acquire) and !app_state.g_dictation_running.load(.acquire)) {
        app_state.g_voice_listening_active.store(false, .release);
        app_state.g_voice_state = .idle;
    }
    invalidateChatHeader();
}

pub fn voiceScheduleTurnEnd(shell_id: u32) void {
    if (!app_state.g_voice_mode_active or app_state.g_main_hwnd == null) return;
    app_state.g_voice_pending_turn_shell_id = shell_id;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_VOICE_TURN_END, 800, null);
}

pub fn voiceCheckScreenFallback() void {
    if (!app_state.g_voice_mode_active) return;
    if (app_state.g_voice_state != .waiting and app_state.g_voice_state != .idle) return;
    if (app_state.active_shell >= app_state.shell_count) return;
    voiceRefreshTranscriptCache(false);
    var out: [8192]u16 = undefined;
    const n = chatLatestAgentReply(&out);
    const hash = if (n == 0) 0 else std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(out[0..n]));
    const now = GetTickCount64();
    if (hash != app_state.g_voice_fallback_last_hash) {
        app_state.g_voice_fallback_last_hash = hash;
        app_state.g_voice_fallback_stable_since = now;
    }
    const stable_ms = now -| app_state.g_voice_fallback_stable_since;
    const should_speak = voiceScreenFallbackShouldSpeak(
        app_state.g_voice_state,
        n,
        hash,
        app_state.shells[app_state.active_shell].voice_last_reply_hash,
        stable_ms,
        app_state.g_chat_screen_working,
    );
    if (should_speak) {
        dictationAudit("voice-turn-end-screen-fallback", @intCast(stable_ms));
        voiceOnTurnEnd(app_state.shells[app_state.active_shell].shell_id);
    }
}

pub fn voiceOnTurnEnd(shell_id: u32) void {
    if (!app_state.g_voice_mode_active) return;
    if (app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].shell_id != shell_id) {
        dictationAudit("voice-turn-end-not-active-shell", 0);
        return;
    }
    if (app_state.g_voice_state == .listening or app_state.g_voice_state == .sending) {
        if (app_state.g_voice_always_listen and !app_state.g_voice_mic_failed) app_state.g_voice_deferred_turn_shell_id = shell_id;
        dictationAudit("voice-turn-end-busy-state", 0);
        return;
    }
    voiceRefreshTranscriptCache(true);
    var out: [8192]u16 = undefined;
    const n = chatLatestAgentReply(&out);
    if (n == 0) {
        dictationAudit("voice-turn-end-no-reply", 0);
        app_state.g_voice_state = .waiting;
        invalidateChatHeader();
        return;
    }
    const hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(out[0..n]));
    if (hash == app_state.shells[app_state.active_shell].voice_last_reply_hash) {
        dictationAudit("voice-turn-end-same-reply", 0);
        app_state.g_voice_state = .waiting;
        invalidateChatHeader();
        return;
    }
    app_state.shells[app_state.active_shell].voice_last_reply_hash = hash;
    app_state.g_voice_state = .speaking;
    app_state.g_voice_speaking_shell_id = shell_id;
    app_state.g_voice_last_activity_tick = GetTickCount64();
    if (app_state.g_voice_always_listen) {
        app_state.g_voice_repin.store(true, .release);
        app_state.g_voice_tts_since.store(GetTickCount64(), .release);
        app_state.g_voice_tts_quiet_since.store(0, .release);
        app_state.g_voice_tts_audible.store(false, .release);
    }
    dictationAudit("voice-speak-start", n);
    if (!voiceSpeakReply(out[0..n], shell_id)) {
        app_state.g_voice_state = .idle;
        showHeaderNoticeAscii("Voice Mode: text-to-speech unavailable", 4000, true);
        invalidateChatHeader();
        return;
    }
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL, 150, null);
    invalidateChatHeader();
}

pub fn voiceReadReply(step: voice_filter.ReplyStep) void {
    if (app_state.active_shell >= app_state.shell_count) {
        showHeaderNoticeAscii("No reply to read yet", 3000, true);
        return;
    }
    const shell_id = app_state.shells[app_state.active_shell].shell_id;
    voiceRefreshTranscriptCache(true);
    var out: [8192]u16 = undefined;
    const user_blocks = std.heap.page_allocator.alloc(bool, app_state.g_chat_block_count) catch return;
    defer std.heap.page_allocator.free(user_blocks);
    for (0..app_state.g_chat_block_count) |i| user_blocks[i] = app_state.g_chat_blocks[i].role == .user or app_state.g_chat_blocks[i].role == .injected;
    var latest: [8192]u16 = undefined;
    const latest_len = chatLatestAgentReply(&latest);
    const latest_hash = if (latest_len == 0) @as(u64, 0) else std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(latest[0..latest_len]));
    if (app_state.g_voice_cursor_shell_id != shell_id or app_state.g_voice_cursor_latest_hash != latest_hash) {
        app_state.g_voice_cursor_shell_id = shell_id;
        app_state.g_voice_cursor_latest_hash = latest_hash;
        app_state.g_voice_cursor_start = null;
    }
    const range = voice_filter.selectReply(user_blocks[0..app_state.g_chat_block_count], app_state.g_voice_cursor_start, step) orelse {
        showHeaderNoticeAscii("No reply to read yet", 3000, true);
        return;
    };
    if (step == .latest and latest_len == 0) {
        showHeaderNoticeAscii("No reply to read yet", 3000, true);
        return;
    }
    var n: usize = 0;
    const buf = app_state.g_chat_capture[0..app_state.g_chat_last_len];
    for (range.start..range.end) |i| {
        const disp = chatBlockDisplayRange(buf, app_state.g_chat_blocks[i]);
        if (disp.len == 0) continue;
        if (n != 0) {
            if (n + 2 > out.len) break;
            out[n] = '\r';
            out[n + 1] = '\n';
            n += 2;
        }
        const size = @min(disp.len, out.len - n);
        @memcpy(out[n .. n + size], buf[disp.start .. disp.start + size]);
        n += size;
    }
    if (n == 0) return;
    app_state.g_voice_cursor_start = range.start;
    app_state.g_voice_highlight = range;
    if (app_state.g_chat_active and app_state.g_chat_transcript_hwnd != null) {
        var client: RECT = std.mem.zeroes(RECT);
        _ = GetClientRect(app_state.g_chat_transcript_hwnd, &client);
        const top = app_state.g_chat_layout_rects[range.start].top;
        const bottom = app_state.g_chat_layout_rects[range.end - 1].bottom;
        if (top < app_state.g_chat_scroll_y or bottom > app_state.g_chat_scroll_y + client.bottom - client.top) {
            app_state.g_chat_scroll_y = std.math.clamp(if (bottom - top <= client.bottom - client.top) bottom - (client.bottom - client.top) else top, chatMinScroll(), chatMaxScroll());
        }
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    }
    dictationAudit("voice-replay", n);
    if (latest_len != 0) app_state.shells[app_state.active_shell].voice_last_reply_hash = latest_hash;
    if (app_state.g_voice_listening_active.load(.acquire)) {
        app_state.g_dictation_recording.store(false, .release);
        app_state.g_voice_legacy_discard = true;
    }
    app_state.g_voice_utt_open = @splat(.{});
    app_state.g_voice_deferred_turn_shell_id = 0;
    app_state.g_voice_replay_only = true;
    app_state.g_voice_state = .speaking;
    app_state.g_voice_speaking_shell_id = shell_id;
    app_state.g_voice_last_activity_tick = GetTickCount64();
    if (!voiceSpeakReply(out[0..n], shell_id)) {
        app_state.g_voice_highlight = null;
        app_state.g_voice_state = .idle;
        app_state.g_voice_replay_only = false;
        showHeaderNoticeAscii("Voice Mode: text-to-speech unavailable", 4000, true);
        invalidateChatHeader();
        return;
    }
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL, 150, null);
    invalidateChatHeader();
}

fn voiceStopAll() void {
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL);
    voiceMicStop();
    app_state.g_voice_tts_audible.store(false, .release);
    voiceStopSpeaking();
    app_state.g_voice_highlight = null;
    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    voiceSapiStop();
    voiceTtsDeviceStop();
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_TURN_END);
    if (app_state.g_voice_listening_active.load(.acquire)) app_state.g_dictation_recording.store(false, .release);
    app_state.g_voice_state = .idle;
    app_state.g_voice_deferred_turn_shell_id = 0;
}

pub fn setVoiceModeActive(active: bool) void {
    if (active == app_state.g_voice_mode_active) return;
    if (!active) {
        app_state.g_voice_mode_active = false;
        if (app_state.g_voice_state == .speaking) dictationAudit("voice-stop", 4);
        voiceStopAll();
        dictationAudit("voice-mode-off", 0);
        invalidateChatHeader();
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    app_state.g_voice_mode_active = true;
    app_state.g_voice_state = .idle;
    app_state.g_voice_last_activity_tick = GetTickCount64();
    if (!app_state.g_chat_active and app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_REFRESH, 120, null);
    if (app_state.g_voice_always_listen) {
        voiceMicStart();
    }
    voiceRefreshTranscriptCache(true);
    if (app_state.shells[app_state.active_shell].activity == .active and app_state.g_chat_screen_working) {
        app_state.g_voice_state = .waiting;
        dictationAudit("voice-mode-on-waiting", 0);
    } else {
        dictationAudit("voice-mode-on", 0);
        voiceOnTurnEnd(app_state.shells[app_state.active_shell].shell_id);
    }
    invalidateChatHeader();
}

fn voiceDuckingOptOut() void {
    const hr_init = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    dictationAudit("voice-duplex-duck-com", @as(u32, @bitCast(hr_init)));
    if (hr_init < 0 and hr_init != @as(i32, @bitCast(@as(u32, 0x80010106)))) return;
    defer if (hr_init >= 0) CoUninitialize();
    var ptr: ?*anyopaque = null;
    var hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, null, CLSCTX_INPROC_SERVER, &IID_IMMDeviceEnumerator, &ptr);
    dictationAudit("voice-duplex-duck-enumerator", @as(u32, @bitCast(hr)));
    if (hr < 0 or ptr == null) return;
    const enumr: *IMMDeviceEnumerator = @ptrCast(@alignCast(ptr.?));
    defer comRelease(enumr);
    var dev: ?*IMMDevice = null;
    hr = enumr.lpVtbl.GetDefaultAudioEndpoint(enumr, 0, 0, &dev);
    dictationAudit("voice-duplex-duck-output", @as(u32, @bitCast(hr)));
    if (hr < 0 or dev == null) return;
    defer comRelease(dev.?);
    ptr = null;
    hr = dev.?.lpVtbl.Activate(dev.?, &IID_IAudioSessionManager, CLSCTX_INPROC_SERVER, null, &ptr);
    dictationAudit("voice-duplex-duck-manager", @as(u32, @bitCast(hr)));
    if (hr < 0 or ptr == null) return;
    const manager: *IAudioSessionManager = @ptrCast(@alignCast(ptr.?));
    defer comRelease(manager);
    ptr = null;
    hr = manager.lpVtbl.GetAudioSessionControl(manager, null, 0, &ptr);
    dictationAudit("voice-duplex-duck-session", @as(u32, @bitCast(hr)));
    if (hr < 0 or ptr == null) return;
    const control: *IUnknown = @ptrCast(@alignCast(ptr.?));
    defer comRelease(control);
    ptr = null;
    hr = control.lpVtbl.QueryInterface(@ptrCast(control), &IID_IAudioSessionControl2, &ptr);
    dictationAudit("voice-duplex-duck-query", @as(u32, @bitCast(hr)));
    if (hr < 0 or ptr == null) return;
    const control2: *IAudioSessionControl2 = @ptrCast(@alignCast(ptr.?));
    defer comRelease(control2);
    hr = control2.lpVtbl.SetDuckingPreference(control2, 1);
    dictationAudit("voice-duplex-duck-optout", @as(u32, @bitCast(hr)));
}

pub fn voicePostResult(result: *const VoiceResult) void {
    if (result.epoch != app_state.g_voice_mic_epoch.load(.acquire)) return;
    const idx = result.id % app_state.g_voice_results.len;
    while (true) {
        while (!app_state.g_voice_result_mutex.tryLock()) Sleep(0);
        if (result.epoch != app_state.g_voice_mic_epoch.load(.acquire)) {
            app_state.g_voice_result_mutex.unlock();
            return;
        }
        const slot = &app_state.g_voice_results[idx];
        if (!slot.ready or slot.result.epoch != result.epoch) {
            slot.* = .{ .ready = true, .result = result.* };
            app_state.g_voice_result_mutex.unlock();
            if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_UTTERANCE_READY, result.id, 0);
            return;
        }
        app_state.g_voice_result_mutex.unlock();
        if (!app_state.g_voice_mic_run.load(.acquire) or result.epoch != app_state.g_voice_mic_epoch.load(.acquire)) return;
        Sleep(10);
    }
}

pub fn voiceMicStop() void {
    app_state.g_voice_mic_start_pending = false;
    app_state.g_voice_mic_run.store(false, .release);
    if (app_state.g_voice_mic_thread) |thread| {
        thread.join();
        app_state.g_voice_mic_thread = null;
    }
    _ = app_state.g_voice_mic_epoch.fetchAdd(1, .acq_rel);
}
pub fn voiceMicStart() void {
    if (!app_state.g_voice_always_listen) return;
    voiceDuckingOptOut();
    app_state.g_voice_mic_start_pending = false;
    app_state.g_voice_mic_failed = false;
    var key: [256]u8 = undefined;
    if (readDeepgramApiKey(&key) == null) {
        app_state.g_voice_mic_failed = true;
        showHeaderNoticeAscii("Set DEEPGRAM_API_KEY to talk back", 5000, true);
        return;
    }
    voiceMicStop();
    app_state.g_voice_utt_open = @splat(.{});
    app_state.g_voice_echo_notice_shown = false;
    app_state.g_voice_mic_run.store(true, .release);
    const epoch = app_state.g_voice_mic_epoch.load(.acquire);
    app_state.g_voice_mic_thread = std.Thread.spawn(.{}, voiceMicWorkerThread, .{epoch}) catch {
        app_state.g_voice_mic_run.store(false, .release);
        app_state.g_voice_mic_failed = true;
        showHeaderNoticeAscii("Always listening unavailable, taking turns", 5000, true);
        dictationAudit("voice-duplex-mic-failed", epoch);
        if (app_state.g_voice_state == .idle) voiceStartListening();
        return;
    };
}

pub fn voiceSttWorkerThread(job: *VoiceJob) void {
    defer {
        std.heap.page_allocator.free(job.audio);
        std.heap.page_allocator.destroy(job);
        _ = app_state.g_voice_stt_pending.fetchSub(1, .acq_rel);
    }
    var result = VoiceResult{ .id = job.id, .epoch = job.epoch, .overlapped = job.overlapped };
    const dg = deepgramTranscribePcm(job.audio[0..job.audio_len], &result.text);
    dictationAudit("voice-duplex-stt-status", dg.status);
    if (dg.status == 200) {
        var text: []const u8 = result.text[0..dg.transcript_len];
        if (job.overlapped) {
            if (duplex.transcriptEchoesSpokenText(text, job.spoken[0..job.spoken_len])) {
                dictationAudit("voice-duplex-echo-drop", job.id);
                text = "";
            } else text = duplex.stripEchoPrefix(text, job.spoken[0..job.spoken_len]);
        }
        result.len = @min(text.len, result.text.len);
        std.mem.copyForwards(u8, result.text[0..result.len], text[0..result.len]);
    }
    voicePostResult(&result);
}

fn voiceMicRunWasapi(mic: *VoiceMic, frames: *VoiceFrame) void {
    var last_event = GetTickCount64();
    while (app_state.g_voice_mic_run.load(.acquire)) {
        if (app_state.g_voice_repin.swap(false, .acq_rel)) mic.pinRender();
        const wait = WaitForSingleObject(mic.event, 200);
        if (wait == 0) last_event = GetTickCount64();
        if (GetTickCount64() -| last_event > 2000 or wait == 0xFFFFFFFF) return;
        while (true) {
            var size: u32 = 0;
            var hr = mic.capture.?.lpVtbl.GetNextPacketSize(mic.capture.?, &size);
            if (hr < 0) {
                dictationAudit("voice-duplex-wasapi-packet", @as(u32, @bitCast(hr)));
                return;
            }
            if (size == 0) break;
            var data: ?[*]u8 = null;
            var count: u32 = 0;
            var flags: u32 = 0;
            hr = mic.capture.?.lpVtbl.GetBuffer(mic.capture.?, &data, &count, &flags, null, null);
            if (hr < 0) {
                dictationAudit("voice-duplex-wasapi-buffer", @as(u32, @bitCast(hr)));
                return;
            }
            if ((flags & 2) != 0 or data == null) {
                var zeros: [320]i16 = @splat(0);
                var remaining: usize = count;
                while (remaining > 0) {
                    const n = @min(remaining, zeros.len);
                    frames.accept(zeros[0..n]);
                    remaining -= n;
                }
            } else frames.accept(std.mem.bytesAsSlice(i16, data.?[0 .. @as(usize, count) * 2]));
            hr = mic.capture.?.lpVtbl.ReleaseBuffer(mic.capture.?, count);
            if (hr < 0) {
                dictationAudit("voice-duplex-wasapi-release", @as(u32, @bitCast(hr)));
                return;
            }
        }
    }
}

fn voiceMicRunWaveIn(frames: *VoiceFrame) void {
    const event = CreateEventW(null, 0, 0, null);
    if (event == null) return;
    defer _ = CloseHandle(event);
    const fmt = WAVEFORMATEX{ .wFormatTag = WAVE_FORMAT_PCM, .nChannels = 1, .nSamplesPerSec = DICTATION_SAMPLE_RATE, .nAvgBytesPerSec = DICTATION_SAMPLE_RATE * 2, .nBlockAlign = 2, .wBitsPerSample = 16, .cbSize = 0 };
    var hw: HWAVEIN = null;
    const open = waveInOpen(&hw, WAVE_MAPPER, &fmt, @intFromPtr(event), 0, CALLBACK_EVENT);
    dictationAudit("voice-duplex-fallback-wavein", open);
    if (open != 0 or hw == null) return;
    defer _ = waveInClose(hw);
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_MIC_STATUS, 2, @intCast(frames.epoch));
    var buffers: [DICTATION_BUFFER_COUNT][DICTATION_CHUNK_BYTES]u8 = undefined;
    var headers: [DICTATION_BUFFER_COUNT]WAVEHDR = undefined;
    var prepared: usize = 0;
    defer {
        _ = waveInStop(hw);
        _ = waveInReset(hw);
        for (headers[0..prepared]) |*header| _ = waveInUnprepareHeader(hw, header, @sizeOf(WAVEHDR));
    }
    for (0..DICTATION_BUFFER_COUNT) |i| {
        headers[i] = std.mem.zeroes(WAVEHDR);
        headers[i].lpData = &buffers[i];
        headers[i].dwBufferLength = DICTATION_CHUNK_BYTES;
        if (waveInPrepareHeader(hw, &headers[i], @sizeOf(WAVEHDR)) != 0) return;
        prepared += 1;
        if (waveInAddBuffer(hw, &headers[i], @sizeOf(WAVEHDR)) != 0) return;
    }
    if (waveInStart(hw) != 0) return;
    while (app_state.g_voice_mic_run.load(.acquire)) {
        _ = WaitForSingleObject(event, 100);
        for (headers[0..prepared]) |*header| {
            if ((header.dwFlags & WHDR_DONE) == 0) continue;
            if (header.lpData) |data| frames.accept(std.mem.bytesAsSlice(i16, data[0 .. @as(usize, header.dwBytesRecorded) & ~@as(usize, 1)]));
            if (waveInUnprepareHeader(hw, header, @sizeOf(WAVEHDR)) != 0) return;
            header.dwFlags = 0;
            header.dwBytesRecorded = 0;
            if (waveInPrepareHeader(hw, header, @sizeOf(WAVEHDR)) != 0 or waveInAddBuffer(hw, header, @sizeOf(WAVEHDR)) != 0) return;
        }
    }
}

fn voiceMicWorkerThread(epoch: u32) void {
    crash_recorder.guardThread();
    defer {
        app_state.g_voice_mic_run.store(false, .release);
    }
    const frames = std.heap.page_allocator.create(VoiceFrame) catch {
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_MIC_STATUS, 3, @intCast(epoch));
        return;
    };
    frames.* = .{ .epoch = epoch };
    defer std.heap.page_allocator.destroy(frames);
    defer {
        frames.close();
        if (app_state.g_voice_mic_run.load(.acquire) and app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_MIC_STATUS, 3, @intCast(epoch));
    }
    const init_hr = CoInitializeEx(null, 0);
    dictationAudit("voice-duplex-com", @as(u32, @bitCast(init_hr)));
    if (init_hr < 0) {
        voiceMicRunWaveIn(frames);
        return;
    }
    defer CoUninitialize();
    var tries: u32 = 0;
    var first_try = GetTickCount64();
    while (app_state.g_voice_mic_run.load(.acquire)) {
        var mic = VoiceMic{};
        if (mic.open()) {
            frames.aec = mic.aec_state;
            if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_VOICE_MIC_STATUS, if (mic.aec_state == .off or mic.aec_state == .absent) 2 else 1, @intCast(epoch));
            voiceMicRunWasapi(&mic, frames);
        } else {
            mic.close();
            frames.aec = .absent;
            voiceMicRunWaveIn(frames);
            break;
        }
        mic.close();
        frames.close();
        if (GetTickCount64() -| first_try > 60000) {
            tries = 0;
            first_try = GetTickCount64();
        }
        tries += 1;
        if (tries >= 5) break;
        for (0..5) |_| {
            if (!app_state.g_voice_mic_run.load(.acquire)) break;
            Sleep(100);
        }
    }
}

fn voiceTypingKeyTick() u32 {
    return if (app_state.g_chat_active) app_state.g_voice_composer_key_tick.load(.acquire) else app_state.g_voice_console_key_tick.load(.acquire);
}

pub fn voiceHandleSpeechStart(id: u32, overlapped: bool) void {
    if (!app_state.g_voice_mode_active or !app_state.g_voice_always_listen or app_state.active_shell >= app_state.shell_count) return;
    app_state.g_voice_last_activity_tick = GetTickCount64();
    const slot = &app_state.g_voice_utt_open[id % app_state.g_voice_utt_open.len];
    slot.* = .{
        .id = id,
        .shell_id = app_state.shells[app_state.active_shell].shell_id,
        .typed = app_state.g_chat_active and GetWindowTextLengthW(app_state.g_chat_composer_hwnd) > 0,
        .key_tick = voiceTypingKeyTick(),
    };
    if (app_state.g_voice_state == .speaking) {
        voiceStopSpeaking();
        _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL);
    }
    _ = overlapped;
    app_state.g_voice_state = .listening;
    invalidateChatHeader();
}
pub fn voiceHandleUtterance(result: *VoiceResult) void {
    if (result.epoch != app_state.g_voice_mic_epoch.load(.acquire) or !app_state.g_voice_mode_active or !app_state.g_voice_always_listen) return;
    const slot = &app_state.g_voice_utt_open[result.id % app_state.g_voice_utt_open.len];
    if (!duplex.voiceResultMatchesSlot(slot.id, result.id)) return;
    const target_shell_id = slot.shell_id;
    const changed = app_state.active_shell >= app_state.shell_count or app_state.shells[app_state.active_shell].shell_id != target_shell_id;
    var current: [16384]u16 = undefined;
    const current_len = if (app_state.g_chat_active and app_state.g_chat_composer_hwnd != null) GetWindowTextW(app_state.g_chat_composer_hwnd, &current, current.len) else 0;
    const decision = duplex.voiceUtteranceDecision(.{ .empty = result.len == 0, .typed = slot.typed or voiceTypingKeyTick() != slot.key_tick or (app_state.g_chat_active and !slot.consumed and current_len > 0), .changed_tab = changed, .consumed = slot.consumed });
    slot.* = .{};
    const another_open = for (app_state.g_voice_utt_open) |other| {
        if (other.id != 0) break true;
    } else false;
    app_state.g_voice_state = if (another_open) .listening else .idle;
    if (decision == .drop) {
        if (!another_open and app_state.g_voice_deferred_turn_shell_id != 0) {
            const deferred = app_state.g_voice_deferred_turn_shell_id;
            app_state.g_voice_deferred_turn_shell_id = 0;
            voiceOnTurnEnd(deferred);
        }
        invalidateChatHeader();
        return;
    }
    var wide: [8192]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, result.text[0..result.len]) catch return;
    if (changed) {
        const pending = &app_state.g_voice_deferred_text[result.id % app_state.g_voice_deferred_text.len];
        pending.shell_id = target_shell_id;
        pending.len = n;
        @memcpy(pending.text[0..n], wide[0..n]);
        showHeaderNoticeAscii("Voice text saved for the previous tab", 3500, false);
        invalidateChatHeader();
        return;
    }
    if (app_state.g_chat_active) insertTextIntoChatComposer(wide[0..n]);
    if (decision == .send) {
        const skipped = app_state.g_voice_deferred_turn_shell_id != 0;
        app_state.g_voice_deferred_turn_shell_id = 0;
        voiceRefreshTranscriptCache(true);
        var reply: [8192]u16 = undefined;
        const reply_len = chatLatestAgentReply(&reply);
        if (reply_len > 0 and app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].voice_last_reply_hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(reply[0..reply_len]));
        app_state.g_voice_state = .sending;
        dictationAudit("voice-duplex-send", result.id);
        app_state.g_voice_auto_sending = true;
        if (app_state.g_chat_active) sendChatPrompt() else _ = voiceSendTranscriptToShell(wide[0..n]);
        app_state.g_voice_auto_sending = false;
        app_state.g_voice_state = if (another_open) .listening else .waiting;
        if (skipped) showHeaderNoticeAscii("Skipped reading the last reply (you were talking)", 3500, false);
    } else if (!app_state.g_chat_active) {
        if (voicePasteTranscriptToShellNoEnter(wide[0..n])) {
            showHeaderNoticeAscii("Voice text added, press Enter to send", 4000, false);
        } else {
            const pending = &app_state.g_voice_deferred_text[result.id % app_state.g_voice_deferred_text.len];
            pending.shell_id = target_shell_id;
            pending.len = n;
            @memcpy(pending.text[0..n], wide[0..n]);
            showHeaderNoticeAscii("Voice text not added, switch back to this tab to retry", 4000, true);
        }
    } else showHeaderNoticeAscii("Voice text added, press Enter to send", 4000, false);
    invalidateChatHeader();
}

fn readDeepgramApiKey(out: []u8) ?[]const u8 {
    if (out.len == 0) return null;
    var len: usize = readUserEnvRegistryAscii("DEEPGRAM_API_KEY", out);
    while (len > 0 and (out[len - 1] == ' ' or out[len - 1] == '\r' or out[len - 1] == '\n' or out[len - 1] == '\t')) len -= 1;
    return if (len == 0) null else out[0..len];
}

pub fn logDeepgramKeySource() void {
    var key_buf: [256]u8 = undefined;
    debugLog(if (readDeepgramApiKey(&key_buf) != null) "[voice] deepgram key source=registry" else "[voice] deepgram key source=none");
}

fn readUserEnvRegistryAscii(comptime name: []const u8, out: []u8) usize {
    var wide: [512]u16 = undefined;
    var size: DWORD = @intCast(wide.len * 2);
    const RRF_RT_REG_SZ: DWORD = 0x00000002;
    if (RegGetValueW(HKEY_CURRENT_USER, L("Environment"), L(name), RRF_RT_REG_SZ, null, &wide, &size) != 0) return 0;
    const n: usize = @min(size / 2, wide.len);
    var len: usize = 0;
    for (wide[0..n]) |c| {
        if (c == 0) break;
        if (c > 0x7F or len >= out.len) return 0;
        out[len] = @intCast(c);
        len += 1;
    }
    return len;
}

pub fn asciiToWideZ(src: []const u8, out: []u16) ?[*:0]const u16 {
    if (src.len + 1 > out.len) return null;
    for (src, 0..) |c, i| out[i] = c;
    out[src.len] = 0;
    return out[0..src.len :0].ptr;
}

fn dictationSetErrorAscii(msg: []const u8) void {
    while (!app_state.g_dictation_mutex.tryLock()) Sleep(0);
    defer app_state.g_dictation_mutex.unlock();
    app_state.g_dictation_transcript_len = 0;
    app_state.g_dictation_error_len = @min(msg.len, app_state.g_dictation_error.len - 1);
    for (msg[0..app_state.g_dictation_error_len], 0..) |c, i| app_state.g_dictation_error[i] = c;
    app_state.g_dictation_error[app_state.g_dictation_error_len] = 0;
}

pub fn dictationAudit(stage: []const u8, value: usize) void {
    var path_buf: [512]u8 = undefined;
    const appdata_len = GetEnvironmentVariableA("APPDATA", &path_buf, path_buf.len);
    if (appdata_len == 0 or appdata_len >= 470) return;
    const suffix = "\\ZigShell\\dictation-audit.log";
    const start: usize = @intCast(appdata_len);
    if (start + suffix.len >= path_buf.len) return;
    @memcpy(path_buf[start .. start + suffix.len], suffix);
    const h = win32OpenAppend(path_buf[0 .. start + suffix.len]) orelse return;
    defer _ = CloseHandle(h);
    writeAuditU64(h, GetTickCount64());
    win32WriteAll(h, "\t");
    win32WriteAll(h, stage);
    win32WriteAll(h, "\t");
    writeAuditU64(h, value);
    win32WriteAll(h, "\n");
}

fn dictationSetTranscriptUtf8(text: []const u8) bool {
    while (!app_state.g_dictation_mutex.tryLock()) Sleep(0);
    defer app_state.g_dictation_mutex.unlock();
    app_state.g_dictation_error_len = 0;
    const converted = MultiByteToWideChar(CP_UTF8, 0, text.ptr, @intCast(text.len), @ptrCast(&app_state.g_dictation_transcript), @intCast(app_state.g_dictation_transcript.len - 1));
    if (converted <= 0) {
        app_state.g_dictation_transcript_len = 0;
        return false;
    }
    app_state.g_dictation_transcript_len = @intCast(converted);
    app_state.g_dictation_transcript[app_state.g_dictation_transcript_len] = 0;
    return true;
}

fn deepgramTranscript(value: std.json.Value, out: []u8) usize {
    switch (value) {
        .object => |obj| {
            var it = obj.iterator();
            while (it.next()) |entry| {
                if (std.mem.eql(u8, entry.key_ptr.*, "transcript")) {
                    if (json_reader.string(entry.value_ptr.*)) |text| {
                        const n = @min(text.len, out.len);
                        if (n > 0) {
                            @memcpy(out[0..n], text[0..n]);
                            return n;
                        }
                    }
                }
                const n = deepgramTranscript(entry.value_ptr.*, out);
                if (n > 0) return n;
            }
        },
        .array => |items| for (items.items) |item| {
            const n = deepgramTranscript(item, out);
            if (n > 0) return n;
        },
        else => {},
    }
    return 0;
}

fn parseDeepgramTranscript(json: []const u8, out: []u8) usize {
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch return 0;
    defer parsed.deinit();
    return deepgramTranscript(parsed.value, out);
}

fn dictationFixtureEnabled() bool {
    var value: [520]u8 = undefined;
    inline for (.{ .{ "GITHUB_ACTIONS", "true" }, .{ "RUNNER_OS", "Windows" }, .{ "MULTIPROMPT_NO_LOGIN", "1" } }) |entry| {
        const n = GetEnvironmentVariableA(entry[0], &value, value.len);
        if (n != entry[1].len or !std.mem.eql(u8, value[0..n], entry[1])) return false;
    }
    const n = GetEnvironmentVariableA("MULTIPROMPT_DICTATION_FIXTURE", &value, value.len);
    return n > 0 and n < value.len;
}

fn readDictationFixture(name: []const u8, out: []u8) usize {
    var root: [520]u8 = undefined;
    const n = GetEnvironmentVariableA("MULTIPROMPT_DICTATION_FIXTURE", &root, root.len);
    if (n == 0 or n >= root.len) return 0;
    var path: [600]u8 = undefined;
    const file = std.fmt.bufPrint(&path, "{s}\\{s}", .{ root[0..n], name }) catch return 0;
    const handle = @import("file_io.zig").win32OpenRead(file) orelse return 0;
    defer _ = CloseHandle(handle);
    return @import("file_io.zig").win32ReadAll(handle, out);
}

fn publishDictationLevel(pcm: []const u8) void {
    const samples = std.mem.bytesAsSlice(i16, pcm[0 .. pcm.len - pcm.len % 2]);
    const level: u32 = @intFromFloat(@min(1000, pcmFrameRms(samples) * 1000 / 8192));
    app_state.g_dictation_level.store(level, .release);
}

fn captureDictationPcm(out: []u8) usize {
    if (dictationFixtureEnabled()) {
        const n = readDictationFixture("goforward.pcm", out);
        dictationAudit("fixture-audio-bytes", n);
        var cursor: usize = 0;
        while (app_state.g_dictation_recording.load(.acquire)) {
            const end = @min(cursor + DICTATION_CHUNK_BYTES, n);
            publishDictationLevel(out[cursor..end]);
            cursor = if (end == n) 0 else end;
            Sleep(100);
        }
        return n;
    }

    const event = CreateEventW(null, 0, 0, null);
    if (event == null) return 0;
    defer _ = CloseHandle(event);

    const fmt = WAVEFORMATEX{
        .wFormatTag = WAVE_FORMAT_PCM,
        .nChannels = 1,
        .nSamplesPerSec = DICTATION_SAMPLE_RATE,
        .nAvgBytesPerSec = DICTATION_SAMPLE_RATE * 2,
        .nBlockAlign = 2,
        .wBitsPerSample = 16,
        .cbSize = 0,
    };

    var hw: HWAVEIN = null;
    if (waveInOpen(&hw, WAVE_MAPPER, &fmt, @intFromPtr(event), 0, CALLBACK_EVENT) != 0 or hw == null) return 0;
    defer _ = waveInClose(hw);

    var buffers: [DICTATION_BUFFER_COUNT][DICTATION_CHUNK_BYTES]u8 = undefined;
    var headers: [DICTATION_BUFFER_COUNT]WAVEHDR = undefined;
    for (0..DICTATION_BUFFER_COUNT) |i| {
        headers[i] = std.mem.zeroes(WAVEHDR);
        headers[i].lpData = &buffers[i];
        headers[i].dwBufferLength = DICTATION_CHUNK_BYTES;
        if (waveInPrepareHeader(hw, &headers[i], @sizeOf(WAVEHDR)) != 0) return 0;
        if (waveInAddBuffer(hw, &headers[i], @sizeOf(WAVEHDR)) != 0) return 0;
    }

    if (waveInStart(hw) != 0) {
        _ = waveInReset(hw);
        for (0..DICTATION_BUFFER_COUNT) |i| _ = waveInUnprepareHeader(hw, &headers[i], @sizeOf(WAVEHDR));
        return 0;
    }

    var pos: usize = 0;
    while (app_state.g_dictation_recording.load(.acquire) and pos < out.len) {
        _ = WaitForSingleObject(event, 100);
        for (0..DICTATION_BUFFER_COUNT) |i| {
            if ((headers[i].dwFlags & WHDR_DONE) == 0) continue;
            const n = @min(@as(usize, @intCast(headers[i].dwBytesRecorded)), out.len - pos);
            if (n > 0 and headers[i].lpData != null) {
                const src = headers[i].lpData.?[0..n];
                publishDictationLevel(src);
                @memcpy(out[pos .. pos + n], src);
                pos += n;
                if (app_state.g_voice_listening_active.load(.acquire) and n >= 2) {
                    const samples = std.mem.bytesAsSlice(i16, src[0 .. n - (n % 2)]);
                    const frame_ms: u32 = @intCast((n * 1000) / (2 * DICTATION_SAMPLE_RATE));
                    if (vadStep(&app_state.g_voice_vad_state, pcmFrameRms(samples), frame_ms) != .continue_listening) {
                        app_state.g_dictation_recording.store(false, .release);
                    }
                }
            }
            _ = waveInUnprepareHeader(hw, &headers[i], @sizeOf(WAVEHDR));
            headers[i].dwFlags = 0;
            headers[i].dwBytesRecorded = 0;
            _ = waveInPrepareHeader(hw, &headers[i], @sizeOf(WAVEHDR));
            _ = waveInAddBuffer(hw, &headers[i], @sizeOf(WAVEHDR));
        }
    }

    app_state.g_dictation_recording.store(false, .release);
    _ = waveInStop(hw);
    _ = waveInReset(hw);
    for (0..DICTATION_BUFFER_COUNT) |i| {
        if ((headers[i].dwFlags & WHDR_DONE) != 0 and pos < out.len) {
            const n = @min(@as(usize, @intCast(headers[i].dwBytesRecorded)), out.len - pos);
            if (n > 0 and headers[i].lpData != null) {
                const src = headers[i].lpData.?[0..n];
                @memcpy(out[pos .. pos + n], src);
                pos += n;
            }
        }
        _ = waveInUnprepareHeader(hw, &headers[i], @sizeOf(WAVEHDR));
    }
    return pos;
}

fn deepgramTranscribePcm(audio: []const u8, transcript_out: []u8) DictationHttpResult {
    if (dictationFixtureEnabled()) {
        const expected = std.heap.page_allocator.alloc(u8, audio.len + 1) catch return .{};
        defer std.heap.page_allocator.free(expected);
        const expected_len = readDictationFixture("goforward.pcm", expected);
        if (audio.len == 0 or !std.mem.eql(u8, audio, expected[0..expected_len])) return .{};
        var response: [65536]u8 = undefined;
        const n = readDictationFixture("response.json", &response);
        dictationAudit("fixture-response-bytes", n);
        return .{ .transcript_len = parseDeepgramTranscript(response[0..n], transcript_out), .status = 200 };
    }

    var key_buf: [256]u8 = undefined;
    const key = readDeepgramApiKey(&key_buf) orelse return .{};

    const session = WinHttpOpen(L("multiprompt Dictation"), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (session == null) return .{};
    defer _ = WinHttpCloseHandle(session);
    _ = WinHttpSetTimeouts(session, 8000, 8000, 30000, 30000);

    const http_connect = WinHttpConnect(session, DEEPGRAM_HOST, INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (http_connect == null) return .{};
    defer _ = WinHttpCloseHandle(http_connect);

    const request = WinHttpOpenRequest(
        http_connect,
        L("POST"),
        if (DEEPGRAM_MIP_OPT_OUT) L("/v1/listen?model=nova-3&smart_format=true&punctuate=true&encoding=linear16&sample_rate=16000&channels=1&mip_opt_out=true") else L("/v1/listen?model=nova-3&smart_format=true&punctuate=true&encoding=linear16&sample_rate=16000&channels=1"),
        null,
        null,
        null,
        WINHTTP_FLAG_SECURE,
    );
    if (request == null) return .{};
    defer _ = WinHttpCloseHandle(request);

    var header_ascii: [420]u8 = undefined;
    const headers = std.fmt.bufPrint(&header_ascii, "Authorization: Token {s}\r\nContent-Type: audio/raw\r\n", .{key}) catch return .{};
    var header_wide: [420]u16 = undefined;
    const header_z = asciiToWideZ(headers, &header_wide) orelse return .{};
    if (WinHttpAddRequestHeaders(request, header_z, 0xFFFFFFFF, WINHTTP_ADDREQ_FLAG_ADD) == 0) return .{};

    if (audio.len > std.math.maxInt(DWORD)) return .{};
    const audio_len: DWORD = @intCast(audio.len);
    if (WinHttpSendRequest(request, null, 0, @ptrCast(@constCast(audio.ptr)), audio_len, audio_len, 0) == 0) return .{};
    if (WinHttpReceiveResponse(request, null) == 0) return .{};

    var status: DWORD = 0;
    var status_size: DWORD = @sizeOf(DWORD);
    _ = WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, null, &status, &status_size, null);

    var json_buf: [65536]u8 = undefined;
    var json_len: usize = 0;
    while (json_len < json_buf.len) {
        var avail: DWORD = 0;
        if (WinHttpQueryDataAvailable(request, &avail) == 0 or avail == 0) break;
        const want: DWORD = @intCast(@min(@as(usize, @intCast(avail)), json_buf.len - json_len));
        var got: DWORD = 0;
        if (WinHttpReadData(request, @ptrCast(&json_buf[json_len]), want, &got) == 0 or got == 0) break;
        json_len += @intCast(got);
    }
    return .{ .transcript_len = parseDeepgramTranscript(json_buf[0..json_len], transcript_out), .status = status };
}

fn dictationWorkerThread() void {
    crash_recorder.guardThread();
    const audio = std.heap.page_allocator.alloc(u8, DICTATION_MAX_BYTES) catch {
        dictationSetErrorAscii("Dictation failed: out of memory");
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_READY, 0, 0);
        return;
    };
    defer std.heap.page_allocator.free(audio);

    app_state.g_dictation_capturing.store(true, .release);
    const audio_len = captureDictationPcm(audio);
    app_state.g_dictation_capturing.store(false, .release);
    dictationAudit("audio-bytes", audio_len);
    if (app_state.g_dictation_cancelled.load(.acquire)) {
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_READY, 0, 0);
        return;
    }
    if (audio_len < 1600) {
        dictationSetErrorAscii("Dictation failed: no audio captured");
        if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_READY, 0, 0);
        return;
    }

    var transcript_utf8: [8192]u8 = undefined;
    const result = deepgramTranscribePcm(audio[0..audio_len], &transcript_utf8);
    dictationAudit("transcript-utf8-bytes", result.transcript_len);
    dictationAudit("http-status", @intCast(result.status));
    if (result.transcript_len == 0 or !dictationSetTranscriptUtf8(transcript_utf8[0..result.transcript_len])) {
        if (result.status == 0) {
            dictationSetErrorAscii("Dictation failed: could not reach Deepgram");
        } else if (result.status == 401 or result.status == 403) {
            dictationSetErrorAscii("Dictation failed: Deepgram rejected the key");
        } else if (result.status != 200) {
            var status_msg: [48]u8 = undefined;
            const msg: []const u8 = std.fmt.bufPrint(&status_msg, "Dictation failed: Deepgram error ({d})", .{result.status}) catch "Dictation failed: Deepgram error";
            dictationSetErrorAscii(msg);
        } else {
            dictationSetErrorAscii("Dictation failed: no transcript returned");
        }
    }
    if (app_state.g_main_hwnd != null) _ = PostMessageW(app_state.g_main_hwnd, WM_APP_DICTATION_READY, 0, 0);
}

pub fn synthesizeCtrlVIntoForeground() void {
    const VK_CONTROL_U8: u8 = 0x11;
    const VK_V_U8: u8 = 0x56;
    const SCAN_CONTROL: u8 = 0x1D;
    const SCAN_V: u8 = 0x2F;
    const KEYUP: DWORD = 0x0002;
    app_state.g_native_paste_passthrough_until = GetTickCount64() + 1000;
    const ctrl_down = isCtrlDown();
    if (!ctrl_down) keybd_event(VK_CONTROL_U8, SCAN_CONTROL, 0, 0);
    keybd_event(VK_V_U8, SCAN_V, 0, 0);
    keybd_event(VK_V_U8, SCAN_V, KEYUP, 0);
    if (!ctrl_down) keybd_event(VK_CONTROL_U8, SCAN_CONTROL, KEYUP, 0);
}

fn dictationTargetIsBrowser() bool {
    if (activeBrowserSurfaceHasForegroundFocus()) return true;
    return app_state.g_browser_focus_mode and (activeBrowserHwndLive() != null or webView2OwnsActiveShell());
}

fn trimDictationText(text: []const u16) []const u16 {
    var start: usize = 0;
    while (start < text.len and switch (text[start]) {
        ' ', '\t', '\r', '\n' => true,
        else => false,
    }) : (start += 1) {}

    var end = text.len;
    while (end > start and switch (text[end - 1]) {
        ' ', '\t', '\r', '\n' => true,
        else => false,
    }) : (end -= 1) {}
    return text[start..end];
}

fn appendDictationComparable(input: []const u16, out: []u16, pos: *usize) void {
    for (input) |raw| {
        var c = raw;
        if (c >= 'A' and c <= 'Z') c += 'a' - 'A';
        const ascii_word = (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9');
        const decoration = (c >= 0x2500 and c <= 0x259F) or (c >= 0xE000 and c <= 0xF8FF);
        if (!ascii_word and (c <= 0x7F or decoration)) continue;
        if (pos.* >= out.len) return;
        out[pos.*] = c;
        pos.* += 1;
    }
}

fn countDictationComparableOccurrences(haystack: []const u16, needle: []const u16) usize {
    if (needle.len == 0 or haystack.len < needle.len) return 0;
    var count: usize = 0;
    var start: usize = 0;
    while (start + needle.len <= haystack.len) : (start += 1) {
        if (std.mem.eql(u16, haystack[start .. start + needle.len], needle)) count += 1;
    }
    return count;
}

fn dictationOutputShowsNewText(before: []const u16, after: []const u16, transcript: []const u16) bool {
    var expected: [8192]u16 = undefined;
    var expected_len: usize = 0;
    appendDictationComparable(transcript, &expected, &expected_len);
    if (expected_len == 0) return false;
    const expected_slice = expected[0..expected_len];
    return countDictationComparableOccurrences(after, expected_slice) >
        countDictationComparableOccurrences(before, expected_slice);
}

fn readShellViewportComparable(shell_index: u32, out: []u16) ?usize {
    if (shell_index >= app_state.shell_count) return null;
    const pid = app_state.shells[shell_index].pid;
    if (pid == 0) return null;

    _ = FreeConsole();
    if (AttachConsole(pid) == 0) return null;
    defer _ = FreeConsole();

    const handle = openAttachedConsoleOutput() orelse return null;
    defer _ = CloseHandle(handle);
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;

    const width_i32 = @as(i32, info.srWindow.right) - @as(i32, info.srWindow.left) + 1;
    if (width_i32 <= 0) return null;
    const read_width: DWORD = @intCast(@min(width_i32, 1024));
    var line: [1024]u16 = undefined;
    var out_len: usize = 0;
    var row: i32 = info.srWindow.top;
    const bottom: i32 = info.srWindow.bottom;
    while (row <= bottom and out_len < out.len) : (row += 1) {
        var chars_read: DWORD = 0;
        const coord = COORD{ .x = info.srWindow.left, .y = @intCast(row) };
        if (ReadConsoleOutputCharacterW(handle, &line, read_width, coord, &chars_read) == 0) continue;
        appendDictationComparable(line[0..@intCast(chars_read)], out, &out_len);
    }
    return out_len;
}

fn pasteDictationToShellVerified(shell_index: u32, transcript: []const u16) DictationShellPasteResult {
    var before: [32768]u16 = undefined;
    const before_len = readShellViewportComparable(shell_index, &before) orelse 0;

    if (!pasteTextToShellDirect(shell_index, transcript)) return .delivery_failed;
    dictationAudit("shell-vk-packet-written", transcript.len);

    var attempt: u8 = 0;
    while (attempt < 30) : (attempt += 1) {
        Sleep(50);
        var after: [32768]u16 = undefined;
        const after_len = readShellViewportComparable(shell_index, &after) orelse continue;
        if (dictationOutputShowsNewText(before[0..before_len], after[0..after_len], transcript)) {
            return .verified;
        }
    }
    return .output_unverified;
}

test "dictation ignores provider edge whitespace without changing spoken content" {
    const padded = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '\r', '\n' };
    try std.testing.expectEqualSlices(u16, &[_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' }, trimDictationText(&padded));
    try std.testing.expectEqual(@as(usize, 0), trimDictationText(&[_]u16{ ' ', '\t', '\r', '\n' }).len);
}

test "dictation verification ignores TUI framing and requires new console text" {
    const spoken = [_]u16{ 'F', 'i', 'x', ' ', 't', 'h', 'i', 's', '!' };
    const before = [_]u16{ 'o', 'l', 'd', 't', 'e', 'x', 't' };
    const after = [_]u16{ 'o', 'l', 'd', 't', 'e', 'x', 't', 0x2502, 'f', 'i', 'x', 0x2502, 't', 'h', 'i', 's' };
    var normalized: [32]u16 = undefined;
    var normalized_len: usize = 0;
    appendDictationComparable(&after, &normalized, &normalized_len);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 'o', 'l', 'd', 't', 'e', 'x', 't', 'f', 'i', 'x', 't', 'h', 'i', 's' }, normalized[0..normalized_len]);
    try std.testing.expectEqual(true, dictationOutputShowsNewText(&before, normalized[0..normalized_len], &spoken));
    try std.testing.expectEqual(false, dictationOutputShowsNewText(normalized[0..normalized_len], normalized[0..normalized_len], &spoken));
}

pub fn cancelDictation() void {
    if (!app_state.g_dictation_running.load(.acquire)) return;
    app_state.g_dictation_cancelled.store(true, .release);
    app_state.g_dictation_send_on_ready = false;
    app_state.g_dictation_recording.store(false, .release);
    app_state.g_dictation_level.store(0, .release);
    app_state.g_dictation_draft_owner_len = 0;
    @import("chat_composer.zig").chatDictationSync();
    dictationAudit("cancel", 0);
    showHeaderNoticeAscii("Dictation cancelled", 2200, false);
}

pub fn handleDictationReady() void {
    @import("chat_composer.zig").chatDictationSync();
    defer @import("chat_composer.zig").chatDictationSync();
    app_state.g_dictation_recording.store(false, .release);
    app_state.g_dictation_running.store(false, .release);
    const send_on_ready = app_state.g_dictation_send_on_ready;
    app_state.g_dictation_send_on_ready = false;
    app_state.g_dictation_level.store(0, .release);
    var text_copy: [8192]u16 = undefined;
    var text_len: usize = 0;
    var err_copy: [160]u16 = undefined;
    var err_len: usize = 0;
    while (!app_state.g_dictation_mutex.tryLock()) Sleep(0);
    {
        defer app_state.g_dictation_mutex.unlock();
        text_len = @min(app_state.g_dictation_transcript_len, text_copy.len - 1);
        if (text_len > 0) @memcpy(text_copy[0..text_len], app_state.g_dictation_transcript[0..text_len]);
        text_copy[text_len] = 0;
        err_len = @min(app_state.g_dictation_error_len, err_copy.len - 1);
        if (err_len > 0) @memcpy(err_copy[0..err_len], app_state.g_dictation_error[0..err_len]);
        err_copy[err_len] = 0;
        app_state.g_dictation_transcript_len = 0;
        app_state.g_dictation_error_len = 0;
    }

    const was_voice_listening = app_state.g_voice_listening_active.load(.acquire);
    app_state.g_voice_listening_active.store(false, .release);
    const discard_legacy = app_state.g_voice_legacy_discard;
    app_state.g_voice_legacy_discard = false;
    if (app_state.g_dictation_cancelled.load(.acquire)) {
        if (was_voice_listening) {
            app_state.g_voice_state = .idle;
            invalidateChatHeader();
        }
        app_state.g_dictation_cancelled.store(false, .release);
        app_state.g_dictation_draft_owner_len = 0;
        dictationAudit("cancelled", 0);
        return;
    }

    if (was_voice_listening and (discard_legacy or !app_state.g_voice_mode_active or !duplex.voiceLegacyResultAllowed(app_state.g_voice_always_listen, app_state.g_voice_mic_failed))) {
        dictationAudit("voice-dropped-mode-off", text_len);
        return;
    }

    if (was_voice_listening) app_state.g_voice_last_activity_tick = GetTickCount64();
    const transcript = trimDictationText(text_copy[0..text_len]);
    if (transcript.len == 0) {
        if (was_voice_listening) {
            app_state.g_voice_state = .idle;
            invalidateChatHeader();
        }
        dictationAudit("empty-transcript", err_len);
        if (err_len > 0) {
            app_state.g_cap_msg_len = @min(err_len, app_state.g_cap_msg_text.len - 1);
            @memcpy(app_state.g_cap_msg_text[0..app_state.g_cap_msg_len], err_copy[0..app_state.g_cap_msg_len]);
            app_state.g_cap_msg_text[app_state.g_cap_msg_len] = 0;
            app_state.g_cap_msg_until = GetTickCount64() + 5000;
            if (app_state.g_main_hwnd != null) {
                _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
                _ = SetTimer(app_state.g_main_hwnd, TIMER_CAP_MSG, 5100, null);
            }
        } else {
            showHeaderNoticeAscii("Dictation failed: no speech detected", 5000, true);
        }
        return;
    }

    rememberLastPasteText(transcript);

    if (was_voice_listening) {
        dictationAudit("voice-send", transcript.len);
        app_state.g_voice_state = .sending;
        invalidateChatHeader();
        if (app_state.g_chat_active and app_state.g_chat_composer_hwnd != null) {
            insertTextIntoChatComposer(transcript);
            sendChatPrompt();
        } else {
            _ = voiceSendTranscriptToShell(transcript);
        }
        app_state.g_voice_state = .waiting;
        invalidateChatHeader();
        return;
    }

    if (app_state.g_dictation_draft_owner_len > 0) {
        @import("chat_composer.zig").chatDraftAppend(app_state.g_dictation_draft_owner[0..app_state.g_dictation_draft_owner_len], transcript);
        dictationAudit("target-chat-composer", transcript.len);
        var owner: [app_state.CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        if (send_on_ready and app_state.g_chat_active and std.mem.eql(u8, app_state.g_dictation_draft_owner[0..app_state.g_dictation_draft_owner_len], @import("chat_composer.zig").chatDraftKeyForShell(app_state.active_shell, &owner))) {
            sendChatPrompt();
        }
        return;
    }

    if (dictationTargetIsBrowser()) {
        dictationAudit("target-browser", transcript.len);
        if (!setUnicodeClipboardTextWithRetry(transcript)) {
            showHeaderNoticeAscii("Dictation failed: clipboard unavailable", 5000, true);
            return;
        }
        debugLog("dictation: paste target browser");
        focusActiveBrowserPane();
        Sleep(50);
        synthesizeCtrlVIntoForeground();
        showHeaderNoticeAscii("Dictation pasted", 2200, false);
    } else if (app_state.active_shell < app_state.shell_count) {
        dictationAudit("target-shell", transcript.len);
        debugLog("dictation: paste target shell");
        if (!setUnicodeClipboardTextWithRetry(transcript)) {
            showHeaderNoticeAscii("Dictation failed: clipboard unavailable", 5000, true);
            return;
        }
        const paste_result = pasteDictationToShellVerified(app_state.active_shell, transcript);
        if (paste_result != .delivery_failed) @import("inbox.zig").stampSessionUse(app_state.active_shell, false);
        preserveClipboardTextAfterPaste(transcript);
        switch (paste_result) {
            .verified => {
                dictationAudit("shell-output-verified", transcript.len);
                showHeaderNoticeAscii("Dictation pasted", 2200, false);
            },
            .delivery_failed => {
                dictationAudit("shell-vk-packet-failed", transcript.len);
                showHeaderNoticeAscii("Dictation copied: console rejected input", 5000, true);
            },
            .output_unverified => {
                dictationAudit("shell-output-unverified", transcript.len);
                showHeaderNoticeAscii("Dictation copied: console did not confirm paste", 5000, true);
            },
        }
    } else {
        dictationAudit("target-foreground-fallback", transcript.len);
        if (!setUnicodeClipboardTextWithRetry(transcript)) {
            showHeaderNoticeAscii("Dictation failed: clipboard unavailable", 5000, true);
            return;
        }
        debugLog("dictation: paste target foreground fallback");
        synthesizeCtrlVIntoForeground();
        showHeaderNoticeAscii("Dictation pasted", 2200, false);
    }
}

pub fn toggleDictation() void {
    defer @import("chat_composer.zig").chatDictationSync();
    if (app_state.g_voice_mode_active and app_state.g_voice_always_listen and !app_state.g_voice_mic_failed and app_state.g_voice_mic_run.load(.acquire)) {
        showHeaderNoticeAscii("Voice Mode is already listening", 3000, false);
        return;
    }
    app_state.g_dictation_enter_stop_queued.store(false, .release);
    if (app_state.g_dictation_recording.load(.acquire)) {
        app_state.g_dictation_recording.store(false, .release);
        dictationAudit("stop", 0);
        showHeaderNoticeAscii("Dictation transcribing...", 60000, false);
        return;
    }
    if (app_state.g_dictation_running.load(.acquire)) {
        showHeaderNoticeAscii("Dictation already transcribing...", 3000, false);
        return;
    }
    var key_buf: [256]u8 = undefined;
    if (!dictationFixtureEnabled() and readDeepgramApiKey(&key_buf) == null) {
        showHeaderNoticeAscii("Set DEEPGRAM_API_KEY to use dictation", 5000, true);
        return;
    }
    if (app_state.g_voice_mode_active and app_state.g_voice_state == .speaking) {
        dictationAudit("voice-stop", 5);
        voiceStopSpeaking();
        app_state.g_voice_state = .idle;
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_VOICE_POLL);
        invalidateChatHeader();
    }
    while (!app_state.g_dictation_mutex.tryLock()) Sleep(0);
    {
        defer app_state.g_dictation_mutex.unlock();
        app_state.g_dictation_transcript_len = 0;
        app_state.g_dictation_error_len = 0;
    }
    app_state.g_dictation_draft_owner_len = 0;
    if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count) {
        const id = @import("chat_composer.zig").chatDraftKeyForShell(app_state.active_shell, &app_state.g_dictation_draft_owner);
        app_state.g_dictation_draft_owner_len = id.len;
    }
    app_state.g_dictation_start_tick = GetTickCount64();
    app_state.g_dictation_level.store(0, .release);
    app_state.g_dictation_cancelled.store(false, .release);
    app_state.g_dictation_send_on_ready = false;
    app_state.g_dictation_recording.store(true, .release);
    app_state.g_dictation_running.store(true, .release);
    dictationAudit("start", if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].shell_id else 0);
    const t = std.Thread.spawn(.{}, dictationWorkerThread, .{}) catch {
        app_state.g_dictation_recording.store(false, .release);
        app_state.g_dictation_running.store(false, .release);
        showHeaderNoticeAscii("Dictation failed: could not start worker", 5000, true);
        return;
    };
    t.detach();
    showHeaderNoticeAscii("Dictation recording - Ctrl+Shift+Space to stop", 60000, false);
}
