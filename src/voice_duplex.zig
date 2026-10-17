const std = @import("std");

pub const VoiceState = enum { idle, speaking, listening, sending, waiting };

pub const AecState = enum { unknown, on, off, absent };
pub const EchoPath = enum { unknown, clean, echoey };
pub const AudioEffect = struct { id: [16]u8, state: i32 };
pub const aec_id = [16]u8{ 0xBE, 0xAD, 0x64, 0x6F, 0x11, 0x82, 0xE2, 0x11, 0x8C, 0x70, 0x2C, 0x27, 0xD7, 0xF0, 0x01, 0xFA };

pub fn effectsAecState(effects: []const AudioEffect) AecState {
    for (effects) |effect| if (std.mem.eql(u8, &effect.id, &aec_id)) {
        return if (effect.state == 1) .on else .off;
    };
    return .absent;
}

pub const NoiseFloor = struct {
    value: f32 = 100,
    pub fn step(self: *NoiseFloor, rms: f32) void {
        const rate: f32 = if (rms > self.value) 0.002 else 0.12;
        self.value += (rms - self.value) * rate;
    }
};

pub const TTS_ECHO_LEARN_FRAMES: u32 = 20;
pub const TtsEchoPeak = struct {
    value: f32 = 100,
    frames: u32 = 0,
    pub fn step(self: *TtsEchoPeak, rms: f32, threshold: f32) void {
        self.frames +|= 1;
        const learning = self.frames <= TTS_ECHO_LEARN_FRAMES;
        if (!learning and rms >= threshold) return;
        const rise: f32 = if (learning) 0.6 else 0.05;
        const rate: f32 = if (rms > self.value) rise else 0.002;
        self.value += (rms - self.value) * rate;
    }
};

pub fn voiceResultMatchesSlot(slot_id: u32, result_id: u32) bool {
    return slot_id != 0 and slot_id == result_id;
}

pub fn utteranceAtCapacity(speech_ms: u32) bool {
    return speech_ms >= 300;
}

pub fn voiceShouldAutoOff(always_listen: bool, working: bool, speaking: bool, quiet_ms: u64) bool {
    return always_listen and !working and !speaking and quiet_ms >= 600000;
}

pub fn voiceLegacyResultAllowed(always_listen: bool, mic_failed: bool) bool {
    return !always_listen or mic_failed;
}

pub fn voiceShouldStartLegacyListening(always_listen: bool, mic_failed: bool, state: VoiceState) bool {
    return voiceLegacyResultAllowed(always_listen, mic_failed) and state == .idle;
}

pub fn voiceQuietTick(now: u64, previous: u64, working: bool, speaking: bool) u64 {
    return if (working or speaking) now else previous;
}

pub fn classifyEchoPath(idle: f32, tts: f32, tts_ms: u32) EchoPath {
    if (tts_ms < 3000) return .unknown;
    return if (tts <= 2 * @max(idle, 1)) .clean else .echoey;
}

pub fn bargeInThreshold(idle: f32, tts: f32, audible: bool, aec: AecState, ms_into_reply: u32) f32 {
    const base = @max(500, 3 * idle);
    if (!audible) return base;
    const echo_gate = if (aec == .on and tts <= 2 * @max(idle, 1)) base else @max(base, 2.5 * tts);
    return echo_gate * (if (ms_into_reply < 400) @as(f32, 1.6) else 1);
}

pub const OnsetDetector = struct {
    high_ms: u32 = 0,
    gap_ms: u32 = 0,
    pub fn step(self: *OnsetDetector, rms: f32, frame_ms: u32, threshold: f32, ms_since_key: u32, continuous: bool) bool {
        if (ms_since_key < 400) {
            self.* = .{};
            return false;
        }
        if (rms >= threshold) {
            self.high_ms +|= frame_ms;
            self.gap_ms = 0;
        } else {
            self.gap_ms +|= frame_ms;
            if (continuous or self.gap_ms > 20) self.* = .{};
        }
        if (self.high_ms < 200) return false;
        self.* = .{};
        return true;
    }
};

pub const UtteranceTracker = struct {
    next_id: u32 = 0,
    id: u32 = 0,
    elapsed_ms: u32 = 0,
    silence_ms: u32 = 0,
    speech_ms: u32 = 0,
    pub fn open(self: *UtteranceTracker) u32 {
        self.next_id +%= 1;
        if (self.next_id == 0) self.next_id = 1;
        self.id = self.next_id;
        self.elapsed_ms = 0;
        self.silence_ms = 0;
        self.speech_ms = 200;
        return self.id;
    }
    pub fn step(self: *UtteranceTracker, rms: f32, threshold: f32, frame_ms: u32) ?bool {
        if (self.id == 0) return null;
        self.elapsed_ms +|= frame_ms;
        if (rms >= threshold) {
            self.speech_ms +|= frame_ms;
            self.silence_ms = 0;
        } else self.silence_ms +|= frame_ms;
        if (self.silence_ms < 1300 and self.elapsed_ms < 60000) return null;
        self.id = 0;
        return self.speech_ms >= 300;
    }
};

pub const PreRoll = struct {
    samples: [9600]i16 = @splat(0),
    pos: usize = 0,
    filled: usize = 0,
    pub fn append(self: *PreRoll, input: []const i16) void {
        for (input) |s| {
            self.samples[self.pos] = s;
            self.pos = (self.pos + 1) % self.samples.len;
            self.filled = @min(self.filled + 1, self.samples.len);
        }
    }
    pub fn copyLast(self: *const PreRoll, out: []align(1) i16, ms: u32) usize {
        const n = @min(@min(out.len, self.filled), @as(usize, ms) * 16);
        for (0..n) |i| out[i] = self.samples[(self.pos + self.samples.len - n + i) % self.samples.len];
        return n;
    }
};

fn nextWord(text: []const u8, pos: *usize) []const u8 {
    while (pos.* < text.len and !std.ascii.isAlphanumeric(text[pos.*])) pos.* += 1;
    const start = pos.*;
    while (pos.* < text.len and std.ascii.isAlphanumeric(text[pos.*])) pos.* += 1;
    return text[start..pos.*];
}
fn wordEq(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

pub fn transcriptEchoesSpokenText(text: []const u8, spoken: []const u8) bool {
    var words: [256][]const u8 = undefined;
    var count: usize = 0;
    var p: usize = 0;
    while (count < words.len) {
        const word = nextWord(text, &p);
        if (word.len == 0) break;
        words[count] = word;
        count += 1;
    }
    if (count < 3) return false;
    var hits: usize = 0;
    for (0..count - 2) |i| {
        var q: usize = 0;
        while (true) {
            const a = nextWord(spoken, &q);
            if (a.len == 0) break;
            const next = q;
            const b = nextWord(spoken, &q);
            const c = nextWord(spoken, &q);
            if (wordEq(a, words[i]) and wordEq(b, words[i + 1]) and wordEq(c, words[i + 2])) {
                hits += 1;
                break;
            }
            q = next;
        }
    }
    return hits * 5 >= (count - 2) * 3;
}

pub fn stripEchoPrefix(text: []const u8, spoken: []const u8) []const u8 {
    var t: usize = 0;
    var s: usize = 0;
    var matched: usize = 0;
    var end: usize = 0;
    while (true) {
        const w = nextWord(text, &t);
        if (w.len == 0) break;
        var found = false;
        while (true) {
            const v = nextWord(spoken, &s);
            if (v.len == 0) break;
            if (wordEq(w, v)) {
                found = true;
                break;
            }
            if (matched != 0) break;
        }
        if (!found) break;
        matched += 1;
        end = t;
    }
    return if (matched >= 3) std.mem.trimStart(u8, text[end..], " \t\r\n,.:;!?") else text;
}

pub const ToggleAction = enum { turn_on, turn_off, stop_speaking };
pub fn voiceToggleAction(active: bool, speaking: bool, force: usize) ToggleAction {
    if (force == 1) return .turn_on;
    if (force == 2) return .turn_off;
    return if (!active) .turn_on else if (speaking) .stop_speaking else .turn_off;
}
pub fn voiceKeyStopsSpeech(vk: u32, alt: bool) bool {
    if (vk >= 0x10 and vk <= 0x12 or vk >= 0xA0 and vk <= 0xA5 or vk == 0x5B or vk == 0x5C) return false;
    return !(alt and vk == 'V');
}
pub const Decision = enum { drop, insert_only, send };
pub const DecisionInput = struct { empty: bool = false, echo: bool = false, typed: bool = false, changed_tab: bool = false, consumed: bool = false };
pub fn voiceUtteranceDecision(input: DecisionInput) Decision {
    if (input.empty or input.echo) return .drop;
    if (input.typed or input.changed_tab or input.consumed) return .insert_only;
    return .send;
}

test "floors, thresholds, onset and utterance lifecycle" {
    var floor = NoiseFloor{};
    for (0..500) |_| floor.step(200);
    try std.testing.expect(floor.value > 160 and floor.value < 200);
    floor.step(20000);
    try std.testing.expect(floor.value < 250);
    var tts = TtsEchoPeak{};
    tts.step(1200, 500);
    try std.testing.expect(tts.value > 700);
    for (1..TTS_ECHO_LEARN_FRAMES) |_| tts.step(1200, 2.5 * tts.value);
    const learned = tts.value;
    try std.testing.expect(learned > 1150 and learned < 1250);
    tts.step(20000, 2.5 * tts.value);
    try std.testing.expectEqual(learned, tts.value);
    for (0..30) |_| floor.step(50);
    try std.testing.expect(floor.value < 100);
    try std.testing.expectEqual(EchoPath.unknown, classifyEchoPath(100, 900, 2999));
    try std.testing.expectEqual(EchoPath.clean, classifyEchoPath(100, 200, 3000));
    try std.testing.expectEqual(EchoPath.echoey, classifyEchoPath(100, 201, 3000));
    try std.testing.expectEqual(@as(f32, 800), bargeInThreshold(100, 200, true, .on, 0));
    try std.testing.expectEqual(@as(f32, 1250), bargeInThreshold(100, 500, true, .absent, 500));
    var onset = OnsetDetector{};
    try std.testing.expect(!onset.step(3000, 20, 500, 100, false));
    for (0..9) |_| try std.testing.expect(!onset.step(3000, 20, 500, 500, false));
    try std.testing.expect(!onset.step(0, 20, 500, 500, false));
    try std.testing.expect(onset.step(3000, 20, 500, 500, false));
    var tracker = UtteranceTracker{};
    const id = tracker.open();
    try std.testing.expectEqual(@as(u32, 1), id);
    try std.testing.expect(tracker.step(2000, 500, 100) == null);
    try std.testing.expect(tracker.step(0, 500, 1299) == null);
    try std.testing.expectEqual(@as(?bool, true), tracker.step(0, 500, 1));
    try std.testing.expect(tracker.step(0, 500, 1300) == null);
    _ = tracker.open();
    try std.testing.expectEqual(@as(?bool, false), tracker.step(0, 500, 1300));
    _ = tracker.open();
    try std.testing.expectEqual(@as(?bool, true), tracker.step(2000, 500, 60000));
}

test "TTS word gaps never trigger talk-over without AEC, but louder speech does" {
    for ([_]AecState{ .absent, .unknown, .off }) |aec| {
        var peak = TtsEchoPeak{};
        var onset = OnsetDetector{};
        for (0..500) |i| {
            const ms: u32 = @intCast(i * 20);
            const rms: f32 = if (i % 15 < 10) 3000 else 300;
            const prior = bargeInThreshold(100, peak.value, true, aec, ms);
            peak.step(rms, prior);
            const gate = bargeInThreshold(100, peak.value, true, aec, ms);
            try std.testing.expect(!onset.step(rms, 20, gate, 1000, true));
        }
        try std.testing.expect(peak.value > 2000);
        var triggered = false;
        for (0..15) |_| {
            const gate = bargeInThreshold(100, peak.value, true, aec, 10000);
            peak.step(9000, gate);
            if (onset.step(9000, 20, bargeInThreshold(100, peak.value, true, aec, 10000), 1000, true)) {
                triggered = true;
                break;
            }
        }
        try std.testing.expect(triggered);
    }
}

test "out of order results still match their own open slots" {
    var slots = [_]u32{ 0, 1, 2, 0 };
    try std.testing.expect(voiceResultMatchesSlot(slots[2], 2));
    slots[2] = 0;
    try std.testing.expect(voiceResultMatchesSlot(slots[1], 1));
    try std.testing.expect(!voiceResultMatchesSlot(slots[2], 2));
    try std.testing.expect(!voiceResultMatchesSlot(slots[1], 5));
}

test "full utterance retains speech and quiet timer ignores agent work" {
    try std.testing.expect(!utteranceAtCapacity(299));
    try std.testing.expect(utteranceAtCapacity(300));
    try std.testing.expect(utteranceAtCapacity(59400));
    try std.testing.expect(!voiceShouldAutoOff(false, false, false, 700000));
    try std.testing.expect(!voiceShouldAutoOff(true, true, false, 700000));
    try std.testing.expect(!voiceShouldAutoOff(true, false, true, 700000));
    try std.testing.expect(!voiceShouldAutoOff(true, false, false, 599999));
    try std.testing.expect(voiceShouldAutoOff(true, false, false, 600000));
    try std.testing.expect(!voiceShouldStartLegacyListening(true, false, .idle));
    try std.testing.expect(voiceShouldStartLegacyListening(true, true, .idle));
    try std.testing.expect(voiceShouldStartLegacyListening(false, false, .idle));
    try std.testing.expect(!voiceShouldStartLegacyListening(false, false, .waiting));
    try std.testing.expect(!voiceLegacyResultAllowed(true, false));
    try std.testing.expect(voiceLegacyResultAllowed(true, true));
    try std.testing.expect(voiceLegacyResultAllowed(false, false));
    try std.testing.expectEqual(@as(u64, 900000), voiceQuietTick(900000, 100, true, false));
    try std.testing.expectEqual(@as(u64, 900000), voiceQuietTick(900000, 100, false, true));
    try std.testing.expectEqual(@as(u64, 100), voiceQuietTick(900000, 100, false, false));
}

fn simulateTalkOver(aec: AecState, idle: f32, echo_hi: f32, echo_lo: f32, echo_frames: usize, user: []const f32, user_frames: usize) ?u32 {
    var peak = TtsEchoPeak{};
    var onset = OnsetDetector{};
    const continuous = aec != .on;
    for (0..echo_frames + user_frames) |i| {
        const ms: u32 = @intCast(i * 20);
        const echo: f32 = if (i % 20 < 14) echo_hi else echo_lo;
        const u: f32 = if (i >= echo_frames and user.len > 0) user[(i - echo_frames) % user.len] else 0;
        const rms = @sqrt(u * u + echo * echo);
        const prior = bargeInThreshold(idle, peak.value, true, aec, ms);
        peak.step(rms, prior);
        const gate = bargeInThreshold(idle, peak.value, true, aec, ms);
        if (onset.step(rms, 20, gate, 5000, continuous)) {
            if (i < echo_frames) return 0;
            return @intCast((i + 1 - echo_frames) * 20);
        }
    }
    return null;
}

test "talk-over with AEC fires within 300 ms on normal varying speech" {
    const normal = [_]f32{ 600, 1500, 2500, 3000, 2000, 3200, 2600, 1800, 3000, 2400 };
    for ([_][2]f32{ .{ 200, 120 }, .{ 400, 150 } }) |echo| {
        const fired = simulateTalkOver(.on, 150, echo[0], echo[1], 100, &normal, 50);
        try std.testing.expect(fired != null);
        try std.testing.expect(fired.? > 0 and fired.? <= 300);
    }
}

test "agent echo alone never fires talk-over without AEC" {
    for ([_]AecState{ .absent, .unknown, .off }) |aec| {
        try std.testing.expectEqual(@as(?u32, null), simulateTalkOver(aec, 150, 3000, 300, 500, &.{}, 0));
    }
}

test "quiet floor under playback tells working AEC from echo" {
    const idle: f32 = 150;
    for ([_][3]f32{ .{ 200, 120, 0 }, .{ 400, 150, 0 }, .{ 3000, 300, 1 } }) |case| {
        var quiet = NoiseFloor{};
        for (0..500) |i| quiet.step(if (i % 20 < 14) case[0] else case[1]);
        const want: EchoPath = if (case[2] == 1) .echoey else .clean;
        try std.testing.expectEqual(want, classifyEchoPath(idle, quiet.value, 10000));
    }
    var peak = TtsEchoPeak{};
    for (0..500) |i| peak.step(if (i % 20 < 14) 400 else 150, bargeInThreshold(idle, peak.value, true, .on, @intCast(i * 20)));
    try std.testing.expectEqual(EchoPath.echoey, classifyEchoPath(idle, peak.value, 10000));
}

test "echo matching sees the full spoken reply past the former 8 KB limit" {
    var spoken: [12000]u8 = @splat(' ');
    const phrase = "words near the very end of this long reply";
    @memcpy(spoken[10000 .. 10000 + phrase.len], phrase);
    try std.testing.expect(transcriptEchoesSpokenText(phrase, &spoken));
    try std.testing.expectEqualStrings("please stop", stripEchoPrefix(phrase ++ ", please stop", &spoken));
}

test "preroll wrap, effects, echo words, toggles and send decisions" {
    var roll = PreRoll{};
    const chunk: [9600]i16 = @splat(1);
    roll.append(&chunk);
    roll.append(&[_]i16{ 2, 3 });
    var out: [4]i16 = undefined;
    try std.testing.expectEqual(@as(usize, 4), roll.copyLast(&out, 200));
    try std.testing.expectEqualSlices(i16, &.{ 1, 1, 2, 3 }, &out);
    try std.testing.expectEqual(AecState.absent, effectsAecState(&.{}));
    try std.testing.expectEqual(AecState.on, effectsAecState(&.{.{ .id = aec_id, .state = 1 }}));
    try std.testing.expectEqual(AecState.off, effectsAecState(&.{.{ .id = aec_id, .state = 0 }}));
    try std.testing.expect(transcriptEchoesSpokenText("Hello, this is THE reply.", "Hello this is the reply"));
    try std.testing.expect(!transcriptEchoesSpokenText("yes stop that", "Hello this is the reply"));
    try std.testing.expectEqualStrings("please wait", stripEchoPrefix("This is the reply, please wait", "This is the reply"));
    try std.testing.expectEqual(ToggleAction.stop_speaking, voiceToggleAction(true, true, 0));
    try std.testing.expectEqual(ToggleAction.turn_off, voiceToggleAction(true, false, 0));
    try std.testing.expectEqual(ToggleAction.turn_on, voiceToggleAction(false, false, 1));
    try std.testing.expect(!voiceKeyStopsSpeech(0x12, true));
    try std.testing.expect(!voiceKeyStopsSpeech('V', true));
    try std.testing.expect(voiceKeyStopsSpeech('A', false));
    try std.testing.expectEqual(Decision.drop, voiceUtteranceDecision(.{ .echo = true }));
    try std.testing.expectEqual(Decision.insert_only, voiceUtteranceDecision(.{ .consumed = true }));
    try std.testing.expectEqual(Decision.insert_only, voiceUtteranceDecision(.{ .changed_tab = true }));
    try std.testing.expectEqual(Decision.insert_only, voiceUtteranceDecision(.{ .typed = true }));
    try std.testing.expectEqual(Decision.send, voiceUtteranceDecision(.{}));
}

pub fn pcmFrameRms(samples: []align(1) const i16) f32 {
    if (samples.len == 0) return 0;
    var sum: f64 = 0;
    for (samples) |s| {
        const f: f64 = @floatFromInt(s);
        sum += f * f;
    }
    return @floatCast(@sqrt(sum / @as(f64, @floatFromInt(samples.len))));
}

pub const VadState = struct {
    speech_ms: u32 = 0,
    silence_ms: u32 = 0,
    total_ms: u32 = 0,
    has_spoken: bool = false,
};

pub const VadDecision = enum { continue_listening, stop_had_speech, stop_no_speech };

const VAD_RMS_THRESHOLD: f32 = 500.0;
const VAD_SPEECH_MS_TO_ARM: u32 = 200;
const VAD_SILENCE_MS_TO_STOP: u32 = 1200;
const VAD_NO_SPEECH_TIMEOUT_MS: u32 = 8000;
const VAD_HARD_CAP_MS: u32 = 60000;

pub fn vadStep(state: *VadState, frame_rms: f32, frame_ms: u32) VadDecision {
    state.total_ms +|= frame_ms;
    if (frame_rms >= VAD_RMS_THRESHOLD) {
        state.speech_ms +|= frame_ms;
        state.silence_ms = 0;
        if (state.speech_ms >= VAD_SPEECH_MS_TO_ARM) state.has_spoken = true;
    } else {
        state.speech_ms = 0;
        if (state.has_spoken) state.silence_ms +|= frame_ms;
    }
    if (state.has_spoken and state.silence_ms >= VAD_SILENCE_MS_TO_STOP) return .stop_had_speech;
    if (!state.has_spoken and state.total_ms >= VAD_NO_SPEECH_TIMEOUT_MS) return .stop_no_speech;
    if (state.total_ms >= VAD_HARD_CAP_MS) return if (state.has_spoken) .stop_had_speech else .stop_no_speech;
    return .continue_listening;
}

test "vad stops after silence following speech" {
    var state = VadState{};
    try std.testing.expectEqual(VadDecision.continue_listening, vadStep(&state, 2000, 100));
    try std.testing.expectEqual(VadDecision.continue_listening, vadStep(&state, 2000, 100));
    try std.testing.expectEqual(VadDecision.continue_listening, vadStep(&state, 2000, 100));
    try std.testing.expect(state.has_spoken);
    var i: u32 = 0;
    while (i < 11) : (i += 1) {
        try std.testing.expectEqual(VadDecision.continue_listening, vadStep(&state, 0, 100));
    }
    try std.testing.expectEqual(VadDecision.stop_had_speech, vadStep(&state, 0, 100));
}

test "vad times out with no speech at all" {
    var state = VadState{};
    var i: u32 = 0;
    while (i < 79) : (i += 1) {
        try std.testing.expectEqual(VadDecision.continue_listening, vadStep(&state, 0, 100));
    }
    try std.testing.expectEqual(VadDecision.stop_no_speech, vadStep(&state, 0, 100));
    try std.testing.expect(!state.has_spoken);
}

test "vad hard caps at 60s even mid speech" {
    var state = VadState{};
    var i: u32 = 0;
    var decision: VadDecision = .continue_listening;
    while (i < 600) : (i += 1) {
        decision = vadStep(&state, 2000, 100);
    }
    try std.testing.expectEqual(VadDecision.stop_had_speech, decision);
}

pub fn voiceScreenFallbackShouldSpeak(
    state: VoiceState,
    reply_len: usize,
    reply_hash: u64,
    last_spoken_hash: u64,
    stable_ms: u64,
    working_visible: bool,
) bool {
    if (state != .waiting and state != .idle) return false;
    if (reply_len == 0) return false;
    if (reply_hash == last_spoken_hash) return false;
    if (working_visible) return false;
    return stable_ms >= 2500;
}

test "voiceScreenFallbackShouldSpeak only fires on a stable, unspoken, finished reply" {
    try std.testing.expect(voiceScreenFallbackShouldSpeak(.waiting, 40, 111, 222, 2500, false));
    try std.testing.expect(voiceScreenFallbackShouldSpeak(.idle, 40, 111, 222, 3000, false));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.speaking, 40, 111, 222, 3000, false));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.listening, 40, 111, 222, 3000, false));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.waiting, 0, 111, 222, 3000, false));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.waiting, 40, 111, 111, 3000, false));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.waiting, 40, 111, 222, 3000, true));
    try std.testing.expect(!voiceScreenFallbackShouldSpeak(.waiting, 40, 111, 222, 1000, false));
}
