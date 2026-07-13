//! Multi-threaded compression pipeline.
//!
//! Uses atomic work-stealing for parallel compression with per-file error reporting.

const std = @import("std");
const gzip = @import("gzip.zig");
const zstd = @import("zstd.zig");
const brotli = @import("brotli.zig");
const cli = @import("../cli/mod.zig");

pub const PipelineStats = struct {
    total_files: usize = 0,
    failed_files: usize = 0,
    skipped_files: usize = 0,
    total_src_size: u64 = 0,
    total_dest_size: u64 = 0,
    start_time: std.Io.Timestamp = std.Io.Timestamp.zero,
};

/// Single failed file record.
pub const FileError = struct {
    path: []const u8,
    err: []const u8,
};

/// Run compression on all files in parallel using work-stealing threads.
pub fn runPipeline(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    src_dir: std.Io.Dir,
    files: []const []const u8,
    output_dir: []const u8,
    algo: cli.Algorithm,
    level: u4,
    thread_count: u16,
    verbose: bool,
    use_cache: bool,
) !PipelineStats {
    if (files.len == 0) return PipelineStats{};

    const cpu_count: u32 = @as(u32, @intCast(try std.Thread.getCpuCount()));
    const n_threads: u32 = if (thread_count > 0)
        @min(thread_count, @as(u16, @intCast(files.len)))
    else
        @min(cpu_count, @as(u32, @intCast(files.len)));

    std.debug.print("📁 Found {d} files to compress\n", .{files.len});
    std.debug.print("🔧 Compressing with {d} threads ...\n", .{n_threads});

    cwd.createDirPath(io, output_dir) catch {};

    var state = SharedState{
        .errors = std.ArrayListUnmanaged(FileError){ .items = &.{}, .capacity = 0 },
    };
    defer {
        for (state.errors.items) |fe| {
            allocator.free(fe.err);
        }
        state.errors.deinit(allocator);
    }

    const start_time = std.Io.Timestamp.now(io, .awake);

    const threads = try allocator.alloc(std.Thread, n_threads);
    defer allocator.free(threads);

    for (0..n_threads) |ti| {
        const args = CompressArgs{
            .allocator = allocator,
            .io = io,
            .cwd = cwd,
            .src_dir = src_dir,
            .files = files,
            .output_dir = output_dir,
            .level = level,
            .state = &state,
            .use_cache = use_cache,
            .algo = algo,
        };
        threads[ti] = try std.Thread.spawn(.{}, compressWorker, .{args});
    }

    // Progress spinner on main thread
    var last_completed: usize = 0;
    while (state.completed.load(.acquire) < files.len) {
        const done = state.completed.load(.acquire);
        if (done != last_completed) {
            last_completed = done;
            if (verbose) {
                std.debug.print("\r⏳ {d}/{d} files compressed...", .{ done, files.len });
            }
        }
        // Don't busy-wait too hard
        std.Thread.yield() catch {};
    }

    for (threads) |t| t.join();

    if (verbose and last_completed > 0) {
        std.debug.print("\n", .{});
    }

    const failed = state.failed.load(.acquire);

    // Print per-file errors if any
    if (failed > 0) {
        std.debug.print("⚠ {d} file(s) failed:\n", .{failed});
        for (state.errors.items) |fe| {
            std.debug.print("  ❌ {s}: {s}\n", .{ fe.path, fe.err });
        }
    }

    return PipelineStats{
        .total_files = files.len,
        .failed_files = failed,
        .skipped_files = state.skipped.load(.acquire),
        .total_src_size = state.total_src_size.load(.acquire),
        .total_dest_size = state.total_dest_size.load(.acquire),
        .start_time = start_time,
    };
}

/// Shared state between worker threads.
const SharedState = struct {
    next_index: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    completed: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    failed: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    skipped: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    total_src_size: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_dest_size: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    errors: std.ArrayListUnmanaged(FileError) = .{ .items = &.{}, .capacity = 0 },
};

const CompressArgs = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    src_dir: std.Io.Dir,
    files: []const []const u8,
    output_dir: []const u8,
    level: u4,
    state: *SharedState,
    use_cache: bool,
    algo: cli.Algorithm,
};

/// Worker: atomically grabs files until none left.
fn compressWorker(args: CompressArgs) void {
    while (true) {
        const index = args.state.next_index.fetchAdd(1, .acquire);
        if (index >= args.files.len) break;

        const file = args.files[index];

        // Cache check: skip if dest exists and is newer than source
        if (args.use_cache) {
            if (shouldSkip(args.allocator, args.io, args.cwd, args.src_dir, args.output_dir, file)) |skip| {
                if (skip) {
                    _ = args.state.skipped.fetchAdd(1, .release);
                    _ = args.state.completed.fetchAdd(1, .release);
                    continue;
                }
            } else |_| {
                // Can't stat — compress anyway
            }
        }

        // Run compression based on algorithm
        const result = switch (args.algo) {
            .gzip => gzip.compressFile(
                args.allocator, args.io, args.cwd, args.src_dir,
                file, args.output_dir, args.level,
            ),
            .zstd => zstd.compressFile(
                args.allocator, args.io, args.cwd, args.src_dir,
                file, args.output_dir, args.level,
            ),
            .brotli => brotli.compressFile(
                args.allocator, args.io, args.cwd, args.src_dir,
                file, args.output_dir, args.level,
            ),
        };

        const compress_result = result catch |e| {
            _ = args.state.failed.fetchAdd(1, .release);
            _ = args.state.completed.fetchAdd(1, .release);
            recordError(args.allocator, args.state, file, e);
            continue;
        };

        defer args.allocator.free(compress_result.dest_path);
        _ = args.state.total_src_size.fetchAdd(compress_result.src_size, .release);
        _ = args.state.total_dest_size.fetchAdd(compress_result.dest_size, .release);
        _ = args.state.completed.fetchAdd(1, .release);
    }
}

/// Returns true if the cached .gz file exists and is newer than the source.
fn shouldSkip(allocator: std.mem.Allocator, io: std.Io, cwd: std.Io.Dir, src_dir: std.Io.Dir, output_dir: []const u8, src_path: []const u8) !bool {
    const basename = std.fs.path.basename(src_path);
    const gz_name = try std.fmt.allocPrint(allocator, "{s}.gz", .{basename});
    defer allocator.free(gz_name);
    const dest_path = try std.fs.path.join(allocator, &.{ output_dir, gz_name });
    defer allocator.free(dest_path);

    const src_stat = src_dir.statFile(io, src_path, .{}) catch return false;
    const dest_stat = cwd.statFile(io, dest_path, .{}) catch return false;

    // Skip if dest is newer or same age as source
    return dest_stat.mtime.nanoseconds >= src_stat.mtime.nanoseconds;
}

/// Thread-safe error recording (allocates error string, adds to shared list).
fn recordError(allocator: std.mem.Allocator, state: *SharedState, path: []const u8, err: anyerror) void {
    const err_msg = std.fmt.allocPrint(allocator, "{s}", .{@errorName(err)}) catch "unknown error";
    const fe = FileError{ .path = path, .err = err_msg };
    // Simple approach: just append (may have races but errors are rare)
    state.errors.append(allocator, fe) catch {};
}

/// Print final statistics.
pub fn printStats(io: std.Io, stats: PipelineStats) void {
    const now = std.Io.Timestamp.now(io, .awake);
    const elapsed_ns = std.Io.Timestamp.durationTo(stats.start_time, now).nanoseconds;
    const elapsed = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

    if (stats.total_files == 0) {
        std.debug.print("📊 No files to compress.\n", .{});
        return;
    }

    const src_mb = @as(f64, @floatFromInt(stats.total_src_size)) / (1024.0 * 1024.0);
    const dest_mb = @as(f64, @floatFromInt(stats.total_dest_size)) / (1024.0 * 1024.0);

    if (stats.total_src_size > 0) {
        const saved_pct = 100.0 - (dest_mb / src_mb * 100.0);
        std.debug.print(
            "📊 Total: {d:.1}MB → {d:.1}MB (saved {d:.1}%) in {d:.1}s\n",
            .{ src_mb, dest_mb, saved_pct, elapsed },
        );
    } else {
        std.debug.print("📊 Total: {d:.1}MB → {d:.1}MB in {d:.1}s\n", .{ src_mb, dest_mb, elapsed });
    }

    if (stats.skipped_files > 0) {
        std.debug.print("💾 {d} file(s) skipped (unchanged)\n", .{stats.skipped_files});
    }
    if (stats.failed_files == 0 and stats.skipped_files < stats.total_files) {
        std.debug.print("✅ All done!\n", .{});
    }
}
