const std = @import("std");

pub const MAX_NAME: usize = 48;
pub const MAX_WORKERS: usize = 6;
pub const MAX_STEPS: usize = 5;

pub const Source = enum { unknown, plan_pick, subagent };

fn copyInto(buffer: anytype, len: *usize, value: []const u8) void {
    const n = @min(value.len, buffer.len);
    @memcpy(buffer[0..n], value[0..n]);
    len.* = n;
}

pub const Worker = struct {
    id: [MAX_NAME]u8 = @splat(0),
    id_len: usize = 0,
    harness: [24]u8 = @splat(0),
    harness_len: usize = 0,
    model: [24]u8 = @splat(0),
    model_len: usize = 0,
    label: [MAX_NAME]u8 = @splat(0),
    label_len: usize = 0,
    started_at: u64 = 0,
    source: Source = .unknown,

    pub fn idSlice(self: *const Worker) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn harnessSlice(self: *const Worker) []const u8 {
        return self.harness[0..self.harness_len];
    }

    pub fn modelSlice(self: *const Worker) []const u8 {
        return self.model[0..self.model_len];
    }

    pub fn labelSlice(self: *const Worker) []const u8 {
        return self.label[0..self.label_len];
    }

    pub fn set(self: *Worker, id: []const u8, harness: []const u8, model: []const u8, label: []const u8, started_at: u64, source: Source) void {
        copyInto(&self.id, &self.id_len, id);
        copyInto(&self.harness, &self.harness_len, harness);
        copyInto(&self.model, &self.model_len, model);
        copyInto(&self.label, &self.label_len, label);
        self.started_at = started_at;
        self.source = source;
    }

    pub fn name(self: *const Worker, out: []u8) []const u8 {
        var w = Writer{ .out = out };
        if (self.harness_len > 0) w.add(self.harnessSlice());
        if (self.model_len > 0) {
            if (w.len > 0) w.add("-");
            w.add(self.modelSlice());
        }
        return w.done();
    }
};

pub const Step = struct {
    text: [MAX_NAME]u8 = @splat(0),
    text_len: usize = 0,
    running: bool = false,

    pub fn textSlice(self: *const Step) []const u8 {
        return self.text[0..self.text_len];
    }
};

pub const Activity = struct {
    running: bool = false,
    step: [MAX_NAME]u8 = @splat(0),
    step_len: usize = 0,
    workers: [MAX_WORKERS]Worker = @splat(Worker{}),
    worker_count: usize = 0,
    steps: [MAX_STEPS]Step = @splat(Step{}),
    step_count: usize = 0,

    pub fn stepSlice(self: *const Activity) []const u8 {
        return self.step[0..self.step_len];
    }

    pub fn visible(self: *const Activity) bool {
        return self.running or self.worker_count > 0;
    }

    pub fn setStep(self: *Activity, value: []const u8) void {
        copyInto(&self.step, &self.step_len, value);
    }

    pub fn pushStep(self: *Activity, value: []const u8, running: bool) void {
        if (self.step_count >= MAX_STEPS) {
            std.mem.copyForwards(Step, self.steps[0 .. MAX_STEPS - 1], self.steps[1..MAX_STEPS]);
            self.step_count = MAX_STEPS - 1;
        }
        var step = Step{ .running = running };
        copyInto(&step.text, &step.text_len, value);
        self.steps[self.step_count] = step;
        self.step_count += 1;
    }

    pub fn pushWorker(self: *Activity, worker: Worker) void {
        if (self.worker_count >= MAX_WORKERS) return;
        self.workers[self.worker_count] = worker;
        self.worker_count += 1;
    }

    pub fn expandedRows(self: *const Activity) usize {
        return self.step_count + self.worker_count;
    }
};

const Writer = struct {
    out: []u8,
    len: usize = 0,

    fn add(self: *Writer, text: []const u8) void {
        if (self.len >= self.out.len) return;
        const n = @min(self.out.len - self.len, text.len);
        @memcpy(self.out[self.len..][0..n], text[0..n]);
        self.len += n;
    }

    fn addInt(self: *Writer, value: u64) void {
        var buffer: [20]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return;
        self.add(text);
    }

    fn done(self: *const Writer) []const u8 {
        return self.out[0..self.len];
    }
};

pub fn elapsed(started_at: u64, now: u64, out: []u8) []const u8 {
    var w = Writer{ .out = out };
    const millis = now -| started_at;
    const seconds = millis / 1000;
    if (seconds < 60) {
        w.addInt(seconds);
        w.add("s");
    } else if (seconds < 3600) {
        w.addInt(seconds / 60);
        w.add("m");
    } else {
        w.addInt(seconds / 3600);
        w.add("h ");
        w.addInt((seconds % 3600) / 60);
        w.add("m");
    }
    return w.done();
}

pub fn workerNames(activity: *const Activity, out: []u8) []const u8 {
    var w = Writer{ .out = out };
    var name_buffer: [32]u8 = undefined;
    var shown: usize = 0;
    for (activity.workers[0..activity.worker_count]) |*worker| {
        if (shown >= 2) break;
        const name = worker.name(&name_buffer);
        if (name.len == 0) continue;
        if (shown > 0) w.add(", ");
        w.add(name);
        shown += 1;
    }
    return w.done();
}

fn workerCount(w: *Writer, count: usize, plural: []const u8) void {
    w.addInt(count);
    w.add(" ");
    w.add(plural);
    if (count != 1) w.add("s");
}

pub fn pillText(activity: *const Activity, out: []u8) []const u8 {
    var w = Writer{ .out = out };
    if (activity.running) {
        w.add(if (activity.step_len > 0) activity.stepSlice() else "Working");
        w.add("…");
    }
    if (activity.worker_count > 0) {
        if (w.len > 0) w.add(" · ");
        workerCount(&w, activity.worker_count, "worker");
        var names_buffer: [80]u8 = undefined;
        const names = workerNames(activity, &names_buffer);
        if (names.len > 0) {
            w.add(" · ");
            w.add(names);
        }
    }
    return w.done();
}

pub fn lineText(activity: *const Activity, out: []u8) []const u8 {
    var w = Writer{ .out = out };
    if (activity.running) {
        w.add("Working");
        if (activity.step_len > 0) {
            w.add(" · ");
            w.add(activity.stepSlice());
        }
    }
    if (activity.worker_count > 0) {
        if (w.len > 0) w.add(" · ");
        workerCount(&w, activity.worker_count, "sub-worker");
    }
    return w.done();
}

pub fn workerLine(worker: *const Worker, now: u64, out: []u8) []const u8 {
    var w = Writer{ .out = out };
    var name_buffer: [32]u8 = undefined;
    var span_buffer: [24]u8 = undefined;
    const name = worker.name(&name_buffer);
    if (name.len > 0) w.add(name);
    if (worker.label_len > 0) {
        if (w.len > 0) w.add(" · ");
        w.add(worker.labelSlice());
    }
    if (worker.started_at > 0) {
        if (w.len > 0) w.add(" · ");
        w.add(elapsed(worker.started_at, now, &span_buffer));
    }
    return w.done();
}

test "MUBO-591 a working session shows its step and the worker summary" {
    var activity = Activity{ .running = true };
    activity.setStep("Editing");
    var worker = Worker{};
    worker.set("plan-pick:a", "pi", "deepseek", "w-2839c", 1000, .plan_pick);
    activity.pushWorker(worker);
    var second = Worker{};
    second.set("plan-pick:b", "hax", "codex", "review the queue", 2000, .plan_pick);
    activity.pushWorker(second);
    var text: [96]u8 = undefined;
    try std.testing.expectEqualStrings("Editing… · 2 workers · pi-deepseek, hax-codex", pillText(&activity, &text));
    var line: [96]u8 = undefined;
    try std.testing.expectEqualStrings("Working · Editing · 2 sub-workers", lineText(&activity, &line));
}

test "MUBO-591 an idle session with live workers still shows a pill" {
    var activity = Activity{ .running = false };
    var worker = Worker{};
    worker.set("plan-pick:a", "plan-pick", "opus", "w-1", 1000, .plan_pick);
    activity.pushWorker(worker);
    try std.testing.expect(activity.visible());
    var text: [96]u8 = undefined;
    try std.testing.expectEqualStrings("1 worker · plan-pick-opus", pillText(&activity, &text));
    var line: [96]u8 = undefined;
    try std.testing.expectEqualStrings("1 sub-worker", lineText(&activity, &line));
}

test "MUBO-591 an idle session with no workers shows nothing" {
    const activity = Activity{};
    try std.testing.expect(!activity.visible());
    var text: [96]u8 = undefined;
    try std.testing.expectEqualStrings("", pillText(&activity, &text));
    try std.testing.expectEqualStrings("", lineText(&activity, &text));
}

test "MUBO-591 a worker line carries its harness, task and elapsed time" {
    var worker = Worker{};
    worker.set("tool-1", "pi", "deepseek", "audit the board", 1000, .subagent);
    var out: [64]u8 = undefined;
    try std.testing.expectEqualStrings("pi-deepseek · audit the board · 2m", workerLine(&worker, 121000, &out));
    try std.testing.expectEqualStrings("7s", elapsed(1000, 8000, &out));
    try std.testing.expectEqualStrings("1h 4m", elapsed(0, 3_860_000, &out));
}

test "MUBO-591 the expanded list keeps the newest five steps and six workers" {
    var activity = Activity{};
    for (0..8) |index| {
        var text_buffer: [16]u8 = undefined;
        const label = std.fmt.bufPrint(&text_buffer, "step-{d}", .{index}) catch unreachable;
        activity.pushStep(label, index == 7);
    }
    try std.testing.expectEqual(MAX_STEPS, activity.step_count);
    try std.testing.expectEqualStrings("step-3", activity.steps[0].textSlice());
    try std.testing.expect(activity.steps[MAX_STEPS - 1].running);
    for (0..9) |index| {
        var worker = Worker{};
        var id_buffer: [16]u8 = undefined;
        const id = std.fmt.bufPrint(&id_buffer, "worker-{d}", .{index}) catch unreachable;
        worker.set(id, "pi", "deepseek", "", 0, .subagent);
        activity.pushWorker(worker);
    }
    try std.testing.expectEqual(MAX_WORKERS, activity.worker_count);
    try std.testing.expectEqual(MAX_STEPS + MAX_WORKERS, activity.expandedRows());
}
