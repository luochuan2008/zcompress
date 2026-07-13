//! Terminal progress bar for zcompress.
//!
//! Renders a simple text-based progress bar to stderr using carriage return
//! to update in place. Non-thread-safe — call from single thread only.

const std = @import("std");

const BAR_WIDTH: usize = 40;

pub const Progress = struct {
    total: usize,
    current: usize,
    start_time: std.Io.Timestamp,
    last_update_time: std.Io.Timestamp,
    bar_chars: [BAR_WIDTH]u8,

    pub fn init(io: std.Io, total: usize) Progress {
        const now = std.Io.Timestamp.now(io, .awake);
        var bar: [BAR_WIDTH]u8 = undefined;
        @memset(&bar, ' ');
        return Progress{
            .total = total,
            .current = 0,
            .start_time = now,
            .last_update_time = now,
            .bar_chars = bar,
        };
    }

    /// Increment progress by n items and redraw the progress bar.
    pub fn advance(self: *Progress, io: std.Io, n: usize) void {
        self.current += n;
        self.draw(io);
    }

    /// Redraw the progress bar. Throttled to ~100ms between draws.
    pub fn draw(self: *Progress, io: std.Io) void {
        const now = std.Io.Timestamp.now(io, .awake);
        const since_last = std.Io.Timestamp.durationTo(self.last_update_time, now).nanoseconds;
        if (since_last < 100 * std.time.ns_per_ms and self.current < self.total) return;
        self.last_update_time = now;

        const pct: f64 = if (self.total > 0)
            @as(f64, @floatFromInt(self.current)) / @as(f64, @floatFromInt(self.total)) * 100.0
        else
            100.0;

        const filled = if (self.total > 0)
            @as(usize, @intFromFloat(@as(f64, @floatFromInt(self.current)) / @as(f64, @floatFromInt(self.total)) * BAR_WIDTH))
        else
            BAR_WIDTH;

        var bar_buf: [BAR_WIDTH]u8 = undefined;
        @memset(bar_buf[0..filled], '█');
        @memset(bar_buf[filled..], '░');

        const elapsed_ns = std.Io.Timestamp.durationTo(self.start_time, now).nanoseconds;
        const elapsed = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

        std.debug.print(
            "\r🔄 [{s}] {d: >3.0}% ({d}/{d}) — {d:.1}s",
            .{ bar_buf, pct, self.current, self.total, elapsed },
        );
    }

    /// Print the final completion line and move to new line.
    pub fn finish(self: *Progress, io: std.Io) void {
        const now = std.Io.Timestamp.now(io, .awake);
        const elapsed_ns = std.Io.Timestamp.durationTo(self.start_time, now).nanoseconds;
        const elapsed = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

        std.debug.print(
            "\r✅ [{s}] 100% ({d}/{d}) — {d:.1}s\n",
            .{ "█" ** BAR_WIDTH, self.total, self.total, elapsed },
        );
    }
};

test "progress init and advance" {
    const tio = std.testing.io;
    var p = Progress.init(tio, 100);
    try std.testing.expectEqual(@as(usize, 0), p.current);
    try std.testing.expectEqual(@as(usize, 100), p.total);

    p.advance(tio, 10);
    try std.testing.expectEqual(@as(usize, 10), p.current);
}
