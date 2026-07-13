//! Gzip compression using std.compress.flate.
//!
//! Streaming: reads file in 64KB chunks, compresses incrementally.

const std = @import("std");
const flate = std.compress.flate;

const CHUNK_SIZE = 64 * 1024;

/// Compress a single file to gzip format with streaming I/O.
pub fn compressFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    src_dir: std.Io.Dir,
    src_path: []const u8,
    dest_dir: []const u8,
    level: u4,
) !CompressResult {
    // Open source file for positional chunked reading
    const src_file = try src_dir.openFile(io, src_path, .{});
    defer src_file.close(io);

    const stat = try src_file.stat(io);
    const src_size = stat.size;

    // Prepare destination path
    const src_basename = std.fs.path.basename(src_path);
    const dest_name = try std.fmt.allocPrint(allocator, "{s}.gz", .{src_basename});
    defer allocator.free(dest_name);

    const dest_path = try std.fs.path.join(allocator, &.{ dest_dir, dest_name });
    defer allocator.free(dest_path);

    if (std.fs.path.dirname(dest_path)) |parent| {
        cwd.createDirPath(io, parent) catch {};
    }

    const dest_file = try cwd.createFile(io, dest_path, .{});
    defer dest_file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer = dest_file.writer(io, &wbuf);

    var cbuf: [flate.max_window_len]u8 = undefined;
    var compress = try flate.Compress.init(&writer.interface, &cbuf, .gzip, levelToOptions(level));

    // Stream chunks: read → compress → write
    // Use a small file optimization: for files < CHUNK_SIZE, read all at once
    if (src_size <= CHUNK_SIZE and src_size > 0) {
        const data = try src_dir.readFileAlloc(io, src_path, allocator, .unlimited);
        defer allocator.free(data);
        try compress.writer.writeAll(data);
    } else {
        var chunk: [CHUNK_SIZE]u8 = undefined;
        var offset: u64 = 0;
        while (offset < src_size) {
            const remaining = src_size - offset;
            const to_read = @min(CHUNK_SIZE, remaining);
            const bufs = [_][]u8{chunk[0..to_read]};
            const n = try src_file.readPositional(io, &bufs, offset);
            if (n == 0) break;
            try compress.writer.writeAll(chunk[0..n]);
            offset += n;
        }
    }

    try compress.finish();
    try writer.interface.flush();

    const dest_stat = try dest_file.stat(io);

    return CompressResult{
        .src_path = src_path,
        .dest_path = dest_path,
        .src_size = src_size,
        .dest_size = dest_stat.size,
    };
}

fn levelToOptions(level: u4) flate.Compress.Options {
    return switch (level) {
        1 => flate.Compress.Options.level_1,
        2 => flate.Compress.Options.level_2,
        3 => flate.Compress.Options.level_3,
        4 => flate.Compress.Options.level_4,
        5 => flate.Compress.Options.level_5,
        6 => flate.Compress.Options.level_6,
        7 => flate.Compress.Options.level_7,
        8 => flate.Compress.Options.level_8,
        9 => flate.Compress.Options.level_9,
        else => flate.Compress.Options.default,
    };
}

pub const CompressResult = struct {
    src_path: []const u8,
    dest_path: []const u8,
    src_size: u64,
    dest_size: u64,
};

test "compress and verify a simple file" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_data = "Hello, Zig! This is a test file for gzip compression.";

    try tmp.dir.writeFile(tio, .{ .sub_path = "test.txt", .data = test_data });
    try tmp.dir.createDirPath(tio, "out");

    const result = try compressFile(gpa, tio, tmp.dir, tmp.dir, "test.txt", "out", 6);
    defer gpa.free(result.dest_path);

    try std.testing.expect(result.src_size > 0);
    try std.testing.expect(result.dest_size > 0);
    _ = try tmp.dir.openFile(tio, result.dest_path, .{});
}

test "compression reduces size for text" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_data = "Hello World! " ** 100;

    try tmp.dir.writeFile(tio, .{ .sub_path = "repeated.txt", .data = test_data });
    try tmp.dir.createDirPath(tio, "out");

    const result = try compressFile(gpa, tio, tmp.dir, tmp.dir, "repeated.txt", "out", 6);
    defer gpa.free(result.dest_path);

    try std.testing.expect(result.dest_size < result.src_size);
    try std.testing.expect(result.dest_size < test_data.len / 2);
}
